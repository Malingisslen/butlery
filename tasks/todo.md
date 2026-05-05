# Sprint Backlog

## Sprint: CI duration telemetry + ML runtime memo + ticket-state hygiene — 2026-05-05 (M)

Theme: 2 implementations + 2 ticket-rescopes. After sprint L's light touch, this sprint ships CI build-time telemetry across the 4 main workflows (BUT-495), a long-overdue research memo on the on-device ML runtime decision (BUT-571), and rescopes two stale tickets where the premise has drifted.

**In Progress carry-overs (NOT in this sprint, NOT shipped):**
- BUT-442 — repo migrations (own focused sprint, mid-flight).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-495 fits** — `test.yml`, `build-validation.yml`, `e2e_tests.yml`, `architecture-validation.yml` all currently lack any duration instrumentation. The ticket's 4 named jobs (`validate`, `build-android`, `build-web`, `tests`) map cleanly to those files. Inline 2-step (start-time + report) pattern beats a composite action — no abstraction needed for 4 sites.
- **BUT-571 fits** — research-only ticket; output is a single memory note. Self-contained.
- **BUT-488 PLAN STALE (premise wrong)** — `pubspec.yaml` is at `0.9.0+1`, NOT `1.0.0+1` as the ticket claims. Manual bumping has happened. The "stuck since inception" framing is stale, so the ticket's urgency is wrong. Keep the auto-bump idea but rescope the framing. Stays in Backlog.
- **BUT-397 PREMISE GONE (for now)** — last 7+ `test.yml` runs on main are all `cancelled` (CI billing-quirk per memory), so no successful baseline exists yet to set tightened floors against. The just-pushed `6af9efc88` is the first non-cancelled run. Defer until ≥5 successful runs accumulate. Stays in Backlog with status comment.

### Agent A: CI build-time duration telemetry

Specialists: none required (no `.dart` change, only YAML).

- [ ] **A1. BUT-495 — Instrument 4 workflows with build-time duration telemetry**
  - **Pattern (applied uniformly):** at the start of each job, record `date +%s` into `JOB_START` via `$GITHUB_ENV`. At the end (`if: always()`), compute duration, emit a `## Build duration` block to `$GITHUB_STEP_SUMMARY`, and emit `::warning::` if duration exceeds the per-job budget.
  - **Per-workflow budgets (ticket spec):**
    - `test.yml` `unit-tests` job → 15 min (current `timeout-minutes: 20` is the hard kill; 15 is the soft budget)
    - `test.yml` `integration-tests` job → 15 min (same kill, same soft)
    - `build-validation.yml` android job → 15 min
    - `build-validation.yml` web job → 10 min
    - `e2e_tests.yml` → 20 min (e2e is naturally slower)
    - `architecture-validation.yml` → 5 min (analyzer + lint only)
  - **Files** (all in `.github/workflows/`):
    1. `test.yml` — instrument both `unit-tests` (matrix, so the warning fires per-OS) and `integration-tests`.
    2. `build-validation.yml` — instrument each platform job.
    3. `e2e_tests.yml` — instrument the main job.
    4. `architecture-validation.yml` — instrument the validate job.
  - **Verification**: each workflow file YAML-validates (no `flutter analyze` step needed; no Dart change). After push, the next CI run shows the duration block in step summary. Out of scope: pushing to Cloud Monitoring (ticket marks that as optional).
  - **Out of scope**: `dep-audit.yml`, `firestore-rules.yml`, `sbom.yml` — these run on schedule, not per-commit, and are not the user-facing latency surface the ticket targets. Future ticket if needed.
  - (BUT-495)

### Agent B: ML runtime decision memo

- [ ] **B1. BUT-571 — Document `flutter_onnxruntime` vs `tflite_flutter` decision**
  - **New memory file** `C:\Users\malla\.claude\projects\C--Butlery-butlery\memory\ml_runtime_decision.md`:
    1. Current state: `flutter_onnxruntime ^1.6.4` powers on-device NER (ingredient parsing) via `lib/services/parsing/ner/onnx_ner_service.dart` and the line classifier (`onnx_line_classifier_service.dart`).
    2. Why it's the chosen runtime today: on-device, no network round-trip, no privacy footprint, models trained in PyTorch convert cleanly to ONNX.
    3. Trigger conditions for re-evaluating TFLite: (a) Android AAB exceeds 150 MB Play Console upload limit, (b) iOS IPA exceeds 200 MB OTA download limit (requires Wi-Fi prompt at install), (c) ≥3 user-reported "app too big to download" complaints in a quarter.
    4. Migration cost if triggered: ONNX → TFLite model conversion (`tf2onnx` reverse pipeline; not always lossless), accuracy parity check, possibly retraining if the conversion drops F1 >2pp on the held-out parsing eval set, plus rewriting `OnnxNerService` and `OnnxLineClassifierService` against `tflite_flutter`'s API surface.
    5. Estimated effort if triggered: 1-2 days for the runtime swap + 1-3 days for accuracy recovery if the naive conversion regresses.
    6. Decision: **stay on ONNX Runtime indefinitely** until one of the three trigger conditions fires. No proactive migration.
  - **Index entry** in `MEMORY.md`:
    `- [ML Runtime Decision (ONNX vs TFLite)](ml_runtime_decision.md) — staying on flutter_onnxruntime; trigger conditions documented.`
  - **Verification**: re-read the memo end-to-end; confirm cited paths still exist (`lib/services/parsing/ner/onnx_ner_service.dart`, `lib/services/parsing/line_classifier/onnx_line_classifier_service.dart`).
  - (BUT-571)

