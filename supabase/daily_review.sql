-- Marks a log_date as explicitly reviewed ("checked everything, nothing
-- else to add") — a row existing IS the flag, no boolean column needed.
-- Distinguishes "confirmed nothing taken/logged" from "just never entered
-- anything" for alcohol_log/food_log (which have no per-row taken/not-taken
-- flag, unlike supplement_log) so history pages can render three states
-- instead of two. Run in Supabase -> SQL Editor.

create table if not exists daily_review (
  log_date date primary key
);

alter table daily_review enable row level security;

drop policy if exists "daily_review read"   on daily_review;
drop policy if exists "daily_review insert" on daily_review;
drop policy if exists "daily_review delete" on daily_review;
create policy "daily_review read"   on daily_review for select to authenticated using (true);
create policy "daily_review insert" on daily_review for insert to authenticated with check (true);
create policy "daily_review delete" on daily_review for delete to authenticated using (true);
