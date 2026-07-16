-- Alcohol tracker: manageable list of alcohol items (type + subtype + ABV%)
-- + a daily shots-taken log. A day can have multiple entries (even for the
-- same drink), so alcohol_log is transactional (own id per entry), not one
-- row per item per day. Run in Supabase → SQL Editor. (Supersedes an
-- earlier one-row-per-item-per-day version of alcohol_log — drops it if
-- present; alcohol_items is untouched.)

create table if not exists alcohol_items (
  name        text primary key,
  type        text not null,   -- 'Hard Liquor' | 'Wine' | 'Beer'
  subtype     text,            -- free text, e.g. Whiskey, Rum, Red, Lager
  abv_percent numeric,
  notes       text,
  active      boolean not null default true,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

drop table if exists alcohol_log;

create table alcohol_log (
  id           bigint generated always as identity primary key,
  log_date     date not null,
  alcohol_item text not null references alcohol_items(name) on delete cascade,
  shots        numeric,
  created_at   timestamptz not null default now()
);

alter table alcohol_items enable row level security;
alter table alcohol_log enable row level security;

drop policy if exists "alcohol_items read"   on alcohol_items;
drop policy if exists "alcohol_items insert" on alcohol_items;
drop policy if exists "alcohol_items update" on alcohol_items;
create policy "alcohol_items read"   on alcohol_items for select to authenticated using (true);
create policy "alcohol_items insert" on alcohol_items for insert to authenticated with check (true);
create policy "alcohol_items update" on alcohol_items for update to authenticated using (true);

drop policy if exists "alcohol_log read"   on alcohol_log;
drop policy if exists "alcohol_log insert" on alcohol_log;
drop policy if exists "alcohol_log delete" on alcohol_log;
create policy "alcohol_log read"   on alcohol_log for select to authenticated using (true);
create policy "alcohol_log insert" on alcohol_log for insert to authenticated with check (true);
create policy "alcohol_log delete" on alcohol_log for delete to authenticated using (true);
