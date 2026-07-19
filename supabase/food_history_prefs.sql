-- Persists which food-item chips are selected on food-history.html, so the
-- picker survives a page refresh. Single-row settings table, same
-- singleton pattern as user_profile / supplement_history_prefs.
-- Run in Supabase -> SQL Editor.

create table if not exists food_history_prefs (
  id             int primary key default 1,
  selected_items jsonb not null default '[]'  -- [food_item_name, ...]
);

alter table food_history_prefs enable row level security;

drop policy if exists "food_history_prefs read"   on food_history_prefs;
drop policy if exists "food_history_prefs insert" on food_history_prefs;
drop policy if exists "food_history_prefs update" on food_history_prefs;
create policy "food_history_prefs read"   on food_history_prefs for select to authenticated using (true);
create policy "food_history_prefs insert" on food_history_prefs for insert to authenticated with check (true);
create policy "food_history_prefs update" on food_history_prefs for update to authenticated using (true);
