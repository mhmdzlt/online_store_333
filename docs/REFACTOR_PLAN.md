# UI/UX Refactor Path

Purpose: keep a single, explicit path for UI/UX refactor work to avoid overlap and regressions.

## Scope
- Flutter app with RTL and Material 3.
- Focus on layout stability, responsive grids, scroll performance, shared UI widgets.

## Phases
### Phase A: Layout stabilization (prevent overflow/tangles)
- Convert nested vertical scrolls to slivers in Home.
- Make grids responsive (avoid fixed crossAxisCount).
- Remove unnecessary `resizeToAvoidBottomInset: false` unless a screen needs it.

### Phase B: Shared UI components (design system)
- Extract shared widgets: `AppSearchField`, `AppSectionHeader`, `AppEmptyState`, `AppLoading`.
- Centralize spacing and text styles via theme + constants.

### Phase C: Performance and images
- Replace `Image.network` with `CachedNetworkImage` with stable placeholders.
- Reduce rebuilds by splitting large widgets.

### Phase D: Navigation clarity
- Decide between manual `IndexedStack` or go_router stateful shell for tabs.
- Ensure deep links and back-stack behavior are consistent.

## Current Progress
- Home screen converted to slivers to remove nested vertical scrolls.
- Categories grid made responsive (max cross-axis extent).
- Shared AppSearchField extracted and wired into primary screens.
- Category product sort sheet fixed to retain selection.
- Image widgets migrated to CachedNetworkImage where applicable.
- Root SafeArea updated to include top padding.
- Shared empty/loading states extracted and applied to key screens.
- Shared AppImage widget introduced for consistent placeholders.
- AppImage placeholders normalized via Theme colorScheme.
- Legacy search inputs switched to AppSearchField for consistent spacing.
- Design system package created and common widgets moved.
- Theme tokens + shared ThemeData centralized in design_system and wired to all apps.
- go_router adopted in admin/seller for unified routing.

## Files Touched
- lib/presentation/screens/home/home_screen.dart
- lib/presentation/widgets/home/categories_grid.dart
- lib/presentation/screens/product/product_list_by_category_screen.dart
- lib/presentation/screens/categories/categories_screen.dart
- lib/presentation/screens/donations/donations_home_screen.dart
- lib/presentation/screens/notifications/notifications_screen.dart
- lib/screens/brands/car_brands_screen.dart
- lib/screens/brands/car_models_screen.dart
- lib/screens/brands/car_years_screen.dart
- lib/screens/brands/car_trims_screen.dart
- lib/screens/brands/car_sections_v2_screen.dart
- lib/screens/brands/car_subsections_screen.dart
- lib/screens/brands/car_subsection_products_screen.dart
- lib/screens/parts_browser/parts_browser_screen.dart
- lib/main.dart
- lib/presentation/widgets/home/promo_banner_carousel.dart
- lib/presentation/screens/product/product_details_screen.dart
- lib/presentation/screens/cart/cart_screen.dart
- lib/presentation/screens/donations/donation_details_screen.dart
- lib/screens/brands/car_subsection_products_screen.dart
- lib/screens/parts_browser/parts_browser_products_screen.dart
- packages/design_system/lib/src/app_image.dart
- packages/design_system/lib/src/app_search_field.dart
- packages/design_system/lib/src/app_states.dart

## Next Steps (recommended order)
1) Update admin/seller to use design_system components.
2) Review legacy screens for remaining `Image.network` usage.

## Conventions
- Keep RTL consistent via `Directionality.rtl`.
- Prefer `CustomScrollView` + slivers for long, mixed-content screens.
- Use `AppSizes` for spacing and sizes; avoid magic numbers.
