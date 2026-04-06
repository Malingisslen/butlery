# Sprint Backlog

## Sprint: Smart Import + Menu Intelligence — 2026-04-06

### Agent A: Import Pipeline

- [x] **A1. Extract richer Schema.org data** — RecipeCore new fields, NutritionInfo model, SchemaOrgTier extraction, legacy extractor parity, cuisine→tagging wire-up, input sanitization. (BUT-208)
- [x] **A2. Upgrade duplicate detection to side-by-side merge** — Jaccard similarity in ContentFingerprint, DuplicateMergeSheet, enhanced _checkForDuplicates, merge logic. (BUT-241)
- [x] **A3. Honest import progress with elapsed timer** — onProgress callback in ImportManager, ImportProgressTracker helper, elapsed timer display. (BUT-247)

### Agent B: Menu Intelligence

- [x] **B1. Weighted + seasonal menu generation** — Weighted selection by lastCookedAt, season boost, cuisine diversity, favorites/recent keyword support, suggestion chips. (BUT-204)
- [x] **B2. Dietary-aware menu swap with alternatives count** — useSmartSwap toggle, cuisine-aware scoring, SwapResult with alternatives count, updated callers. (BUT-270)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Manual verification
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Previous Sprints

### Sprint: Recipe Discovery + Cooking Experience (completed 2026-04-06)

- [x] A1 seasonal recipe prompt (BUT-228)
- [x] A2 dormant recipe nudges (BUT-216)
- [x] A3 personalized empty state (BUT-236)
- [x] B1 cooking mode personalization (BUT-227)
- [x] B2 recipe export/print (BUT-220)
- [x] B3 lastCookedAt tag condition (BUT-222)

### Sprint: Foundation + Polish (completed 2026-04-06)

- [x] A1 test coverage (BUT-7)
- [x] A2 dependency update (BUT-9)
- [x] B1 onboarding improvement (BUT-273)
- [x] B2 screen reader accessibility (BUT-233)
- [x] B3 PWA share target + install (BUT-225)
- [x] B4 recipe completeness badge (BUT-240)

### Earlier Sprints (completed 2026-03-20)

- Sprint 2: BUT-21 — Firestore Performance → PR #122 merged
- Sprint 3: BUT-132 — Cloud Functions Performance → PR #123 merged
- Sprint 4: BUT-136 — App Lifecycle → PR #124 merged
