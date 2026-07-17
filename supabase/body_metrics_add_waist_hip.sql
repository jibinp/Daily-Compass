-- Waist / hip measurements, alongside weight/height. Canonical unit cm
-- (matches height_cm). Run in Supabase → SQL Editor.
alter table body_metrics add column if not exists waist_cm numeric;
alter table body_metrics add column if not exists hip_cm numeric;
