create table if not exists public.app_more_content_settings (
  id boolean primary key default true,
  app_name jsonb not null default '{}'::jsonb,
  app_version text not null default '1.0.0',
  about_text jsonb not null default '{}'::jsonb,
  privacy_text jsonb not null default '{}'::jsonb,
  terms_text jsonb not null default '{}'::jsonb,
  contact_text jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.app_more_content_settings (
  id,
  app_name,
  app_version,
  about_text,
  privacy_text,
  terms_text,
  contact_text
)
values (
  true,
  '{"ar":"متجر + هبات مجانية","en":"Store + Freebies","ckb":"فرۆشگا + بەخششە خۆڕاییەکان","ku":"Firotgeh + Diyariyên Belaş"}'::jsonb,
  '1.0.0',
  '{"ar":"تطبيق بسيط للتسوق والهبات المجانية ويدعم الدخول كزائر أو عبر حساب جوجل.","en":"A simple shopping and freebies app that supports guest mode and Google sign-in.","ckb":"بەرنامەیەکی سادەی کڕین و بەخششە خۆڕاییەکانە کە دۆخی میوان و چوونەژوورەوە بە گووگڵ پشتگیری دەکات.","ku":"Uygulamek hêsan ji bo kirîn û diyariyên belaş e ku moda mêvan û têketina Google piştgirî dike."}'::jsonb,
  '{"ar":"نص تجريبي لسياسة الخصوصية.","en":"Sample privacy policy text.","ckb":"دەقی نموونەیی بۆ سیاسەتی تایبەتمەندی.","ku":"Nivîsa mînakî ya siyaseta taybetîtiyê."}'::jsonb,
  '{"ar":"نص تجريبي للشروط والأحكام.","en":"Sample terms and conditions text.","ckb":"دەقی نموونەیی بۆ مەرج و ڕێساکان.","ku":"Nivîsa mînakî ya merc û şertan."}'::jsonb,
  '{"ar":"واتساب/هاتف (placeholder).","en":"WhatsApp/Phone (placeholder).","ckb":"واتساپ/تەلەفۆن (placeholder).","ku":"WhatsApp/Telefon (placeholder)."}'::jsonb
)
on conflict (id) do nothing;

grant select on table public.app_more_content_settings to anon, authenticated;
grant insert, update on table public.app_more_content_settings to authenticated;
