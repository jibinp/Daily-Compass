-- Money Log: same shape as Daily Counts — one row per day, fixed
-- amount-per-category fields, single currency for the day. Run in
-- Supabase → SQL Editor. (Supersedes an earlier transactional version
-- of this file — drops it if present.)

drop table if exists money_log;
drop table if exists expense_categories;

create table if not exists money_log (
  log_date date primary key,
  mstbn    numeric,
  fk       numeric,
  sn_msg   numeric,
  fk_msg   numeric,
  aop      numeric,
  sxcl     numeric,
  fd       numeric,
  alc      numeric,
  ub       numeric,
  bk_chrg  numeric,
  currency text
);

alter table money_log enable row level security;

drop policy if exists "money_log read"   on money_log;
drop policy if exists "money_log insert" on money_log;
drop policy if exists "money_log update" on money_log;
drop policy if exists "money_log delete" on money_log;
create policy "money_log read"   on money_log for select to authenticated using (true);
create policy "money_log insert" on money_log for insert to authenticated with check (true);
create policy "money_log update" on money_log for update to authenticated using (true);
create policy "money_log delete" on money_log for delete to authenticated using (true);
