-- Adds per-category quotas (year + category, instead of year-only).
-- Existing rows (whole-year quotas) become category = 'Total'.
-- Run in Supabase → SQL Editor. Safe to run once; re-running is a no-op
-- for the parts already applied (guarded by IF NOT EXISTS / catalog checks).

alter table crs_quota add column if not exists category text not null default 'Total';

-- drop the old year-only primary key, add composite (year, category)
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'crs_quota'::regclass and contype = 'p' and conname = 'crs_quota_pkey'
  ) then
    alter table crs_quota drop constraint crs_quota_pkey;
  end if;
end $$;

alter table crs_quota add primary key (year, category);
