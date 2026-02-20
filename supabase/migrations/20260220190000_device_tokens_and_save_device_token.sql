-- Device tokens for push notifications
-- Stores Firebase Cloud Messaging tokens associated with a phone + platform.

create extension if not exists pgcrypto;

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  token text not null,
  platform text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- If the table already existed from earlier manual setup,
-- ensure required columns are present.
alter table if exists public.device_tokens
  add column if not exists phone text,
  add column if not exists token text,
  add column if not exists platform text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists device_tokens_phone_idx
  on public.device_tokens (phone);

create index if not exists device_tokens_active_phone_idx
  on public.device_tokens (is_active, phone);

create unique index if not exists device_tokens_token_uq
  on public.device_tokens (token);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_device_tokens_touch_updated_at on public.device_tokens;
create trigger trg_device_tokens_touch_updated_at
before update on public.device_tokens
for each row execute function public.touch_updated_at();

-- RPC called by mobile apps
create or replace function public.save_device_token(
  p_token text,
  p_phone text,
  p_platform text
)
returns void
language plpgsql
security definer
as $$
declare
  v_token text;
  v_phone text;
  v_platform text;
begin
  v_token := btrim(coalesce(p_token, ''));
  v_phone := btrim(coalesce(p_phone, ''));
  v_platform := lower(btrim(coalesce(p_platform, '')));

  if v_token = '' then
    raise exception 'TOKEN_REQUIRED';
  end if;
  if v_phone = '' then
    raise exception 'PHONE_REQUIRED';
  end if;
  if v_platform = '' then
    raise exception 'PLATFORM_REQUIRED';
  end if;

  insert into public.device_tokens (phone, token, platform, is_active)
  values (v_phone, v_token, v_platform, true)
  on conflict (token) do update
    set phone = excluded.phone,
        platform = excluded.platform,
        is_active = true,
        updated_at = now();
end;
$$;

-- Minimal RLS: deny by default but allow via RPC (security definer)
alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_no_select" on public.device_tokens;
create policy "device_tokens_no_select"
  on public.device_tokens
  for select
  using (false);

drop policy if exists "device_tokens_no_insert" on public.device_tokens;
create policy "device_tokens_no_insert"
  on public.device_tokens
  for insert
  with check (false);

drop policy if exists "device_tokens_no_update" on public.device_tokens;
create policy "device_tokens_no_update"
  on public.device_tokens
  for update
  using (false)
  with check (false);
