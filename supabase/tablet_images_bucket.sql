-- Public storage bucket for tablet pictures uploaded from the
-- add/edit-tablet forms. Run in Supabase → SQL Editor.

insert into storage.buckets (id, name, public)
values ('tablet-images', 'tablet-images', true)
on conflict (id) do nothing;

create policy "tablet-images public read" on storage.objects
  for select to public using (bucket_id = 'tablet-images');

create policy "tablet-images authenticated upload" on storage.objects
  for insert to authenticated with check (bucket_id = 'tablet-images');

create policy "tablet-images authenticated update" on storage.objects
  for update to authenticated using (bucket_id = 'tablet-images');

create policy "tablet-images authenticated delete" on storage.objects
  for delete to authenticated using (bucket_id = 'tablet-images');
