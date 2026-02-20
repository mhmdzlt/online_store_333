create table if not exists public.user_cart_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  product_id uuid not null references public.products(id) on delete cascade,
  product_name text not null,
  product_image text,
  price numeric not null default 0,
  quantity integer not null default 1 check (quantity > 0),
  seller_id uuid,
  size text,
  color text,
  updated_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create index if not exists idx_user_cart_items_user_updated
  on public.user_cart_items (user_id, updated_at desc);

alter table public.user_cart_items enable row level security;

drop policy if exists "Users can view own cart items" on public.user_cart_items;
create policy "Users can view own cart items"
on public.user_cart_items
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert own cart items" on public.user_cart_items;
create policy "Users can insert own cart items"
on public.user_cart_items
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own cart items" on public.user_cart_items;
create policy "Users can update own cart items"
on public.user_cart_items
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete own cart items" on public.user_cart_items;
create policy "Users can delete own cart items"
on public.user_cart_items
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.touch_user_cart_item_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_user_cart_items_updated_at on public.user_cart_items;
create trigger trg_user_cart_items_updated_at
before update on public.user_cart_items
for each row
execute function public.touch_user_cart_item_updated_at();
