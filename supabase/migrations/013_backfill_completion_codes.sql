-- One-off backfill: generate_completion_code() (migration 010) only
-- fires on the transition INTO 'bid_accepted', so any job whose bid was
-- accepted before that migration ran is stuck with completion_code =
-- null forever -- it won't pass through that transition again. This
-- catches those up. Safe to re-run: after the first run, every eligible
-- row already has a non-null code and the WHERE clause excludes it.
update jobs
set completion_code = lpad(floor(random() * 10000)::int::text, 4, '0')
where status in ('bid_accepted', 'en_route', 'in_progress')
  and completion_code is null;
