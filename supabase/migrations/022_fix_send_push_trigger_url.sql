-- Fixes the root cause of push notifications never having worked, in
-- the entire life of this project, for any notification type -- found
-- while live-debugging with a test insert and pg_net's own response
-- log (net._http_response), which showed every single call the
-- trigger ever made coming back 404 "Requested function was not
-- found".
--
-- The actual send-push Edge Function has always been deployed and
-- always had correct code -- but under the wrong name. Early on, the
-- whole `npx supabase functions deploy send-push` command got pasted
-- into the dashboard's "New function" name field instead of being run
-- in a terminal, so the function's real slug has been
-- `supabase-functions-deploy-send-push` this whole time, not
-- `send-push`. Migration 011's trigger correctly called
-- `.../functions/v1/send-push` -- which simply never existed.
--
-- This is a stopgap, not the real fix: it points the trigger at the
-- function's actual (wrong) URL rather than renaming the function
-- itself, since that only needs a database change and not another
-- CLI deploy. Properly renaming the Edge Function to `send-push` and
-- pointing this back at migration 011's original URL is the correct
-- long-term cleanup, whenever `npx supabase functions deploy
-- send-push` is next convenient to run.
--
-- ============================================================
-- BEFORE RUNNING: substitute the two placeholders below, same as
-- migration 011 -- see that file's header for where to find them.
-- ============================================================
do $$
begin
  if '<YOUR-PROJECT-REF>' like '%YOUR-PROJECT-REF%'
     or '<YOUR-PUBLISHABLE-KEY>' like '%YOUR-PUBLISHABLE-KEY%' then
    raise exception
      'Substitute <YOUR-PROJECT-REF> and <YOUR-PUBLISHABLE-KEY> in migration 022 before running it';
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
    url := 'https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/supabase-functions-deploy-send-push',
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
