-- alcohol_log.sql only created read/insert/delete policies — missing update,
-- needed now that +/- taps update an existing day's row (merge into one
-- line per drink) instead of always inserting a new one.
drop policy if exists "alcohol_log update" on alcohol_log;
create policy "alcohol_log update" on alcohol_log for update to authenticated using (true);
