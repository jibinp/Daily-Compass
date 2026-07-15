-- How many tablets were taken, alongside the existing taken/not-taken flag.
-- Run in Supabase → SQL Editor (after supplement_tracker.sql).

alter table supplement_log add column if not exists quantity integer;
