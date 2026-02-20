create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  reviewer_name text not null,
  reviewer_phone text,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  is_approved boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_reviews_product_id_created_at
  on public.product_reviews (product_id, created_at desc);

create index if not exists idx_product_reviews_is_approved
  on public.product_reviews (is_approved);

alter table public.product_reviews enable row level security;

drop policy if exists "Public can view approved product reviews" on public.product_reviews;
create policy "Public can view approved product reviews"
on public.product_reviews
for select
to anon, authenticated
using (is_approved = true);

drop policy if exists "Public can insert product reviews" on public.product_reviews;
create policy "Public can insert product reviews"
on public.product_reviews
for insert
to anon, authenticated
with check (
  rating between 1 and 5
  and length(trim(reviewer_name)) > 0
);
