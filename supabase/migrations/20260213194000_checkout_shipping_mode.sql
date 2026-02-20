begin;

alter table if exists public.checkout_pricing_settings
  add column if not exists shipping_mode text not null default 'fixed';

alter table if exists public.checkout_pricing_settings
  add column if not exists shipping_percentage numeric not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'checkout_pricing_settings_shipping_mode_check'
      and conrelid = 'public.checkout_pricing_settings'::regclass
  ) then
    alter table public.checkout_pricing_settings
      add constraint checkout_pricing_settings_shipping_mode_check
      check (shipping_mode in ('fixed', 'percentage'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'checkout_pricing_settings_shipping_percentage_range'
      and conrelid = 'public.checkout_pricing_settings'::regclass
  ) then
    alter table public.checkout_pricing_settings
      add constraint checkout_pricing_settings_shipping_percentage_range
      check (shipping_percentage >= 0 and shipping_percentage <= 100);
  end if;
end $$;

update public.checkout_pricing_settings
set shipping_mode = coalesce(shipping_mode, 'fixed'),
    shipping_percentage = coalesce(shipping_percentage, 0)
where id = true;

commit;
