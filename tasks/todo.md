# Sprint Backlog

## Sprint: menu→shopping aggregation + ingredient derivation + shopping-view debt — 2026-06-11 (iter-138)

### Agent A: menu→shopping aggregation (BUT-956) `[Tier C]` — RISK-GATED (P2, cross-module) — main loop
- [ ] **A1. Aggregate the week's menu into a shopping list** `[Tier C]` — new aggregation service (sum structured amounts per normalized ingredient name; unit normalization via SmartUnitConverter; name normalization via swedish_character_normalizer; category grouping via ingredient_categorizer) + "Generera inköpslista" action on the weekly menu view. V1 scope decisions (epic trimmed): no pantry subtraction (no pantry feature); idempotency = regeneration updates the week's generated list rather than duplicating. → In Review + notify. (BUT-956)
  - Acceptance: two menu recipes both containing "mjöl" with structured amounts produce ONE summed line (e.g. 2 dl + 1 dl → 3 dl) · raw-only/unparseable lines still land on the list (un-summed, never dropped) · regenerating for the same week does not duplicate items (idempotent) · deterministic, zero LLM calls

### Agent B: structured-ingredient derivation (BUT-1232) `[Tier A]` — feeds A1
- [x] **B1. Derive structuredIngredients where none exist** `[Tier A]` — DONE via flutter-developer: StructuredIngredientDeriver (ren regex-util; LLM-tier avvisad med motivering), text-import + form-save (reuse-by-raw bevarar rikare importdata) + RecipeOperations lockstep med self-healing av stale data; 179 tester gröna. — text-import path derives via the deterministic ingredient parsing strategy; recipe-form save re-derives from final strings; RecipeOperations mutations stop persisting stale structured data. (BUT-1232)
  - Acceptance: a text-imported recipe carries index-aligned structuredIngredients for parseable lines · saving an edited recipe re-derives (alignment holds by construction) · RecipeOperations add/remove/update/reorder no longer leave misaligned structured data persisted · deterministic, zero LLM

### Agent C: shopping-view pattern debt (BUT-1226) `[Tier A]`
- [x] **C1. CollaborativeShoppingView → State-owned-VM pattern + add-item shell test** `[Tier A]` — DONE via flutter-developer: kanoniskt mönster + didUpdateWidget-recreate; test-tand mutation-verifierad; 10/10 gröna. — initState-owned VM + .value provider + _Content widget + didUpdateWidget(listId); full-shell add-item regression test. (BUT-1226)
  - Acceptance: view follows lib/views/CLAUDE.md pattern (no create: in build) · existing 9 view + 3 announce tests stay green · add-item full-shell test pins enterText → 'Lägg till' → addItem hit

### Agent D: scaling wiring pin (BUT-1233) `[Tier A]`
- [x] **D1. Shell-harness pin for detail-content structuredIngredients pass-through** `[Tier A]` — DONE via testing-specialist: exakt-match-assertion (5 dl närvarande, mangle 2 dl frånvarande); 9/9 i filen. — BUT-1225 harness: structured "ca 2,5 dl" entry, tap stepper +, assert "5 dl" renders. (BUT-1233)
  - Acceptance: test fails if the named arg at recipe_detail_content.dart:591 is dropped (string path renders the mangled "2 dl" instead)

### Housekeeping
- [x] BUT-1227 Step-0: PREMISE-GONE — stängd obsolete (AllergenSetupBanner täcker alla importvägar sedan BUT-1198/1200).  Orig:  allergen-setup banner shipped for photo (BUT-1200) + text (BUT-1208) import paths — verify URL-import coverage, then close obsolete or re-scope to the missing path.

### Needs you (Tier D — flagged, not worked)
- (inget nytt; BUT-1229 backfill→deploy väntar fortfarande)

### Post-Sprint Steps
- [ ] dart analyze --fatal-infos + relevant tests
- [ ] Tier-2 review agents + Phase 2.7 grading
- [ ] Commit per ticket, push
- [ ] Linear: Done för Tier A; In Review + PushNotification för BUT-956
- [ ] File follow-ups BEFORE commit

---
## ARCHIVED — iter-137 (BUT-444→In Review, BUT-1228/1230/1231/1223 Done, red main fixed) · iter-136 (BUT-1214/1216→In Review, BUT-1222/1221/1225 Done) · iter-135..130
