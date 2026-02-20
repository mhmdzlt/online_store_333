# خطة ترحيل SupabaseService

## الهدف
تحويل الاعتماد من `lib/services/supabase_service.dart` إلى طبقة البيانات الجديدة تحت `lib/data/datasources/remote/*`.

## الدوال المنقولة بالفعل
- `fetchPromoBanners()` → `SupabaseCatalogDataSource.fetchPromoBanners`
- `fetchCategories()` → `SupabaseCatalogDataSource.fetchCategories`
- `fetchCarBrands()` → `SupabaseCatalogDataSource.fetchCarBrands`
- `fetchCarModels()` → `SupabaseCatalogDataSource.fetchCarModels`
- `fetchCarYears()` → `SupabaseCatalogDataSource.fetchCarYears`
- `fetchCarTrims()` → `SupabaseCatalogDataSource.fetchCarTrims`
- `fetchCarSectionsV2()` → `SupabaseCatalogDataSource.fetchCarSectionsV2`
- `fetchCarSubsections()` → `SupabaseCatalogDataSource.fetchCarSubsections`
- `fetchProductsByCarHierarchy()` → `SupabaseCatalogDataSource.fetchProductsByCarHierarchy`
- `fetchHomeProducts()` → `SupabaseProductDataSource.fetchHomeProducts`
- `fetchBestSellerProducts()` → `SupabaseProductDataSource.fetchBestSellerProducts`
- `fetchProductsByCategory()` → `SupabaseProductDataSource.fetchProductsByCategory`
- `fetchProductById()` → `SupabaseProductDataSource.fetchProductById`
- `fetchGeneralNotifications()` → `SupabaseNotificationDataSource.fetchGeneralNotifications`
- `fetchPhoneNotifications()` → `SupabaseNotificationDataSource.fetchPhoneNotifications`
- `fetchOrderNotifications()` → `SupabaseNotificationDataSource.fetchOrderNotifications`
- `getNotificationsPublic()` → `SupabaseNotificationDataSource.getNotificationsPublic`
- `createOrderPublic()` → `SupabaseOrderDataSource.createOrderPublic`
- `trackOrder()` → `SupabaseOrderDataSource.trackOrder`
- `fetchDonations()` → `SupabaseFreebiesDataSource.fetchDonations`
- `fetchDonationById()` → `SupabaseFreebiesDataSource.fetchDonationById`
- `submitDonationRequest()` → `SupabaseFreebiesDataSource.submitDonationRequest`
- `submitDonation()` → `SupabaseFreebiesDataSource.submitDonation`
- `saveDeviceToken()` → `SupabaseNotificationDataSource.saveDeviceToken`

## دوال تحتاج نقل/تعويض
- لا شيء حالياً (تم تغطية جميع الدوال الشائعة).

## خطوات الحذف التدريجي
1. تحديث جميع الشاشات/الخدمات للاعتماد على Repositories/Datasources.
2. تم تحويل `supabase_service.dart` إلى re-export فقط (بدون shim).
3. يمكن حذفه لاحقاً إذا لم يعد مطلوباً للتوافق الخلفي.

## خطة تنفيذ مقترحة
- يوم 1: استبدال الاستدعاءات في الشاشات القديمة (legacy) بـrepositories.
- يوم 2: نقل `fetchProductsByCarHierarchy` إلى datasource مناسب.
- يوم 3: تم تحويل الملف إلى re-export فقط.
