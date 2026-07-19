-- supplement_received was missing an UPDATE policy — rename flow (item-catalog.html
-- supplementRename) updates supplement_received.supplement to the new name before
-- deleting the old supplements row. Without this policy the update silently fails
-- RLS, the delete never runs, and the rename leaves both old and new rows behind.
-- Run in Supabase -> SQL Editor.

create policy "supplement_received update" on supplement_received for update to authenticated using (true);