### Linear cleanup (no code, ticket-state only)

- [ ] **C1. BUT-488 — rescope ticket body** — pubspec is at `0.9.0+1`; manual bumping happens. Rewrite description to drop the "stuck since inception" framing. Keep the auto-bump-on-conventional-commit feature as a Low priority improvement, not an urgent fix.
- [ ] **C2. BUT-397 — defer comment** — note that the last 7+ `test.yml` runs on main are `cancelled` (CI billing-quirk per memory). No successful coverage baseline accumulated yet. Re-pick this ticket once ≥5 successful runs since BUT-392 land. Stays in Backlog.

### Post-Sprint Steps
- [ ] No `dart analyze` needed (no Dart changes this sprint).
- [ ] No unit-test runs needed.
- [ ] No Tier-2 specialist gates trigger (no `*.dart` files touched).
- [ ] Commit: `feat(sprint): CI duration telemetry + ML runtime memo + Linear hygiene (BUT-495/571/488/397)`.
- [ ] Push to main; reconcile Linear states (BUT-495/571 → Done; BUT-488/397 stay Backlog with rescoped/deferred bodies).

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-704 — i18n @key ARB descriptions (2-day sweep)
- BUT-520 — VM-migration sweep (rescoped sprint I)
- BUT-431 / BUT-530 — main.dart bootstrap split + extraction (rescoped sprint J)
- BUT-581 — `?? ''` migration (rescoped sprint K)
- BUT-610 — offline-mode hardening (multi-day audit)
- BUT-723 — tablet master-detail layouts (multi-day refactor)
- BUT-702 — undo SnackBar generalization (rescoped sprint L)
- BUT-734 — split FirebaseUserRepository (defer until file ≥700 lines)
- BUT-710 / BUT-706 / BUT-711 — platform-polish cluster (BUT-715 shipped sprint L)
- BUT-492 — cost/budget alerts (Console action; doc-only piece needs the alerts to actually be wired)
- BUT-494 — coverage floor 55→85 (same blocker as BUT-397)
- BUT-488 — pubspec auto-bump CI (rescoped this sprint; Low priority)
- BUT-397 — coverage-floor tightening (deferred this sprint; needs ≥5 successful CI baseline runs)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **CI gets a built-in stopwatch**: today if a slow dependency makes the test pipeline take twice as long, nothing notices except eventually a hard timeout. After this sprint, every CI run prints "this job took N minutes" and pings a yellow warning if it exceeded budget. No code changes, no test changes — just YAML.
- **One memo on the AI engine**: the app uses a thing called ONNX Runtime to do the on-device ingredient-parsing AI. There's been a lingering "should we switch to a smaller alternative called TFLite?" question. This sprint writes it down: stay on ONNX, here are the three things that would change our mind, here's how much swapping would cost. Future-self gets a clear answer.
- **Two ticket-state cleanups**: one ticket said "version stuck at 1.0.0+1 forever" but the version is actually 0.9.0+1 (someone bumped it). Another ticket needed 5 good CI runs to set a tighter coverage threshold, but recent CI has been cancelled by an upstream billing quirk. Both rescoped/deferred so the next picker doesn't waste time on stale assumptions.
- **Risk**: very low. YAML changes are isolated to per-workflow stopwatch lines; can be deleted in seconds if they misbehave. No `.dart` changes; no behavior changes for the running app.

---

## Archived prior sprint (completed in commit 6af9efc88)

Release polish + ops doc + Linear cleanup — 2026-05-05 (L) — shipped BUT-715/493 + reconciled BUT-738/724 + rescoped BUT-702.

## Archived sprint before (completed in commit 25ec5b025)

Tech-debt sweep + dep watch + web polish — 2026-05-05 (K) — shipped BUT-526/567/562/564/578/724/738 + rescoped BUT-581.

## Archived sprint before (completed in commits 245b71478 + a5288014f)

Dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J) — shipped BUT-500/519/524/718 + closed BUT-437 + rescoped BUT-431/530.

## Archived sprint before (completed in commit 1e347b424)

Backend hygiene + auth security micro-hardening — 2026-05-04 (I) — shipped BUT-446/506/465/490 + closed BUT-716 + rescoped BUT-520.

## Archived sprint before (completed in commit 44b6f4792)

GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H) — shipped BUT-466/464/463/462/461/613/471.

## Archived sprint before (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627.
