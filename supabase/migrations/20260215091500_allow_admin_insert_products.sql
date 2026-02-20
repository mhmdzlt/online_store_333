begin;

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
  v_is_admin boolean := false;
begin
  if to_regclass('public.products') is null then
    return new;
  end if;

  v_uid := auth.uid();
  v_role := auth.role();

  if v_role = 'service_role' or v_uid is null then
    return new;
  end if;

  v_is_admin := public.is_app_admin(v_uid);

  if tg_op = 'INSERT' then
    if new.id is null then
      new.id := gen_random_uuid();
    end if;

    if new.seller_id is null then
      new.seller_id := v_uid;
    end if;

    if new.seller_id <> v_uid and not v_is_admin then
      raise exception 'Only seller can create own products';
    end if;

    if v_is_admin then
      if new.publish_status is null then
        new.publish_status := case
          when coalesce(new.is_active, false) then 'approved'
          else 'pending_review'
        end;
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
        new.seller_id,
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
        new.seller_id,
        'submitted',
        'Submitted for admin review',
        v_uid
      );
    end if;

    return new;
  end if;

  if new.seller_id is distinct from old.seller_id then
    raise exception 'Changing seller_id is not allowed';
  end if;

  if old.seller_id is not null and old.seller_id <> v_uid then
    if not v_is_admin then
      raise exception 'Only product owner or admin can update';
    end if;
    return new;
  end if;

  if v_is_admin then
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

commit;
