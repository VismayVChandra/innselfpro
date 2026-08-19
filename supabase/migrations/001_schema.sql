-- Innself MVP schema
-- Run this in Supabase Studio -> SQL Editor (or `supabase db push` once the CLI is linked).

create extension if not exists pgcrypto;

-- ============================================================
-- TABLES
-- ============================================================

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('customer','technician')),
  full_name text not null,
  phone text not null,
  address text,
  created_at timestamptz not null default now()
);

create table technician_details (
  profile_id uuid primary key references profiles(id) on delete cascade,
  skills text,
  service_area text,
  created_at timestamptz not null default now()
);

create table technician_kyc (
  profile_id uuid primary key references profiles(id) on delete cascade,
  id_document_url text not null,
  id_number text not null,
  submitted_at timestamptz not null default now()
);

create table categories (
  id serial primary key,
  name text not null unique
);

insert into categories (name) values
  ('Electrician'),
  ('Plumber'),
  ('Carpenter'),
  ('AC Repair'),
  ('Appliance Repair'),
  ('Painter'),
  ('Cleaning'),
  ('Pest Control'),
  ('Other');

-- jobs and bids reference each other, so create jobs first without the
-- accepted_bid_id FK, then add it after bids exists.
create table jobs (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id),
  category_id int not null references categories(id),
  description text not null,
  photo_url text,
  location text not null,
  status text not null default 'open'
    check (status in ('open','bid_accepted','in_progress','completed','disputed')),
  accepted_bid_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table bids (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  technician_id uuid not null references profiles(id),
  amount numeric(10,2) not null,
  note text,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  unique (job_id, technician_id)
);

alter table jobs
  add constraint jobs_accepted_bid_fk foreign key (accepted_bid_id) references bids(id);

create table payments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id),
  customer_id uuid not null references profiles(id),
  technician_id uuid not null references profiles(id),
  amount numeric(10,2) not null,
  razorpay_order_id text,
  razorpay_payment_id text,
  status text not null default 'created' check (status in ('created','paid','failed')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id),
  customer_id uuid not null references profiles(id),
  technician_id uuid not null references profiles(id),
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  type text not null check (type in ('new_bid','bid_accepted','job_completed','payment_received')),
  job_id uuid references jobs(id),
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table disputes (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id),
  flagged_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'open' check (status in ('open','closed')),
  created_at timestamptz not null default now()
);

-- ============================================================
-- INDEXES (feed queries filter on these)
-- ============================================================

create index jobs_status_idx on jobs (status);
create index jobs_category_idx on jobs (category_id);
create index bids_job_id_idx on bids (job_id);
create index bids_technician_id_idx on bids (technician_id);
create index notifications_user_id_idx on notifications (user_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table profiles enable row level security;
alter table technician_details enable row level security;
alter table technician_kyc enable row level security;
alter table categories enable row level security;
alter table jobs enable row level security;
alter table bids enable row level security;
alter table payments enable row level security;
alter table reviews enable row level security;
alter table notifications enable row level security;
alter table disputes enable row level security;

-- profiles: any signed-in user can read basic profile info (names shown on
-- jobs/bids); only the owner can write.
create policy "profiles_select_all" on profiles
  for select using (auth.role() = 'authenticated');
create policy "profiles_insert_own" on profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on profiles
  for update using (auth.uid() = id);

-- technician_details / technician_kyc: owner only, never public.
create policy "technician_details_select_own" on technician_details
  for select using (auth.uid() = profile_id);
create policy "technician_details_insert_own" on technician_details
  for insert with check (auth.uid() = profile_id);
create policy "technician_details_update_own" on technician_details
  for update using (auth.uid() = profile_id);

create policy "technician_kyc_select_own" on technician_kyc
  for select using (auth.uid() = profile_id);
create policy "technician_kyc_insert_own" on technician_kyc
  for insert with check (auth.uid() = profile_id);
create policy "technician_kyc_update_own" on technician_kyc
  for update using (auth.uid() = profile_id);

-- categories: readable by any signed-in user, editable only via console (service role).
create policy "categories_select_all" on categories
  for select using (auth.role() = 'authenticated');

-- jobs: customer sees their own jobs; technicians see open jobs plus any
-- job they've bid on; customer can update their own job (accept bid);
-- the technician on the accepted bid can advance status.
create policy "jobs_select" on jobs
  for select using (
    customer_id = auth.uid()
    or status = 'open'
    or exists (select 1 from bids b where b.job_id = jobs.id and b.technician_id = auth.uid())
  );

create policy "jobs_insert_customer" on jobs
  for insert with check (
    customer_id = auth.uid()
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'customer')
  );

create policy "jobs_update_owning_customer" on jobs
  for update using (customer_id = auth.uid());

create policy "jobs_update_assigned_technician" on jobs
  for update using (
    exists (
      select 1 from bids b
      where b.id = jobs.accepted_bid_id
      and b.technician_id = auth.uid()
    )
  );

-- bids: technician sees their own bids; customer sees bids on their jobs;
-- technician can bid on open jobs; only the owning customer can accept/reject.
create policy "bids_select" on bids
  for select using (
    technician_id = auth.uid()
    or exists (select 1 from jobs j where j.id = bids.job_id and j.customer_id = auth.uid())
  );

create policy "bids_insert_technician" on bids
  for insert with check (
    technician_id = auth.uid()
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'technician')
    and exists (select 1 from jobs j where j.id = bids.job_id and j.status = 'open')
  );

create policy "bids_update_owning_customer" on bids
  for update using (
    exists (select 1 from jobs j where j.id = bids.job_id and j.customer_id = auth.uid())
  );

-- payments: read-only for the two parties involved. All writes happen via
-- an Edge Function using the service role (Razorpay order creation + the
-- webhook that confirms payment) -- clients never mark their own job paid.
create policy "payments_select" on payments
  for select using (customer_id = auth.uid() or technician_id = auth.uid());

-- reviews: ratings are public; only the customer on a completed job can
-- leave one (uniqueness enforced by the unique job_id column).
create policy "reviews_select_all" on reviews
  for select using (auth.role() = 'authenticated');
create policy "reviews_insert_customer" on reviews
  for insert with check (
    customer_id = auth.uid()
    and exists (
      select 1 from jobs j
      where j.id = reviews.job_id and j.customer_id = auth.uid() and j.status = 'completed'
    )
  );

-- notifications: user reads/marks-read their own; rows are only ever
-- inserted server-side (Edge Function / trigger), never by clients.
create policy "notifications_select_own" on notifications
  for select using (user_id = auth.uid());
create policy "notifications_update_own" on notifications
  for update using (user_id = auth.uid());

-- disputes: visible to the two parties on the job; either can flag; no
-- client update policy -- resolution is handled manually via the console.
create policy "disputes_select" on disputes
  for select using (
    flagged_by = auth.uid()
    or exists (select 1 from jobs j where j.id = disputes.job_id and j.customer_id = auth.uid())
    or exists (
      select 1 from jobs j join bids b on b.id = j.accepted_bid_id
      where j.id = disputes.job_id and b.technician_id = auth.uid()
    )
  );

create policy "disputes_insert" on disputes
  for insert with check (
    flagged_by = auth.uid()
    and (
      exists (select 1 from jobs j where j.id = disputes.job_id and j.customer_id = auth.uid())
      or exists (
        select 1 from jobs j join bids b on b.id = j.accepted_bid_id
        where j.id = disputes.job_id and b.technician_id = auth.uid()
      )
    )
  );
