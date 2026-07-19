-- supplements, alcohol_items, food_items were missing DELETE policies.
-- Their rename flows (supplementRename / alcoholItemRename / foodItemRename
-- in item-catalog.html) insert the new-name row then delete the old-name
-- row last. Without a delete policy that final delete is silently blocked
-- by RLS, leaving both old and new rows behind after every rename.
-- Run in Supabase -> SQL Editor.

create policy "supplements delete"   on supplements   for delete to authenticated using (true);
create policy "alcohol_items delete" on alcohol_items for delete to authenticated using (true);
create policy "food_items delete"    on food_items    for delete to authenticated using (true);
