-- How many tablets/pills arrived, alongside the existing received date.
-- Run in Supabase → SQL Editor (after supplement_received.sql).

alter table supplement_received add column if not exists quantity integer;
