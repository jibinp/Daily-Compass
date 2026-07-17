-- Seed sleep-duration band cutoffs (thresholds.html / Time History Sleep
-- column / Data Entry Sleep card): <6h Very low, 6-7h Warning, 7-8h OK,
-- 8-9h Bit high, >9h Over. Effective from today — to backdate like the
-- fasting threshold, insert another row with an earlier effective_date.
insert into thresholds (metric_key, value, effective_date) values
  ('sleep_h_verylow', 6, current_date),
  ('sleep_h_warn',    7, current_date),
  ('sleep_h_ok',      8, current_date),
  ('sleep_h_bithigh', 9, current_date)
on conflict (metric_key, effective_date) do nothing;
