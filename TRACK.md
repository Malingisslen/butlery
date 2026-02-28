# Track 3: Architecture + Performance + UX

**Branch**: `track-3/arch-perf-ux`
**Phases**: 4 (Architecture) → 6 (Performance) → 7 (UX & Accessibility)
**Estimated effort**: ~9 days
**Run sequentially** — Phases 4 and 6 share DI modules

## Why these are together
Phase 4 fixes architecture violations (repository boundaries, DI hygiene). Phase 6 optimizes startup and data loading (requires clean DI from Phase 4). Phase 7 is UI/accessibility polish that doesn't conflict but benefits from the cleaner architecture.

## Phase 4 — Architecture Fixes (~4 days, 14 items)
Reference: `docs/analysis/master-plan/phase_04_architecture.md`

Priority order:
1. **P4-03** — Views import repositories directly (CRIT, MVVM violation)
2. **P4-04** — FeedbackService bypasses repository layer (CRIT)
3. **P4-05** — MessagingService bypasses repository for polls (CRIT)
4. P4-01 — Create FirestoreCollections constants class (2d, biggest item)
5. P4-02 — Migrate 4 remaining models to SerializationUtils
6. P4-06 — 5 ViewModels import cloud_firestore (Timestamp leakage)
7. P4-07 — ProfileViewModel imports firebase_auth
8. P4-08 — Views import firebase_auth for MFA types
9. P4-09 — Remove direct Firebase static references in DI
10. P4-10 — notification_repository.dart misplaced in services/
11. P4-12 — Direct service instantiation in ViewModels
12. P4-13 — Inconsistent null-coalescing patterns
13. P4-14 — 3 ViewModels manually manage _isLoading
14. P4-15 — 9 plain service classes without BaseService/ErrorHandlingMixin

## Phase 6 — Performance & Scalability (~2 days, 9 items)
Reference: `docs/analysis/master-plan/phase_06_performance.md`

Key items:
1. **P6-01** — subscribeToUserRecipes unbounded listener (CRIT, 30 min)
2. **P6-06** — Convert 53 eager singletons to lazy (1-2d, biggest item)
3. P6-05 — Parallelize independent DI module initialization
4. P6-04 — Subcollection TTL for views/engagements/dismissals
5. P6-08 — Inject shared HTTP client
6. P6-09 — Add hasPendingWrites sync indicator
7. P6-11 — Convert 14 ListViews to .builder
8. P6-12 — Cloud Function for Storage cleanup on recipe delete
9. P6-13 — Cache-first read patterns

## Phase 7 — UX, Accessibility & Polish (~3 days, 19 items)
Reference: `docs/analysis/master-plan/phase_07_ux_accessibility.md`

All 19 items. Start with HIGH accessibility items (P7-01 through P7-04), then P7-09 (error messages, 1-2d), then remaining.

## Also handle from Phase 9 (deferred here):
- P9-11 — Consolidate go_router vs Navigator
- P9-12 — Decompose personal_tags_view.dart
- P9-13 — Decompose personal_tag_service.dart
- P9-14 — Decompose personal_tag_rule.dart
- P9-15 — Update stale architecture documentation
- P9-16 — Resolve old TODO/FIXME comments
- P9-18 — recipe_image_manager.dart review

## Merge strategy
Merge to main after each phase completes. Phase 4 first, then 6, then 7, then P9 extras.
