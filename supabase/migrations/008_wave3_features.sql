-- Wave 3: rebook a specific technician, multiple job photos, and price
-- guidance from historical accepted bids. Idempotent throughout.

-- ============================================================
-- 1. Rebook: invite one specific technician to a job
-- ============================================================
-- Set when a customer books a technician they've worked with before
-- directly, rather than posting an open request. Null means the normal
-- open-to-everyone behaviour, unchanged.
alter table jobs add column if not exists invited_technician_id uuid references profiles(id);

-- jobs_select's status='open' clause used to mean "every technician
-- can see it" unconditionally. Now it also means that UNLESS the job
-- is invite-only, in which case only the invited technician (and the
-- owning customer, already covered by the first clause) can see it.
-- This is a plain column check on the jobs row being evaluated, not a
-- cross-table subquery, so it carries none of the recursion risk fixed
-- in migration 003.
drop policy if exists "jobs_select" on jobs;
create policy "jobs_select" on jobs
  for select using (
    customer_id = auth.uid()
    or (status = 'open' and (invited_technician_id is null or invited_technician_id = auth.uid()))
    or public.technician_has_bid_on_job(id, auth.uid())
  );

-- Setting invited_technician_id at insert time must point at an actual
-- technician, not any profile id.
drop policy if exists "jobs_insert_customer" on jobs;
create policy "jobs_insert_customer" on jobs
  for insert with check (
    customer_id = auth.uid()
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'customer')
    and (
      invited_technician_id is null
      or exists (select 1 from profiles p2 where p2.id = invited_technician_id and p2.role = 'technician')
    )
  );

-- Mirrors job_is_open(), but also respects an invite -- a technician
-- who isn't the invited one can't bid even if they somehow got hold of
-- the job id directly, matching what jobs_select already hides from
-- their view.
create or replace function public.job_is_open_for_technician(p_job_id uuid, p_technician_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from jobs
    where id = p_job_id
      and status = 'open'
      and (invited_technician_id is null or invited_technician_id = p_technician_id)
  );
$$;

grant execute on function public.job_is_open_for_technician(uuid, uuid) to authenticated;

drop policy if exists "bids_insert_technician" on bids;
create policy "bids_insert_technician" on bids
  for insert with check (
    technician_id = auth.uid()
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'technician')
    and public.job_is_open_for_technician(job_id, auth.uid())
  );

-- A technician gets notified the moment they're personally requested --
-- direct_request joins the four existing types. notifications_type_check
-- is Postgres's auto-generated name for the inline check from migration
-- 001; if this errors, run `\d notifications` to find the real name.
alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in ('new_bid','bid_accepted','job_completed','payment_received','direct_request'));

create or replace function public.notify_direct_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.invited_technician_id is not null then
    insert into notifications (user_id, type, job_id, message)
    values (new.invited_technician_id, 'direct_request', new.id, 'A customer requested you directly for a job');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_direct_request on jobs;
create trigger trg_notify_direct_request
  after insert on jobs
  for each row execute function public.notify_direct_request();

-- ============================================================
-- 2. Multiple job photos
-- ============================================================
-- Replaces the single photo_url with an array. Wrapped in a guard so
-- re-running this migration after photo_url is already gone doesn't
-- fail trying to read a column that no longer exists.
alter table jobs add column if not exists photo_urls text[];

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'jobs' and column_name = 'photo_url'
  ) then
    update jobs set photo_urls = array[photo_url] where photo_url is not null and photo_urls is null;
    alter table jobs drop column photo_url;
  end if;
end $$;

-- ============================================================
-- 3. Price guidance from historical accepted bids
-- ============================================================
-- Returns only an aggregate, never individual bids -- safe to expose to
-- any authenticated user despite bids_select normally restricting each
-- bid row to its own technician or the job's own customer.
create or replace function public.category_price_guidance(p_category_id int)
returns table(avg_amount numeric, min_amount numeric, max_amount numeric, sample_size bigint)
language sql
security definer
set search_path = public
stable
as $$
  select
    avg(b.amount)::numeric,
    min(b.amount)::numeric,
    max(b.amount)::numeric,
    count(*)::bigint
  from bids b
  join jobs j on j.id = b.job_id
  where j.category_id = p_category_id and b.status = 'accepted';
$$;

grant execute on function public.category_price_guidance(int) to authenticated;
