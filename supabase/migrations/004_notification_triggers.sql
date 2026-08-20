-- Auto-inserts notification rows for the 4 events in scope: new bid,
-- bid accepted, job completed, payment received. Clients can never insert
-- into notifications directly (see the RLS policy in 001_schema.sql) --
-- these SECURITY DEFINER trigger functions are the only path in, so a
-- notification always reflects something that actually happened.

create or replace function public.notify_new_bid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
begin
  select customer_id into v_customer_id from jobs where id = new.job_id;
  if v_customer_id is not null then
    insert into notifications (user_id, type, job_id, message)
    values (v_customer_id, 'new_bid', new.job_id, 'New bid received: ₹' || new.amount);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_new_bid on bids;
create trigger trg_notify_new_bid
  after insert on bids
  for each row execute function public.notify_new_bid();

create or replace function public.notify_bid_accepted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    insert into notifications (user_id, type, job_id, message)
    values (new.technician_id, 'bid_accepted', new.job_id, 'Your bid was accepted!');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_bid_accepted on bids;
create trigger trg_notify_bid_accepted
  after update on bids
  for each row execute function public.notify_bid_accepted();

create or replace function public.notify_job_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    insert into notifications (user_id, type, job_id, message)
    values (new.customer_id, 'job_completed', new.id, 'Your job was marked completed. Pay to close it out.');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_job_completed on jobs;
create trigger trg_notify_job_completed
  after update on jobs
  for each row execute function public.notify_job_completed();

create or replace function public.notify_payment_received()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    insert into notifications (user_id, type, job_id, message)
    values (new.technician_id, 'payment_received', new.job_id, 'Payment received: ₹' || new.amount);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_payment_received on payments;
create trigger trg_notify_payment_received
  after update on payments
  for each row execute function public.notify_payment_received();
