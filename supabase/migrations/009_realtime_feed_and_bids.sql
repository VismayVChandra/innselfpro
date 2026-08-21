-- Enables realtime on jobs and bids, so the technician feed and a
-- job's bids-received list update live instead of needing a manual
-- refresh. No RLS changes needed -- jobs_select (migration 008) and
-- bids_select (migration 001) already gate exactly the right rows;
-- Realtime enforces each subscriber's own RLS the same as a normal
-- query, it just doesn't add or remove anything a query couldn't
-- already show them.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'jobs'
  ) then
    alter publication supabase_realtime add table jobs;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'bids'
  ) then
    alter publication supabase_realtime add table bids;
  end if;
end $$;
