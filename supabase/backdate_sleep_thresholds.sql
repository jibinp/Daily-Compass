insert into thresholds (metric_key, value, effective_date) values
  ('sleep_h_verylow', 6, '2022-01-01'),
  ('sleep_h_warn',    7, '2022-01-01'),
  ('sleep_h_ok',      8, '2022-01-01'),
  ('sleep_h_bithigh', 9, '2022-01-01')
on conflict (metric_key, effective_date) do nothing;
