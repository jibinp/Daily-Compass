-- Root-cause fix for the rename-creates-2-rows bug: supplements/alcohol_items/
-- food_items had no surrogate id, so item-catalog.html faked a rename via
-- insert-new -> update children -> delete-old (4 separate RLS-gated calls).
-- Any one call failing left old + new rows both present.
--
-- Add ON UPDATE CASCADE to every FK referencing these name-as-PK tables, so
-- a rename becomes one atomic `update ... set name = new where name = old`
-- and Postgres itself propagates the new name to every child row. No more
-- multi-step dance, no more partial-failure duplicates.
-- Run in Supabase -> SQL Editor.

alter table supplement_log
  drop constraint if exists supplement_log_supplement_fkey,
  add constraint supplement_log_supplement_fkey
    foreign key (supplement) references supplements(name) on delete cascade on update cascade;

alter table supplement_received
  drop constraint if exists supplement_received_supplement_fkey,
  add constraint supplement_received_supplement_fkey
    foreign key (supplement) references supplements(name) on delete cascade on update cascade;

alter table supplement_ingredients
  drop constraint if exists supplement_ingredients_supplement_fkey,
  add constraint supplement_ingredients_supplement_fkey
    foreign key (supplement) references supplements(name) on delete cascade on update cascade;

alter table alcohol_log
  drop constraint if exists alcohol_log_alcohol_item_fkey,
  add constraint alcohol_log_alcohol_item_fkey
    foreign key (alcohol_item) references alcohol_items(name) on delete cascade on update cascade;

alter table food_log
  drop constraint if exists food_log_food_item_fkey,
  add constraint food_log_food_item_fkey
    foreign key (food_item) references food_items(name) on delete cascade on update cascade;
