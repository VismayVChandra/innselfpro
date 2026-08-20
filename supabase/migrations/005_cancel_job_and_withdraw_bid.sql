-- Adds two new client actions: a customer cancelling an open job before any
-- bid is accepted, and a technician withdrawing a pending bid before the
-- job leaves the open state.
-- Run this once in the SQL Editor against the already-provisioned project.

-- jobs.status gets a new terminal value. The existing
-- "jobs_update_owning_customer" policy from 001_schema.sql already lets the
-- owning customer update their job in any status (the same trust model
-- already used for the accept-bid and status-tracking writes), so only the
-- CHECK constraint needs relaxing. If this DROP errors with "constraint
-- does not exist", run `\d jobs` in the SQL Editor to find the actual
-- auto-generated name and substitute it below.
alter table jobs drop constraint jobs_status_check;
alter table jobs add constraint jobs_status_check
  check (status in ('open','bid_accepted','in_progress','completed','disputed','cancelled'));

-- A technician can delete their own bid while it's still pending and the
-- job is still open -- withdrawing after acceptance isn't offered (that's
-- what the dispute flow is for instead). Reuses the existing job_is_open()
-- SECURITY DEFINER helper from 001_schema.sql, so this follows the same
-- safe pattern as every other jobs/bids cross-table check and carries no
-- risk of reintroducing the 42P17 recursion fixed in 003.
create policy "bids_delete_own_pending" on bids
  for delete using (
    technician_id = auth.uid()
    and status = 'pending'
    and public.job_is_open(job_id)
  );
