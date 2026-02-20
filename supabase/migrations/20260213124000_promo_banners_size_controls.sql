do $$
begin
  if to_regclass('public.promo_banners') is null then
    return;
  end if;

  alter table public.promo_banners
    add column if not exists height_factor double precision not null default 1.0,
    add column if not exists cta_full_width boolean not null default true;

  update public.promo_banners
  set
    height_factor = coalesce(height_factor, 1.0),
    cta_full_width = coalesce(cta_full_width, true);

  alter table public.promo_banners
    alter column height_factor set default 1.0,
    alter column cta_full_width set default true;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'promo_banners_height_factor_range'
  ) then
    alter table public.promo_banners
      add constraint promo_banners_height_factor_range
      check (height_factor >= 0.7 and height_factor <= 2.0);
  end if;
end
$$;
