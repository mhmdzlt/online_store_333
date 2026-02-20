-- Make save_device_token compatible with legacy device_tokens schemas
-- Some existing deployments use column name fcm_token and may enforce NOT NULL.

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
  has_fcm_token boolean;
  has_token boolean;
  token_col text;
  sql text;
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

  select exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'device_tokens'
      and column_name = 'fcm_token'
  ) into has_fcm_token;

  select exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'device_tokens'
      and column_name = 'token'
  ) into has_token;

  if has_fcm_token then
    token_col := 'fcm_token';
  elsif has_token then
    token_col := 'token';
  else
    raise exception 'TOKEN_COLUMN_MISSING';
  end if;

  -- Ensure there is a unique constraint/index for the chosen token column.
  if token_col = 'fcm_token' then
    begin
      execute 'create unique index if not exists device_tokens_fcm_token_uq on public.device_tokens (fcm_token)';
    exception when others then
      null;
    end;
  else
    begin
      execute 'create unique index if not exists device_tokens_token_uq on public.device_tokens (token)';
    exception when others then
      null;
    end;
  end if;

  if token_col = 'fcm_token' and has_token then
    sql := format(
      'insert into public.device_tokens (phone, platform, %1$I, token, is_active) '
      || 'values ($1, $2, $3, $3, true) '
      || 'on conflict (%1$I) do update set '
      || 'phone = excluded.phone, '
      || 'platform = excluded.platform, '
      || 'token = excluded.token, '
      || 'is_active = true, '
      || 'updated_at = now()'
      , token_col
    );
    execute sql using v_phone, v_platform, v_token;
  else
    sql := format(
      'insert into public.device_tokens (phone, platform, %1$I, is_active) '
      || 'values ($1, $2, $3, true) '
      || 'on conflict (%1$I) do update set '
      || 'phone = excluded.phone, '
      || 'platform = excluded.platform, '
      || 'is_active = true, '
      || 'updated_at = now()'
      , token_col
    );
    execute sql using v_phone, v_platform, v_token;
  end if;
end;
$$;

grant execute on function public.save_device_token(text, text, text) to anon, authenticated;
