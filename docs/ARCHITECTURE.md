# Architecture

## Scope
- Monorepo contains 3 apps: customer / admin / seller
- Shared packages: design_system, shared_domain, shared_data

## Repo Structure
online_store_333/ (customer)
admin/
seller/
packages/
  design_system/ (created)
  shared_domain/
  shared_data/
docs/
  ARCHITECTURE.md
  STYLEGUIDE.md
  REFACTOR_PLAN.md
  adrs/

## Layers inside each App
- presentation: features/<feature>/screens + widgets + controllers
- application: usecases/state
- domain: entities/contracts (prefer shared_domain)
- data: repos/datasources (prefer shared_data)

- Shared packages: design_system, shared_domain, shared_data
- Shared UI primitives live in `packages/design_system` and are reused across customer/admin/seller.
  - Theme tokens + shared ThemeData are centralized in `packages/design_system` (`AppTheme`, `AppColors`, `AppSizes`, `AppTextStyles`).

## Routing
- Single choice: go_router (unified)
- Tabs: StatefulShellRoute or IndexedStack (choose one only)

- Do not mix state approaches across core screens

## Data Access
- Supabase through shared_data
- Repositories + DTO mapping + caching policy

## Database Overview
See [docs/DATABASE_OVERVIEW.md](docs/DATABASE_OVERVIEW.md) for the full Supabase snapshot and RLS summary.

## Legacy Policy
- Root shell lives under lib/presentation/shell/root_shell.dart
- No legacy screen layer (legacy/screens removed after migration)

## Execution Plan
See [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) for the ordered migration plan and documentation cadence.
