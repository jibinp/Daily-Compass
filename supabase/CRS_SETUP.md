# CRS pool distribution — setup

The **CRS pool distribution** section (Temporary → Canadian PR) stores a table of
IRCC's "CRS score distribution of candidates in the pool as of `<date>`", one
snapshot per date, with history.

## 1. Works immediately (manual)

Run once, then reload the app:

```sql
-- supabase/crs_pool.sql
```
Open **SQL Editor**, paste the contents of [`crs_pool.sql`](./crs_pool.sql), Run.

Now **Temporary → Canadian PR → Add snapshot** works: pick the "pool as of" date,
paste IRCC's table (one row per line, `range` then `number`), Save. New date =
new snapshot; the dropdown keeps history.

## 2. Automatic weekly check (optional, deploy-later)

Makes the **Check now** button live and runs an unattended check every Sunday.
IRCC blocks plain bots (HTTP 403), so the fetch runs server-side with a browser
User-Agent in an Edge Function.

1. **Deploy the function** (needs [Supabase CLI](https://supabase.com/docs/guides/cli)):
   ```bash
   supabase link --project-ref twpzcszcvylhaopcwqkv
   supabase functions deploy crs-refresh
   ```
   Code: [`functions/crs-refresh/index.ts`](./functions/crs-refresh/index.ts).

2. **Test it** — click **Check now** in the app, or:
   ```bash
   curl -X POST https://twpzcszcvylhaopcwqkv.supabase.co/functions/v1/crs-refresh \
     -H "Authorization: Bearer <ANON_OR_SERVICE_KEY>"
   ```
   Expect `{ "pool_date": "...", "rows": N, "total": ... }`.
   If it returns a parse error, IRCC changed the page layout — adjust `parse()`
   in the function; manual add still works meanwhile.

3. **Schedule weekly** — paste your `service_role` key into
   [`crs_cron.sql`](./crs_cron.sql) and run it (Sunday 09:00 Toronto-ish; see the
   DST note in the file).

## Data shape

`crs_pool` row:
```json
{
  "pool_date": "2026-07-05",
  "distribution": [{ "range": "601-1200", "count": 1234 }, "..."],
  "total": 250000,
  "source_url": "https://www.canada.ca/.../rounds-invitations.html",
  "fetched_at": "2026-07-07T13:00:00Z"
}
```
Both the manual form and the Edge Function write the same shape, so trends/analysis
later can read one consistent table.
