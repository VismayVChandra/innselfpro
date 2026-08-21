-- Wave 6: real location matching, saved addresses, and job expiry.
-- Idempotent throughout -- see migration 006's header comment for why.
--
-- Deliberate trims from the wave 6 doc, flagged here for anyone reading
-- this migration later: no PostGIS (the doc explicitly said plain
-- haversine is enough) and no separate open_jobs_for_technician RPC --
-- the existing feed is realtime (migration 009), so distance is instead
-- computed client-side over the same streamed rows, using the identical
-- haversine math as the SQL helper below. technician_details.service_pincodes
-- from the doc's schema sketch was dropped too -- redundant with
-- base_lat/base_lng/service_radius_km, which is what actually produces
-- the "3.2 km away" figure the doc's own "done when" asks for.

-- ============================================================
-- 6.1 Real location instead of free text
-- ============================================================
alter table jobs add column if not exists pincode text;
alter table jobs add column if not exists lat double precision;
alter table jobs add column if not exists lng double precision;

alter table technician_details add column if not exists base_lat double precision;
alter table technician_details add column if not exists base_lng double precision;
alter table technician_details add column if not exists service_radius_km int not null default 10;

-- Plain haversine, no PostGIS. Pure math over its arguments -- no table
-- access, so no SECURITY DEFINER needed.
create or replace function public.distance_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371 * acos(
    least(1::double precision, greatest(-1::double precision,
      cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2) - radians(lng1))
      + sin(radians(lat1)) * sin(radians(lat2))
    ))
  );
$$;

-- Re-defines the wave 4.3 fan-out again (see migration 012's own
-- comment on this function for the "once 5.2 lands" precedent this
-- follows): prefers precise radius matching when both the job and the
-- technician have coordinates, falling back to the old free-text
-- service_area match otherwise -- so a technician who hasn't set a
-- location yet, or a job posted without one, still degrades gracefully
-- instead of being silently excluded.
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
      (
        td.base_lat is not null and td.base_lng is not null
        and new.lat is not null and new.lng is not null
        and public.distance_km(td.base_lat, td.base_lng, new.lat, new.lng) <= td.service_radius_km
      )
      or (
        (td.base_lat is null or td.base_lng is null or new.lat is null or new.lng is null)
        and (
          td.service_area is null
          or td.service_area = ''
          or new.location ilike '%' || td.service_area || '%'
        )
      )
    )
  limit 50;

  return new;
end;
$$;

-- ============================================================
-- 6.2 Saved addresses
-- ============================================================
create table if not exists customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id) on delete cascade,
  label text not null,
  address text not null,
  pincode text,
  lat double precision,
  lng double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists customer_addresses_customer_id_idx on customer_addresses (customer_id);

alter table customer_addresses enable row level security;

drop policy if exists "customer_addresses_select_own" on customer_addresses;
create policy "customer_addresses_select_own" on customer_addresses
  for select using (customer_id = auth.uid());

drop policy if exists "customer_addresses_insert_own" on customer_addresses;
create policy "customer_addresses_insert_own" on customer_addresses
  for insert with check (customer_id = auth.uid());

drop policy if exists "customer_addresses_update_own" on customer_addresses;
create policy "customer_addresses_update_own" on customer_addresses
  for update using (customer_id = auth.uid());

drop policy if exists "customer_addresses_delete_own" on customer_addresses;
create policy "customer_addresses_delete_own" on customer_addresses
  for delete using (customer_id = auth.uid());

-- ============================================================
-- 6.3 Job expiry and no-bid feedback
-- ============================================================
-- Only new rows get a default expiry -- an already-open job posted
-- before this migration keeps expires_at = null, which the expiry job
-- below simply never matches, so nothing already-open is retroactively
-- expired out from under a customer mid-flow.
alter table jobs add column if not exists expires_at timestamptz default (now() + interval '3 days');

alter table jobs drop constraint if exists jobs_status_check;
alter table jobs add constraint jobs_status_check
  check (status in ('open','bid_accepted','en_route','in_progress','completed','disputed','cancelled','expired'));

alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'new_bid','bid_accepted','job_completed','payment_received',
    'direct_request','new_job','new_message','technician_en_route','job_expired'
  ));

-- Runs hourly via pg_cron below -- a plain SQL function rather than a
-- scheduled Edge Function, so there's no separate manual deploy step
-- the way send-push (wave 4.2) needed.
create or replace function public.expire_old_jobs()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    update jobs
    set status = 'expired'
    where status = 'open' and expires_at is not null and expires_at < now()
    returning id, customer_id
  loop
    insert into notifications (user_id, type, job_id, message)
    values (
      r.customer_id, 'job_expired', r.id,
      'Your request expired with no bids. Try reposting with a wider area or a different price.'
    );
  end loop;
end;
$$;

create extension if not exists pg_cron;

do $$
begin
  if not exists (select 1 from cron.job where jobname = 'expire-open-jobs') then
    perform cron.schedule('expire-open-jobs', '0 * * * *', 'select public.expire_old_jobs()');
  end if;
end $$;
