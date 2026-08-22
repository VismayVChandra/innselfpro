-- Wave 7: KYC status + verified badge, cancel/reschedule after
-- acceptance, and an admin surface. Idempotent throughout -- see
-- migration 006's header comment for why.

-- ============================================================
-- 7.1 KYC status and a verified badge
-- ============================================================
alter table technician_kyc add column if not exists status text not null default 'pending';
alter table technician_kyc drop constraint if exists technician_kyc_status_check;
alter table technician_kyc add constraint technician_kyc_status_check
  check (status in ('pending','verified','rejected'));
alter table technician_kyc add column if not exists verified_at timestamptz;
alter table technician_kyc add column if not exists rejection_reason text;

-- technician_kyc stays owner-only by design (it holds ID documents), so
-- the customer-facing signal is mirrored onto profiles instead, which is
-- already readable by any authenticated user (profiles_select_all).
-- Only the boolean crosses over -- never the document or ID number.
alter table profiles add column if not exists is_verified boolean not null default false;

-- Late cancellations after a technician was already assigned (7.2).
-- Visible on a profile so the signal exists without being punitive.
alter table profiles add column if not exists late_cancellations int not null default 0;

-- profiles_update_own (migration 001) lets a user update their own
-- profile row -- which now includes is_verified and late_cancellations.
-- Without this guard a technician could simply mark themselves verified,
-- or reset their own cancellation count. Both columns are
-- platform-controlled: this pins them to their existing values on any
-- ordinary update, and the trigger functions that legitimately change
-- them set app.sync_platform_columns first to opt out.
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
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_platform_profile_columns on profiles;
create trigger trg_guard_platform_profile_columns
  before update on profiles
  for each row execute function public.guard_platform_profile_columns();

create or replace function public.sync_profile_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.sync_platform_columns', 'on', true);
  update profiles
  set is_verified = (new.status = 'verified')
  where id = new.profile_id;
  perform set_config('app.sync_platform_columns', 'off', true);
  return new;
end;
$$;

drop trigger if exists trg_sync_profile_verification on technician_kyc;
create trigger trg_sync_profile_verification
  after insert or update of status on technician_kyc
  for each row execute function public.sync_profile_verification();

-- Stamps verified_at alongside the status change, so an admin approving
-- a technician doesn't have to remember to set both.
create or replace function public.stamp_kyc_verified_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'verified' and old.status is distinct from 'verified' then
    new.verified_at := now();
  elsif new.status <> 'verified' then
    new.verified_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_kyc_verified_at on technician_kyc;
create trigger trg_stamp_kyc_verified_at
  before update on technician_kyc
  for each row execute function public.stamp_kyc_verified_at();

-- ============================================================
-- 7.2 Cancel and reschedule after acceptance
-- ============================================================
create table if not exists job_cancellations (
  job_id uuid primary key references jobs(id) on delete cascade,
  cancelled_by uuid not null references profiles(id),
  reason text not null,
  created_at timestamptz not null default now()
);

alter table job_cancellations enable row level security;

-- Rows are only ever written by cancel_job_with_reason (SECURITY
-- DEFINER, below), so there's no insert policy here on purpose -- same
-- reasoning as notifications. Both participants can read it.
drop policy if exists "job_cancellations_select" on job_cancellations;
create policy "job_cancellations_select" on job_cancellations
  for select using (
    cancelled_by = auth.uid()
    or public.job_belongs_to_customer(job_id, auth.uid())
    or public.accepted_bid_technician(job_id) = auth.uid()
  );

alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'new_bid','bid_accepted','job_completed','payment_received',
    'direct_request','new_job','new_message','technician_en_route',
    'job_expired','job_cancelled','job_rescheduled'
  ));

-- Blocks the transitions the doc rules out: once work has actually
-- started or finished, cancelling is not an ordinary change of plan any
-- more and belongs in the dispute flow. Enforced as a guard trigger for
-- the same reason as the wave 4.4 completion guard -- both participants
-- hold broad update policies on jobs, so tightening those is far more
-- fragile than refusing the transition itself.
create or replace function public.guard_job_cancellation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled'
     and old.status is distinct from 'cancelled'
     and old.status in ('in_progress','completed') then
    raise exception 'A job that has already started or finished cannot be cancelled -- flag an issue instead';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_job_cancellation on jobs;
create trigger trg_guard_job_cancellation
  before update on jobs
  for each row execute function public.guard_job_cancellation();

