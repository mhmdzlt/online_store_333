-- Make admin authorization resilient by supporting both app_admins table
-- and legacy admin flags in profiles.
create or replace function public.is_app_admin(
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
stable
as $$
declare
  v_role_col_exists boolean := false;
  v_is_admin_col_exists boolean := false;
  v_sql text;
  v_result boolean := false;
begin
  if p_user_id is null then
    return false;
  end if;

  if exists (
    select 1
    from public.app_admins a
    where a.user_id = p_user_id
  ) then
    return true;
  end if;

  if to_regclass('public.profiles') is null then
    return false;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'role'
  ) into v_role_col_exists;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'is_admin'
  ) into v_is_admin_col_exists;

  if not v_role_col_exists and not v_is_admin_col_exists then
    return false;
  end if;

  v_sql := 'select exists (select 1 from public.profiles p where p.user_id = $1 and (';

  if v_role_col_exists then
    v_sql := v_sql || 'coalesce(p.role, '''') in (''admin'', ''super_admin'')';
  end if;

  if v_role_col_exists and v_is_admin_col_exists then
    v_sql := v_sql || ' or ';
  end if;

  if v_is_admin_col_exists then
    v_sql := v_sql || 'coalesce(p.is_admin, false) = true';
  end if;

  v_sql := v_sql || '))';

  execute v_sql into v_result using p_user_id;
  return coalesce(v_result, false);
end;
$$;
