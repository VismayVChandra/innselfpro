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
-- The anon key below is safe to hardcode: it's Supabase's public
-- "publishable" key, already shipped inside the compiled Android app
-- (see lib/core/env.dart) -- it only has to satisfy send-push's gateway
-- JWT check, and grants no elevated access on its own.
create extension if not exists pg_net;

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
