# Sprint Backlog

## Sprint: iter-46 — BUT-883 CPI Phase 2 codemod — 2026-05-24 (Sun)

Theme: Retroactive plan after user pushback ("Men nu skippar du ju planning stagen eller?"). Iter 32 had the same correction; I drifted again across iters 33–45 by jumping straight to implementation. Re-anchoring on `/sprint-execute` Phase 1.

### Step 0 — premise verification

BUT-883 ticket is `archivedAt`-flaggad i Linear (2026-05-22) men premissen håller: `grep CircularProgressIndicator` i `lib/widgets/common/buttons/` (4 hits) + `lib/widgets/common/dialogs/` (14 hits) = 18 callsites. Phase 2 inte gjord; archive-flagga betyder "ut ur aktiv sprint", inte "klar".

### Ship this sprint

- [x] **A1. BUT-883** — Migrate inline button + dialog spinners to `LoadingIndicator`.
  - `lib/widgets/common/buttons/action_buttons.dart` — 4 sites (`SizedBox + CPI strokeWidth:2` → `LoadingIndicator(size:..., strokeWidth:2)`).
  - `lib/widgets/common/dialogs/base_dialog.dart` — 5 sites (mix of sized button-icon spinners + bare centered CPI).
  - 8 more dialog files — bare CPI or sized button-icon spinners.
  - Import `loading_indicator.dart` added per file via sed.
  - Used base constructor `LoadingIndicator(size, strokeWidth)` not `.small()` to avoid the built-in padding inflating button layouts.

### Post-Sprint Steps

- [x] `flutter analyze` — No issues found.
- [ ] Tier-2: `code-reviewer` (auto-trigger), `testing-specialist` if any test asserts on `CircularProgressIndicator` byType.
- [ ] `/code-review high` (simplify marker).
- [ ] Commit + push.
- [ ] Stäng BUT-883 i Linear → Done.

### Why no follow-up filed

Phase 3+ (BUT-884, BUT-885) are separate Linear tickets covering different file groups (settings views, remaining lib/ usage). No new follow-up needed beyond those already-tracked tickets.

---

## Archived iter-45 (commit `c61b810bc`) — 2026-05-24 (Sun)

PII audit: stripped `recipe.title` from 21 non-DEBUG AppLogger sites across lib/. DEBUG sites kept intact (dev-only, no prod Cloud Logging shipment). BUT-804 HIGH-AI2 fully closed.
