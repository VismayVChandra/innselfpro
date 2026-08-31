-- In-app support chat, replacing the email-only contact in Help &
-- Support -- a real-time conversation between one user and "the admin
-- team" collectively (any admin can see and reply to any thread, same
-- as the existing admin surface's other tools), rather than a per-job
-- concept like the existing messages table. One ongoing thread per
-- user, not a ticket-per-issue system -- support_messages.user_id is
-- the thread's identity, sender_id is whoever actually wrote that row
-- (the user themselves, or whichever admin replied).

create table if not exists support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  sender_id uuid not null references profiles(id),
  body text not null,
  read_by_admin boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists support_messages_user_id_idx on support_messages (user_id, created_at);

alter table support_messages enable row level security;

drop policy if exists "support_messages_select" on support_messages;
create policy "support_messages_select" on support_messages
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists "support_messages_insert" on support_messages;
create policy "support_messages_insert" on support_messages
  for insert with check (
    sender_id = auth.uid()
    and (user_id = auth.uid() or public.is_admin(auth.uid()))
  );

-- Only used to mark a thread read when an admin opens it.
drop policy if exists "support_messages_update_admin" on support_messages;
create policy "support_messages_update_admin" on support_messages
  for update using (public.is_admin(auth.uid()));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'support_messages'
  ) then
    alter publication supabase_realtime add table support_messages;
  end if;
end $$;

alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'new_bid','bid_accepted','job_completed','payment_received',
    'direct_request','new_job','new_message','technician_en_route',
    'job_expired','job_cancelled','job_rescheduled','support_message'
  ));

-- A user's own message notifies every current admin (fanned out, same
-- shape as notify_matching_technicians); an admin's reply notifies
-- just that one user. Same pg_net-trigger pattern as the rest of this
-- app's push delivery -- trg_send_push (migration 011) already fires
-- on every notifications insert regardless of type, so this needs no
-- extra wiring to actually reach a device.
create or replace function public.notify_support_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_name text;
begin
  if new.sender_id = new.user_id then
    select full_name into v_sender_name from profiles where id = new.sender_id;
    insert into notifications (user_id, type, message)
    select a.user_id, 'support_message', 'New support message from ' || coalesce(v_sender_name, 'a user')
    from admins a
    where a.user_id <> new.sender_id;
  else
    insert into notifications (user_id, type, message)
    values (new.user_id, 'support_message', 'New reply from support');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_support_message on support_messages;
create trigger trg_notify_support_message
  after insert on support_messages
  for each row execute function public.notify_support_message();

-- Every user's thread in one round trip for the admin inbox --
-- SECURITY DEFINER because support_messages_select would otherwise
-- require the admin to already know which user_ids to ask for.
create or replace function public.admin_list_support_threads()
returns table (
  user_id uuid,
  full_name text,
  last_message text,
  last_message_at timestamptz,
  unread_count int
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return query
    select
      sm.user_id,
      p.full_name,
      (array_agg(sm.body order by sm.created_at desc))[1],
      max(sm.created_at),
      count(*) filter (where sm.sender_id = sm.user_id and not sm.read_by_admin)::int
    from support_messages sm
    join profiles p on p.id = sm.user_id
    group by sm.user_id, p.full_name
    order by max(sm.created_at) desc;
end;
$$;

grant execute on function public.admin_list_support_threads() to authenticated;
