# Sprint Backlog

## Sprint: URL/text import draft widget tests — 2026-06-04 (iter-123)

Single-ticket Tier-A: BUT-1204 (my own filed follow-up from BUT-904). Closes the
URL+text import draft view-glue gap. Test-only, closes to Done.

- [x] **A1. Widget tests: URL + text import draft restore + save** `[Tier A]` — `test/widget/views/import_draft_persistence_test.dart`: 4 tests green (restore-on-mount + save-on-keystroke per surface, byte-identical keys). (BUT-1204)
- [x] **A2. Shared-infra fix** `[Tier A]` — `production_mocks.dart`: `MockUrlImportViewModel` was missing the derived `hasError` getter (returned null → build crash). Added `bool get hasError => _error != null` (additive-safe; mirrors sibling mocks). (BUT-1204)

**Note:** clear-on-commit not widget-driven (same as BUT-1207) — disproportionate
fetch/parse-success + navigation scaffolding for a one-line wiring whose clear primitive
is unit-proven. Restore + save (the codec-unreachable glue) covered.

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

---
## ARCHIVED — iter-122 (BUT-1207 group-dialog draft test — Done) · iter-121 (BUT-1201 a11y — Done) · iter-120 (BUT-1208 — Done) · iter-119 (BUT-1200 — Done) · iter-118 (BUT-1203 — Done) · iter-117 (CI tooling — Done) · iter-116 (BUT-904 — In Review)
