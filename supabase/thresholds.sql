-- Generic thresholds: pass/fail bars for metrics (fasting duration, and
-- whatever else gets added later). Same effective-dated pattern as
-- nutrition_targets — a metric's threshold can change any time; whichever
-- row has the latest effective_date <= a given date is "the" threshold for
-- that date. Editable from thresholds.html. Run in Supabase → SQL Editor.

create table if not exists thresholds (
  id             bigint generated always as identity primary key,
  metric_key     text    not null,
  value          numeric not null,
  effective_date date    not null,
  unique (metric_key, effective_date)
);

alter table thresholds enable row level security;

drop policy if exists "thresholds read"   on thresholds;
drop policy if exists "thresholds insert" on thresholds;
drop policy if exists "thresholds update" on thresholds;
create policy "thresholds read"   on thresholds for select to authenticated using (true);
create policy "thresholds insert" on thresholds for insert to authenticated with check (true);
create policy "thresholds update" on thresholds for update to authenticated using (true);

-- Seed today's fasting threshold at 16h (the value already hardcoded in the
-- app) so the Fasting window card / column has something to compare against
-- immediately. Change any time from the Thresholds settings page.
insert into thresholds (metric_key, value, effective_date)
values ('fasting_hours', 16, current_date)
on conflict (metric_key, effective_date) do nothing;
