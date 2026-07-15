-- Split freeform ingredient amount into value + unit + form, e.g.
-- "8 mg (Zinc Sulphate)" becomes amount_value=8, amount_unit='mg',
-- amount_form='Zinc Sulphate'. Parses existing amount text before
-- dropping it. Run in Supabase → SQL Editor.

alter table supplement_ingredients add column if not exists amount_value numeric;
alter table supplement_ingredients add column if not exists amount_unit text;
alter table supplement_ingredients add column if not exists amount_form text;

update supplement_ingredients
set amount_value = nullif((regexp_match(amount, '^\s*([\d.]+)'))[1], '')::numeric,
    amount_unit  = (regexp_match(amount, '^\s*[\d.]+\s*([a-zA-Zµ%]+)'))[1],
    amount_form  = (regexp_match(amount, '\(([^)]+)\)'))[1]
where amount is not null;

alter table supplement_ingredients drop column if exists amount;
