-- Attach influencer referral to an order after checkout and create commission row.

create or replace function public.apply_influencer_ref_to_order_public(
  p_order_number text,
  p_phone text,
  p_ref_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_promo record;
  v_commission_amount numeric(12,2);
begin
  if coalesce(trim(p_order_number), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_ref_code), '') = '' then
    return jsonb_build_object(
      'ok', false,
      'reason', 'missing_arguments'
    );
  end if;

  select o.id, o.order_number, o.phone, coalesce(o.total_amount, 0)::numeric as total_amount
  into v_order
  from public.orders o
  where o.order_number = trim(p_order_number)
    and o.phone = trim(p_phone)
  order by o.created_at desc
  limit 1;

  if v_order.id is null then
    return jsonb_build_object(
      'ok', false,
      'reason', 'order_not_found'
    );
  end if;

  select pc.id,
         pc.influencer_id,
         pc.code,
         coalesce(pc.commission_percent, 0)::numeric as commission_percent
  into v_promo
  from public.influencer_promo_codes pc
  join public.influencer_profiles ip
    on ip.id = pc.influencer_id
  where pc.code = upper(trim(p_ref_code))
    and pc.is_active = true
    and ip.status = 'approved'
  order by pc.created_at desc
  limit 1;

  if v_promo.id is null then
    return jsonb_build_object(
      'ok', false,
      'reason', 'invalid_ref_code'
    );
  end if;

  v_commission_amount := round((v_order.total_amount * v_promo.commission_percent) / 100.0, 2);

  insert into public.influencer_order_commissions (
    order_id,
    influencer_id,
    promo_code_id,
    order_number,
    order_total,
    commission_percent,
    commission_amount,
    status
  )
  values (
    v_order.id,
    v_promo.influencer_id,
    v_promo.id,
    v_order.order_number,
    v_order.total_amount,
    v_promo.commission_percent,
    v_commission_amount,
    'pending'
  )
  on conflict (order_id) do nothing;

  insert into public.influencer_click_events (
    promo_code_id,
    influencer_id,
    source,
    campaign,
    landing_path
  )
  values (
    v_promo.id,
    v_promo.influencer_id,
    'checkout',
    'post_order_attribution',
    '/checkout'
  );

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'influencer_id', v_promo.influencer_id,
    'promo_code', v_promo.code,
    'commission_percent', v_promo.commission_percent,
    'commission_amount', v_commission_amount
  );
end;
$$;

grant execute on function public.apply_influencer_ref_to_order_public(text, text, text)
to anon, authenticated, service_role;
