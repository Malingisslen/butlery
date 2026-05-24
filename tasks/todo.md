# Sprint Backlog

## Sprint: iter-52 — BUT-891 update CPI assertions to LoadingIndicator — 2026-05-24 (Sun)

Theme: iOS-platform-coupling latent bug. Tests assert `CircularProgressIndicator` against views/helpers that render `LoadingIndicator` → `AdaptiveActivityIndicator` → CPI on Linux/Android only. Pass-by-coincidence on current CI matrix, fail on iOS. Plan-fil FÖRST per discipline.

### Step 0 — premise verification

All 5 sites in ticket verified at the exact lines:
- `test/views/social/group_detail_view_test.dart:99` — `find.byType(CircularProgressIndicator), findsOneWidget`
- `test/views/social/group_detail_view_test.dart:415` — same
- `test/views/social/shared_with_me_view_test.dart:263-266` — print-only no-op branch (asserts nothing)
- `test/views/helpers/view_test_helpers.dart:368` — `expectLoadingState` helper
- `test/views/helpers/view_test_helpers.dart:401` — `expectContentState` helper

### Design choices

- **Site 1+2 (group_detail_view_test)**: replace `find.byType(CircularProgressIndicator)` → `find.byType(LoadingIndicator)`. Add import.
- **Site 3 (shared_with_me_view_test)**: per ticket "either flip to LoadingIndicator + assert, or delete". The print-only branch is observation-without-assertion which means it never fails. Flip to a real assertion. Add import.
- **Site 4+5 (view_test_helpers)**: per ticket "prefer LoadingIndicator as primary check with CPI as tolerated legacy fallback". Update both helpers to look for either widget — tolerates the still-raw-CPI legitimate sites (lib/widgets/common/indicators/) without forcing wholesale migration first. Add import.
- **No other test files need touching**: ticket explicitly lists 5 out-of-scope tests that legitimately target widget primitives still rendering raw CPI.

### Ship this sprint

- [ ] **A1. group_detail_view_test.dart** — 2 sites swap CPI → LoadingIndicator + import.
- [ ] **A2. shared_with_me_view_test.dart** — convert print-only branch to real assertion + import.
- [ ] **A3. view_test_helpers.dart** — both helpers updated to find either widget + import.
- [ ] **A4. Spot-check** — grep `test/` for stragglers; report.

### Acceptance

- [ ] `flutter test test/views/social/group_detail_view_test.dart` passes.
- [ ] `flutter test test/views/social/shared_with_me_view_test.dart` passes.
- [ ] `flutter analyze` clean.
- [ ] No `find.byType(CircularProgressIndicator)` assertions on migrated views remain (out-of-scope files preserved per ticket).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-891 i Linear → Done

---

## Archived iter-51 (commit `8d7bc683b`) — 2026-05-24 (Sun)

BUT-885 partial — 11 CPI sites in tagging/social/recipe widgets migrated to LoadingIndicator. +57 / -80. BUT-885 still In Progress (Phase 5 broad-sweep + arch-test = BUT-1066).
