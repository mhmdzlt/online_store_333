# Database Overview (Supabase)

## Scope
- Project: enxihyplaelrdkievkrk (Supabase)
- Schemas in use: auth, public, storage, realtime
- Goal: keep a single source of truth for data, RLS, and edge functions

## Core Schemas
- auth: users and authentication metadata
- public: main business data (products, categories, orders, sellers, notifications)
- storage: buckets and objects
- realtime: messages and subscriptions tables

## Key Tables (Public)
- profiles (linked to auth.users)
- products, categories
- orders, order_items
- sellers
- notifications
- user_events (analytics)
- car_* tables (brands, models, years, trims, sections, subsections)

## Storage
- storage.buckets
- storage.objects (active usage)

## Realtime
- realtime.messages and daily message tables

## RLS Status (Summary)
- Many core tables have RLS enabled with explicit policies
- Several car_* tables show RLS disabled or missing policies
- Some public read policies exist for banners, categories, car brands, and product images
- Orders and order_items include admin and seller policies
- Products have multiple admin/seller/public policies

## Edge Functions
- resend_confirmation_email (verify_jwt = true)
- send_notification (verify_jwt = true)

## Extensions (Notable)
- pgcrypto, uuid-ossp, pg_stat_statements
- pgjwt
- pg_trgm, vector, rum
- pg_net / http
- supabase_vault

## Risks / Gaps
- car_* tables with RLS disabled can be accessed by the Data API
- user_events shows RLS disabled
- policies for some public tables should be audited for least-privilege access

## Action Items
1) Audit RLS on car_* tables and user_events
2) Confirm edge function permissions and expected roles
3) Verify storage object access policies
4) Document data flows between customer/admin/seller apps and shared tables

---

# نظرة عامة على قاعدة البيانات (Supabase)

## النطاق
- المشروع: enxihyplaelrdkievkrk (Supabase)
- المخططات المستخدمة: auth, public, storage, realtime
- الهدف: مصدر واحد للحقيقة للبيانات وRLS وEdge Functions

## المخططات الأساسية
- auth: المستخدمون وبيانات المصادقة
- public: بيانات العمل (المنتجات، الفئات، الطلبات، البائعون، الإشعارات)
- storage: الدلاء والملفات
- realtime: جداول الرسائل والاشتراكات

## الجداول الرئيسية (public)
- profiles (مرتبطة بـ auth.users)
- products, categories
- orders, order_items
- sellers
- notifications
- user_events (تحليلات)
- جداول car_* (العلامات، الموديلات، السنوات، الفئات، الأقسام، الأقسام الفرعية)

## التخزين
- storage.buckets
- storage.objects (استخدام فعّال)

## Realtime
- realtime.messages وجداول الرسائل اليومية

## حالة RLS (ملخص)
- العديد من الجداول الأساسية لديها سياسات RLS واضحة
- بعض جداول car_* لديها RLS معطلة أو سياسات ناقصة
- توجد سياسات قراءة عامة للافتات والفئات وصور المنتجات
- الطلبات وعناصر الطلب فيها سياسات للإدارة والبائع
- المنتجات فيها سياسات متعددة (إدارة/بائع/عام)

## دوال الحافة
- resend_confirmation_email (verify_jwt = true)
- send_notification (verify_jwt = true)

## الامتدادات المهمة
- pgcrypto, uuid-ossp, pg_stat_statements
- pgjwt
- pg_trgm, vector, rum
- pg_net / http
- supabase_vault

## المخاطر والفجوات
- جداول car_* مع RLS معطلة قد تكون متاحة عبر Data API
- user_events يظهر أن RLS معطل
- سياسات القراءة العامة تحتاج تدقيق الحد الأدنى للصلاحيات

## مهام مقترحة
1) تدقيق RLS على car_* و user_events
2) التأكد من صلاحيات Edge Functions والأدوار
3) مراجعة سياسات الوصول إلى storage.objects
4) توثيق تدفق البيانات بين تطبيقات العميل/التاجر/المشرف
