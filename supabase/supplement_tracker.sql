-- Supplement Tracker: a fixed list of supplements + a daily taken/not-taken
-- checklist. Run in Supabase → SQL Editor.

create table if not exists supplements (
  name       text primary key,
  dose       text,
  notes      text,
  active     boolean not null default true,   -- archived supplements stay in history but drop off today's checklist
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists supplement_log (
  log_date   date not null,
  supplement text not null references supplements(name) on delete cascade,
  taken      boolean not null default true,
  taken_at   timestamptz,
  primary key (log_date, supplement)
);

alter table supplements enable row level security;
alter table supplement_log enable row level security;

create policy "supplements read"   on supplements for select to authenticated using (true);
create policy "supplements insert" on supplements for insert to authenticated with check (true);
create policy "supplements update" on supplements for update to authenticated using (true);

create policy "supplement_log read"   on supplement_log for select to authenticated using (true);
create policy "supplement_log insert" on supplement_log for insert to authenticated with check (true);
create policy "supplement_log update" on supplement_log for update to authenticated using (true);
create policy "supplement_log delete" on supplement_log for delete to authenticated using (true);
