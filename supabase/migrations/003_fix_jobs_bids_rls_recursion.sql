-- Fixes: PostgrestException 42P17 "infinite recursion detected in policy for
-- relation jobs". jobs and bids policies each subqueried the other table via
-- EXISTS, which re-triggers that table's own RLS policies -- a cycle.
-- Run this once in the SQL Editor against the already-provisioned project.
-- (001_schema.sql has also been updated so a fresh setup avoids this from
-- the start.)

create or replace function public.technician_has_bid_on_job(p_job_id uuid, p_technician_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from bids
    where job_id = p_job_id and technician_id = p_technician_id
  );
$$;

create or replace function public.job_belongs_to_customer(p_job_id uuid, p_customer_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from jobs
    where id = p_job_id and customer_id = p_customer_id
  );
$$;

create or replace function public.job_is_open(p_job_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from jobs
    where id = p_job_id and status = 'open'
  );
$$;

create or replace function public.accepted_bid_technician(p_job_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select b.technician_id
  from jobs j join bids b on b.id = j.accepted_bid_id
  where j.id = p_job_id;
$$;

grant execute on function public.technician_has_bid_on_job(uuid, uuid) to authenticated;
grant execute on function public.job_belongs_to_customer(uuid, uuid) to authenticated;
grant execute on function public.job_is_open(uuid) to authenticated;
grant execute on function public.accepted_bid_technician(uuid) to authenticated;

drop policy if exists "jobs_select" on jobs;
create policy "jobs_select" on jobs
  for select using (
    customer_id = auth.uid()
    or status = 'open'
    or public.technician_has_bid_on_job(id, auth.uid())
  );

drop policy if exists "jobs_update_assigned_technician" on jobs;
create policy "jobs_update_assigned_technician" on jobs
  for update using (public.accepted_bid_technician(id) = auth.uid());

drop policy if exists "bids_select" on bids;
create policy "bids_select" on bids
  for select using (
    technician_id = auth.uid()
    or public.job_belongs_to_customer(job_id, auth.uid())
  );

drop policy if exists "bids_insert_technician" on bids;
create policy "bids_insert_technician" on bids
  for insert with check (
    technician_id = auth.uid()
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'technician')
    and public.job_is_open(job_id)
  );

drop policy if exists "bids_update_owning_customer" on bids;
create policy "bids_update_owning_customer" on bids
  for update using (public.job_belongs_to_customer(job_id, auth.uid()));

drop policy if exists "disputes_select" on disputes;
create policy "disputes_select" on disputes
  for select using (
    flagged_by = auth.uid()
    or public.job_belongs_to_customer(job_id, auth.uid())
    or public.accepted_bid_technician(job_id) = auth.uid()
  );

drop policy if exists "disputes_insert" on disputes;
create policy "disputes_insert" on disputes
  for insert with check (
    flagged_by = auth.uid()
    and (
      public.job_belongs_to_customer(job_id, auth.uid())
      or public.accepted_bid_technician(job_id) = auth.uid()
    )
  );
