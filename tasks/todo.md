# Sprint Backlog

## Sprint: iter-51 — BUT-885 partial — tagging/social/recipe widget CPI migration — 2026-05-24 (Sun)

Theme: Phase 4 ticket är "residual sites + arch-test". Plockar tagging/social/recipe-widgets-delen denna iter; lämnar bredare residual (image-overlays = BUT-884 territory; views/onboarding/auth = Phase-5-shape) + arch-test till separat commit.

### Step 0 — premise verification

- BUT-885 archived 2026-05-22 but Backlog premise still valid: `grep CircularProgressIndicator(` shows **65 files** in lib/ — Phase 1+2 closed buttons/dialogs only.
- Phase 4 ticket scope: "residual tagging/social/recipe widget files (everything not covered by Phase 1-3)". Targeted:
  - `lib/widgets/tagging/` — 4 sites (3 files): personal_tag_edit_dialog (2), personal_tag_rule_dialog (1), personal_tag_selector (1)
  - `lib/widgets/social/` — 3 sites: ping_compose_sheet (1), groups/group_shared_content_section (1), groups/shared/group_dialog_components (1)
  - `lib/widgets/recipe/` — 4 sites: cook_snap_gallery (2), ingredient_substitution_sheet (1), heirloom_section (1)
- Total: **11 sites across 9 files**.

### Design choices

- **Same constructor strategy as iter-46 (BUT-883)**: base `LoadingIndicator(size:, strokeWidth:, color:)`, NOT `.small()`. Padding inflation breaks inline icon-slots.
- **Pure mechanical replace** — read each site for strokeWidth + size context, swap with matching params.
- **Imports**: each touched file gets `loading_indicator.dart` import added if missing.
- **Arch-test deferred**: ticket asks for one but adding the regex+allowlist guard to `test/architecture/architecture_test.dart` would inflate this iter; file BUT-XXX follow-up.
- **Other 56 files of CPI**: 9 image/upload-progress files = BUT-884 (Phase 3) territory; the rest are views/widgets that belong to either Phase 3 (image) or a future Phase 5 (broad residual sweep). Leaving them out keeps this iter focused.

### Ship this sprint

- [ ] **A1. BUT-885 partial** — Migrate 11 tagging/social/recipe widget CPI sites.
  - For each site: read strokeWidth/size from existing SizedBox/CPI wrapper, replace with `LoadingIndicator(...)` preserving dimensions.
  - Add `loading_indicator.dart` import per touched file.
- [ ] **A2. Follow-up Linear** — File BUT-XXX for "arch-test guard for new CPI introductions" with the regex+allowlist pattern.

### Acceptance

- [ ] `grep CircularProgressIndicator\\b lib/widgets/{tagging,social,recipe}` returns zero hits.
- [ ] `flutter analyze` clean.
- [ ] No visual change to spinner dimensions (strokeWidth/size match per call site).

### Post-Sprint Steps

- [ ] `flutter analyze` clean
- [ ] Commit + push
- [ ] Update BUT-885 — partial completion comment; leave In Progress for residual + arch-test
- [ ] File the arch-test follow-up

---

## Archived iter-50 (commit `744624eb9`) — 2026-05-24 (Sun)

BUT-919 group-creation draft persist. First multi-field JSON-payload variant. +121 / -26. BUT-919 → Done. Draft-pattern now 4/5 forms; BUT-910 photo-import remains (needs on-disk staging, out of pattern scope).
