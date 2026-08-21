-- Wave 5: per-job chat, technician availability, and on-my-way/ETA.
-- Idempotent throughout -- see migration 006's header comment for why.

-- ============================================================
-- 5.1 Per-job chat
-- ============================================================
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  sender_id uuid not null references profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_job_id_idx on messages (job_id, created_at);

alter table messages enable row level security;

-- Both participants can read the whole thread. Referencing jobs directly
-- here (rather than only through the technician_has_bid_on_job-style
-- helpers) is safe -- jobs' own policies never reference messages, so
-- there's no cycle, same reasoning migration 006 already used for
-- payments_insert_cash_by_customer.
drop policy if exists "messages_select" on messages;
create policy "messages_select" on messages
  for select using (
    public.job_belongs_to_customer(job_id, auth.uid())
    or public.accepted_bid_technician(job_id) = auth.uid()
  );

-- Chat only opens once a bid is accepted, not during bidding -- keeps
-- this policy simple and stops the platform being bypassed before a job
-- is actually booked.
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
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table messages;
  end if;
end $$;

alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'new_bid','bid_accepted','job_completed','payment_received',
    'direct_request','new_job','new_message','technician_en_route'
  ));

create or replace function public.notify_new_message()
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
  v_recipient := case when new.sender_id = v_customer_id then v_technician_id else v_customer_id end;
  if v_recipient is not null then
    insert into notifications (user_id, type, job_id, message)
    values (v_recipient, 'new_message', new.job_id, 'New message about your job');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_new_message on messages;
create trigger trg_notify_new_message
  after insert on messages
  for each row execute function public.notify_new_message();

-- ============================================================
-- 5.2 Technician availability
-- ============================================================
alter table technician_details add column if not exists is_available boolean not null default true;

-- Any authenticated user (not just the technician themselves) needs to
-- read this one boolean to grey out rebook/direct-request on an
-- unavailable technician -- technician_details itself stays owner-only
-- (technician_kyc-style), so this is a narrow SECURITY DEFINER read
-- instead of loosening the table's RLS.
create or replace function public.is_technician_available(p_technician_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(is_available, true) from technician_details where profile_id = p_technician_id;
$$;

grant execute on function public.is_technician_available(uuid) to authenticated;

-- Re-defines the wave 4.3 fan-out to also require availability -- this
-- is exactly the "once 5.2 lands" follow-up that migration 010's own
-- comment on this function called out in advance.
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
    and td.is_available
    and (
      td.service_area is null
      or td.service_area = ''
      or new.location ilike '%' || td.service_area || '%'
    )
  limit 50;

  return new;
end;
$$;

-- ============================================================
-- 5.3 On my way + ETA
-- ============================================================
alter table jobs drop constraint if exists jobs_status_check;
alter table jobs add constraint jobs_status_check
  check (status in ('open','bid_accepted','en_route','in_progress','completed','disputed','cancelled'));

alter table jobs add column if not exists eta_at timestamptz;

create or replace function public.notify_technician_en_route()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'en_route' and old.status is distinct from 'en_route' then
    insert into notifications (user_id, type, job_id, message)
    values (new.customer_id, 'technician_en_route', new.id, 'Your technician is on the way');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_technician_en_route on jobs;
create trigger trg_notify_technician_en_route
  after update on jobs
  for each row execute function public.notify_technician_en_route();
