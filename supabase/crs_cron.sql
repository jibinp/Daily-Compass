-- Weekly IRCC check: Sunday 09:00. Run in Supabase → SQL Editor AFTER deploying
-- the crs-refresh function. Requires pg_cron + pg_net (enable in Database → Extensions).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- pg_cron schedules in UTC. 09:00 America/Toronto (IRCC time) =
--   13:00 UTC during EDT (summer), 14:00 UTC during EST (winter).
-- Below fires 13:00 UTC (= 09:00 EDT / 08:00 EST). Adjust to '0 14 * * 0' in winter,
-- or schedule both if exact 09:00 local matters. The check just needs to run weekly.
select cron.schedule(
  'crs-weekly',
  '0 13 * * 0',                       -- min hour dom mon dow (0 = Sunday)
  $$
  select net.http_post(
    url     := 'https://twpzcszcvylhaopcwqkv.supabase.co/functions/v1/crs-refresh',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>'   -- paste your service_role key
    )
  );
  $$
);

-- Manage:
--   select * from cron.job;                       -- list
--   select cron.unschedule('crs-weekly');         -- remove
