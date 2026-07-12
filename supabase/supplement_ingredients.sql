-- Each supplement entry is now a tablet that can contain multiple
-- ingredients (e.g. one multivitamin tablet = Vitamin D3 + B12 + Zinc).
-- Run in Supabase → SQL Editor (after supplement_tracker.sql).

create table if not exists supplement_ingredients (
  id         bigint generated always as identity primary key,
  supplement text not null references supplements(name) on delete cascade,
  ingredient text not null,
  amount     text,
  sort_order int not null default 0
);

alter table supplement_ingredients enable row level security;

create policy "supplement_ingredients read"   on supplement_ingredients for select to authenticated using (true);
create policy "supplement_ingredients insert" on supplement_ingredients for insert to authenticated with check (true);
create policy "supplement_ingredients update" on supplement_ingredients for update to authenticated using (true);
create policy "supplement_ingredients delete" on supplement_ingredients for delete to authenticated using (true);
