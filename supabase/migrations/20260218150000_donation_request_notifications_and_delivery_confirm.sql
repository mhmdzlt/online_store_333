alter table if exists public.donation_requests
  add column if not exists contact_method text not null default 'whatsapp'
    check (contact_method in ('whatsapp', 'call', 'chat')),
  add column if not exists delivered_at timestamptz,
  add column if not exists delivery_confirmed_by_phone text;

create index if not exists donation_requests_status_idx
  on public.donation_requests (status);

create index if not exists donation_requests_donation_status_idx
  on public.donation_requests (donation_id, status);

create or replace function public.enqueue_phone_notification(
  p_phone text,
  p_title text,
  p_body text,
  p_route text default 'donations',
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
as $$
begin
  if p_phone is null or btrim(p_phone) = '' then
    return;
  end if;

  if to_regclass('public.notifications') is null then
    return;
  end if;

  begin
    insert into public.notifications (
      title,
      body,
      is_active,
      target_type,
      target_phone,
      route,
      data,
      created_at
    ) values (
      p_title,
      p_body,
      true,
      'phone',
      btrim(p_phone),
      p_route,
      coalesce(p_data, '{}'::jsonb),
      now()
    );
  exception
    when undefined_column then
      begin
        insert into public.notifications (
          title,
          body,
          is_active,
          target_type,
          target_phone,
          created_at
        ) values (
          p_title,
          p_body,
          true,
          'phone',
          btrim(p_phone),
          now()
        );
      exception
        when others then
          null;
      end;
    when others then
      null;
  end;
end;
$$;

create or replace function public.notify_donor_on_donation_request_insert()
returns trigger
language plpgsql
security definer
as $$
declare
  v_donor_phone text;
  v_title text;
  v_requester text;
begin
  select
    d.donor_phone,
    d.title
  into
    v_donor_phone,
    v_title
  from public.donations d
  where d.id = new.donation_id;

  if v_donor_phone is null or btrim(v_donor_phone) = '' then
    return new;
  end if;

  v_requester := nullif(btrim(coalesce(new.requester_name, '')), '');

  perform public.enqueue_phone_notification(
    p_phone => v_donor_phone,
    p_title => 'طلب هبة جديد',
    p_body => case
      when v_requester is not null then
        'تم إرسال طلب جديد على هبتك من ' || v_requester || '. راجع الطلب للموافقة.'
      else
        'تم إرسال طلب جديد على هبتك. راجع الطلب للموافقة.'
    end,
    p_route => 'donations',
    p_data => jsonb_build_object(
      'route', 'donations',
      'donation_id', new.donation_id,
      'request_id', new.id
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_donor_on_donation_request_insert on public.donation_requests;
create trigger trg_notify_donor_on_donation_request_insert
after insert on public.donation_requests
for each row execute function public.notify_donor_on_donation_request_insert();

create or replace function public.mark_donation_delivered_public(
  p_donation_id uuid,
  p_actor_phone text
)
returns void
language plpgsql
security definer
as $$
declare
  v_phone text;
  v_donor_phone text;
  v_request_id uuid;
  v_requester_phone text;
  v_requester_name text;
begin
  v_phone := btrim(coalesce(p_actor_phone, ''));
  if v_phone = '' then
    raise exception 'PHONE_REQUIRED';
  end if;

  select btrim(coalesce(d.donor_phone, ''))
    into v_donor_phone
  from public.donations d
  where d.id = p_donation_id;

  if v_donor_phone is null then
    raise exception 'DONATION_NOT_FOUND';
  end if;

  select
    r.id,
    btrim(coalesce(r.requester_phone, '')),
    r.requester_name
  into
    v_request_id,
    v_requester_phone,
    v_requester_name
  from public.donation_requests r
  where r.donation_id = p_donation_id
    and coalesce(r.status, '') not in ('cancelled', 'rejected')
  order by r.created_at desc
  limit 1;

  if v_request_id is null then
    raise exception 'REQUEST_NOT_FOUND';
  end if;

  if v_phone <> v_donor_phone and v_phone <> v_requester_phone then
    raise exception 'PHONE_NOT_ALLOWED';
  end if;

  update public.donations
  set status = 'completed'
  where id = p_donation_id;

  update public.donation_requests
  set
    status = 'completed',
    delivered_at = coalesce(delivered_at, now()),
    delivery_confirmed_by_phone = v_phone
  where id = v_request_id;

  if v_phone = v_donor_phone and v_requester_phone is not null and v_requester_phone <> '' then
    perform public.enqueue_phone_notification(
      p_phone => v_requester_phone,
      p_title => 'تم تأكيد التسليم',
      p_body => 'أكد المتبرع أنه تم تسليم الهبة.',
      p_route => 'donations',
      p_data => jsonb_build_object(
        'route', 'donations',
        'donation_id', p_donation_id,
        'request_id', v_request_id
      )
    );
  elsif v_phone = v_requester_phone and v_donor_phone is not null and v_donor_phone <> '' then
    perform public.enqueue_phone_notification(
      p_phone => v_donor_phone,
      p_title => 'تم تأكيد التسليم',
      p_body => case
        when nullif(btrim(coalesce(v_requester_name, '')), '') is not null then
          'أكد ' || btrim(v_requester_name) || ' أنه استلم الهبة.'
        else
          'أكد المتبرع له أنه استلم الهبة.'
      end,
      p_route => 'donations',
      p_data => jsonb_build_object(
        'route', 'donations',
        'donation_id', p_donation_id,
        'request_id', v_request_id
      )
    );
  end if;
end;
$$;

grant execute on function public.mark_donation_delivered_public(uuid, text) to anon, authenticated;
grant execute on function public.enqueue_phone_notification(text, text, text, text, jsonb) to anon, authenticated;