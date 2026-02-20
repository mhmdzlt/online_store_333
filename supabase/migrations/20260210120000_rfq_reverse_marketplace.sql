-- RFQ / Reverse Marketplace (طلبات تسعير + عروض + شات)
-- Additive migration: does not modify existing orders/cart/checkout.

begin;

-- Needed for gen_random_uuid() and gen_random_bytes().
create extension if not exists pgcrypto with schema extensions;

-- Requests created by customers (guest supported via phone + access_token)
create table if not exists public.part_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique,
  access_token text not null,
  customer_name text,
  customer_phone text,
  vin text,
  description text,
  car_brand_id uuid,
  car_model_id uuid,
  car_year_id uuid,
  car_generation_id uuid,
  car_trim_id uuid,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create index if not exists idx_part_requests_number on public.part_requests (request_number);
create index if not exists idx_part_requests_phone on public.part_requests (customer_phone);

create table if not exists public.part_request_images (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.part_requests(id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_part_request_images_req on public.part_request_images (request_id);

-- Seller offers. For cart/checkout compatibility, offers reference an existing product.
create table if not exists public.part_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.part_requests(id) on delete cascade,
  seller_id uuid not null,
  seller_store_name text,
  seller_phone text,
  product_id uuid not null,
  offered_price numeric,
  currency text default 'IQD',
  condition text default 'new',
  guaranteed_fit boolean not null default false,
  notes text,
  status text not null default 'submitted',
  created_at timestamptz not null default now()
);

create index if not exists idx_part_offers_request on public.part_offers (request_id);
create index if not exists idx_part_offers_seller on public.part_offers (seller_id);

-- Chat threads are per (request, seller) to keep context clear.
create table if not exists public.part_threads (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.part_requests(id) on delete cascade,
  seller_id uuid not null,
  created_at timestamptz not null default now(),
  unique (request_id, seller_id)
);

create index if not exists idx_part_threads_request on public.part_threads (request_id);
create index if not exists idx_part_threads_seller on public.part_threads (seller_id);

create table if not exists public.part_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.part_threads(id) on delete cascade,
  sender_role text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_part_messages_thread on public.part_messages (thread_id);

-- RLS
alter table public.part_requests enable row level security;
alter table public.part_request_images enable row level security;
alter table public.part_offers enable row level security;
alter table public.part_threads enable row level security;
alter table public.part_messages enable row level security;

-- Minimal safe defaults:
-- Customers are guests (no auth) => public access happens via SECURITY DEFINER RPCs below.
-- Sellers (authenticated) can read requests and create offers/messages for operational use.

-- Requests: allow authenticated read of open requests (no sensitive fields beyond phone/name).
drop policy if exists part_requests_select_authed on public.part_requests;
create policy part_requests_select_authed
  on public.part_requests for select
  to authenticated
  using (true);

-- Images: allow authenticated read.
drop policy if exists part_request_images_select_authed on public.part_request_images;
create policy part_request_images_select_authed
  on public.part_request_images for select
  to authenticated
  using (true);

-- Offers: allow sellers (authenticated) to read their offers.
drop policy if exists part_offers_select_seller on public.part_offers;
create policy part_offers_select_seller
  on public.part_offers for select
  to authenticated
  using (seller_id = auth.uid());

-- Offers insert/update by seller only.
drop policy if exists part_offers_insert_seller on public.part_offers;
create policy part_offers_insert_seller
  on public.part_offers for insert
  to authenticated
  with check (seller_id = auth.uid());

drop policy if exists part_offers_update_seller on public.part_offers;
create policy part_offers_update_seller
  on public.part_offers for update
  to authenticated
  using (seller_id = auth.uid())
  with check (seller_id = auth.uid());

-- Threads/messages: seller can see their threads + messages.
drop policy if exists part_threads_select_seller on public.part_threads;
create policy part_threads_select_seller
  on public.part_threads for select
  to authenticated
  using (seller_id = auth.uid());

drop policy if exists part_threads_insert_seller on public.part_threads;
create policy part_threads_insert_seller
  on public.part_threads for insert
  to authenticated
  with check (seller_id = auth.uid());

drop policy if exists part_messages_select_seller on public.part_messages;
create policy part_messages_select_seller
  on public.part_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.part_threads t
      where t.id = part_messages.thread_id
        and t.seller_id = auth.uid()
    )
  );

drop policy if exists part_messages_insert_seller on public.part_messages;
create policy part_messages_insert_seller
  on public.part_messages for insert
  to authenticated
  with check (
    exists (
      select 1 from public.part_threads t
      where t.id = part_messages.thread_id
        and t.seller_id = auth.uid()
    )
  );

