# Sprint Backlog

## Sprint: snap-visibility + ingredient-foundation + observability + test-gaps — 2026-06-10 (iter-136)

### Agent A: per-snap visibility override (BUT-1214) `[Tier B]` — carried from iter-135, spec complete
- [x] **A1. CookSnap.visibility field + capped override** `[Tier B]` — DONE: model enum + dialog RadioGroup + service/repo own-vs-friends query split + STRICT-equality rules (rules-tester found+killed a query-leak in the permissive back-compat clause; 32/32 emulator green) + new composite index + backfill script (MUST run before rules deploy) + 29 unit tests. — `lib/models/cook_snap.dart`: `sameAsRecipe` (default) | `onlyMe`; toggle in BUT-901 disclosure dialog ("Samma som receptet" / "Bara jag"); persist in `firebase_cook_snap_repository`; read-enforce in `cook_snap_service.watchCookSnaps` + gallery query; Firestore rules restrict `onlyMe` reads to author. → In Review + notify. (BUT-1214)
  - Acceptance: a snap posted `onlyMe` on a public/shared recipe is invisible to other viewers, enforced in the read path AND firestore.rules (not just UI) · default stays `sameAsRecipe` — existing snaps and the no-override flow deserialize and behave unchanged · disclosure dialog offers the choice at upload time · firestore-rules-tester suite covers allow(author-read) + deny(other-viewer-read) for `onlyMe`

### Agent B: structured ingredient model foundation (BUT-1216) `[Tier C]` — RISK-GATED (P2, cross-module)
- [x] **B1. RecipeIngredient structured model + parser wire-through** `[Tier C]` — DONE: RecipeIngredient model + RecipeCore field (ser/de both paths, copyWith) + alignment-validated facade getter (stale data never served) + URL-import wire-through + checksum-stability test. Remaining import paths → follow-up ticket. — add `RecipeIngredient` (amount/unit/name/note/raw) + `List<RecipeIngredient>` on Recipe ALONGSIDE existing `List<String> ingredients` (additive, non-breaking); import paths that produce `ParsedIngredient` persist the structured form; read-time fallback parses missing structured data lazily (no backfill CF); `contentHash` stays on raw strings (stable). → In Review + notify with design decisions enumerated. (BUT-1216)
  - Acceptance: Recipe round-trips structured ingredients through Firestore toJson/fromJson · an older doc with only `List<String>` deserializes safely (structured list empty/derived, no throw) · at least one import path persists `ParsedIngredient` data into the structured field · `contentHash` for an existing recipe is byte-identical before/after the change

### Agent C: small Tier A batch
- [x] **C1. ocr_recipe_image.complete timing event** `[Tier A]` — DONE via cloud-functions-specialist: 12 exit paths each emit once, token counts folded in, standalone usage log removed; 15/15 + 21/21 + 7/7 tests, tsc clean. — `functions/src/ocr-recipe-image.ts`: emitTiming-style structured event on every exit path (durationMs, success, reason, retry outcome, modelId, 3 token-count fields); fold the standalone usage log in. (BUT-1222)
  - Acceptance: every exit path of the OCR callable emits exactly one `ocr_recipe_image.complete` event · token counts live in the same event as duration/success · unit tests assert fields on success + one failure path
- [x] **C2. Photo-import draft-restore dialog wiring test** `[Tier A]` — DONE: 5 tests green (accept/decline/back-press/2 guard branches), incl. the load-bearing back-press-keeps-draft contract. — extend `_FakePhotoImportViewModel` in test/widget/a11y/photo_import_announce_test.dart pattern; 4 branches. (BUT-1221)
  - Acceptance: accept → restoreDraft() called, no discard · "Börja om" → discardPersistedDraft() called · dialog dismissed null (back) → NEITHER called · no dialog when hasImage/hasOcrResult
- [ ] **C3. RecipeDetailView first-ever view scaffolding + favorite announce** `[Tier A]` — mock 4+ locator services via prod↔test bridge, seed via RecipeFactory; tap `ValueKey('test-recipe-detail-favorite')` → assert a11yRecipeFavorited/Unfavorited via AnnounceChannel. (BUT-1225)
  - Acceptance: a test pumps the real RecipeDetailView shell (not a fake) without exception · favorite tap announces a11yRecipeFavorited, untap announces a11yRecipeUnfavorited against live l10n

### Housekeeping (done at selection)
- [x] BUT-1219 → Duplicate of BUT-1214 (same scope filed twice on consecutive days)

### Needs you (Tier D — flagged, not worked)
- (none selected this iteration; 15 D-BLOCKED tickets remain in backlog per .claude/state/backlog-scan.json)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos` + `dart format`
- [ ] Run relevant unit/widget tests + functions tests for C1
- [ ] Tier-2 review agents per staged paths (code-reviewer, testing-specialist, firebase-backend-security, firestore-rules-tester)
- [ ] Phase 2.7 outcome verification (fresh-context grader vs acceptance criteria)
- [ ] Commit per ticket, push
- [ ] Linear: Done for Tier A; In Review + PushNotification for BUT-1214 + BUT-1216
- [ ] File follow-up tickets for any deferred scope BEFORE commit

---
## ARCHIVED — iter-135 (BUT-910, BUT-1212, BUT-828, BUT-1032 ph1 shipped; BUT-1214 carried) · iter-134 (BUT-1213 + BUT-1217) · iter-133 (BUT-1216 foundation filed) · iter-132 (BUT-925 groomed) · iter-131 (BUT-906 In Review) · iter-130 (BUT-901 In Review)
