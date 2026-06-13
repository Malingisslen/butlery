# Sprint Backlog

## Sprint: close-out clean follow-ups (round-trip test + recipe-id index + rules allow-test) — 2026-06-13 (iter-145)

5th sprint this session. Genuinely-clean Tier A is the session's own filed follow-ups — knocking out 3 small, self-contained ones. All Tier A → Done.

### Agent A: backend — isolate round-trip test + O(1) recipe-id index
- [x] **A1. ParsedRecipeStructure round-trip losslessness test** `[Tier A]` — add a test constructing a fully-populated `ParsedRecipeStructure` (every field non-default incl. the Duration total-time) and asserting `fromIsolateMap(toIsolateMap(x))` equals it field-for-field. Guards the BUT-862 isolate seam against a future field being added without updating both serializers. (BUT-1246)
  - Acceptance: a test builds a fully-populated ParsedRecipeStructure and asserts round-trip equality field-for-field · the test would fail if a field were added to only one of toIsolateMap/fromIsolateMap · existing parsing tests stay green
- [x] **A2. O(1) getRecipeById index in UnifiedRecipeService** `[Tier A]` — replace the linear `_recipes.where((r)=>r.id==id).firstOrNull` with a `Map<String,Recipe>` index rebuilt whenever `_recipes` changes; getRecipeById does a map lookup. Find ALL `_recipes` mutation sites and keep the index in sync. No behavior change. (BUT-1251)
  - Acceptance: getRecipeById is an O(1) map lookup · the index is rebuilt/kept in sync at every `_recipes` assignment/mutation site (grep-verified) · existing UnifiedRecipeService + recipe tests pass unchanged · `dart analyze` clean

### Agent B: rules — recipes schemaVersion allow-test
- [x] **B1. schemaVersion-at-root allow-case for recipes collection** `[Tier A]` — add an emulator allow-test to `functions/src/__tests__/firestore-rules.test.ts` (or the recipes rules suite) proving an owner can create AND update a `users/{uid}/recipes` doc carrying root-level `schemaVersion: 1`. Guards against a future top-level recipe validator silently rejecting it (recipes is the one collection with a nested hasOnly). (BUT-1249)
  - Acceptance: an emulator test proves owner create+update of a recipes doc with root-level schemaVersion:1 is allowed · the rules suite runs green on the emulator (or documented if emulator unavailable) · no rules-file change needed (test-only)

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos --fatal-warnings` + arch gate
- [x] Run relevant unit tests + rules suite
- [x] Phase 2.7 outcome-grading
- [x] Commit, push
- [x] Linear: BUT-1246/1251/1249 → Done (Tier A)

---
## ARCHIVED — iter-144 (BUT-648/1057 In Review; follow-ups BUT-1248/1249/1250/1251; CI green) · iter-143 (BUT-1245/626 Done, BUT-1244/862 In Review) · iter-142 (BUT-879/881 Done, BUT-1243/925/1154 In Review) · äldre i git-historiken
