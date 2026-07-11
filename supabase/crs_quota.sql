-- Yearly Express Entry admissions quota (one overall target per year).
-- Run in Supabase → SQL Editor.

create table if not exists crs_quota (
  year  int primary key,
  quota int not null
);

alter table crs_quota enable row level security;

create policy "crs_quota read"   on crs_quota for select to authenticated using (true);
create policy "crs_quota insert" on crs_quota for insert to authenticated with check (true);
create policy "crs_quota update" on crs_quota for update to authenticated using (true);
