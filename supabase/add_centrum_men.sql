-- Add "Centrum Men" multivitamin tablet + its ingredient panel.
-- Values transcribed from the product label (%DV kept in amount_form
-- since there's no dedicated %DV column). Assumed serving = 1 tablet.
-- Run in Supabase -> SQL Editor.

insert into supplements (name, dose, notes, active, sort_order) values
('Centrum Men', '1 tablet', 'Energy 2.38 kcal, Protein 0.07 g per serving.', true,
  (select coalesce(max(sort_order), -1) + 1 from supplements))
on conflict (name) do nothing;

delete from supplement_ingredients where supplement = 'Centrum Men';

insert into supplement_ingredients (supplement, ingredient, amount_value, amount_unit, amount_form, sort_order) values
('Centrum Men', 'Vitamin A',      800,  'mcg', '80% DV', 0),
('Centrum Men', 'Vitamin C',      80,   'mg',  '100% DV', 1),
('Centrum Men', 'Vitamin D2',     600,  'IU',  '100% DV', 2),
('Centrum Men', 'Vitamin E',      5,    'mg',  '50% DV', 3),
('Centrum Men', 'Biotin',         25,   'mcg', '63% DV', 4),
('Centrum Men', 'Folate',         200,  'mcg', '67% DV', 5),
('Centrum Men', 'Vitamin B12',    2.2,  'mcg', '100% DV', 6),
('Centrum Men', 'Vitamin B1',     1.2,  'mg',  '67% DV', 7),
('Centrum Men', 'Vitamin B2',     1.2,  'mg',  '48% DV', 8),
('Centrum Men', 'Vitamin B3',     15,   'mg',  '83% DV', 9),
('Centrum Men', 'Vitamin B5',     5,    'mg',  '100% DV', 10),
('Centrum Men', 'Vitamin B6',     1.3,  'mg',  '54% DV', 11),
('Centrum Men', 'Vitamin K1',     55,   'mcg', '100% DV', 12),
('Centrum Men', 'Calcium',        250,  'mg',  '25% DV', 13),
('Centrum Men', 'Iron',           3.7,  'mg',  '19% DV', 14),
('Centrum Men', 'Zinc',           11,   'mg',  '65% DV', 15),
('Centrum Men', 'Iodine',         140,  'mcg', '100% DV', 16),
('Centrum Men', 'Magnesium',      66,   'mg',  '15% DV', 17),
('Centrum Men', 'Manganese',      1.2,  'mg',  '30% DV', 18),
('Centrum Men', 'Copper',         0.45, 'mg',  '26% DV', 19),
('Centrum Men', 'Selenium',       40,   'mcg', '100% DV', 20),
('Centrum Men', 'Chromium',       17.5, 'mcg', '35% DV', 21),
('Centrum Men', 'Molybdenum',     45,   'mcg', '100% DV', 22);
