do $$
begin
  if to_regclass('public.promo_banners') is null then
    return;
  end if;

  alter table public.promo_banners
    add column if not exists width_factor double precision not null default 1.0;

  update public.promo_banners
  set width_factor = coalesce(width_factor, 1.0);

  alter table public.promo_banners
    alter column width_factor set default 1.0;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'promo_banners_width_factor_range'
  ) then
    alter table public.promo_banners
      add constraint promo_banners_width_factor_range
      check (width_factor >= 0.7 and width_factor <= 1.0);
  end if;
end
$$;
