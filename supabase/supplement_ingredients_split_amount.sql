-- Split freeform ingredient amount into value + unit + form, e.g.
-- "8 mg (Zinc Sulphate)" becomes amount_value=8, amount_unit='mg',
-- amount_form='Zinc Sulphate'. No existing data preserved — re-enter
-- ingredient amounts via the UI after running this. Run in Supabase →
-- SQL Editor.

alter table supplement_ingredients drop column if exists amount;
alter table supplement_ingredients add column if not exists amount_value numeric;
alter table supplement_ingredients add column if not exists amount_unit text;
alter table supplement_ingredients add column if not exists amount_form text;
