-- Meal log: one freeform entry per day (macros + what was eaten), compared
-- against nutrition targets that are versioned by effective_date — targets
-- change occasionally, not daily, so each day compares against whichever
-- target row was most recently in effect on or before that date.
-- Run in Supabase → SQL Editor.

create table if not exists meal_log (
  log_date date primary key,
  calories numeric,
  protein  numeric,
  fat      numeric,
  fiber    numeric,
  carbs    numeric,
  eaten    text,
  remarks  text
);

create table if not exists nutrition_targets (
  effective_date date primary key,
  calorie_limit  numeric,
  protein_min    numeric,
  fat_limit      numeric,
  carb_limit     numeric,
  fiber_min      numeric,
  created_at timestamptz not null default now()
);

alter table meal_log enable row level security;
alter table nutrition_targets enable row level security;

drop policy if exists "meal_log read"   on meal_log;
drop policy if exists "meal_log insert" on meal_log;
drop policy if exists "meal_log update" on meal_log;
drop policy if exists "meal_log delete" on meal_log;
create policy "meal_log read"   on meal_log for select to authenticated using (true);
create policy "meal_log insert" on meal_log for insert to authenticated with check (true);
create policy "meal_log update" on meal_log for update to authenticated using (true);
create policy "meal_log delete" on meal_log for delete to authenticated using (true);

drop policy if exists "nutrition_targets read"   on nutrition_targets;
drop policy if exists "nutrition_targets insert" on nutrition_targets;
create policy "nutrition_targets read"   on nutrition_targets for select to authenticated using (true);
create policy "nutrition_targets insert" on nutrition_targets for insert to authenticated with check (true);
