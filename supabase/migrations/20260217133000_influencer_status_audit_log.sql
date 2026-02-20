-- Audit trail for influencer application status changes

create table if not exists public.influencer_profile_status_logs (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.influencer_profiles(id) on delete cascade,
  old_status text,
  new_status text,
  old_notes text,
  new_notes text,
  changed_by uuid,
  changed_at timestamptz not null default now()
);

create index if not exists idx_influencer_status_logs_profile_changed_at
  on public.influencer_profile_status_logs(profile_id, changed_at desc);

alter table public.influencer_profile_status_logs enable row level security;

drop policy if exists influencer_status_logs_select_admin on public.influencer_profile_status_logs;
create policy influencer_status_logs_select_admin
  on public.influencer_profile_status_logs
  for select
  using (public.is_app_admin(auth.uid()));

drop policy if exists influencer_status_logs_insert_admin on public.influencer_profile_status_logs;
create policy influencer_status_logs_insert_admin
  on public.influencer_profile_status_logs
  for insert
  with check (public.is_app_admin(auth.uid()));

create or replace function public.log_influencer_profile_status_change()
returns trigger
language plpgsql
as $$
begin
  if (old.status is distinct from new.status)
     or (old.notes is distinct from new.notes) then
    insert into public.influencer_profile_status_logs (
      profile_id,
      old_status,
      new_status,
      old_notes,
      new_notes,
      changed_by,
      changed_at
    ) values (
      new.id,
      old.status,
      new.status,
      old.notes,
      new.notes,
      auth.uid(),
      now()
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_influencer_profiles_status_audit
  on public.influencer_profiles;
create trigger trg_influencer_profiles_status_audit
after update on public.influencer_profiles
for each row
execute function public.log_influencer_profile_status_change();
