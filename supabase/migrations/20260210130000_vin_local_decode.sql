-- Local VIN decode support (WMI lookup + year decode)
-- Additive migration for local Supabase integration

begin;

create table if not exists public.vin_wmi (
  wmi text primary key,
  make text not null,
  country text not null,
  created_at timestamptz not null default now()
);

-- Minimal seed data (extend as needed)
insert into public.vin_wmi (wmi, make, country) values
  ('JHM', 'Honda', 'Japan'),
  ('1HG', 'Honda', 'USA'),
  ('JHL', 'Honda', 'Japan'),
  ('JT3', 'Toyota', 'Japan'),
  ('JT2', 'Toyota', 'Japan'),
  ('4T1', 'Toyota', 'USA'),
  ('4T3', 'Toyota', 'USA'),
  ('1NX', 'Toyota', 'USA'),
  ('JTD', 'Toyota', 'Japan'),
  ('JN1', 'Nissan', 'Japan'),
  ('JN8', 'Nissan', 'Japan'),
  ('1N4', 'Nissan', 'USA'),
  ('KNM', 'Nissan', 'Korea'),
  ('KMH', 'Hyundai', 'Korea'),
  ('KNA', 'Kia', 'Korea'),
  ('KND', 'Kia', 'Korea'),
  ('1FA', 'Ford', 'USA'),
  ('1FB', 'Ford', 'USA'),
  ('1G1', 'Chevrolet', 'USA'),
  ('1G2', 'Pontiac', 'USA'),
  ('1G6', 'Cadillac', 'USA'),
  ('1C3', 'Chrysler', 'USA'),
  ('1C4', 'Chrysler', 'USA'),
  ('WVW', 'Volkswagen', 'Germany'),
  ('WBA', 'BMW', 'Germany'),
  ('WDC', 'Mercedes-Benz', 'Germany')
on conflict do nothing;

-- VIN decode helper
create or replace function public.decode_vin_local(
  p_vin text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vin text;
  v_wmi text;
  v_year_code text;
  v_year int;
  v_make text;
  v_country text;
  v_valid boolean;
begin
  v_vin := upper(regexp_replace(coalesce(p_vin, ''), '\s+', '', 'g'));
  v_valid := char_length(v_vin) = 17;

  if not v_valid then
    return json_build_object(
      'vin', v_vin,
      'valid', false,
      'error', 'VIN_INVALID_LENGTH'
    );
  end if;

  v_wmi := substring(v_vin, 1, 3);
  v_year_code := substring(v_vin, 10, 1);

  select make, country
    into v_make, v_country
  from public.vin_wmi
  where wmi = v_wmi;

  v_year := case v_year_code
    when 'A' then 2010
    when 'B' then 2011
    when 'C' then 2012
    when 'D' then 2013
    when 'E' then 2014
    when 'F' then 2015
    when 'G' then 2016
    when 'H' then 2017
    when 'J' then 2018
    when 'K' then 2019
    when 'L' then 2020
    when 'M' then 2021
    when 'N' then 2022
    when 'P' then 2023
    when 'R' then 2024
    when 'S' then 2025
    when 'T' then 2026
    when 'V' then 2027
    when 'W' then 2028
    when 'X' then 2029
    when 'Y' then 2030
    when '1' then 2031
    when '2' then 2032
    when '3' then 2033
    when '4' then 2034
    when '5' then 2035
    when '6' then 2036
    when '7' then 2037
    when '8' then 2038
    when '9' then 2039
    else null
  end;

  return json_build_object(
    'vin', v_vin,
    'valid', true,
    'wmi', v_wmi,
    'make', v_make,
    'country', v_country,
    'year', v_year
  );
end;
$$;

commit;
