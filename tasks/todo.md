# Sprint Backlog

## Sprint: iter-72 — BUT-1089 sibling fromMap hardening — 2026-05-25 (Mon)

Theme: Apply BUT-1071's fail-loud hardening to `RealtimeMenuFactory.parseRepositoryData` + `parseJsonData`. Asymmetry creates corruption-disguise risk (recipes reject what menus quietly accept). P4 backend Bug.

### Step 0 — premise verification

- `RealtimeMenuFactory.parseRepositoryData` (line 79) and `parseJsonData` (line 119) use `safeString`/`safeRequiredDateTime` for `ownerId`/`createdAt`/`lastEditedAt`/`lastEditedBy` — same silent-default pattern BUT-1071 fixed in RealtimeRecipe.
- **Re-scope (plan-stale, Step 0):** Original ticket scope included `RealtimeResource.parseFirestoreMetadata`. Grep confirms zero production callers — it's a test-only helper with an explicit "should handle missing fields" test. Hardening it would break tests for zero production benefit. **Skipped + filed separately as candidate-for-deletion.**
- Existing happy-path tests in `realtime_menu_factory_test.dart` (lines 192-213, 215-240, etc.) all include the 4 required fields. Won't break.
- Classification: **fits with scope narrowing**.

### Design choices

- Use the same `SerializationUtils.requiredString` and `requiredDateTime` introduced in BUT-1071. No new helpers.
- Apply to 4 fields in both methods: `ownerId`, `createdAt`, `lastEditedAt`, `lastEditedBy`. Display-name fields stay soft (same as recipe contract).
- Add 5 new tests mirroring BUT-1071 (1 happy-path + 4 missing-required) for each method = 10 new tests total. Borderline — collapse to 5 by parameterizing both methods over `validData(method)` if it stays readable.
- **Don't touch `parseRequiredDateTimeValue` line 104** in parseRepositoryData — that's the misnamed util again. The hardening swap replaces it.

### Ship this sprint

- [ ] **A1. Harden parseRepositoryData** — `lib/models/realtime/realtime_menu_factory.dart:99-107`: swap 4 silent-default calls to `requiredString` / `requiredDateTime`. (BUT-1089)
- [ ] **A2. Harden parseJsonData** — same file, lines 138-145, same 4 fields. (BUT-1089)
- [ ] **A3. Add tests** — `test/unit/models/realtime_menu_factory_test.dart`: 4-8 new tests covering missing-required cases for both parser variants. (BUT-1089)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test realtime_menu_factory_test.dart` passes.
- [ ] Existing recipe-fromMap tests still pass (sanity).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1089
- [ ] File follow-up for `RealtimeResource.parseFirestoreMetadata` deletion (or wire-up decision)

---

## Archived iter-71 (commit `f5286fba1`) — 2026-05-25 (Mon)

BUT-1076 P4 — aligned UrlImportStrategy tier metadata to source-comment names (3→5, 5→7). +24 / −18. 38/38 tests pass.
