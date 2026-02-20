begin;

-- Admin allowlist table (explicit admins for moderation actions)
create table if not exists public.app_admins (
  user_id uuid primary key,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

drop policy if exists app_admins_select_self on public.app_admins;
create policy app_admins_select_self
  on public.app_admins for select
  to authenticated
  using (user_id = auth.uid());

-- Per-seller publish controls
create table if not exists public.seller_product_controls (
  seller_id uuid primary key,
  can_add_products boolean not null default false,
  approval_mode text not null default 'manual'
    check (approval_mode in ('manual', 'auto')),
  is_blocked boolean not null default false,
  notes text,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_seller_product_controls_mode
  on public.seller_product_controls (approval_mode);

alter table public.seller_product_controls enable row level security;

drop policy if exists seller_product_controls_select_self on public.seller_product_controls;
create policy seller_product_controls_select_self
  on public.seller_product_controls for select
  to authenticated
  using (seller_id = auth.uid());

-- Moderation audit log
create table if not exists public.product_moderation_log (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null,
  seller_id uuid,
  action text not null check (action in ('submitted', 'approved', 'rejected', 'resubmitted')),
  note text,
  acted_by uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_moderation_log_product
  on public.product_moderation_log (product_id, created_at desc);

alter table public.product_moderation_log enable row level security;

drop policy if exists product_moderation_log_select_self on public.product_moderation_log;
create policy product_moderation_log_select_self
  on public.product_moderation_log for select
  to authenticated
  using (seller_id = auth.uid());

-- Add moderation fields to products (if products table exists)
do $$
begin
  if to_regclass('public.products') is not null then
    alter table public.products
      add column if not exists publish_status text,
      add column if not exists review_note text,
      add column if not exists approved_at timestamptz,
      add column if not exists approved_by uuid;

    update public.products
    set publish_status = case
      when coalesce(is_active, false) then 'approved'
      else 'pending_review'
    end
    where publish_status is null;

    alter table public.products
      alter column publish_status set default 'pending_review';
  end if;
end $$;

-- Add check constraint only once
 do $$
 begin
   if to_regclass('public.products') is not null then
     if not exists (
       select 1
       from pg_constraint
       where conname = 'products_publish_status_check'
         and conrelid = 'public.products'::regclass
     ) then
       alter table public.products
         add constraint products_publish_status_check
         check (publish_status in ('pending_review', 'approved', 'rejected'));
     end if;
   end if;
 end $$;

create or replace function public.is_app_admin(
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
stable
as $$
begin
  if p_user_id is null then
    return false;
  end if;

  return exists (
    select 1
    from public.app_admins a
    where a.user_id = p_user_id
  );
end;
$$;

-- Enforce seller publication rules directly on products writes.
create or replace function public.enforce_product_publication_rules()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_role text;
  v_can_add boolean := false;
  v_mode text := 'manual';
  v_blocked boolean := false;
begin
  if to_regclass('public.products') is null then
    return new;
  end if;

  v_uid := auth.uid();
  v_role := auth.role();

  -- service_role or non-authenticated backend flow: do not interfere.
  if v_role = 'service_role' or v_uid is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.id is null then
      new.id := gen_random_uuid();
    end if;

    if new.seller_id is null then
      new.seller_id := v_uid;
    end if;

    if new.seller_id <> v_uid then
      raise exception 'Only seller can create own products';
    end if;

    select
      c.can_add_products,
      c.approval_mode,
      c.is_blocked
    into
      v_can_add,
      v_mode,
      v_blocked
    from public.seller_product_controls c
    where c.seller_id = v_uid;

    if v_blocked then
      raise exception 'Seller is blocked from product publishing';
    end if;

    if coalesce(v_can_add, false) = false then
      raise exception 'Seller is not allowed to add products';
    end if;

    if coalesce(v_mode, 'manual') = 'auto' then
      new.publish_status := 'approved';
      new.is_active := true;
      new.review_note := null;
      new.approved_at := now();
      new.approved_by := v_uid;
      insert into public.product_moderation_log (
        product_id,
        seller_id,
        action,
        note,
        acted_by
      ) values (
        new.id,
        v_uid,
        'approved',
        'Auto-approved by seller mode',
        v_uid
      );
    else
      new.publish_status := 'pending_review';
      new.is_active := false;
      new.approved_at := null;
      new.approved_by := null;
      insert into public.product_moderation_log (
        product_id,
        seller_id,
        action,
        note,
        acted_by
      ) values (
        new.id,
        v_uid,
        'submitted',
        'Submitted for admin review',
        v_uid
      );
    end if;

    return new;
  end if;

  -- UPDATE rules
  if new.seller_id is distinct from old.seller_id then
    raise exception 'Changing seller_id is not allowed';
  end if;

  if old.seller_id is not null and old.seller_id <> v_uid then
    -- Non-owner updates allowed only for admins.
    if not public.is_app_admin(v_uid) then
      raise exception 'Only product owner or admin can update';
    end if;
    return new;
  end if;

  select
    c.can_add_products,
    c.approval_mode,
    c.is_blocked
  into
    v_can_add,
    v_mode,
    v_blocked
  from public.seller_product_controls c
  where c.seller_id = v_uid;

  if v_blocked then
    raise exception 'Seller is blocked from product publishing';
  end if;

  if coalesce(v_can_add, false) = false then
    raise exception 'Seller is not allowed to edit products';
  end if;

  -- Seller cannot force approval directly.
  if new.publish_status = 'approved' or coalesce(new.is_active, false) = true then
    if coalesce(v_mode, 'manual') <> 'auto' then
      new.publish_status := 'pending_review';
      new.is_active := false;
      new.approved_at := null;
      new.approved_by := null;
    end if;
  end if;

  if coalesce(v_mode, 'manual') = 'manual' then
    new.publish_status := 'pending_review';
    new.is_active := false;
    new.approved_at := null;
    new.approved_by := null;
    insert into public.product_moderation_log (
      product_id,
      seller_id,
      action,
      note,
      acted_by
    ) values (
      new.id,
      v_uid,
      'resubmitted',
      'Updated by seller and sent for re-review',
      v_uid
    );
  else
    new.publish_status := 'approved';
    new.is_active := true;
    new.approved_at := now();
    new.approved_by := v_uid;
  end if;

  return new;
end;
$$;

-- Attach trigger when products table exists.
do $$
begin
  if to_regclass('public.products') is not null then
    drop trigger if exists trg_enforce_product_publication_rules on public.products;
    create trigger trg_enforce_product_publication_rules
    before insert or update on public.products
    for each row execute function public.enforce_product_publication_rules();
  end if;
end $$;

-- Admin RPC: set seller controls
create or replace function public.admin_set_seller_product_control(
  p_seller_id uuid,
  p_can_add_products boolean,
  p_approval_mode text,
  p_is_blocked boolean default false,
  p_notes text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();
  if not public.is_app_admin(v_uid) then
    raise exception 'Not authorized';
  end if;

  if p_approval_mode not in ('manual', 'auto') then
    raise exception 'Invalid approval_mode';
  end if;

  insert into public.seller_product_controls (
    seller_id,
    can_add_products,
    approval_mode,
    is_blocked,
    notes,
    updated_by,
    updated_at
  ) values (
    p_seller_id,
    p_can_add_products,
    p_approval_mode,
    coalesce(p_is_blocked, false),
    p_notes,
    v_uid,
    now()
  )
  on conflict (seller_id)
  do update set
    can_add_products = excluded.can_add_products,
    approval_mode = excluded.approval_mode,
    is_blocked = excluded.is_blocked,
    notes = excluded.notes,
    updated_by = excluded.updated_by,
    updated_at = now();

  return json_build_object(
    'seller_id', p_seller_id,
    'can_add_products', p_can_add_products,
    'approval_mode', p_approval_mode,
    'is_blocked', coalesce(p_is_blocked, false)
  );
end;
$$;

-- Admin RPC: list controls
create or replace function public.admin_list_seller_product_controls()
returns table (
  seller_id uuid,
  can_add_products boolean,
  approval_mode text,
  is_blocked boolean,
  notes text,
  updated_by uuid,
  updated_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_app_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;

  return query
  select
    c.seller_id,
    c.can_add_products,
    c.approval_mode,
    c.is_blocked,
    c.notes,
    c.updated_by,
    c.updated_at,
    c.created_at
  from public.seller_product_controls c
  order by c.updated_at desc;
end;
$$;

-- Seller RPC: self control snapshot
create or replace function public.seller_get_product_control()
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_row public.seller_product_controls%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_row
  from public.seller_product_controls
  where seller_id = v_uid;

  if not found then
    return json_build_object(
      'seller_id', v_uid,
      'can_add_products', false,
      'approval_mode', 'manual',
      'is_blocked', false,
      'notes', null
    );
  end if;

  return json_build_object(
    'seller_id', v_row.seller_id,
    'can_add_products', v_row.can_add_products,
    'approval_mode', v_row.approval_mode,
    'is_blocked', v_row.is_blocked,
    'notes', v_row.notes,
    'updated_at', v_row.updated_at
  );
end;
$$;

-- Admin RPC: pending products moderation list
create or replace function public.admin_list_pending_products(
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  id uuid,
  seller_id uuid,
  name text,
  price numeric,
  currency text,
  image_url text,
  publish_status text,
  is_active boolean,
  created_at timestamptz,
  review_note text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_app_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;

  if to_regclass('public.products') is null then
    return;
  end if;

  return query
  select
    p.id,
    p.seller_id,
    p.name,
    p.price,
    p.currency,
    p.image_url,
    p.publish_status,
    p.is_active,
    p.created_at,
    p.review_note
  from public.products p
  where p.publish_status = 'pending_review'
  order by p.created_at asc
  limit greatest(1, least(coalesce(p_limit, 100), 500))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- Admin RPC: approve/reject product
create or replace function public.admin_review_product(
  p_product_id uuid,
  p_action text,
  p_note text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_seller_id uuid;
  v_action text;
begin
  v_uid := auth.uid();
  if not public.is_app_admin(v_uid) then
    raise exception 'Not authorized';
  end if;

  v_action := lower(trim(coalesce(p_action, '')));
  if v_action not in ('approve', 'reject') then
    raise exception 'Invalid action';
  end if;

  if to_regclass('public.products') is null then
    raise exception 'Products table is missing';
  end if;

  if v_action = 'approve' then
    update public.products p
    set
      publish_status = 'approved',
      is_active = true,
      review_note = nullif(trim(p_note), ''),
      approved_at = now(),
      approved_by = v_uid
    where p.id = p_product_id
    returning p.seller_id into v_seller_id;

    if v_seller_id is null then
      raise exception 'Product not found';
    end if;

    insert into public.product_moderation_log (
      product_id,
      seller_id,
      action,
      note,
      acted_by
    ) values (
      p_product_id,
      v_seller_id,
      'approved',
      nullif(trim(p_note), ''),
      v_uid
    );

    return json_build_object(
      'product_id', p_product_id,
      'status', 'approved'
    );
  end if;

  update public.products p
  set
    publish_status = 'rejected',
    is_active = false,
    review_note = nullif(trim(p_note), ''),
    approved_at = null,
    approved_by = null
  where p.id = p_product_id
  returning p.seller_id into v_seller_id;

  if v_seller_id is null then
    raise exception 'Product not found';
  end if;

  insert into public.product_moderation_log (
    product_id,
    seller_id,
    action,
    note,
    acted_by
  ) values (
    p_product_id,
    v_seller_id,
    'rejected',
    nullif(trim(p_note), ''),
    v_uid
  );

  return json_build_object(
    'product_id', p_product_id,
    'status', 'rejected'
  );
end;
$$;

commit;
