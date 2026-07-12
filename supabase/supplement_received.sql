-- Log of when a new tablet/bottle was received (stock arrival), separate
-- from the daily taken/not-taken checklist. Run in Supabase → SQL Editor
-- (after supplement_tracker.sql).

create table if not exists supplement_received (
  id            bigint generated always as identity primary key,
  supplement    text not null references supplements(name) on delete cascade,
  received_date date not null,
  created_at    timestamptz not null default now()
);

alter table supplement_received enable row level security;

create policy "supplement_received read"   on supplement_received for select to authenticated using (true);
create policy "supplement_received insert" on supplement_received for insert to authenticated with check (true);
create policy "supplement_received delete" on supplement_received for delete to authenticated using (true);
