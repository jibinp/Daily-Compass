-- Optional picture per tablet, shown in the checklist and tablet list.
-- Run in Supabase → SQL Editor (after supplement_tracker.sql).

alter table supplements add column if not exists image_url text;
