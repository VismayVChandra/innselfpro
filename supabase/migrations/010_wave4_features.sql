-- Wave 4: tap-to-call/WhatsApp needs no schema. This migration covers
-- push notification device tokens (4.2), new-job alerts to matching
-- technicians (4.3), and the completion-code handoff (4.4). Idempotent
-- throughout -- see migration 006's header comment for why.

-- ============================================================
-- 4.2 Push notification device tokens
-- ============================================================
-- One row per (user, device). A user can have several devices; a device
-- token is replaced (not appended) on refresh via upsert from the client.
create table if not exists device_tokens (
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table device_tokens enable row level security;

drop policy if exists "device_tokens_select_own" on device_tokens;
create policy "device_tokens_select_own" on device_tokens
  for select using (user_id = auth.uid());

drop policy if exists "device_tokens_insert_own" on device_tokens;
create policy "device_tokens_insert_own" on device_tokens
  for insert with check (user_id = auth.uid());

drop policy if exists "device_tokens_update_own" on device_tokens;
create policy "device_tokens_update_own" on device_tokens
  for update using (user_id = auth.uid());

drop policy if exists "device_tokens_delete_own" on device_tokens;
create policy "device_tokens_delete_own" on device_tokens
  for delete using (user_id = auth.uid());

-- The send-push Edge Function is invoked by a Database Webhook (set up in
-- the Supabase dashboard, not via SQL) on notifications INSERT, using the
-- service role -- it doesn't need a client-facing RLS change here.

-- ============================================================
-- 4.3 New-job alerts to matching technicians
-- ============================================================
-- notifications_type_check is Postgres's auto-generated name for the
-- inline check from migration 001 (already widened twice since). If this
-- errors, run `\d notifications` in the SQL Editor to find the real name.
alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'new_bid','bid_accepted','job_completed','payment_received',
    'direct_request','new_job'
  ));

-- Fans a new open job out to technicians who could plausibly take it:
-- skilled in the category (technician_skills, migration 007) and either
-- unset on service area or a free-text match against the job's location.
-- Real geo matching arrives in wave 6 (6.1) -- this is a deliberately
-- coarse stand-in, capped at 50 recipients so a broad/empty service_area
-- can't fan a single job out to every technician on the platform.
-- Direct-request jobs are excluded -- notify_direct_request (migration
-- 008) already covers that path with its own notification type.
create or replace function public.notify_matching_technicians()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.invited_technician_id is not null then
    return new;
  end if;

  insert into notifications (user_id, type, job_id, message)
  select
    ts.profile_id,
    'new_job',
    new.id,
    'New ' || c.name || ' job posted near you'
  from technician_skills ts
  join technician_details td on td.profile_id = ts.profile_id
  join categories c on c.id = new.category_id
  where ts.category_id = new.category_id
    and ts.profile_id <> new.customer_id
    and (
      td.service_area is null
      or td.service_area = ''
      or new.location ilike '%' || td.service_area || '%'
    )
  limit 50;

  return new;
end;
$$;

drop trigger if exists trg_notify_matching_technicians on jobs;
create trigger trg_notify_matching_technicians
  after insert on jobs
  for each row execute function public.notify_matching_technicians();

-- ============================================================
-- 4.4 Completion code
-- ============================================================
alter table jobs add column if not exists completion_code text;
alter table jobs add column if not exists customer_confirmed_at timestamptz;
alter table jobs add column if not exists completion_code_attempts int not null default 0;

-- Generates a 4-digit code the moment a job is assigned, so it's ready
-- for the customer to read out before the technician even starts.
create or replace function public.generate_completion_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'bid_accepted'
     and old.status is distinct from 'bid_accepted'
     and new.completion_code is null then
    new.completion_code := lpad(floor(random() * 10000)::int::text, 4, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_generate_completion_code on jobs;
create trigger trg_generate_completion_code
  before update on jobs
  for each row execute function public.generate_completion_code();

-- This is what actually enforces the code -- jobs_update_assigned_technician
-- (migration 001) lets the assigned technician update any column on the
-- job, including status, so tightening that policy instead would be far
-- more fragile than a guard that fires regardless of which policy let the
-- update through.
create or replace function public.guard_job_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed'
     and old.status is distinct from 'completed'
     and new.customer_confirmed_at is null then
    raise exception 'Job cannot be marked completed without the customer confirmation code';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_job_completion on jobs;
create trigger trg_guard_job_completion
  before update on jobs
  for each row execute function public.guard_job_completion();

-- The only path a technician has to close out a job: verifies the caller
-- is the accepted technician and the code matches, then sets status,
-- completion_photo_url and customer_confirmed_at in one statement so the
-- guard trigger above sees a satisfied NEW row. Locks out after 5 wrong
-- attempts so the 4-digit code can't be brute-forced.
create or replace function public.complete_job_with_code(
  p_job_id uuid,
  p_code text,
  p_photo_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_technician_id uuid;
  v_stored_code text;
  v_attempts int;
begin
  select public.accepted_bid_technician(p_job_id) into v_technician_id;
  if v_technician_id is null or v_technician_id <> auth.uid() then
    raise exception 'Not authorized to complete this job';
  end if;

  select completion_code, completion_code_attempts into v_stored_code, v_attempts
  from jobs where id = p_job_id
  for update;

  if v_attempts >= 5 then
    raise exception 'Too many incorrect attempts -- ask the customer to re-check the code';
  end if;

  if v_stored_code is null or v_stored_code is distinct from p_code then
    update jobs set completion_code_attempts = completion_code_attempts + 1
    where id = p_job_id;
    raise exception 'Incorrect completion code';
  end if;

  update jobs
  set status = 'completed',
      completion_photo_url = coalesce(p_photo_url, completion_photo_url),
      customer_confirmed_at = now()
  where id = p_job_id;
end;
$$;

grant execute on function public.complete_job_with_code(uuid, text, text) to authenticated;