-- Records the reason and cancels in one statement, so a cancellation can
-- never end up with a reason row but no status change (or the reverse).
create or replace function public.cancel_job_with_reason(p_job_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_technician_id uuid;
  v_status text;
begin
  select customer_id, status into v_customer_id, v_status from jobs where id = p_job_id;
  v_technician_id := public.accepted_bid_technician(p_job_id);

  if auth.uid() is distinct from v_customer_id and auth.uid() is distinct from v_technician_id then
    raise exception 'Not authorized to cancel this job';
  end if;
  if v_status not in ('open','bid_accepted','en_route') then
    raise exception 'This job can no longer be cancelled';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required to cancel';
  end if;

  insert into job_cancellations (job_id, cancelled_by, reason)
  values (p_job_id, auth.uid(), trim(p_reason))
  on conflict (job_id) do update
    set cancelled_by = excluded.cancelled_by,
        reason = excluded.reason,
        created_at = now();

  update jobs set status = 'cancelled' where id = p_job_id;
end;
$$;

grant execute on function public.cancel_job_with_reason(uuid, text) to authenticated;

-- Notifies whichever participant did not do the cancelling, and counts
-- it against the canceller only when a technician was already assigned
-- (cancelling a job nobody has taken yet costs nobody anything).
create or replace function public.notify_job_cancelled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_technician_id uuid;
  v_recipient uuid;
begin
  select customer_id into v_customer_id from jobs where id = new.job_id;
  v_technician_id := public.accepted_bid_technician(new.job_id);
  v_recipient := case when new.cancelled_by = v_customer_id then v_technician_id else v_customer_id end;

  if v_recipient is not null then
    insert into notifications (user_id, type, job_id, message)
    values (v_recipient, 'job_cancelled', new.job_id, 'A job was cancelled: ' || new.reason);
  end if;

  if v_technician_id is not null then
    perform set_config('app.sync_platform_columns', 'on', true);
    update profiles
    set late_cancellations = late_cancellations + 1
    where id = new.cancelled_by;
    perform set_config('app.sync_platform_columns', 'off', true);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_job_cancelled on job_cancellations;
create trigger trg_notify_job_cancelled
  after insert on job_cancellations
  for each row execute function public.notify_job_cancelled();

-- Rescheduling needs no table and no RPC: both participants already hold
-- update policies on jobs, so it's a plain scheduled_for write plus this
-- notification to whoever didn't make the change.
create or replace function public.notify_job_rescheduled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_technician_id uuid;
  v_recipient uuid;
begin
  if new.scheduled_for is distinct from old.scheduled_for
     and new.status in ('bid_accepted','en_route') then
    v_technician_id := public.accepted_bid_technician(new.id);
    v_recipient := case when auth.uid() = new.customer_id then v_technician_id else new.customer_id end;
    if v_recipient is not null then
      insert into notifications (user_id, type, job_id, message)
      values (v_recipient, 'job_rescheduled', new.id, 'A job was rescheduled');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_job_rescheduled on jobs;
create trigger trg_notify_job_rescheduled
  after update on jobs
  for each row execute function public.notify_job_rescheduled();

-- ============================================================
-- 7.3 Admin surface
-- ============================================================
-- Membership is granted from the Supabase console only: there are no
-- insert/update/delete policies, so no client can make itself an admin.
create table if not exists admins (
  user_id uuid primary key references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table admins enable row level security;

drop policy if exists "admins_select_own" on admins;
create policy "admins_select_own" on admins
  for select using (user_id = auth.uid());

-- Same SECURITY DEFINER shape as every other cross-table check in this
-- schema, so admin policies on disputes/technician_kyc can't recurse
-- back through admins' own policy.
create or replace function public.is_admin(p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from admins where user_id = p_user_id);
$$;

grant execute on function public.is_admin(uuid) to authenticated;

-- Widen dispute visibility to admins, and give them the update path that
-- migration 001 deliberately left out ("resolution is handled manually
-- via the console") now that there's a real surface for it.
drop policy if exists "disputes_select" on disputes;
create policy "disputes_select" on disputes
  for select using (
    flagged_by = auth.uid()
    or public.job_belongs_to_customer(job_id, auth.uid())
    or public.accepted_bid_technician(job_id) = auth.uid()
    or public.is_admin(auth.uid())
  );

drop policy if exists "disputes_update_admin" on disputes;
create policy "disputes_update_admin" on disputes
  for update using (public.is_admin(auth.uid()));

drop policy if exists "technician_kyc_select_admin" on technician_kyc;
create policy "technician_kyc_select_admin" on technician_kyc
  for select using (public.is_admin(auth.uid()));

drop policy if exists "technician_kyc_update_admin" on technician_kyc;
create policy "technician_kyc_update_admin" on technician_kyc
  for update using (public.is_admin(auth.uid()));

-- Lists pending KYC submissions with the applicant's name/phone in one
-- round trip. SECURITY DEFINER because technician_kyc's own owner-only
-- select policy would otherwise hide every row from the admin -- the
-- is_admin check inside is what authorises the read.
create or replace function public.admin_list_kyc(p_status text default null)
returns table (
  profile_id uuid,
  full_name text,
  phone text,
  id_number text,
  id_document_url text,
  status text,
  rejection_reason text,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return query
    select k.profile_id, p.full_name, p.phone, k.id_number, k.id_document_url,
           k.status, k.rejection_reason, k.submitted_at
    from technician_kyc k
    join profiles p on p.id = k.profile_id
    where p_status is null or k.status = p_status
    order by k.submitted_at;
end;
$$;

grant execute on function public.admin_list_kyc(text) to authenticated;

create or replace function public.admin_set_kyc_status(
  p_profile_id uuid,
  p_status text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  if p_status not in ('pending','verified','rejected') then
    raise exception 'Invalid status';
  end if;
  update technician_kyc
  set status = p_status,
      rejection_reason = case when p_status = 'rejected' then p_reason else null end
  where profile_id = p_profile_id;
end;
$$;

grant execute on function public.admin_set_kyc_status(uuid, text, text) to authenticated;

-- Open disputes with enough job context to act on them, same
-- SECURITY DEFINER reasoning as admin_list_kyc.
create or replace function public.admin_list_disputes(p_status text default null)
returns table (
  id uuid,
  job_id uuid,
  job_status text,
  category_name text,
  flagged_by uuid,
  flagged_by_name text,
  reason text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return query
    select d.id, d.job_id, j.status, c.name, d.flagged_by, p.full_name,
           d.reason, d.status, d.created_at
    from disputes d
    join jobs j on j.id = d.job_id
    join categories c on c.id = j.category_id
    join profiles p on p.id = d.flagged_by
    where p_status is null or d.status = p_status
    order by d.created_at desc;
end;
$$;

grant execute on function public.admin_list_disputes(text) to authenticated;