-- Public RPCs for guest customers (token-based)
create or replace function public.create_part_request_public(
  p_customer_name text,
  p_customer_phone text,
  p_vin text default null,
  p_description text default null,
  p_car_brand_id uuid default null,
  p_car_model_id uuid default null,
  p_car_year_id uuid default null,
  p_car_generation_id uuid default null,
  p_car_trim_id uuid default null,
  p_image_urls text[] default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_number text;
  v_token text;
  v_id uuid;
  v_now text;
  v_suffix text;
  v_idx int;
begin
  v_now := to_char(now(), 'YYYYMMDD');
  v_suffix := substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  v_number := 'RFQ-' || v_now || '-' || v_suffix;
  v_token :=
    md5(random()::text || clock_timestamp()::text || coalesce(p_customer_phone, '') || v_number)
    ||
    md5(random()::text || clock_timestamp()::text || coalesce(p_customer_name, '') || v_number);

  insert into public.part_requests (
    request_number,
    access_token,
    customer_name,
    customer_phone,
    vin,
    description,
    car_brand_id,
    car_model_id,
    car_year_id,
    car_generation_id,
    car_trim_id
  ) values (
    v_number,
    v_token,
    nullif(trim(p_customer_name), ''),
    nullif(trim(p_customer_phone), ''),
    nullif(trim(p_vin), ''),
    nullif(trim(p_description), ''),
    p_car_brand_id,
    p_car_model_id,
    p_car_year_id,
    p_car_generation_id,
    p_car_trim_id
  )
  returning id into v_id;

  if p_image_urls is not null then
    v_idx := 1;
    foreach v_now in array p_image_urls loop
      insert into public.part_request_images (request_id, image_url, sort_order)
      values (v_id, v_now, v_idx);
      v_idx := v_idx + 1;
    end loop;
  end if;

  return json_build_object(
    'id', v_id,
    'request_number', v_number,
    'access_token', v_token
  );
end;
$$;

create or replace function public.list_part_offers_public(
  p_request_number text,
  p_customer_phone text,
  p_access_token text
)
returns table (
  offer_id uuid,
  seller_id uuid,
  seller_store_name text,
  seller_phone text,
  product_id uuid,
  offered_price numeric,
  currency text,
  condition text,
  guaranteed_fit boolean,
  notes text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request_id uuid;
begin
  select r.id into v_request_id
  from public.part_requests r
  where r.request_number = p_request_number
    and r.access_token = p_access_token
    and (p_customer_phone is null or r.customer_phone = p_customer_phone);

  if v_request_id is null then
    return;
  end if;

  return query
  select
    o.id,
    o.seller_id,
    o.seller_store_name,
    o.seller_phone,
    o.product_id,
    o.offered_price,
    o.currency,
    o.condition,
    o.guaranteed_fit,
    o.notes,
    o.created_at
  from public.part_offers o
  where o.request_id = v_request_id
    and o.status = 'submitted'
  order by o.created_at desc;
end;
$$;

create or replace function public.get_or_create_part_thread_public(
  p_request_number text,
  p_access_token text,
  p_seller_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request_id uuid;
  v_thread_id uuid;
begin
  select r.id into v_request_id
  from public.part_requests r
  where r.request_number = p_request_number
    and r.access_token = p_access_token;

  if v_request_id is null then
    return null;
  end if;

  select t.id into v_thread_id
  from public.part_threads t
  where t.request_id = v_request_id and t.seller_id = p_seller_id;

  if v_thread_id is null then
    insert into public.part_threads (request_id, seller_id)
    values (v_request_id, p_seller_id)
    returning id into v_thread_id;
  end if;

  return v_thread_id;
end;
$$;

create or replace function public.list_part_messages_public(
  p_request_number text,
  p_access_token text,
  p_seller_id uuid
)
returns table (
  message_id uuid,
  sender_role text,
  message text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_thread_id uuid;
begin
  v_thread_id := public.get_or_create_part_thread_public(
    p_request_number,
    p_access_token,
    p_seller_id
  );

  if v_thread_id is null then
    return;
  end if;

  return query
  select m.id, m.sender_role, m.message, m.created_at
  from public.part_messages m
  where m.thread_id = v_thread_id
  order by m.created_at asc;
end;
$$;

create or replace function public.send_part_message_public(
  p_request_number text,
  p_access_token text,
  p_seller_id uuid,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_thread_id uuid;
  v_msg_id uuid;
begin
  v_thread_id := public.get_or_create_part_thread_public(
    p_request_number,
    p_access_token,
    p_seller_id
  );

  if v_thread_id is null then
    return null;
  end if;

  insert into public.part_messages (thread_id, sender_role, message)
  values (v_thread_id, 'customer', left(coalesce(p_message, ''), 2000))
  returning id into v_msg_id;

  return v_msg_id;
end;
$$;

-- Seller-side helper RPC for sending messages while authenticated.
create or replace function public.send_part_message_seller(
  p_request_id uuid,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_seller_id uuid;
  v_thread_id uuid;
  v_msg_id uuid;
begin
  v_seller_id := auth.uid();
  if v_seller_id is null then
    raise exception 'Not authenticated';
  end if;

  select t.id into v_thread_id
  from public.part_threads t
  where t.request_id = p_request_id and t.seller_id = v_seller_id;

  if v_thread_id is null then
    insert into public.part_threads (request_id, seller_id)
    values (p_request_id, v_seller_id)
    returning id into v_thread_id;
  end if;

  insert into public.part_messages (thread_id, sender_role, message)
  values (v_thread_id, 'seller', left(coalesce(p_message, ''), 2000))
  returning id into v_msg_id;

  return v_msg_id;
end;
$$;

commit;
