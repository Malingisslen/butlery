# Sprint Backlog

## Sprint: iter-71 — BUT-1076 align tier metadata — 2026-05-25 (Mon)

Theme: Analytics-observability fix — `UrlImportStrategy` writes `'tier': 3` for `_tryHtmlTextParse` (commented as Tier 5) and `'tier': 5` for `_createUserAssistedResult` (commented as Tier 7). Mismatch. P4 analytics/import/Bug.

### Step 0 — premise verification

- Ticket points at file lines 264 + 282; actual lines are 279 (tier:3 in `_tryHtmlTextParse`) and 297 (tier:5 in `_createUserAssistedResult`).
- Source comments at lines 138-141 + 158 + 252-282 confirm "Tier 5" / "Tier 7" naming.
- Test `test/unit/services/import/url_import_strategy_test.dart:327` asserts `tier: 3` — must flip to 5. Header docstring lines 27-28 acknowledges the mismatch as "historical" — re-write.
- Per ticket: align metadata to the comment-named numbers (Option: 5 and 7).
- Live analytics dashboards: none in this solo-dev repo to audit. If any post-hoc analytics breaks, easy to map old `tier=3,5` to new `tier=5,7`.
- Classification: **fits**.

### Design choices

- Two single-line metadata changes.
- Update one test assertion + one docstring block.

### Ship this sprint

- [ ] **A1. Align url_import_strategy.dart tier metadata** — `lib/services/import/url_import_strategy.dart:279,297`: `3→5`, `5→7`. (BUT-1076)
- [ ] **A2. Update tests** — `test/.../url_import_strategy_test.dart:27-28 docstring + :327 assertion`. (BUT-1076)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test url_import_strategy_test.dart` passes.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1076

---

## Archived iter-70 (commit `927f808f0`) — 2026-05-25 (Mon)

BUT-1097 P4 — deleted now-zero-caller `@Deprecated SocialRecipeCoordinator.importSharedRecipe`. -90 / +13. Analyze clean.
