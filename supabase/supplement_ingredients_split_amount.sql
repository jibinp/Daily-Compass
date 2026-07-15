-- Split freeform ingredient amount into value + unit + form, e.g.
-- "8 mg (Zinc Sulphate)" becomes amount_value=8, amount_unit='mg',
-- amount_form='Zinc Sulphate'. Run in Supabase → SQL Editor.

alter table supplement_ingredients add column if not exists amount_value numeric;
alter table supplement_ingredients add column if not exists amount_unit text;
alter table supplement_ingredients add column if not exists amount_form text;

-- Hand-verified overrides for the 3 tablets entered earlier this session
-- (raw amount text was inserted multiple times across naming iterations —
-- delete-then-insert avoids any leftover duplicate ingredient rows).
delete from supplement_ingredients where supplement in (
  'Pure Nutrition Iron with Folic Acid + Vitamin C & Zinc',
  'Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)',
  'Health Veda Zinc Citrate',
  'Carbamide Forte Vitamin D3 + K2'
);

insert into supplement_ingredients (supplement, ingredient, amount_value, amount_unit, amount_form, sort_order) values
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Zinc', 8, 'mg', 'Zinc Sulphate', 0),
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Iron', 19, 'mg', 'Ferrous Bisglycinate', 1),
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Ficus carica extract', 50, 'mg', null, 2),
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Vitamin C (L-Ascorbic Acid)', 80, 'mg', null, 3),
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Vitamin B12', 2.2, 'mcg', null, 4),
('Pure Nutrition Iron (Folic acid, Vitamin C & Zinc)', 'Folic Acid', 176, 'mcg', null, 5),
('Health Veda Zinc Citrate', 'Zinc', 13.2, 'mg', 'Zinc Citrate 44 mg', 0),
('Carbamide Forte Vitamin D3 + K2', 'Vitamin K2', 55, 'mcg', 'MK-7 Menaquinone-7', 0),
('Carbamide Forte Vitamin D3 + K2', 'Vitamin D3', 600, 'IU', 'Cholecalciferol, from Lichen (15 mcg)', 1);

alter table supplement_ingredients drop column if exists amount;
