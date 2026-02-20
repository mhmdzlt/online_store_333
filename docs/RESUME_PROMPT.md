We have a Flutter monorepo with three apps: customer/admin/seller.
Current status: Home uses Slivers. AppImage, AppSearchField, AppStates are moved into packages/design_system.
Routing standard: go_router. State standard: Riverpod.
Next steps:
1) Update imports in admin/seller to use design_system.
2) Add shared Theme/tokens to design_system.
3) Apply rules: one vertical scroll, responsive grids, RTL directional.
Provide migration steps, file list, and short diffs.
