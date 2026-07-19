-- Persists which ingredient chips are selected on supplement-history.html,
-- so the picker survives a page refresh instead of resetting to empty every
-- time. Single-row settings table, same singleton pattern as user_profile.
-- Run in Supabase -> SQL Editor.

create table if not exists supplement_history_prefs (
  id                    int primary key default 1,
  selected_ingredients  jsonb not null default '[]'  -- [{ingredient, unit}, ...]
);

alter table supplement_history_prefs enable row level security;

drop policy if exists "supplement_history_prefs read"   on supplement_history_prefs;
drop policy if exists "supplement_history_prefs insert" on supplement_history_prefs;
drop policy if exists "supplement_history_prefs update" on supplement_history_prefs;
create policy "supplement_history_prefs read"   on supplement_history_prefs for select to authenticated using (true);
create policy "supplement_history_prefs insert" on supplement_history_prefs for insert to authenticated with check (true);
create policy "supplement_history_prefs update" on supplement_history_prefs for update to authenticated using (true);
