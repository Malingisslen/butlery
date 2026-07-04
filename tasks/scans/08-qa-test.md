# Scan — Role 8: QA / Test Engineer

Date: 2026-06-27 · Reviewer lens: test-coverage gaps, CI gates for safety-critical code, golden-corpus gating, orphaned/ungated tests, coverage-floor drift.
Owned paths: `.claude/agents/**` (knowledge files), `.github/workflows/golden-llm.yml`, `.github/workflows/test.yml`, `codecov.yml`, `dart_test.yaml`, `functions/src/__tests__/**`, `test/golden/llm/**`, `test/unit/repositories/**`.

Recently-modified rules tests reviewed (per prompt): `account-maturity-rules.test.ts`, `age-gate-rules.test.ts`, `recipe-comments-rules.test.ts`, `firestore-rules.test.ts`. All four were touched by BUT-1384 (min-age → 15) / BUT-1386 (age-compliance gate) and BUT-1049 (comment images). The `firestore-rules-tester.knowledge.md` 2026-06-xx entry documents the cross-file fallout correctly and notes account-maturity-rules.test.ts "had NO npm script and was NOT in test:rules:all — so it had silently rotted." That specific file is now wired; the **structural condition that let it rot is still un-guarded** (see N1, N2).

---

## PASS 1 — zero-coverage code · missing CI gates for safety-critical · skipped/disabled tests · floor drift

### Already-tracked (NOT new — do not file)
- Coverage floor at 55% (temporary, BUT-1149) to be restored to 60% = **BUT-397 / "Restore coverage floor to 60.0%"** (dedup line). Floor logic in `test.yml:301`; per-area floors auth 80 / repositories 70 / rate_limiting 80 (`test.yml:338-340`) are sound.
- 4 paid-API LLM golden corpora (recipe_from_url, ocr_recipe, enhance_recipe, generate_menu) deferred = **BUT-784 follow-up** (dedup). `golden-llm.yml:76-81` correctly skips them.
- NER golden corpus permanently skipped under `flutter test` (platform-channel), needs device-runner integration lane = **"NER golden corpus: real-signal lane"** (dedup) + dossier watch-item. `ner_test.dart` + `golden-llm.yml:101-104` confirmed.
- 7 FieldValue-skipped repository tests in `firebase_shared_menu_repository_test.dart` = dossier watch-item (already documented in role-8 dossier).

### NEW (verified, not in dedup / tracker / accepted-deviations / dossier)

**N1 — ~52 Cloud Functions TypeScript unit tests run in NO CI workflow at all.**
`functions/src/__tests__/` holds ~52 non-rules, non-integration `*.test.ts` suites — including safety/cost-critical ones: `validate-limit.test.ts` (clampLimit guard against unbounded costly Firestore reads), `llm-kill-switch.test.ts`, `rate-limiter-global-limits.test.ts` / `rate-limiter-refill.test.ts`, `pii-scrubber.test.ts`, `notification-rate-cap.test.ts`, `ocr-validation.test.ts`, `parse-recipe-response-*.test.ts`. The composite runner `functions/scripts/run-all-tests.js` (BUT-1223) auto-discovers and runs them via `npm test` — but **no workflow and no lefthook hook invokes `npm test` / `run-all-tests.js`**. Verified by grepping all 14 workflows: the only `functions/`-dir test invocations are `firestore-rules.yml` (runs `test:rules:all` only) and `prompt-changelog-gate.yml` (runs `test:prompt-changelog-guard` only). So the entire hand-written Cloud Functions unit layer can break and ship green. This is the same silent-rot mechanism the dossier already flags for rules tests, but at far larger scale and covering cost/safety logic.
_Evidence: `functions/scripts/run-all-tests.js:1-60` (the runner exists, `npm test` → it); `functions/package.json` "test": "node scripts/run-all-tests.js"; grep of `.github/workflows/**` finds no `npm test`/`run-all-tests` invocation; `validate-limit.test.ts:8` imports `clampLimit` from `../shared/validate-limit`._

**N2 — `acquisition-rules.test.ts` is fully ungated: not in `test:rules:all`, not in the CI `paths` filter, and has no per-file npm script.**
`functions/src/__tests__/acquisition-rules.test.ts` is a real Firestore-rules suite (28 assertSucceeds/assertFails) covering `users/{uid}/acquisition/current` in `firestore.rules:1663` (BUT-612 attribution path: owner-read, first-write-wins create, deny update/delete). It is the **only** `*-rules.test.ts` absent from `test:rules:all`, has no `test:rules:acquisition` script, and is not listed in `firestore-rules.yml` paths. It runs only if a developer manually `ts-node`'s it. This is exactly the "silently rotted" state the knowledge file describes for account-maturity — caught only by luck. A `firestore.rules` edit affecting the acquisition path would not exercise this suite in CI.
_Evidence: `functions/src/__tests__/acquisition-rules.test.ts:1-28` (rules contract); `firestore.rules:1663-1672`; `functions/package.json` `test:rules:all` (acquisition absent); `.github/workflows/firestore-rules.yml` paths (acquisition absent)._

---

## PASS 2 — golden-dataset gaps (CRF/NER not CI-gated) · rules-test coverage gaps · test-reviewer trigger gaps · safety-critical zero-coverage

### NEW (verified)

