-- Fixes a one-time backfill bug from migration 014.
--
-- `alter table jobs add column expires_at ... default (now() + interval
-- '3 days')` doesn't leave pre-existing rows null the way that migration's
-- own comment assumed -- Postgres's fast-default optimization for ADD
-- COLUMN backfills every row that already existed, using the default
-- evaluated ONCE at ALTER TIME, not per-row. So every job that was open
-- when 014 ran got the exact same expires_at (migration-run-time + 3
-- days), with no relation to when it was actually posted, instead of
-- either null or created_at + 3 days.
--
-- Rows inserted after 014 ran are unaffected: their expires_at came from
-- a fresh per-row evaluation of the same now() used for created_at in
-- that INSERT's own transaction, so it's already exactly created_at +
-- 3 days (now() is stable within a transaction, so there's no drift to
-- account for -- the equality check below is exact, not approximate).
update jobs
set expires_at = created_at + interval '3 days'
where status = 'open'
  and expires_at is not null
  and expires_at <> created_at + interval '3 days';
