-- RFQ security hardening
-- Tightens RLS, function validation, and explicit grants for guest/public RPC usage.

begin;

-- ----------------------------------------------------------------------------
-- Table constraints (defensive input/state validation)
-- ----------------------------------------------------------------------------
alter table public.part_requests
  drop constraint if exists part_requests_status_chk;
alter table public.part_requests
  add constraint part_requests_status_chk
  check (status in ('open', 'closed', 'cancelled'));

alter table public.part_offers
  drop constraint if exists part_offers_status_chk;
alter table public.part_offers
  add constraint part_offers_status_chk
  check (status in ('submitted', 'accepted', 'rejected', 'withdrawn'));

alter table public.part_messages
  drop constraint if exists part_messages_sender_role_chk;
alter table public.part_messages
  add constraint part_messages_sender_role_chk
  check (sender_role in ('customer', 'seller'));

-- ----------------------------------------------------------------------------
-- Explicit grants (least privilege)
-- ----------------------------------------------------------------------------
revoke all on table public.part_requests from anon, authenticated;
revoke all on table public.part_request_images from anon, authenticated;
revoke all on table public.part_offers from anon, authenticated;
revoke all on table public.part_threads from anon, authenticated;
revoke all on table public.part_messages from anon, authenticated;

grant select on table public.part_requests to authenticated;
grant select on table public.part_request_images to authenticated;
grant select, insert, update on table public.part_offers to authenticated;
grant select, insert on table public.part_threads to authenticated;
grant select, insert on table public.part_messages to authenticated;

-- ----------------------------------------------------------------------------
-- RLS tightening for seller visibility
-- ----------------------------------------------------------------------------
drop policy if exists part_requests_select_authed on public.part_requests;
create policy part_requests_select_authed
  on public.part_requests for select
  to authenticated
  using (
    exists (
      select 1
      from public.part_offers o
      where o.request_id = part_requests.id
        and o.seller_id = auth.uid()
    )
    or exists (
      select 1
      from public.part_threads t
      where t.request_id = part_requests.id
        and t.seller_id = auth.uid()
    )
  );

