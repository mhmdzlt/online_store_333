create table if not exists public.donation_reports (
  id uuid primary key default gen_random_uuid(),
  donation_id uuid not null references public.donations(id) on delete cascade,
  reason text not null,
  details text,
  reporter_name text,
  reporter_phone text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists donation_reports_donation_id_idx
  on public.donation_reports (donation_id);

create index if not exists donation_reports_status_idx
  on public.donation_reports (status);

create or replace function public.touch_donation_reports_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_donation_reports_updated_at on public.donation_reports;
create trigger trg_touch_donation_reports_updated_at
before update on public.donation_reports
for each row execute function public.touch_donation_reports_updated_at();

grant select, insert on table public.donation_reports to anon, authenticated;
grant update on table public.donation_reports to authenticated;
