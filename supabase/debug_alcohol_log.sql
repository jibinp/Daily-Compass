-- Diagnostic only, not a migration. Shows: (1) actual current rows in
-- alcohol_log (real ids), (2) whether the update policy actually exists.
select id, log_date, alcohol_item, shots from alcohol_log order by log_date desc, id desc limit 20;

select policyname, cmd, qual, with_check from pg_policies where tablename = 'alcohol_log';
