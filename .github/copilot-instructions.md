# Copilot Instructions for online_store_333

## Project overview
- Flutter app (Arabic RTL) with a tabbed shell; screens are migrating from `lib/screens/*` to `lib/presentation/screens/*`.
- App entry + theme live in `lib/main.dart` (Material 3, `Directionality.rtl`, `SafeArea` wrapper).
- Bottom navigation and back/exit flow live in `lib/screens/root_shell.dart` (IndexedStack + custom exit sheet).

## Initialization flow (order matters)
- `main()` initializes Supabase, signs out any prior session, then Firebase, then `TrackingService.init()`, then `NotificationService.init()`.
- `NotificationService.init()` must run after `Firebase.initializeApp()`; keep the background handler top-level (`firebaseMessagingBackgroundHandler`).

## Data/services architecture
- Supabase is the primary backend (tables + RPCs + storage). `lib/services/supabase_service.dart` still exists, but newer screens use focused datasources under `lib/data/datasources/remote/`.
  - RPCs: `create_order_public`, `track_order_public`, `get_notifications_public`, `save_device_token`.
  - Donations store images in Supabase Storage bucket `product-images` (`submitDonation()`).
- Focused datasources live in `lib/data/datasources/remote/` (products, orders, freebies, notifications) and are wrapped by repositories in `lib/data/repositories/`.
- Car catalog data uses `lib/services/car_catalog_service.dart`; it maps year → generation → trims and has a single model `lib/models/car_brand.dart`.
- Cart state is a `ChangeNotifier` in `lib/presentation/providers/cart_provider.dart`, provided at app root; it enforces a single-seller cart.
- Tracking uses `lib/core/services/tracking_service.dart`: queues events in `SharedPreferences` and inserts into `user_events` in Supabase.

## UI/data conventions
- Many screens consume Supabase results as `List<Map<String, dynamic>>`; avoid adding heavy DTOs unless needed.
- Images: use `resolveProductImage()` / `resolveDonationImage()` (see `lib/utils/image_resolvers.dart`); ignore placeholder.com URLs via `isPlaceholderUrl()`.
- Phone + tracking flags are persisted via `LocalStorage` in `lib/utils/local_storage.dart`.

## Notifications & deep links
- `NotificationService` (`lib/core/services/notification_service.dart`) handles both FCM and local notifications; it normalizes payload keys before routing.
- Supported `route` values: `home`, `notifications`, `cart`, `donations`, `tracking`, `category`, `product`, `external` (see switch in `NotificationService`).
- Navigation uses `NotificationService.instance.navigatorKey`; if adding a new route, update both normalization and switch cases.

## Where to add new code
- New feature screens: add under `lib/presentation/screens/<feature>/` (use `lib/screens/*` only for legacy files) and wire into `RootShell` if it’s a top-level tab.
- New data access: add a datasource under `lib/data/datasources/remote/` and optional repository under `lib/data/repositories/` (keep `SupabaseService` for legacy usage).