**N3 — Production CRF ingredient-parser golden eval (hard 85% F1 gate) runs in NO CI suite.**
`test/evaluation/crf_evaluator.dart` is a real quality gate, not a print harness: `expect(fieldPct, greaterThanOrEqualTo(85.0))` against a 433-entry human-verified Swedish golden dataset (`crf_evaluator.dart:531-540`), scoring the **production** CRF ingredient-line parser (`CrfIngredientParser.parseLine` — the deterministic core of recipe import). But `test.yml` runs only `test/unit`, `test/widget`, `test/views`, `test/golden`, `test/integration` — `test/evaluation/` is in no suite matrix and no other workflow runs it. CRF accuracy regressions below 85% all-fields-exact would ship green. Distinct from the NER corpus (BUT-1005, dedup) and from the CRF *unit* tests under `test/unit/services/parsing/crf/` (those gate decoder/feature mechanics, not end-to-end parse F1). Cheapest fix: add `test/evaluation` to the `suite-tests` matrix in `test.yml:146` (deterministic, no API cost, no platform channel).
_Evidence: `test/evaluation/crf_evaluator.dart:491-540` (test() with `greaterThanOrEqualTo(85.0)` field gate); `.github/workflows/test.yml:146,395` (suite matrices omit `evaluation`); grep finds no workflow/script running `test/evaluation`._

**N4 — Editing a Cloud Functions unit test triggers ZERO commit-review gates.**
`require-review-before-commit.sh` maps reviewers by path: code-reviewer fires on `\.dart$` only; testing-specialist on `^lib/.*\.dart$` only; firebase-backend-security on `functions/src/` **excluding `__tests__/`** (`hook:109-111`); firestore-rules-tester only on `__tests__/.*-rules\.test\.ts$` (`hook:123`). So a change to any of the ~52 non-rules TS unit tests (N1) matches none of the four triggers — no reviewer is required. Combined with N1 (not run in CI), these tests have **no quality gate of any kind** — neither pre-commit review nor CI execution. A bad edit (weakened assertion, accidental skip) lands unreviewed and unrun.
_Evidence: `.claude/hooks/require-review-before-commit.sh:93-127` (four triggers; none match `functions/src/__tests__/*.test.ts` that isn't `-rules`)._

**N5 — Safety-critical `Phase1AllergenCalculator` + the three GDPR-export sub-managers have ZERO direct tests.**
`lib/services/tagging/phases/tag_phase1_allergen.dart` (`Phase1AllergenCalculator`) computes the per-ingredient tri-valued allergen status (FREE / CONTAINS / UNKNOWN) that the allergen-safe-filtering guarantee rests on. The surrounding pipeline (`tagging_pipeline_runner`, `allergen_config`, `allergen_mismatch`) is tested, but the calculator unit itself has zero test references — a coverage cliff on the single most safety-critical computation in the app. Separately, all three GDPR Article-15 export sub-managers — `activity_export_manager.dart`, `social_export_manager.dart`, `content_export_manager.dart` — that actually shape the exported user-data payload have zero direct tests; they are covered only indirectly through `DataExportService`'s integration test, so a bug that silently drops a record-type from a data-subject export would not be caught. (Lower-priority zero-coverage classes also surfaced — `consent_broadcast.dart` cross-tab consent invalidation, `llm_extraction_fallback.dart` LLM cost path, `permission_cache_invalidator.dart`, `MenuQualityAnalyzer` — fold into the same gap rather than separate findings.)
_Evidence: `lib/services/tagging/phases/tag_phase1_allergen.dart:11` (class exists; zero `Phase1AllergenCalculator` hits across `test/`); zero test files reference `ActivityExportManager` / `SocialExportManager` / `ContentExportManager`._

### Worth-noting (NOT filing — judgment calls)
- 4 unit `*.test.ts` files have no individual npm script and are invisible even to `run-all-tests.js`: `log-parse-event-domain.test.ts`, `rate-limiter-refill.test.ts`, `validate-limit.test.ts`, `winback-context.test.ts`. Folds into N1's fix (a CI job running `npm test` won't pick these up either — they'd need scripts). Worth fixing together with N1, not separately.
- 3 integration tests not in `test:rules:all`: `cleanup-rate-limits`, `cleanup-shared-content-metadata`, `on-user-deleted` — but these have individual `test:integration:*` scripts and the `*.integration.test.ts` set is emulator-bound by design; the CI runner deliberately runs a curated subset. Not a clear gap at current scale.
- `dart_test.yaml` defines a `skip` tag (`skip: true`) and a `corpus-tools` env-gated tag — both intentional and documented. No drift.
- `golden-llm.yml` is intentionally nightly-only (paid APIs), failures emit a tracking issue rather than block merges — a deliberate, documented posture, not a gap.

---

COVERAGE: all 14 workflows for functions/Dart test invocation · `test.yml` suite matrices (per-commit + nightly cross-OS + coverage floor + per-area floors) · `codecov.yml` targets/ignores · `dart_test.yaml` tags/skips · `golden-llm.yml` corpus gating · every `functions/src/__tests__/*.test.ts` cross-referenced against `test:rules:all`, individual npm scripts, and `firestore-rules.yml` paths · `run-all-tests.js` discovery vs CI invocation · `test/evaluation/crf_evaluator.dart` + `test/golden/llm/**` (CRF/NER/categorize/adversarial) gating · `require-review-before-commit.sh` trigger map vs TS-unit-test paths · `firestore-rules-tester.knowledge.md` (recent rotted-file fallout) · zero-coverage sweep of `lib/services/**` (379 files) + `lib/viewmodels/**` (126 files), each claimed gap Grep-verified. NEW: 5 (N1 CF TS unit tests never run in CI · N2 acquisition-rules orphaned from all gating · N3 CRF 85% F1 golden eval not in any CI suite · N4 CF unit-test edits hit zero review gates · N5 allergen calculator + 3 GDPR-export sub-managers have zero direct tests). All cross-checked against `_scan_dedup_titles.txt`, `linear-tracker.json`, `accepted-deviations.md`, and the role-8 dossier watch-items.
