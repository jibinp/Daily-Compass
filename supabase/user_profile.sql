-- One-time profile settings (single row) — date of birth + sex, needed for
-- BMR (age changes daily, so DOB is stored once and age is computed on the
-- fly rather than re-entered). Run in Supabase → SQL Editor.

create table if not exists user_profile (
  id             int primary key default 1,
  date_of_birth  date,
  sex            text   -- 'male' | 'female'
);

alter table user_profile enable row level security;

drop policy if exists "user_profile read"   on user_profile;
drop policy if exists "user_profile insert" on user_profile;
drop policy if exists "user_profile update" on user_profile;
create policy "user_profile read"   on user_profile for select to authenticated using (true);
create policy "user_profile insert" on user_profile for insert to authenticated with check (true);
create policy "user_profile update" on user_profile for update to authenticated using (true);
