-- One-time cleanup: merges existing duplicate alcohol_log rows (same
-- log_date + alcohol_item logged as separate entries, from before the
-- +/- buttons started merging) into a single row with summed shots.
-- Safe to re-run (no-ops once there's nothing left to merge).

with grouped as (
  select log_date, alcohol_item, sum(shots) as total_shots, min(id) as keep_id
  from alcohol_log
  group by log_date, alcohol_item
  having count(*) > 1
)
update alcohol_log a
set shots = g.total_shots
from grouped g
where a.id = g.keep_id;

with grouped as (
  select log_date, alcohol_item, min(id) as keep_id
  from alcohol_log
  group by log_date, alcohol_item
  having count(*) > 1
)
delete from alcohol_log a
using grouped g
where a.log_date = g.log_date
  and a.alcohol_item = g.alcohol_item
  and a.id <> g.keep_id;
