-- Reward points: technicians earn for on-time arrival and job completion,
-- customers earn for prompt payment and leaving a review. Points spend on
-- non-monetary visibility boosts (top of a customer's bid list / top of
-- a technician's job feed) -- deliberately not a discount on real money,
-- which would need InnSelf to absorb a cost it doesn't currently collect
-- and adds payment-regulation surface neither side asked for.

alter table profiles add column if not exists reward_points int not null default 0;

-- reward_points joins is_verified/late_cancellations as a platform-only
-- column -- profiles_update_own (migration 001) would otherwise let a
-- user set their own balance directly.
create or replace function public.guard_platform_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('app.sync_platform_columns', true), 'off') <> 'on' then
    new.is_verified := old.is_verified;
    new.late_cancellations := old.late_cancellations;
    new.reward_points := old.reward_points;
  end if;
  return new;
end;
$$;

-- Audit ledger -- profiles.reward_points is the running total, this is
-- how it got there. No insert/update/delete policy: every row comes from
-- award_points/spend_points below, never a direct client write.
create table if not exists points_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id),
  delta int not null,
  reason text not null check (reason in (
    'on_time_arrival', 'job_completed', 'prompt_payment', 'review_left',
    'boost_bid', 'boost_job'
  )),
  job_id uuid references jobs(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table points_transactions enable row level security;

drop policy if exists "points_transactions_select_own" on points_transactions;
create policy "points_transactions_select_own" on points_transactions
  for select using (profile_id = auth.uid());

-- Not granted to authenticated -- only ever called from inside another
-- SECURITY DEFINER function (a trigger below, or spend_points), which
-- runs as this function's owner and can call it regardless of grants.
create or replace function public.award_points(
  p_profile_id uuid, p_delta int, p_reason text, p_job_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into points_transactions (profile_id, delta, reason, job_id)
  values (p_profile_id, p_delta, p_reason, p_job_id);
  perform set_config('app.sync_platform_columns', 'on', true);
  update profiles set reward_points = reward_points + p_delta where id = p_profile_id;
  perform set_config('app.sync_platform_columns', 'off', true);
end;
$$;

-- Same shape as award_points but checks the balance first and raises
-- instead of allowing it to go negative -- points_transactions.delta
-- being a plain int has no floor of its own.
create or replace function public.spend_points(
  p_profile_id uuid, p_amount int, p_reason text, p_job_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
begin
  select reward_points into v_balance from profiles where id = p_profile_id for update;
  if v_balance < p_amount then
    raise exception 'Not enough points';
  end if;
  perform public.award_points(p_profile_id, -p_amount, p_reason, p_job_id);
end;
$$;

-- Technician side: on-time arrival + job completion. One trigger checks
-- both transitions since they're both plain client-side jobs.status
-- updates (JobsRepository.startEnRoute/startJob/complete_job_with_code),
-- not funneled through a single RPC.
create or replace function public.award_job_transition_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_technician_id uuid;
begin
  if new.status = 'in_progress' and old.status = 'en_route'
     and old.eta_at is not null and now() <= old.eta_at then
    select public.accepted_bid_technician(new.id) into v_technician_id;
    if v_technician_id is not null then
      perform public.award_points(v_technician_id, 20, 'on_time_arrival', new.id);
    end if;
  end if;

  if new.status = 'completed' and old.status is distinct from 'completed' then
    select public.accepted_bid_technician(new.id) into v_technician_id;
    if v_technician_id is not null then
      perform public.award_points(v_technician_id, 30, 'job_completed', new.id);
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_award_job_transition_points on jobs;
create trigger trg_award_job_transition_points
  after update on jobs
  for each row execute function public.award_job_transition_points();

-- Customer side: paying within 24h of confirming the job done.
create or replace function public.award_payment_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_confirmed_at timestamptz;
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    select customer_confirmed_at into v_confirmed_at from jobs where id = new.job_id;
    if v_confirmed_at is not null and now() <= v_confirmed_at + interval '24 hours' then
      perform public.award_points(new.customer_id, 15, 'prompt_payment', new.job_id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_award_payment_points on payments;
create trigger trg_award_payment_points
  after update on payments
  for each row execute function public.award_payment_points();

-- Customer side: leaving a review. reviewer_role distinguishes this from
-- a technician reviewing their customer (migration 007), which doesn't
-- earn -- only the customer-initiated review does.
create or replace function public.award_review_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.reviewer_role = 'customer' then
    perform public.award_points(new.customer_id, 10, 'review_left', new.job_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_award_review_points on reviews;
create trigger trg_award_review_points
  after insert on reviews
  for each row execute function public.award_review_points();

-- ============================================================
-- Spending: visibility boosts. Non-null = boosted, no expiry needed --
-- both bids and jobs naturally leave the "pending"/"open" pool once
-- decided, which is the only state boosting matters in anyway.
-- ============================================================
alter table bids add column if not exists boosted_at timestamptz;
alter table jobs add column if not exists boosted_at timestamptz;

create or replace function public.boost_bid(p_bid_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_technician_id uuid;
  v_status text;
begin
  select technician_id, status into v_technician_id, v_status from bids where id = p_bid_id;
  if v_technician_id is null or v_technician_id <> auth.uid() then
    raise exception 'Not authorized to boost this bid';
  end if;
  if v_status <> 'pending' then
    raise exception 'Only a pending bid can be boosted';
  end if;
  perform public.spend_points(auth.uid(), 50, 'boost_bid', (select job_id from bids where id = p_bid_id));
  update bids set boosted_at = now() where id = p_bid_id;
end;
$$;

grant execute on function public.boost_bid(uuid) to authenticated;

create or replace function public.boost_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_status text;
begin
  select customer_id, status into v_customer_id, v_status from jobs where id = p_job_id;
  if v_customer_id is null or v_customer_id <> auth.uid() then
    raise exception 'Not authorized to boost this job';
  end if;
  if v_status <> 'open' then
    raise exception 'Only an open job can be boosted';
  end if;
  perform public.spend_points(auth.uid(), 50, 'boost_job', p_job_id);
  update jobs set boosted_at = now() where id = p_job_id;
end;
$$;

grant execute on function public.boost_job(uuid) to authenticated;
