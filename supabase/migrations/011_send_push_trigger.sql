-- Calls the send-push Edge Function directly via pg_net instead of a
-- Supabase Database Webhook -- the dashboard's Webhooks feature depends
-- on an internal `supabase_functions` schema that this project doesn't
-- have (fails with "schema supabase_functions does not exist" even
-- with pg_net enabled), so this bypasses it entirely.
--
-- net.http_post is asynchronous -- it queues the request and returns
-- immediately -- so a slow or failing push can never roll back the
-- notification insert that triggered it, same guarantee the wave 4 doc
-- asked a webhook for.
--
-- ============================================================
-- BEFORE RUNNING: substitute the two placeholders below.
-- ============================================================
--   <YOUR-PROJECT-REF>       Supabase dashboard -> Project Settings ->
--                            General -> Reference ID
--   <YOUR-PUBLISHABLE-KEY>   Project Settings -> API Keys -> the
--                            publishable / anon key (the same value
--                            lib/core/env.dart holds)
--
-- The publishable key is not a secret -- it ships inside the compiled
-- Android app, and RLS is what actually protects the data -- but it is
-- kept out of this repo so the project isn't trivially discoverable
-- from source. Same reasoning as lib/core/env.example.dart.
--
-- The guard below makes an unsubstituted run fail immediately rather
-- than installing a trigger that silently swallows every push.
create extension if not exists pg_net;

do $$
begin
  if '<YOUR-PROJECT-REF>' like '%YOUR-PROJECT-REF%'
     or '<YOUR-PUBLISHABLE-KEY>' like '%YOUR-PUBLISHABLE-KEY%' then
    raise exception
      'Substitute <YOUR-PROJECT-REF> and <YOUR-PUBLISHABLE-KEY> in migration 011 before running it';
  end if;
end $$;

create or replace function public.trigger_send_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <YOUR-PUBLISHABLE-KEY>'
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'schema', 'public',
      'record', to_jsonb(new)
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_send_push on notifications;
create trigger trg_send_push
  after insert on notifications
  for each row execute function public.trigger_send_push();
