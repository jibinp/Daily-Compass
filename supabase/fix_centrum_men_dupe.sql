-- Cleanup: rename flow (item-catalog.html supplementRename) left an orphan
-- "Centrum Men" row behind when renaming to "Multivitamin : Centrum Men"
-- (RLS blocked the supplement_received update — see
-- supplement_received_update_policy.sql). Merge any references still
-- pointing at the orphan name onto the kept name, then drop the orphan.
-- Run supplement_received_update_policy.sql FIRST, then this.
-- Run in Supabase -> SQL Editor.

update supplement_log
  set supplement = 'Multivitamin : Centrum Men'
  where supplement = 'Centrum Men'
    and not exists (
      select 1 from supplement_log l2
      where l2.supplement = 'Multivitamin : Centrum Men' and l2.log_date = supplement_log.log_date
    );
delete from supplement_log where supplement = 'Centrum Men';

update supplement_received
  set supplement = 'Multivitamin : Centrum Men'
  where supplement = 'Centrum Men';

delete from supplements where name = 'Centrum Men';
