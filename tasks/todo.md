# Sprint Backlog

## Sprint: dup-threshold-tests + A/B-prompt-buckets + parse-confidence-l10n + parser-isolate-offload — 2026-06-13 (iter-143)

Reusing iter-142 full-backlog scan (98 workable: 36 A / 38 B / 8 C / 16 D). Picked 4 fully-verifiable tickets; skipped BUT-610 (4-6 day epic) and routed BUT-862 through a Step-0 plugin-isolate reality check.

### Agent A: testing — duplicate-detection threshold logic
- [x] **A1. Extract + test ImportResultHandler duplicate-threshold decision** `[Tier A]` — extract the pure score→`DuplicateMergeChoice` decision (thresholds `_contentDuplicateThreshold=0.6`, `_exactMatchMinScore=0.8`) out of the UI/service-coupled `ImportResultHandler.checkForDuplicates` into a testable function; unit-test the boundaries. `lib/views/smart_import/import_result_handler.dart` + `test/`. (BUT-1245)
  - Acceptance: a pure, service-free function encapsulates the score→branch decision (extracted from the dialog/service-coupled method) · unit test proves a score just below 0.8 vs ≥0.8 routes to different branches · unit test proves the 0.6 content-duplicate boundary triggers/!triggers the content-dup path · existing smart_import tests still pass; `dart analyze` clean

### Agent B: backend — A/B prompt-variant buckets (functions)
- [x] **B1. Bucket-based prompt-variant assignment** `[Tier A]` — Step 0: confirm `functions/src/llm/prompts-config.ts` (Remote Config path) + `promptVersion` analytics field exist. Add deterministic `hash(userId)→bucket` assignment in `functions/src/middleware/rate_limiter.ts` (`withRateLimit`); select variant from the existing Remote Config path; emit the bucket in analytics. NO new Firestore `system/prompts/variants` collection. (BUT-626)
  - Acceptance: a deterministic bucket function maps a given userId to a stable bucket (same id → same bucket, testpinned) · variant is sourced from the existing Remote Config path, not a new Firestore collection · the assigned bucket is emitted in analytics alongside the existing `promptVersion` · `npm test` (functions) green

### Agent C: UI/l10n — finish the parse-confidence widget
- [x] **C1. l10n pass + neutral ButleryColors slot** `[Tier B]` — extract ALL hardcoded Swedish (visible strings + the 2 Semantics labels) in `lib/widgets/recipe/parse_confidence_review.dart` to `context.l10n` keys in both `app_sv.arb` + `app_en.arb`; add a `neutral` slot to `ButleryColors` and route the grey pill through it; update the widget test. (BUT-1244)
  - Acceptance: zero hardcoded user-visible/Semantics strings in the widget (all `context.l10n`, keys in both ARB files) · a `neutral` slot exists on ButleryColors (light+dark), pill grey reads it, no direct `AppColors.neutralMedium` in the widget · `flutter gen-l10n` clean · widget test updated (reads token + l10n) and green

### Agent D: perf refactor — isolate-offload the SAFE hot path(s) `[Tier C]` (always risk-gated)
- [x] **D1. compute()/Isolate.run offload, plugin-safe only** `[Tier C]` — Step 0 MANDATORY: determine which of the 3 paths (text parser / CRF inference / OCR post-processor) are pure-Dart (offloadable) vs platform-plugin-bound. CRF uses `flutter_onnxruntime` and OCR uses platform channels — these CANNOT run in a background isolate (MissingPluginException). Wrap ONLY the safe pure-Dart path(s) in `compute()`; document why the plugin-bound ones can't be. (BUT-862)
  - Acceptance: Step-0 classification recorded (which paths are pure vs plugin-bound) · only pure-Dart path(s) wrapped; NO plugin-backed path wrapped (would crash) · the wrapped path produces identical output (unit tests pass unchanged) · parser/CRF/OCR unit tests all green; `dart analyze` clean (jank/profiler claim parked for manual In-Review confirmation)

### Needs you (Tier D / deferred this batch)
- BUT-610 — offline-mode audit+harden is a 4-6 day epic; needs its own focused multi-session effort, not a sprint batch slot.
- BUT-840 / ops cluster — unchanged from iter-142 (Algolia admin key + console/creds/enrollment).

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos` + arch gates (architecture_test + AppColors grep, per iter-142 lesson)
- [x] Run relevant unit tests
- [x] Phase 2.7 outcome-grading per agent group
- [x] Follow-ups → Linear BEFORE commit
- [x] Commit, push
- [x] Linear: Tier A (1245, 626) → Done; Tier B/C (1244, 862) → In Review + notify

---
## ARCHIVED — iter-142 (BUT-879/881 Done; BUT-1243/925/1154 In Review; follow-ups BUT-1244/1245; CI arch-fix 5e04bcabe) · iter-141 (BUT-1238/1005/1237/928/604/954) · iter-140 (BUT-1235/1236/839/877 Done) · äldre i git-historiken
