# Sprint Backlog

## Sprint: portion-scaling on structured ingredients + import wiring + test debt — 2026-06-10 (iter-137)

### Agent A: structured-ingredient wire-through (BUT-1228) `[Tier A]` — FIRST (feeds B1)
- [x] **A1. Wire structuredIngredients through remaining import paths** `[Tier A]` — DONE via flutter-developer: toRecipeData + LLM seam (_extractedToRecipe — covers TikTok/Instagram/photo-vision/URL-LLM-fallback/enhance). Step-0 finding: text import has NO ParsedIngredient (regex pipeline) — wiring it = derivation work, stays deferred → follow-up ticket. 67+174 tests green. — text import, photo/OCR import, TikTok pipeline (`tiktok_pipeline.dart:405`), and `ParsedRecipe.toRecipeData()` (`parsed_recipe.dart:172`) persist the structured form index-aligned with the strings. (BUT-1228)
  - Acceptance: each wired path persists structuredIngredients with entry.raw == ingredients[i] · toRecipeData carries the structured form · one test per wired path proves persisted structured data · ingredient strings themselves unchanged (no behavior change to existing consumers)

### Agent B: portion scaling rebuild (BUT-444) `[Tier C]` — RISK-GATED (P2, cross-module)
- [x] **B1. Scale on structured amounts + fix range quantities** `[Tier C]` — DONE: scaleEntries (structured-first, per-entry raw fallback) + range handling in BOTH paths; detail-content + cooking-mode switched, edit view deliberately stays string-path; 242 input-suite + 38 cooking/detail tests green. — rebuild the PortionScaler path (`lib/widgets/common/input/portion_scaler*.dart`, `lib/utils/text/unit_converter.dart`, wiring at `recipe_detail_content.dart:168` + edit view + `cooking_mode_viewmodel.dart:148`) to consume `Recipe.structuredIngredients` when entries are structured, falling back to the existing string path for raw-only entries; add range handling ("2-3 dl" scales both endpoints). Deterministic, no LLM. → In Review + notify. (BUT-444)
  - Acceptance: structured entries scale via the model's `amount` (no string re-parse on that path) · "2-3 dl" at 2x renders "4-6 dl" (ranges scale both endpoints, not silently wrong) · raw-only/legacy entries keep current v1 behavior (regression-tested) · zero LLM calls introduced

### Agent C: small Tier A batch
- [x] **C1. Fix improve-banner overflow at narrow widths** `[Tier A]` — DONE: Flexible wrap; regression test proven red-before-fix, green-after (375px + 320px). — `lib/views/recipe_detail/recipe_detail_shared_widgets.dart:166`: wrap banner text in Flexible; narrow-width regression test on the BUT-1225 scaffolding. (BUT-1230)
  - Acceptance: RecipeDetailView with an incomplete recipe renders without RenderFlex overflow at 375px · regression test pins it
- [x] **C2. Dialog-wiring test: "Bara jag" reaches addSnap(visibility: onlyMe)** `[Tier A]` — DONE via testing-specialist: 4 tests on the BUT-1225 harness (onlyMe wiring, default, cancel, private-recipe-no-dialog invariant), 8/8 file total. — BUT-1225 harness + faked image-picker dialog; select ValueKey('cook-snap-visibility-only-me'), confirm, assert VM/service receives onlyMe. (BUT-1231)
  - Acceptance: "Bara jag" + confirm → addSnap called with onlyMe · default confirm → sameAsRecipe · cancel → no addSnap call
- [x] **C3. Fix functions npm-test chain: 6 red suites + fail-at-end** `[Tier A]` — DONE via cloud-functions-specialist: rate-cap injection seam + cascade-fake extensions (3 stale batching assertions corrected to post-BUT-886 contract); run-all-collect-exit runner; +10 orphan suites registered; 44/44 green, tsc clean, break-experiment verified. — rate-cap app-init seam (lapsed-users, activity-digest) + cascade-test fakes (presence-cascade, notification-gdpr, but753, but466); replace && chain with run-all-collect-exit. (BUT-1223)
  - Acceptance: full `npm test` in functions/ green · a deliberately-broken suite still lets the rest run AND the chain exits non-zero · all 6 named suites individually green

### Needs you (Tier D — flagged, not worked)
- (none this iteration; BUT-1229 backfill→deploy ordering from iter-136 still awaits you)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos` + relevant tests
- [ ] Tier-2 review agents per staged paths + Phase 2.7 outcome grading
- [ ] Commit per ticket, push
- [ ] Linear: Done for Tier A; In Review + PushNotification for BUT-444
- [ ] File follow-up tickets for deferred scope BEFORE commit

---
## ARCHIVED — iter-136 (BUT-1214→In Review, BUT-1216→In Review, BUT-1222/1221/1225 Done, BUT-1219 duped; rules-tester killed a query-leak pre-ship; follow-ups BUT-1228..1231) · iter-135 (BUT-910, BUT-1212, BUT-828, BUT-1032 ph1) · iter-134 (BUT-1213 + BUT-1217) · iter-133..130
