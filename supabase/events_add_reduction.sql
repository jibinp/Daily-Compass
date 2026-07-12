-- Wakeup "additional reduction" — minutes subtracted from the computed sleep
-- duration (e.g. time spent awake in bed before actually getting up).
-- Run in Supabase → SQL Editor.

alter table events add column if not exists reduction_min integer;
