-- Wave 1 feature additions: cash payments and job scheduling. Run this
-- once in the SQL Editor. (Account deletion needs no schema change --
-- it's a new Edge Function using the service role -- see
-- supabase/functions/delete-account/index.ts.)

-- Cash payment: a payment_method column distinguishes how a job was
-- settled. Existing rows (all created via the create-razorpay-order
-- Edge Function) are left null, which the app treats as "razorpay" --
-- that function is untouched, so nothing needs redeploying.
alter table payments add column payment_method text
  check (payment_method in ('razorpay','cash'));

-- Lets the owning customer record a cash payment directly -- there's no
-- external gateway to verify a cash handoff against, so unlike the
-- online path there's no Edge Function step. The policy still refuses
-- to trust the client for anything that matters: technician_id and
-- amount are re-derived from the job's actual accepted bid, and the job
-- must genuinely be completed. Mirrors the existing
-- reviews_insert_customer policy's shape -- a same-table check plus an
-- EXISTS against jobs -- which carries no recursion risk since jobs'
-- own policies never reference payments.
create policy "payments_insert_cash_by_customer" on payments
  for insert with check (
    customer_id = auth.uid()
    and payment_method = 'cash'
    and status = 'paid'
    and technician_id = public.accepted_bid_technician(job_id)
    and amount = (
      select b.amount from jobs j join bids b on b.id = j.accepted_bid_id
      where j.id = payments.job_id
    )
    and exists (
      select 1 from jobs j
      where j.id = payments.job_id and j.customer_id = auth.uid() and j.status = 'completed'
    )
  );

-- Scheduling: a nullable preferred date/time for the visit. Null means
-- "as soon as possible". No RLS change needed -- RLS is row-level, so a
-- new column on an already-covered table is automatically included in
-- every existing policy.
alter table jobs add column scheduled_for timestamptz;
