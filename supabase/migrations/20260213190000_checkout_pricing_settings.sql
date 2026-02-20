begin;

create table if not exists public.checkout_pricing_settings (
  id boolean primary key default true,
  shipping_cost_courier numeric not null default 3000,
  shipping_cost_local numeric not null default 0,
  service_fee numeric not null default 0,
  updated_at timestamptz not null default now(),
  constraint checkout_pricing_settings_singleton check (id = true),
  constraint checkout_pricing_settings_non_negative check (
    shipping_cost_courier >= 0 and shipping_cost_local >= 0 and service_fee >= 0
  )
);

insert into public.checkout_pricing_settings (id)
values (true)
on conflict (id) do nothing;

alter table public.checkout_pricing_settings enable row level security;

drop policy if exists checkout_pricing_select_public on public.checkout_pricing_settings;
create policy checkout_pricing_select_public
  on public.checkout_pricing_settings
  for select
  to anon, authenticated
  using (true);

drop policy if exists checkout_pricing_update_authenticated on public.checkout_pricing_settings;
create policy checkout_pricing_update_authenticated
  on public.checkout_pricing_settings
  for update
  to authenticated
  using (true)
  with check (true);

commit;
