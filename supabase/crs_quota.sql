-- Express Entry admissions quota, per category per year. Use category
-- 'Total' for an explicit overall target; per-category rows (matching a
-- draw's round_type) let usage be tracked separately.
-- Run in Supabase → SQL Editor.
-- (Upgrading an existing year-only crs_quota table? Run
--  crs_quota_migrate_category.sql instead.)

create table if not exists crs_quota (
  year     int not null,
  category text not null default 'Total',
  quota    int not null,
  primary key (year, category)
);

alter table crs_quota enable row level security;

create policy "crs_quota read"   on crs_quota for select to authenticated using (true);
create policy "crs_quota insert" on crs_quota for insert to authenticated with check (true);
create policy "crs_quota update" on crs_quota for update to authenticated using (true);
