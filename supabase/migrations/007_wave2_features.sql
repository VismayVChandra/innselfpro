-- Wave 2 feature additions: structured technician skills, two-way
-- reviews, completion photos, and realtime notifications. Every
-- statement is idempotent (see migration 006's lesson) -- safe to
-- re-run if something in here fails partway through.

-- ============================================================
-- 1. Technician skills, linked to categories instead of free text
-- ============================================================
-- Replaces technician_details.skills (a free-text box a customer never
-- saw and the feed never used) with a real many-to-many, so the feed
-- can default a technician to their own categories instead of showing
-- every open job unfiltered.
create table if not exists technician_skills (
  profile_id uuid not null references profiles(id) on delete cascade,
  category_id int not null references categories(id),
  primary key (profile_id, category_id)
);

alter table technician_skills enable row level security;

drop policy if exists "technician_skills_select_own" on technician_skills;
create policy "technician_skills_select_own" on technician_skills
  for select using (auth.uid() = profile_id);

drop policy if exists "technician_skills_insert_own" on technician_skills;
create policy "technician_skills_insert_own" on technician_skills
  for insert with check (auth.uid() = profile_id);

drop policy if exists "technician_skills_delete_own" on technician_skills;
create policy "technician_skills_delete_own" on technician_skills
  for delete using (auth.uid() = profile_id);

-- Fully replaced by the table above -- drop rather than keep two
-- sources of truth for the same concept.
alter table technician_details drop column if exists skills;

-- ============================================================
-- 2. Two-way reviews
-- ============================================================
-- reviewer_role says who authored a given review row: 'customer' means
-- the customer wrote it (about the technician, as today); 'technician'
-- means the technician wrote it (about the customer, new). Existing
-- rows are all customer-authored, hence the default.
alter table reviews add column if not exists reviewer_role text
  not null default 'customer' check (reviewer_role in ('customer','technician'));

-- A job can now have up to one review per direction, not just one
-- review total. reviews_job_id_key is Postgres's auto-generated name
-- for the inline `unique` on job_id from migration 001 -- if this
-- errors with "constraint does not exist", run `\d reviews` in the SQL
-- Editor to find the actual name and substitute it here.
alter table reviews drop constraint if exists reviews_job_id_key;
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reviews_job_id_reviewer_role_key'
  ) then
    alter table reviews add constraint reviews_job_id_reviewer_role_key
      unique (job_id, reviewer_role);
  end if;
end $$;

drop policy if exists "reviews_insert_customer" on reviews;
create policy "reviews_insert_customer" on reviews
  for insert with check (
    customer_id = auth.uid()
    and reviewer_role = 'customer'
    and exists (
      select 1 from jobs j
      where j.id = reviews.job_id and j.customer_id = auth.uid() and j.status = 'completed'
    )
  );

-- Mirrors reviews_insert_customer exactly, but for the technician side:
-- same job-completed check, ownership check on technician_id instead,
-- via the existing accepted_bid_technician() helper.
drop policy if exists "reviews_insert_technician" on reviews;
create policy "reviews_insert_technician" on reviews
  for insert with check (
    technician_id = auth.uid()
    and reviewer_role = 'technician'
    and exists (
      select 1 from jobs j
      where j.id = reviews.job_id
        and j.status = 'completed'
        and public.accepted_bid_technician(j.id) = auth.uid()
    )
  );

-- ============================================================
-- 3. Completion photos
-- ============================================================
-- Set by the technician when marking a job complete. No RLS change
-- needed -- jobs_update_assigned_technician already lets the accepted
-- technician update any column on the job, the same trust level
-- already used for status transitions. The job-photos storage bucket's
-- existing policies (migration 002) only check that the upload path
-- starts with the uploader's own uid, so a technician uploading under
-- their own folder is already permitted -- no storage policy change
-- needed either.
alter table jobs add column if not exists completion_photo_url text;

-- ============================================================
-- 4. Realtime notifications
-- ============================================================
-- Adds the table to the publication Supabase's realtime engine reads
-- from. Realtime still enforces each subscriber's own RLS, so this
-- doesn't change who can see what -- notifications_select_own already
-- restricts every row to its own user_id.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end $$;
