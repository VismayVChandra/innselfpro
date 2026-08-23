-- Wave 8: Play Store readiness -- report/block, KYC document viewing for
-- admins, and Aadhaar masking. (8.1 password reset and 8.3 location
-- disclosure are client-only, no schema needed.) Idempotent throughout
-- -- see migration 006's header comment for why.

-- ============================================================
-- 8.2 Report & block
-- ============================================================
create table if not exists user_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table user_blocks enable row level security;

drop policy if exists "user_blocks_select_own" on user_blocks;
create policy "user_blocks_select_own" on user_blocks
  for select using (blocker_id = auth.uid());

drop policy if exists "user_blocks_insert_own" on user_blocks;
create policy "user_blocks_insert_own" on user_blocks
  for insert with check (blocker_id = auth.uid() and blocked_id <> auth.uid());

drop policy if exists "user_blocks_delete_own" on user_blocks;
create policy "user_blocks_delete_own" on user_blocks
  for delete using (blocker_id = auth.uid());

create table if not exists user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id),
  reported_id uuid not null references profiles(id),
  job_id uuid references jobs(id) on delete set null,
  reason text not null,
  status text not null default 'open' check (status in ('open','reviewed')),
  created_at timestamptz not null default now()
);

alter table user_reports enable row level security;

drop policy if exists "user_reports_select" on user_reports;
create policy "user_reports_select" on user_reports
  for select using (reporter_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists "user_reports_insert_own" on user_reports;
create policy "user_reports_insert_own" on user_reports
  for insert with check (reporter_id = auth.uid() and reported_id <> auth.uid());

drop policy if exists "user_reports_update_admin" on user_reports;
create policy "user_reports_update_admin" on user_reports
  for update using (public.is_admin(auth.uid()));

create or replace function public.users_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from user_blocks
    where (blocker_id = p_a and blocked_id = p_b)
       or (blocker_id = p_b and blocked_id = p_a)
  );
$$;

grant execute on function public.users_blocked(uuid, uuid) to authenticated;

-- The other side of a job from p_user_id's perspective -- used only to
-- resolve who a blocked check applies against, same SECURITY DEFINER
-- shape as every other cross-table helper in this schema.
create or replace function public.other_job_participant(p_job_id uuid, p_user_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select case
    when (select customer_id from jobs where id = p_job_id) = p_user_id
      then public.accepted_bid_technician(p_job_id)
    else (select customer_id from jobs where id = p_job_id)
  end;
$$;

grant execute on function public.other_job_participant(uuid, uuid) to authenticated;

-- Widens the wave 5.1 insert policy so a block actually stops new
-- messages in both directions, not just from the read side.
drop policy if exists "messages_insert" on messages;
create policy "messages_insert" on messages
  for insert with check (
    sender_id = auth.uid()
    and (
      public.job_belongs_to_customer(job_id, auth.uid())
      or public.accepted_bid_technician(job_id) = auth.uid()
    )
    and exists (
      select 1 from jobs j where j.id = messages.job_id and j.accepted_bid_id is not null
    )
    and not public.users_blocked(sender_id, public.other_job_participant(job_id, sender_id))
  );

-- Open reports with both names resolved, same SECURITY DEFINER shape
-- (and same reasoning) as admin_list_kyc / admin_list_disputes.
create or replace function public.admin_list_reports(p_status text default null)
returns table (
  id uuid,
  reporter_id uuid,
  reporter_name text,
  reported_id uuid,
  reported_name text,
  job_id uuid,
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
    select r.id, r.reporter_id, rp.full_name, r.reported_id, dp.full_name,
           r.job_id, r.reason, r.status, r.created_at
    from user_reports r
    join profiles rp on rp.id = r.reporter_id
    join profiles dp on dp.id = r.reported_id
    where p_status is null or r.status = p_status
    order by r.created_at desc;
end;
$$;

grant execute on function public.admin_list_reports(text) to authenticated;

-- ============================================================
-- 8.4 KYC document viewing for admins
-- ============================================================
-- createSignedUrl still runs under storage.objects RLS -- without this,
-- an admin's signed-URL request is silently denied the same as any
-- other non-owner read, and the admin screen has nothing to show but
-- the raw path.
drop policy if exists "technician_kyc_select_admin" on storage.objects;
create policy "technician_kyc_select_admin" on storage.objects
  for select using (
    bucket_id = 'technician-kyc' and public.is_admin(auth.uid())
  );
