-- Expense categories (fixed/manageable list) + money log: individual
-- transactional entries, each with its own currency. Run in
-- Supabase → SQL Editor.

create table if not exists expense_categories (
  name       text primary key,
  active     boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists money_log (
  id         bigint generated always as identity primary key,
  log_date   date not null,
  category   text not null references expense_categories(name) on delete cascade,
  amount     numeric not null,
  currency   text not null,
  notes      text,
  created_at timestamptz not null default now()
);

alter table expense_categories enable row level security;
alter table money_log enable row level security;

drop policy if exists "expense_categories read"   on expense_categories;
drop policy if exists "expense_categories insert" on expense_categories;
drop policy if exists "expense_categories update" on expense_categories;
create policy "expense_categories read"   on expense_categories for select to authenticated using (true);
create policy "expense_categories insert" on expense_categories for insert to authenticated with check (true);
create policy "expense_categories update" on expense_categories for update to authenticated using (true);

drop policy if exists "money_log read"   on money_log;
drop policy if exists "money_log insert" on money_log;
drop policy if exists "money_log update" on money_log;
drop policy if exists "money_log delete" on money_log;
create policy "money_log read"   on money_log for select to authenticated using (true);
create policy "money_log insert" on money_log for insert to authenticated with check (true);
create policy "money_log update" on money_log for update to authenticated using (true);
create policy "money_log delete" on money_log for delete to authenticated using (true);

insert into expense_categories (name, sort_order) values
  ('Mstbn', 0), ('Fk', 1), ('Sn Msg', 2), ('Fk Msg', 3), ('AoP', 4), ('sxCl', 5),
  ('Fd', 6), ('Alc', 7), ('Ub', 8), ('BkChrg', 9)
on conflict (name) do nothing;
