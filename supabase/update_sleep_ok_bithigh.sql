-- Sleep bands corrected: <6 Very low, 6-7 Warning, 7-9 OK, 9-10 Bit high,
-- >10 Over. verylow(6)/warn(7) unchanged; ok 8->9, bithigh 9->10. Updates
-- every existing row for these two keys (both the today-seed and the
-- 2022-01-01 backdate), not just one effective_date.
update thresholds set value = 9  where metric_key = 'sleep_h_ok';
update thresholds set value = 10 where metric_key = 'sleep_h_bithigh';