drop policy if exists part_request_images_select_authed on public.part_request_images;
create policy part_request_images_select_authed
  on public.part_request_images for select
  to authenticated
  using (
    exists (
      select 1
      from public.part_requests r
      left join public.part_offers o on o.request_id = r.id
      left join public.part_threads t on t.request_id = r.id
      where r.id = part_request_images.request_id
        and (o.seller_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- Public RPCs hardened with stricter validation
-- ----------------------------------------------------------------------------
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
  v_suffix text;
  v_img text;
  v_idx int;
  v_phone text;
  v_name text;
  v_vin text;
  v_description text;
begin
  v_phone := nullif(trim(p_customer_phone), '');
  if v_phone is null then
    raise exception 'Customer phone is required';
  end if;

  if length(v_phone) < 8 or length(v_phone) > 20 then
    raise exception 'Invalid customer phone length';
  end if;

  if p_image_urls is not null and cardinality(p_image_urls) > 8 then
    raise exception 'Too many images';
  end if;

  v_name := left(nullif(trim(p_customer_name), ''), 120);
  v_vin := left(nullif(trim(p_vin), ''), 40);
  v_description := left(nullif(trim(p_description), ''), 2000);

  v_suffix := encode(gen_random_bytes(4), 'hex');
  v_number := 'RFQ-' || to_char(now(), 'YYYYMMDD') || '-' || v_suffix;
  v_token := encode(gen_random_bytes(32), 'hex');

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
    v_name,
    v_phone,
    v_vin,
    v_description,
    p_car_brand_id,
    p_car_model_id,
    p_car_year_id,
    p_car_generation_id,
    p_car_trim_id
  )
  returning id into v_id;

  if p_image_urls is not null then
    v_idx := 1;
    foreach v_img in array p_image_urls loop
      v_img := nullif(trim(v_img), '');
      if v_img is null then
        continue;
      end if;

      if v_img !~* '^https?://' then
        continue;
      end if;

      insert into public.part_request_images (request_id, image_url, sort_order)
      values (v_id, left(v_img, 2048), v_idx);
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
  v_number text;
  v_token text;
  v_phone text;
begin
  v_number := nullif(trim(p_request_number), '');
  v_token := nullif(trim(p_access_token), '');
  v_phone := nullif(trim(p_customer_phone), '');

  if v_number is null or v_token is null then
    return;
  end if;

  select r.id into v_request_id
  from public.part_requests r
  where r.request_number = v_number
    and r.access_token = v_token
    and (v_phone is null or r.customer_phone = v_phone);

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
  if p_seller_id is null then
    return null;
  end if;

  select r.id into v_request_id
  from public.part_requests r
  where r.request_number = nullif(trim(p_request_number), '')
    and r.access_token = nullif(trim(p_access_token), '');

  if v_request_id is null then
    return null;
  end if;

  if not exists (
    select 1
    from public.part_offers o
    where o.request_id = v_request_id
      and o.seller_id = p_seller_id
      and o.status = 'submitted'
  ) then
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
  v_message text;
begin
  v_thread_id := public.get_or_create_part_thread_public(
    p_request_number,
    p_access_token,
    p_seller_id
  );

  if v_thread_id is null then
    return null;
  end if;

  v_message := left(nullif(trim(p_message), ''), 2000);
  if v_message is null then
    return null;
  end if;

  insert into public.part_messages (thread_id, sender_role, message)
  values (v_thread_id, 'customer', v_message)
  returning id into v_msg_id;

  return v_msg_id;
end;
$$;

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
  v_message text;
begin
  v_seller_id := auth.uid();
  if v_seller_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_request_id is null then
    raise exception 'Request id is required';
  end if;

  if not exists (
    select 1
    from public.part_offers o
    where o.request_id = p_request_id
      and o.seller_id = v_seller_id
  ) then
    raise exception 'Seller is not linked to this request';
  end if;

  select t.id into v_thread_id
  from public.part_threads t
  where t.request_id = p_request_id and t.seller_id = v_seller_id;

  if v_thread_id is null then
    insert into public.part_threads (request_id, seller_id)
    values (p_request_id, v_seller_id)
    returning id into v_thread_id;
  end if;

  v_message := left(nullif(trim(p_message), ''), 2000);
  if v_message is null then
    raise exception 'Message cannot be empty';
  end if;

  insert into public.part_messages (thread_id, sender_role, message)
  values (v_thread_id, 'seller', v_message)
  returning id into v_msg_id;

  return v_msg_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Function execute privileges
-- ----------------------------------------------------------------------------
revoke all on function public.create_part_request_public(text, text, text, text, uuid, uuid, uuid, uuid, uuid, text[]) from public, anon, authenticated;
revoke all on function public.list_part_offers_public(text, text, text) from public, anon, authenticated;
revoke all on function public.get_or_create_part_thread_public(text, text, uuid) from public, anon, authenticated;
revoke all on function public.list_part_messages_public(text, text, uuid) from public, anon, authenticated;
revoke all on function public.send_part_message_public(text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.send_part_message_seller(uuid, text) from public, anon, authenticated;

grant execute on function public.create_part_request_public(text, text, text, text, uuid, uuid, uuid, uuid, uuid, text[]) to anon, authenticated;
grant execute on function public.list_part_offers_public(text, text, text) to anon, authenticated;
grant execute on function public.get_or_create_part_thread_public(text, text, uuid) to anon, authenticated;
grant execute on function public.list_part_messages_public(text, text, uuid) to anon, authenticated;
grant execute on function public.send_part_message_public(text, text, uuid, text) to anon, authenticated;
grant execute on function public.send_part_message_seller(uuid, text) to authenticated;

commit;
