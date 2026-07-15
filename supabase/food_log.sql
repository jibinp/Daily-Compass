-- Food log: a manageable list of food items (like supplements), each
-- logged with a float quantity per day. Run in Supabase → SQL Editor.

create table if not exists food_items (
  name       text primary key,
  active     boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists food_log (
  log_date  date not null,
  food_item text not null references food_items(name) on delete cascade,
  quantity  numeric,
  primary key (log_date, food_item)
);

alter table food_items enable row level security;
alter table food_log enable row level security;

drop policy if exists "food_items read"   on food_items;
drop policy if exists "food_items insert" on food_items;
drop policy if exists "food_items update" on food_items;
create policy "food_items read"   on food_items for select to authenticated using (true);
create policy "food_items insert" on food_items for insert to authenticated with check (true);
create policy "food_items update" on food_items for update to authenticated using (true);

drop policy if exists "food_log read"   on food_log;
drop policy if exists "food_log insert" on food_log;
drop policy if exists "food_log update" on food_log;
drop policy if exists "food_log delete" on food_log;
create policy "food_log read"   on food_log for select to authenticated using (true);
create policy "food_log insert" on food_log for insert to authenticated with check (true);
create policy "food_log update" on food_log for update to authenticated using (true);
create policy "food_log delete" on food_log for delete to authenticated using (true);

insert into food_items (name, sort_order) values
  ('Egg', 0),
  ('Apple cider vinegar', 1),
  ('Lemon', 2),
  ('Turmeric Ginger Tea', 3),
  ('Electrolyte', 4),
  ('Nuts', 5)
on conflict (name) do nothing;
