# Sprint Backlog

## Sprint: iter-61 — BUT-885 Phase 5 partial — views/ CPI sweep — 2026-05-24 (Sun)

Theme: Mechanical CPI → LoadingIndicator migration on lib/views/ files (15 of 52 residual). Plan-fil FÖRST.

### Step 0 — premise verification

- 56 files total contain `CircularProgressIndicator(`.
- Allowlist (legitimate raw CPI): 4 files in `lib/widgets/common/indicators/` + `lib/widgets/common/state/`.
- Residual: 52. Targeting **lib/views/** (15 files) this iter for clean scope-cut.
- Pattern from iter 46 + 51: `LoadingIndicator(size:, strokeWidth:, color:)` not `.small()` (preserves slot sizing).

### Design choices

- **Mechanical replace**: read each site for strokeWidth + size context, swap to `LoadingIndicator(...)`.
- **Add `loading_indicator.dart` import per file** via sed after edits.
- **BUT-895 spillover benefit**: iter-58 added Semantics(label, liveRegion) to LoadingIndicator wrapper. All migrated sites become a11y-compliant for free.
- **Stop at views/**: widgets/ residual (image overlays, messaging, etc.) for next iter.
- **No arch-test add yet**: per BUT-1066 — only meaningful when sites = 0.

### Ship this sprint

- [ ] **A1. lib/views/ migration**: 15 files, each with 1-N CPI sites.

### Acceptance

- [ ] `grep CircularProgressIndicator\\b lib/views/` returns 0 hits.
- [ ] `flutter analyze` clean.
- [ ] No visual regression in spinner dimensions (strokeWidth/size preserved per call).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] BUT-885 Linear comment: Phase 5 partial — views/ done, widgets/ residual = ~37 files (next iter)

---

## Archived iter-60 (commit `ad7e33462`) — 2026-05-24 (Sun)

BUT-952 mark-all-as-read (partial). 4-layer change (repo + service + VM + view). +129 / -19. BUT-952 → Done. BUT-1080 filed för long-press selection mode.
