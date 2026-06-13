# Sprint Backlog

## Sprint: locale-aware LLM/OCR + two test-gap close-outs — 2026-06-13 (iter-146)

6th sprint this session. All Tier A → Done. Backlog re-scan (107 open: 15 A-CLEAN). Keeping to clean Tier A that auto-closes (the In-Review queue is already at 7 awaiting Malin).

### Agent A: backend — locale-aware LLM prompts + OCR language hints `[Tier A]`
- [ ] **A1. CF prompt locale + OCR provider language-hint threading** `[Tier A]` — the client already sends `locale` (BUT-984). (1) `functions/src/llm/structure-recipe.ts` + OCR equivalent: read `request.locale` and prepend a "Respond in <locale>; preserve culturally-meaningful ingredient/dish names" instruction to the prompt. (2) `lib/services/ocr_extraction_service.dart`: add `_providerLanguage(provider, locale)` mapping AppLocale → provider code (OCR.space ISO-639-2, Vision ISO-639-1 array, Tesseract '+'-joined 639-2); reorder existing multi-lang hints so the user's locale is first (keep the others for robustness). (BUT-1053)
  - Acceptance: CF reads `request.locale` and includes the respond-in-locale + preserve-names instruction in the prompt (testpinned in functions) · OCR hints derive from the active locale with user-locale first, per-provider code convention correct (testpinned) · no hardcoded single-language regression (the multi-lang fallback retained) · `npm test` + Dart analyze clean

### Agent B: testing — close the two remaining test-gap follow-ups `[Tier A]`
- [ ] **B1. ImportResultHandler callsite-order contract test** `[Tier A]` — test `checkForDuplicates` (production DI bridge) proving the content-threshold gate is applied BEFORE the exact-match clamp, and the clamp fires only on URL/title matches. Uses `production.ServiceLocator.initialize(DIContainer())`. (BUT-1247)
  - Acceptance: a test exercises checkForDuplicates and pins gate→clamp ordering · pins clamp-only-on-URL/title-match · existing smart_import tests green
- [ ] **B2. End-to-end link-via-picker flow test** `[Tier A]` — widget test tapping the "Länka relaterat recept" button → picker dialog → select → confirm → assert the link callback fires with the selected id and a chip appears (optimistic add). Needs showDialog scaffolding. (BUT-1250)
  - Acceptance: test taps the link button, selects in the picker, confirms, asserts link fires with the right id · asserts the chip appears after (optimistic update) · related_recipes_test green

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos --fatal-warnings` + arch gate + (functions) npm test
- [ ] Phase 2.7 outcome-grading
- [ ] Commit, push
- [ ] Linear: BUT-1053/1247/1250 → Done (Tier A)

---
## ARCHIVED — iter-145 (BUT-1251/1246/1249 Done; follow-up BUT-1252; CI green) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done, BUT-1244/862 In Review) · iter-142 (BUT-879/881 Done, BUT-1243/925/1154 In Review) · äldre i git-historiken
