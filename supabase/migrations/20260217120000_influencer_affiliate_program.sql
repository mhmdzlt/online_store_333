-- Influencer / affiliate core schema

create table if not exists public.influencer_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  handle text,
  platform text not null,
  audience_size integer,
  contact_phone text,
  contact_email text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  tier text not null default 'starter' check (tier in ('starter', 'pro', 'elite')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.influencer_promo_codes (
  id uuid primary key default gen_random_uuid(),
  influencer_id uuid not null references public.influencer_profiles(id) on delete cascade,
  code text not null unique,
  discount_percent numeric(5,2) not null default 10,
  commission_percent numeric(5,2) not null default 5,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint influencer_promo_codes_code_upper check (code = upper(code)),
  constraint influencer_promo_codes_discount_range check (discount_percent >= 0 and discount_percent <= 100),
  constraint influencer_promo_codes_commission_range check (commission_percent >= 0 and commission_percent <= 100)
);

create table if not exists public.influencer_click_events (
  id bigint generated always as identity primary key,
  promo_code_id uuid references public.influencer_promo_codes(id) on delete set null,
  influencer_id uuid references public.influencer_profiles(id) on delete set null,
  session_id text,
  device_id text,
  source text,
  campaign text,
  landing_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.influencer_order_commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  influencer_id uuid not null references public.influencer_profiles(id) on delete restrict,
  promo_code_id uuid references public.influencer_promo_codes(id) on delete set null,
  order_number text,
  order_total numeric(12,2) not null default 0,
  commission_percent numeric(5,2) not null,
  commission_amount numeric(12,2) not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'paid', 'cancelled')),
  approved_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_influencer_profiles_user_id
  on public.influencer_profiles(user_id);

create index if not exists idx_influencer_promo_codes_influencer_id
  on public.influencer_promo_codes(influencer_id);

create index if not exists idx_influencer_click_events_influencer_id
  on public.influencer_click_events(influencer_id, created_at desc);

create index if not exists idx_influencer_order_commissions_influencer_id
  on public.influencer_order_commissions(influencer_id, created_at desc);

alter table public.influencer_profiles enable row level security;
alter table public.influencer_promo_codes enable row level security;
alter table public.influencer_click_events enable row level security;
alter table public.influencer_order_commissions enable row level security;

-- Influencer can view/manage own profile by auth user id.
drop policy if exists influencer_profiles_select_own on public.influencer_profiles;
create policy influencer_profiles_select_own
  on public.influencer_profiles
  for select
  using (auth.uid() = user_id or public.is_app_admin(auth.uid()));

drop policy if exists influencer_profiles_update_own on public.influencer_profiles;
create policy influencer_profiles_update_own
  on public.influencer_profiles
  for update
  using (auth.uid() = user_id or public.is_app_admin(auth.uid()))
  with check (auth.uid() = user_id or public.is_app_admin(auth.uid()));

drop policy if exists influencer_profiles_insert_own on public.influencer_profiles;
create policy influencer_profiles_insert_own
  on public.influencer_profiles
  for insert
  with check (auth.uid() = user_id or public.is_app_admin(auth.uid()));

-- Promo codes visible to owner influencer + admins.
drop policy if exists influencer_promo_codes_select_own on public.influencer_promo_codes;
create policy influencer_promo_codes_select_own
  on public.influencer_promo_codes
  for select
  using (
    public.is_app_admin(auth.uid()) or exists (
      select 1
      from public.influencer_profiles p
      where p.id = influencer_id and p.user_id = auth.uid()
    )
  );

-- Promo code writes are admin-only.
drop policy if exists influencer_promo_codes_admin_write on public.influencer_promo_codes;
create policy influencer_promo_codes_admin_write
  on public.influencer_promo_codes
  for all
  using (public.is_app_admin(auth.uid()))
  with check (public.is_app_admin(auth.uid()));

-- Click events can be inserted publicly for attribution tracking.
drop policy if exists influencer_click_events_insert_public on public.influencer_click_events;
create policy influencer_click_events_insert_public
  on public.influencer_click_events
  for insert
  with check (true);

drop policy if exists influencer_click_events_select_owner on public.influencer_click_events;
create policy influencer_click_events_select_owner
  on public.influencer_click_events
  for select
  using (
    public.is_app_admin(auth.uid()) or exists (
      select 1
      from public.influencer_profiles p
      where p.id = influencer_id and p.user_id = auth.uid()
    )
  );

-- Commission rows visible to owner influencer + admins.
drop policy if exists influencer_order_commissions_select_owner on public.influencer_order_commissions;
create policy influencer_order_commissions_select_owner
  on public.influencer_order_commissions
  for select
  using (
    public.is_app_admin(auth.uid()) or exists (
      select 1
      from public.influencer_profiles p
      where p.id = influencer_id and p.user_id = auth.uid()
    )
  );

-- Commission writes are admin-only.
drop policy if exists influencer_order_commissions_admin_write on public.influencer_order_commissions;
create policy influencer_order_commissions_admin_write
  on public.influencer_order_commissions
  for all
  using (public.is_app_admin(auth.uid()))
  with check (public.is_app_admin(auth.uid()));

-- Keep updated_at fresh.
create or replace function public.set_influencer_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_influencer_profiles_updated_at on public.influencer_profiles;
create trigger trg_influencer_profiles_updated_at
before update on public.influencer_profiles
for each row execute function public.set_influencer_updated_at();

drop trigger if exists trg_influencer_promo_codes_updated_at on public.influencer_promo_codes;
create trigger trg_influencer_promo_codes_updated_at
before update on public.influencer_promo_codes
for each row execute function public.set_influencer_updated_at();

drop trigger if exists trg_influencer_order_commissions_updated_at on public.influencer_order_commissions;
create trigger trg_influencer_order_commissions_updated_at
before update on public.influencer_order_commissions
for each row execute function public.set_influencer_updated_at();
