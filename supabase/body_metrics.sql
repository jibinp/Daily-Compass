-- Daily weight/height entry for BMI. One row per log date. Always stores
-- canonical metric units (kg, cm) — unit display preference (kg/lbs,
-- cm/in) lives client-side only. Run in Supabase → SQL Editor.

create table if not exists body_metrics (
  log_date   date primary key,
  weight_kg  numeric,
  height_cm  numeric,
  created_at timestamptz not null default now()
);

alter table body_metrics enable row level security;

create policy "body_metrics read"   on body_metrics for select to authenticated using (true);
create policy "body_metrics insert" on body_metrics for insert to authenticated with check (true);
create policy "body_metrics update" on body_metrics for update to authenticated using (true);
create policy "body_metrics delete" on body_metrics for delete to authenticated using (true);
