# Next Steps

This document captures the agreed-on execution order after aligning architecture and database context.

## Phase 1: Architecture Decisions
- Finalize routing standard (go_router) across customer/admin/seller. (done)
- Finalize state management choice (Riverpod). (done)
- Update ADRs with the confirmed choices. (done)

## Phase 2: Shared Design System
- Create packages/design_system. (done)
- Move AppImage, AppSearchField, AppStates into design_system. (done)
- Add shared Theme and tokens (colors/spacing/radius/typography). (done)
- Update imports in all three apps. (done)

## Phase 3: App Structure Alignment
- Convert apps to feature-first layout (features/<feature>/...).
- Move legacy code into lib/legacy and stop new additions there. (done, legacy layer removed)
- Migrated brands, parts browser, and admin user events into presentation/features. (done)
- Removed compatibility screen layers (lib/screens and lib/presentation/screens). (done)
- Remove duplicated UI patterns.

## Phase 4: Data Layer Consistency
- Align shared_data repositories for Supabase access.
- Add mapping/DTO conventions and caching policy.

## Phase 5: Quality & Performance
- Enforce single vertical scroll per screen.
- Ensure responsive grids use MaxCrossAxisExtent.
- Review image placeholders and caching.
- Add pagination for large lists.

## Security & RLS Checklist
- RFQ reverse marketplace hardening migration applied: `20260213101500_rfq_security_hardening.sql`. (done)
- RFQ RPC grants/policies tightened and validated with `supabase db lint`. (done)
- RFQ security smoke workflow added: `.github/workflows/rfq-security-smoke.yml` (requires `SUPABASE_URL` + `SUPABASE_ANON_KEY` secrets). (done)
- Audit car_* tables for RLS gaps.
- Review user_events policies.
- Validate storage object access and edge function permissions.

## Documentation Cadence
- Update REFACTOR_PLAN.md after each phase.
- Keep ADRs as the source of truth for decisions.
- Add migration notes in ARCHITECTURE.md when structure changes.
