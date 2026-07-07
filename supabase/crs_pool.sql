-- CRS pool distribution snapshots (one row per "pool as of" date).
-- Run in Supabase → SQL Editor.

create table if not exists crs_pool (
  pool_date   date primary key,        -- the "pool as of" date IRCC publishes
  distribution jsonb not null,          -- [{ "range": "601-1200", "count": 1234 }, ...]
  total       integer,                  -- Total row, if present
  source_url  text,
  fetched_at  timestamptz default now()
);

alter table crs_pool enable row level security;

-- Single-user app: any authenticated user may read/write.
create policy "crs_pool read"   on crs_pool for select to authenticated using (true);
create policy "crs_pool insert" on crs_pool for insert to authenticated with check (true);
create policy "crs_pool update" on crs_pool for update to authenticated using (true);
