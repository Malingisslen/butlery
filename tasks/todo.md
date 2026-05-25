# Sprint Backlog

## Sprint: iter-66 — BUT-1071 fromMap fail-loud on missing required — 2026-05-25 (Mon)

Theme: Data hygiene bug — `RealtimeRecipe.fromMap` silently defaults missing required fields. `safeRequiredDateTime` is a misnomer — it falls back to `clock.now()`. P4 backend.

### Step 0 — premise verification

- Ticket matches `lib/models/realtime/realtime_recipe.dart:334-376` (fromMap) and `lib/core/utils/serialization_utils.dart:127-130` (safeRequiredDateTime — misleadingly named, defaults to clock.now()).
- Truly-required fields in a real document: `ownerId`, `createdAt`, `lastEditedAt`, `lastEditedBy`. Display-name fields are softer (UI only).
- BUT-1069 (iter-63) already propagates parse exceptions to stream subscribers — exception path infrastructure exists; we just need to USE it.
- Classification: **fits** — implement as written.

### Design choices

- **Add strict variants to SerializationUtils**: `requiredString` and `requiredDateTime` that throw `FormatException` on missing/empty. Leave existing `safe*` family alone (they're used in 100+ places).
- **Apply to the 4 truly-required fields in fromMap**: ownerId, createdAt, lastEditedAt, lastEditedBy. Display names stay soft (empty-string default OK).
- **Don't rename `safeRequiredDateTime`** — it's the misnomer cause but renaming is high-blast-radius. The ticket scope is fixing fromMap, not refactoring serialization util naming.
- **Tests**: add 4 new tests covering each required-field absence + 1 success case. Strict-variant utility tests can be inline if minimal.

### Ship this sprint

- [ ] **A1. Add strict required-field parsers** — `lib/core/utils/serialization_utils.dart`: add `requiredString(map, key)` (throws on null/empty) and `requiredDateTime(map, key)` (throws on null/unparseable). (BUT-1071)
- [ ] **A2. Use strict variants in RealtimeRecipe.fromMap** — `lib/models/realtime/realtime_recipe.dart:355-376`: replace silent defaults for ownerId, createdAt, lastEditedAt, lastEditedBy. (BUT-1071)
- [ ] **A3. Tests** — add fromMap tests covering each required-field absence (throws `FormatException`) + happy path. (BUT-1071)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] New tests pass; existing `realtime_sync_service_test.dart` (25 tests) still pass.
- [ ] Display-name fields remain soft (empty-string default).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1071 with commit hash

---

## Archived iter-65 (commit `578bf72c5`) — 2026-05-25 (Mon)

BUT-1061 P3 fix — HtmlSanitizer.check() surfaces non-JSON-LD `<script>` tags as warning (not critical per re-scope to avoid breaking URL imports). Tightened regex prevents `data-note="application/ld+json"` bypass. +102 / −21. 80/80 tests pass. BUT-1084 filed for knowledge-file append.
