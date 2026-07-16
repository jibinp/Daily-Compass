-- Daily Counts: one row per day, fixed float count fields. Run in
-- Supabase → SQL Editor.

create table if not exists daily_counts (
  log_date date primary key,
  mstbn  numeric,
  fk     numeric,
  sn_msg numeric,
  fk_msg numeric,
  aop    numeric,
  sxcl   numeric
);

alter table daily_counts enable row level security;

drop policy if exists "daily_counts read"   on daily_counts;
drop policy if exists "daily_counts insert" on daily_counts;
drop policy if exists "daily_counts update" on daily_counts;
drop policy if exists "daily_counts delete" on daily_counts;
create policy "daily_counts read"   on daily_counts for select to authenticated using (true);
create policy "daily_counts insert" on daily_counts for insert to authenticated with check (true);
create policy "daily_counts update" on daily_counts for update to authenticated using (true);
create policy "daily_counts delete" on daily_counts for delete to authenticated using (true);
