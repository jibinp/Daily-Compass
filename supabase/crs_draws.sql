-- Express Entry draws (rounds of invitations). Run in Supabase → SQL Editor,
-- then run crs_draws_seed.sql to load history.

create table if not exists crs_draws (
  draw_number  int primary key,
  draw_date    date not null,
  round_type   text,          -- e.g. "Canadian Experience Class", "Provincial Nominee Program"
  invitations  int,           -- ITAs issued
  crs_cutoff   int            -- CRS of lowest-ranked candidate invited
);

alter table crs_draws enable row level security;

create policy "crs_draws read"   on crs_draws for select to authenticated using (true);
create policy "crs_draws insert" on crs_draws for insert to authenticated with check (true);
create policy "crs_draws update" on crs_draws for update to authenticated using (true);
