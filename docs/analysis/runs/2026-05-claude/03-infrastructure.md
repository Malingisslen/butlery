# Infrastructure & Operations — Phase 1 Findings

**Analyst:** Claude (Opus 4.7, 1M context)
**Run:** 2026-05-claude — Prompt 03 of 12
**Date:** 2026-05-02
**Phase:** Investigation only — no code changes

---

## Executive Summary

```
INFRASTRUCTURE AND OPERATIONS ANALYSIS — PHASE 1
=================================================
OVERALL SCORE: 73/100   (Acceptable — targeted remediation, no production blockers)
DevOps Maturity Level: 3 of 5 (Defined / repeatable; partially measured)

DIMENSION SCORES:
  Build Pipeline and Automation:    11/15
  Testing Strategy and Coverage:     8/15   (test-infra hang + flutter-test capture aborted)
  Deployment and Release:            8/15   (no automated store upload; everything else solid)
  Backup and Disaster Recovery:     12/15   (PITR + weekly export live; no drill, Auth/Storage gaps)
  Monitoring and Observability:      8/12
  Development Workflow:              7/8
  Incident Response:                 6/10
  CI/CD Security:                    8/10

PRODUCTION READINESS: Blockers MOSTLY RESOLVED — 4 of 7 orchestrator-listed blockers are stale
  Resolved:    Placeholder package name → `se.butlery.app` (live)
               Debug signing only → release keystore wired with hard CI guard
               No ProGuard/minification → R8 + resource shrink enabled
               No Firestore PITR / scheduled backups → both ENABLED on butlery-app-1
  Outstanding: No automated store upload (no Fastlane/store deploy)
               Single Firebase project (no dev/staging/prod separation)
               No restore drill performed (PITR is theoretical until tested)

CRITICAL: 1     HIGH: 6     MEDIUM: 9     LOW: 5
```

**Headline finding:** the operational picture is materially better than the orchestrator describes. Three of the seven "production-readiness blockers" listed in `03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320` are already resolved on disk and another (PITR + scheduled backups) is live with a documented runbook. The remaining real risks are: (a) the unit-test pipeline silently passes despite a known multi-minute hang in `infrastructure_integration_test.dart`, (b) **no restore drill has ever been performed** so the backup posture is unverified, and (c) no automated store upload still blocks any submission flow when the user chooses to start one.

---

## Reality vs orchestrator claims (verified live)

| Orchestrator claim | Source | Reality on disk | Drift |
|---|---|---|---|
| 5 workflows: analyze, test, build-validation, architecture-validation, e2e_tests | `MASTER_ANALYSIS_ORCHESTRATOR.md:53-55` | 6 workflows: architecture-validation, build-validation, dep-audit, e2e_tests, firestore-rules, test (no analyze.yml) | -1, +2 |
| Flutter version pinned to 3.32.4 across all workflows | `03_INFRASTRUCTURE_AND_OPERATIONS.md:53,92` | All 6 workflows pinned to **3.35.1** | +0.3.x — pinning consistent, just newer |
| Placeholder package name `com.example.butlery` in 8+ files | `03_INFRASTRUCTURE_AND_OPERATIONS.md:316` | `applicationId = "se.butlery.app"` at `android/app/build.gradle.kts:34` | RESOLVED |
| Debug signing only, no production keystore | `03_INFRASTRUCTURE_AND_OPERATIONS.md:317` | Release keystore wired (BUT-485): `android/app/build.gradle.kts:44-76`; CI decodes `KEYSTORE_BASE64` and verifies AAB cert is not "Android Debug" (`build-validation.yml:152-213`) | RESOLVED |
| No ProGuard/minification, R8 disabled | `03_INFRASTRUCTURE_AND_OPERATIONS.md:318` | `isMinifyEnabled = true`, `isShrinkResources = true` for release (`android/app/build.gradle.kts:70-75`) | RESOLVED |
| No Firestore PITR / scheduled backups | `03_INFRASTRUCTURE_AND_OPERATIONS.md:319-320` | PITR enabled (7-day window, `versionRetentionPeriod: 604800s`); weekly GCS export Sun 03:00 UTC; backup bucket `gs://butlery-firestore-backups`; 30-day lifecycle (`docs/ops/backups.md:22-31`) | RESOLVED |
| Firebase region europe-west1 (Belgium) | `11_LEGAL_REVIEW.md:54` cross-ref | Cloud Functions region IS europe-west1 (`functions/src/index.ts:20`); but **Firestore region is europe-west3 (Frankfurt)** per `docs/ops/backups.md:30` | Mixed: functions and Firestore live in different EU regions. Adds latency between functions ↔ Firestore. |
| `BackupService` lives at `lib/services/backup_service.dart` | `03_INFRASTRUCTURE_AND_OPERATIONS.md:347` | Confirmed — but it is a **client-side recipe export tool** (`exportToFile`), not a disaster-recovery primitive. The actual DR backup is server-side Cloud Scheduler in GCP. | Reference is misleading. |
| `lib/services/monitoring/app_monitoring_service.dart` exists | `03_INFRASTRUCTURE_AND_OPERATIONS.md:489` | Confirmed (230 LOC) | aligned |

The five "Resolved" rows mean any final synthesis must NOT replay the orchestrator's "Production Readiness Blockers" table verbatim — the bulk of it is stale. This is doc-drift evidence for prompt 12.

---

## Dimension 1 — Build Pipeline and Automation (11/15)

### Workflow inventory (verified)

| Workflow | Triggers | Timeout | Concurrency cancel | Flutter pin | Job count |
|---|---|---|---|---|---|
| `architecture-validation.yml` | push/PR main+develop, manual | 15 min | yes | 3.35.1 | 1 |
| `build-validation.yml` | push/PR main+develop | 15/10/10/60 min per job | yes | 3.35.1 | 4 (validate, security-scan, secret-scan, build matrix) |
| `dep-audit.yml` | PR on lockfile, weekly Mon 05:00 UTC, manual | 15/10 min | — | 3.35.1 | 2 (pub-audit, npm-audit) |
| `e2e_tests.yml` | push/PR main+develop, nightly 02:00 UTC, manual (tier choice) | 20 min | yes | 3.35.1 | 1 (matrix: mock + emulator) |
| `firestore-rules.yml` | PR/push touching rules or rules-tests, manual | 15 min | yes | n/a (Node 22 + Java 21) | 1 |
| `test.yml` | push/PR main+develop | 20 min | yes | 3.35.1 | 2 (unit-tests matrix Linux/macOS/Windows, integration-tests) |

All `paths-ignore` lists exclude `.md`, `docs/**`, `tasks/**`, `.claude/**`, `memory/**` — sensible PR-noise reduction.

### Strengths

- **Concurrency cancel-in-progress** consistently applied — superseded runs auto-cancelled. Saves CI minutes and prevents stale check states.
- **AAB debug-signing guard** (`build-validation.yml:196-213`): unzips `META-INF/*.RSA` and fails if owner contains "Android Debug". This is a real backstop against the historic risk of accidentally shipping a debug-signed bundle.
- **Gradle release-CI guard** (`android/app/build.gradle.kts:59-66`): when `CI=true` and no keystore is present, the build throws rather than silently falling back to debug. Defense-in-depth for the same risk.
- **Build matrix runs Android + iOS + Web in parallel** with `fail-fast: false` (`build-validation.yml:97-109`) — single-platform breakage doesn't poison the other artifacts.
- **Three-OS unit-test matrix** (`test.yml:32-35`): Ubuntu + macOS + Windows. Catches platform-specific path/IO regressions early.
- **`flutter analyze --fatal-infos --fatal-warnings`** on validate job (`build-validation.yml:53`) — strictest mode, blocks PR.
- **`dart format --set-exit-if-changed`** on validate job (`build-validation.yml:48`) — formatting drift cannot land.

### Findings

**H-1 (HIGH). No artifact retention for production AAB / iOS IPA**
- Evidence: `build-validation.yml` builds AAB at `build/app/outputs/bundle/release/app-release.aab` (line 194) and IPA via `flutter build ipa` (line 229), but **no `actions/upload-artifact@v7` step archives either output**. Only `architecture_report.txt`, `architecture_validation_report.json` (architecture workflow), `coverage/lcov_filtered.info` (test workflow), and failure logs are uploaded.
- Operational risk: every successful main-branch build silently discards the signed AAB. A maintainer cannot retrieve "the AAB from commit X" without re-running CI. If a Play Console-rejected upload needs forensic comparison, the artifact is gone.
- Suggested remediation: add a conditional `actions/upload-artifact@v7` step at the end of the Android build matrix branch (and iOS branch) gated on `if: github.ref == 'refs/heads/main'`, retention 90 days, name `app-release-${{ github.sha }}`.

**H-2 (HIGH). Dependabot opens up to 13 PRs/week with no auto-merge configuration**
- Evidence: `.github/dependabot.yml:18,60,98` — three ecosystems with `open-pull-requests-limit: 5/5/5` (orchestrator claimed limits 5/3, also stale).
- Operational risk: solo dev → 13 unattended dependency PRs/week. No auto-merge for patch-level updates. Combined with `if_ci_failed: error` Codecov gate, every PR needs hand-review. Realistic outcome: PRs stale → drift accumulates → next batch is harder to land.
- Suggested remediation: add a GitHub Actions auto-merge workflow keyed on the `dependency,auto` labels for **patch-only** updates after CI green, with a 24h delay window.

**M-1 (MEDIUM). `dep-audit.yml` schedules conflict with `test.yml`/`build-validation.yml`**
- Evidence: `dep-audit.yml:16` runs Mon 05:00 UTC; Dependabot fires Mon 06:00 UTC. The dep-audit job runs against the BEFORE state, not the proposed bumps. Dependabot PRs themselves trigger pub-audit again because `dep-audit.yml:9-13` includes `pubspec.lock` in PR paths, which IS effective — but the scheduled run is largely redundant.
- Operational risk: Low. Belt-and-suspenders posture is fine, just wasted minutes.
- Suggested remediation: keep as-is, or shift schedule to a complementary day (e.g. Thursday) for redundancy spread.

**M-2 (MEDIUM). No `flutter analyze` in `test.yml`**
- Evidence: `test.yml` runs only the test suite. Static analysis lives only in `architecture-validation.yml:54` (non-strict `flutter analyze`) and `build-validation.yml:53` (strict `--fatal-infos --fatal-warnings`).
- Operational risk: if the build-validation workflow is ever skipped for some reason (e.g. a `paths-ignore` change accidentally excludes lib changes), test PRs could land with analyze errors. Probability low; impact medium.
- Suggested remediation: add a `flutter analyze` step to `test.yml`'s validate stage, or extract a shared composite action used by both.

**M-3 (MEDIUM). `flutter analyze` reported a CRITICAL compile error that NO workflow would have caught at the time the run was captured**
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3` shows `error - Undefined name 'ConsentPurpose' - lib\services\notifications\notification_service.dart:648:9`. Live read shows the import IS present and the enum IS exported (per prompt 01 cross-ref). The analyze capture (19:48) preceded a file edit (19:51) — the error is stale relative to disk.
- Pertinence to this prompt: BOTH `architecture-validation.yml:54` and `build-validation.yml:53` would have FAILED on this error if it were on main. So CI **would** catch a regression of this class — that's the good news. The lesson is that the pre-analysis capture is not a CI failure; it's an artifact of the captured-state-vs-edited-state interleave.
- Suggested remediation: nothing for CI; flag pre-analysis capture as stale for prompt 12.

**L-1 (LOW). No build-cache hit-rate metrics**
- Evidence: `subosito/flutter-action@v2` is invoked with `cache: true` everywhere. Gradle cache is also configured (`build-validation.yml:178-186`). But there's no instrumentation showing how often caches actually hit.
- Operational risk: Low. The defaults are sensible.
- Suggested remediation: optional — add a DORA-metrics action (e.g. `lukasbestle/dora-metrics-action`) once deployment automation is added.

---

## Dimension 2 — Testing Strategy and Coverage (8/15)

### Strengths

- **Filtered LCOV pipeline** (`test.yml:78-148`): produces a CI-summary table, enforces a 55% overall floor, and per-area floors of auth ≥80%, repositories ≥70%, rate_limiting ≥80%. Codecov is the primary gate (60% target, 2% threshold per `codecov.yml:13-15`); the local floor is the safety net for token outages. This is genuinely good testing infrastructure.
- **Real-time regression guard** (`test.yml:53-55` → `scripts/check_test_real_time.sh`): blocks `DateTime.now()` and long `Future.delayed` re-introductions in tests — guards the BUT-387 Phase 5 rescue against decay.
- **Three-tier E2E** (`e2e_tests.yml:48-52`): `mock` + `emulator` matrix, with nightly schedule and a `workflow_dispatch` tier selector. Staging tier intentionally absent (no staging Firebase project — see SPOF section).
- **Firestore-rules CI gate** (`firestore-rules.yml`): emulator-backed, blocks merges that touch `firestore.rules` or any of the `*-rules.test.ts` files. This is a Tier-2 specialist's job-shipped: prompt 02 cross-references this.

### Findings

**C-1 (CRITICAL). Test pipeline silently passes through a known multi-minute hang in `infrastructure_integration_test.dart`**
- Evidence:
  - `test/views/helpers/infrastructure_integration_test.dart` (124 LOC, 4 widget tests).
  - Prompt 01 root-caused the hang: `TestServiceLocator.reset()` calls `_getIt.reset(dispose: true)` on ~50 mocks with un-cancelled stream subscriptions; ~10 min/test.
  - Local capture: `flutter test --coverage` aborted at ~45 min with 10 122 passes / 200 failures / 89 skips.
  - CI configuration: `test.yml:36` sets `timeout-minutes: 20`. `test.yml:70` runs `flutter test test/unit test/widget test/views test/golden --coverage --reporter=expanded`. The `test/views/` glob will pick up `infrastructure_integration_test.dart`.
- Operational risk: the unit-tests job has a 20-minute timeout; the captured local run hit ~45 min. **CI will hit the 20-minute job timeout and fail with no useful output, OR — if the hang is non-deterministic — silently pass on lucky runs.** Either way, the coverage number CI publishes does not actually represent the full suite executing.
- Cross-check: `test.yml:67-70` does NOT use `--timeout` per-test, so a hung test consumes the entire 20-minute budget. The CI run almost certainly times out the unit-tests job whenever this test loads — which means **the green-checkmark culture on main is built on a job that frequently times out and is treated as flaky-retry territory**, OR the hang doesn't reproduce on Linux runners (Windows-specific stream-subscription quirk).
- Suggested remediation:
  1. Short term: add `--timeout 60s` to the test command and exclude `test/views/helpers/infrastructure_integration_test.dart` from CI until the underlying TestServiceLocator dispose-leak is fixed (prompt 01's recommendation).
  2. Medium term: fix the dispose-leak in `TestServiceLocator.reset()` — cancel stream subscriptions before `_getIt.reset(dispose: true)`.
  3. Add a job-level timeout assertion: if the unit-tests step exceeds (say) 12 min, fail the step. Currently the only timeout is the 20-min job ceiling.
- Severity: **CRITICAL** because it undermines the coverage signal everyone is gating on.

**H-3 (HIGH). Coverage targets in orchestrator (ViewModels 100%, Services 96%, Firebase Repos 88%) are NOT enforced anywhere**
- Evidence: orchestrator (`03_INFRASTRUCTURE_AND_OPERATIONS.md:179-186`) and `MASTER_ANALYSIS_ORCHESTRATOR.md:61` claim per-layer coverage. CI enforces only: overall 55% floor, auth ≥80%, repositories ≥70%, rate_limiting ≥80% (`test.yml:139-178`). There is no ViewModel area-floor and no Services area-floor.
- Operational risk: layer coverage can drift downward without any signal. The "100% / 96% / 88%" numbers are aspirational documentation, not measured guarantees. Prompt 12 owns the doc-drift assessment but the operational consequence — coverage erosion is invisible — sits with this prompt.
- Suggested remediation: add area floors for ViewModels (`*/viewmodels/*` ≥85%) and Services (`*/services/*` ≥80%) once the test-infra hang is resolved (because the current numbers are unreliable until the suite actually completes).

**H-4 (HIGH). Integration tests run via `if [ -n $(find...) ]` — silently no-op if the path moves**
- Evidence: `test.yml:273-279` — the integration-tests job tests for the existence of Dart files under `test/integration` and skips otherwise. If anyone refactors the test layout, the job goes green with zero tests run and no warning surfaces.
- Operational risk: silent loss of integration-test coverage. The 13-test integration suite cited in the orchestrator is opaque to the gate.
- Suggested remediation: replace the conditional with a hard `flutter test test/integration --reporter=expanded` and a separate `if: hashFiles('test/integration/**.dart') != ''` guard at job level — if missing, log an error rather than skipping silently.

**H-5 (HIGH). E2E-emulator tier waits with `sleep 10` instead of probing emulator readiness**
- Evidence: `test.yml:265-269` (integration-tests job) — `firebase emulators:start --only auth,firestore,storage &` followed by `sleep 10`, then `curl -f http://localhost:8080 || echo "...may not be fully ready"` (note: failure prints a warning but does NOT exit).
- Operational risk: flaky integration-tests on slow runners. The `firestore-rules.yml:74-85` job does this CORRECTLY with a 60-iteration retry loop. The pattern is known; it's just not reused in `test.yml`.
- Suggested remediation: copy the wait-for-port loop from `firestore-rules.yml` into the integration-tests job. (And follow the same pattern in `e2e_tests.yml` if `scripts/run_e2e_tests.sh` doesn't already.)

**M-4 (MEDIUM). No flaky-test detection or quarantine mechanism**
- Evidence: no use of `--retry`, no flaky-test reporter, no quarantine list in any of the 6 workflows.
- Operational risk: when a real-time-guard regression slips in, the only signal is "tests failed locally too". On a 10K+ test suite, transient flakes are statistically guaranteed.
- Suggested remediation: pass `--reporter=expanded --retry=1` (or use `flutter_test_runner` if package allows). Combined with junit XML output and a flaky-detector action.

**M-5 (MEDIUM). Test pyramid distribution unknown — no test-count audit**
- Evidence: orchestrator names targets (70/20/10) but there's no count of how `test/unit`, `test/widget`, `test/views`, `test/integration`, `test/golden`, `test/e2e` files distribute. The `flutter-test.txt` log shows architecture, e2e bootstrap, golden datasets running — looks heavy on integration/E2E early in the run.
- Operational risk: feedback loop slowness. If the pyramid is upside-down (more E2E than unit), every PR feedback cycle is slow.
- Suggested remediation: instrument once — count `*_test.dart` files under each top-level test directory, fold into `architecture_validation_report.json` already produced by the architecture workflow.

---

## Dimension 3 — Deployment and Release (8/15)

### Strengths

- **Real release signing wired end-to-end**: GitHub Secrets → base64 decode → `key.properties` → Gradle → AAB → cert-owner verification. (`build-validation.yml:152-213`, `android/app/build.gradle.kts:44-76`).
- **`.env`-from-secrets pattern** for Firebase config (`build-validation.yml:121-144`): no secrets in repo, dart-define-from-file at build time.
- **Obfuscation + split-debug-info** on Android release (`build-validation.yml:194`): `--obfuscate --split-debug-info=build/debug-info`. Correct for Play Console crash symbolication.
- **iOS no-codesign build** (`build-validation.yml:225-229`): produces a buildable IPA via `--no-codesign --export-options-plist`. Allows Apple-certified signing to be added without breaking the existing flow.
- **`firebase.json` is comprehensive**: Firestore + Storage + Database (Realtime) + Hosting (with strict CSP + HSTS + clickjacking + permissions policy) + Functions (Node 22) + emulators. Hosting headers (`firebase.json:32-37`) are defense-grade — frame-ancestors none, object-src none, MIME sniffing off.

### Findings

**C-2 (CRITICAL — owns blocker). No automated store deployment for any platform**
- Evidence: no `fastlane/Fastfile`, no `play_store_publisher` workflow, no `appstoreconnect-actions` use, no `actions/upload-artifact` even archives the AAB (see H-1).
- Operational risk: every release is a manual ritual. Risks: (a) the human forgets to bump build number, (b) the human uploads the wrong file, (c) the human forgets to activate the obfuscation mapping upload to Play Console for crash deobfuscation.
- Note: the user has explicitly deferred app-store submission per `MEMORY.md` ("No app-store submission yet"). So this is a known gap, not an oversight. Severity is CRITICAL **once submission begins**, MEDIUM until then.
- Suggested remediation: when the user is ready to submit, add a Fastlane lane (`internal` track to start) gated on a manual `workflow_dispatch` with environment protection rules. Out of scope until then.

**H-6 (HIGH). Single Firebase project — no dev/staging/prod separation**
- Evidence:
  - `firebase.json:71-87` — single `projectId: "butlery-app-1"` for all platforms.
  - No `.firebaserc` (verified absent — `ls .firebaserc → no such file`). When missing, `firebase deploy` defaults to whatever project the CLI was last `firebase use`'d on.
  - `e2e_tests.yml` comment line 51: "Note: Staging tests require proper staging Firebase project setup".
- Operational risk: any test that mutates state hits production. Any rules deployment goes straight to prod. The PITR rollback option mitigates this but doesn't eliminate it (see C-3).
- Suggested remediation: create `.firebaserc` with `default: butlery-app-1` and `staging: butlery-staging-XXX`. Provision a stub staging project (no users) for rules-and-functions smoke tests before prod rollout. Effort: medium (~1 day); fundamentally improves blast-radius posture.

**H-7 (HIGH). Firestore rules deployment is manual — no CI promotion**
- Evidence: `firestore-rules.yml` runs the **rules unit tests** (good) but does NOT call `firebase deploy --only firestore:rules`. There is no workflow that deploys rules.
- Operational risk: someone tested rules in CI, merged to main, then rules don't actually update on the live project until a human runs `firebase deploy`. Two consequences: (a) tested rules aren't necessarily live rules, (b) emergency rule rollback requires CLI access + correct project.
- Suggested remediation: add a `firestore-rules-deploy.yml` workflow on push to main that deploys after the rules-test suite passes. Use a `FIREBASE_TOKEN` GitHub Secret (or workload identity federation, preferred). Effort: small (~2h).

**M-6 (MEDIUM). No version-bump automation; `pubspec.yaml` version managed by hand**
- Evidence: no `actions/create-tag` workflow, no `release-please`, no `semantic-release`. `commit-msg` lefthook validates Conventional Commits (`scripts/validate-commit-msg.js`) — the metadata exists but isn't consumed.
- Operational risk: medium. Build number drift between platforms is the realistic failure mode. Conventional Commits already in place make `release-please` a low-effort add.
- Suggested remediation: add `release-please-action@v4` keyed on `main`, configured for `flutter` package type. Output: auto-PR that bumps `pubspec.yaml` version + generates CHANGELOG. Solo-dev-friendly: zero merge ceremony.

**M-7 (MEDIUM). No staged-rollout config for Play Store submissions**
- Evidence: there's no Play Console rollout policy in repo (would live in a Fastlane track config). Tied to C-2.
- Suggested remediation: when submission begins, configure phased rollout (5% → 20% → 50% → 100%) with crash-rate halt criteria.

**L-2 (LOW). Hosting only configured; no actual hosting deployment workflow**
- Evidence: `firebase.json:21-46` defines hosting (build/web, headers, rewrites). No `firebase deploy --only hosting` workflow.
- Operational risk: low — web deployment is presumably manual when needed. The headers config is genuinely good and would deploy correctly the first time.
- Suggested remediation: add a `web-deploy.yml` if web is intended to be a primary platform (currently appears not).

---

## Dimension 4 — Backup and Disaster Recovery (12/15)

### Strengths (already in place)

- **PITR enabled** (verified via `docs/ops/backups.md:25` evidence: `versionRetentionPeriod: 604800s`). 7-day window, minute-granularity recovery for accidental deletes.
- **Weekly GCS export** scheduled Sundays 03:00 UTC via Cloud Scheduler, region europe-west3 (matches Firestore region — keeps exports in-region for GDPR compliance per backup runbook line 64-69).
- **30-day retention lifecycle** on `gs://butlery-firestore-backups` — auto-delete prevents storage cost bloat.
- **Runbook exists** at `docs/ops/backups.md` (verified live, status "ACTIVE" as of 2026-04-24).

### Findings

**C-3 (CRITICAL). Restore drill never performed — backup posture is unverified**
- Evidence: `docs/ops/backups.md:32` literally says "Restore drill — NEVER PERFORMED — schedule one after first successful export". The runbook is dated 2026-04-24; no follow-up entry has been added since.
- Operational risk: untested backup = no backup. The first time we discover the export bucket was misconfigured, the IAM is wrong, or the GCS object format isn't compatible with `gcloud firestore import` will be during a real outage.
- Suggested remediation: schedule a quarterly drill — restore the most recent weekly export to a sibling database (e.g. `butlery-app-1` named database `dr-test`), spot-check 5 collection counts, then delete. Document the procedure inline in `docs/ops/backups.md`. Solo-dev cost: 2-3 hours per quarter, reduces blind-spot risk by 90%.
- Severity: **CRITICAL** because it converts the documented "RPO = 7 days, RTO < 4h" into "RPO/RTO = unknown".

**H-8 (HIGH). No Firebase Auth user export**
- Evidence: `docs/ops/backups.md` covers Firestore only. No documented backup for Firebase Auth user records (UIDs, emails, custom claims, Google linkages).
- Operational risk: if Firebase Auth is misconfigured or the project is locked out, recreating user identities requires per-user re-authentication. Auth records are the linchpin: every Firestore document keys off a UID, so losing UIDs effectively orphans the entire data graph.
- Suggested remediation: add a monthly `firebase auth:export users.json` job (Cloud Scheduler + GCS) with the same 30-day lifecycle. Or document explicitly that Firebase Auth recovery relies on Google's own backup posture (true, but worth saying).

**H-9 (HIGH). No Firebase Storage backup**
- Evidence: `docs/ops/backups.md` does not mention Storage. `firebase.json:15-17` defines Storage rules but no backup configuration.
- Operational risk: recipe images, OCR scans, profile avatars — all uploaded to Storage. PITR doesn't cover Storage. A bad rules deployment that grants delete-all to authenticated users would lose all media permanently.
- Suggested remediation: enable GCS Object Versioning on the Firebase Storage bucket — small cost, allows time-travel for the bucket. Effort: low (single `gcloud storage buckets update --versioning` call).

**M-8 (MEDIUM). Functions-region / Firestore-region mismatch**
- Evidence:
  - Cloud Functions: `functions/src/index.ts:20` — `setGlobalOptions({ region: "europe-west1" })` (Belgium).
  - Firestore: `docs/ops/backups.md:30` — europe-west3 (Frankfurt).
  - Cross-region intra-EU latency: ~10-20ms RTT additional vs same-region.
- Operational risk: every Cloud Function that reads/writes Firestore pays a cross-region tax. For OCR/parsing functions that already invoke external LLMs, the marginal latency is small. For cleanup jobs, it's invisible. Cumulative cost: small but not zero.
- Suggested remediation: NOT to chase this immediately. The migration cost (recreating all functions in europe-west3, redirecting client code, draining old functions) outweighs the latency gain. Document the choice explicitly in `docs/ops/backups.md` so future audits don't re-flag it. Note: this also affects prompt 04 (performance).

**M-9 (MEDIUM). Single Firebase admin account = single point of compromise**
- Evidence: orchestrator notes this as "Investigate" at line 388 — no IAM audit available. No evidence of break-glass account procedure.
- Operational risk: if the primary Google account is compromised or locked, the project is unrecoverable without Google account-recovery support.
- Suggested remediation: add at least one secondary owner via Google Cloud IAM. Document the addition in `docs/ops/`. Out-of-band MFA on both. Out of scope for this audit (requires ownership-level GCP access).

**L-3 (LOW). RTO/RPO targets in orchestrator (table at line 372-378) have no measurement evidence**
- Evidence: orchestrator lists targets per function (User auth 4h/0, Recipes 4h/1h, etc.) but no measurement infrastructure exists to validate them. Crashlytics tracks crash-free, not RTO.
- Operational risk: RTO/RPO claims are aspirational. Without a drill (see C-3), they're untested.
- Suggested remediation: tied to C-3. The drill produces measured RTO numbers.

---

## Dimension 5 — Monitoring and Observability (8/12)

### Strengths

- **Crashlytics wired with both error handlers**: `lib/main.dart:158,228` (`FlutterError.onError`) + `lib/main.dart:236,257,329` (`recordError` for async/web errors), inside `runZonedGuarded` (line 130). Triple-coverage pattern.
- **Performance monitoring services exist**: `lib/services/performance/performance_monitoring_service.dart` (489 LOC) + `lib/services/performance/firebase_performance_service.dart`.
- **Web error reporter**: `lib/services/monitoring/web_error_reporter.dart` — separate channel for web-specific failures.
- **CSP + HSTS + Permissions-Policy** on hosting (`firebase.json:32-37`) — prevents many client-side observability bypasses.

### Findings

**H-10 (HIGH). No SLO definitions document found**
- Evidence: orchestrator references `docs/operations/SLO_DEFINITIONS.md` (line 481) and `docs/operations/FIREBASE_ALERTING_GUIDE.md` (line 482). **These paths do not exist** — `ls docs/operations/ → No such file or directory`. The actual ops dir is `docs/ops/`. SLO/alerting docs are not present there either.
- Operational risk: Crashlytics + Performance Monitoring may be configured at the SDK level, but there is no documented threshold for "what counts as broken". When an alert fires, no one knows whether 99.5% crash-free is acceptable or P0.
- Suggested remediation: write a one-page `docs/ops/SLOs.md`. Rough targets: crash-free users 99.5% (P0 below), p95 startup < 5s (P2), p95 screen load < 2s (P2). Effort: 1h. Doc-drift is owned by prompt 12 but the missing-data is an ops concern.

**M-10 (MEDIUM). No documented alert routing**
- Evidence: GitHub workflow notifications use repo defaults (email-on-failure to commit author). No Crashlytics → Slack/email integration documented. No PagerDuty.
- Operational risk: P0 events depend on the maintainer happening to check the Crashlytics dashboard. Solo-dev mitigation: phone email notification on Crashlytics issues. But this isn't documented anywhere.
- Suggested remediation: document the existing Crashlytics email-alert config in `docs/ops/`. If thresholds need tightening, do so via Crashlytics alert rules in the Firebase Console.

**M-11 (MEDIUM). No Firebase budget alerts in repo**
- Evidence: `firebase.json` doesn't configure budget alerts (correctly — they live in GCP Billing). No reference to budget thresholds in `docs/ops/`.
- Operational risk: a runaway Cloud Function or Firestore read storm could rack up significant cost before being noticed. Solo-dev finance impact.
- Suggested remediation: configure GCP billing alerts at $10/$50/$100 monthly thresholds, document in `docs/ops/`. Out-of-band action.

**L-4 (LOW). PII-in-logs check not automated**
- Evidence: lefthook (`lefthook.yml:19-21`) scans for known credential patterns (AWS, GCP service-account, GitHub tokens, npm, OpenAI sk-) but not for PII patterns (emails, user IDs in print/log statements).
- Operational risk: low — prompt 01 verified zero `print()` in production code. Logger usage may still leak PII.
- Suggested remediation: extend the secret-scan or add a separate logger-misuse linter. Low priority.

---

## Dimension 6 — Development Workflow (7/8)

### Strengths

- **`scripts/setup.sh`** (94 LOC) and **`scripts/setup.ps1`** for cross-platform onboarding.
- **Conventional Commits enforced** via `lefthook.yml:34` → `scripts/validate-commit-msg.js`. Format = `type(scope): description`.
- **`dart format` + `dart analyze --fatal-infos`** on pre-commit (`lefthook.yml:8-26`) — formatting and analyze run before commit, with `git add {staged_files}` re-staging only the originally-staged files (not `git add -A` — explicitly noted in the comment as a parallel-session safety measure).
- **Secret-scan on pre-commit** (`lefthook.yml:19-21`): blocks AWS keys, GCP service-account JSON, GitHub PATs, OpenAI keys before they leave local machine. Excludes `firebase_options.dart` (correct — these are public client-side keys).
- **Lefthook is documented** at the top of `lefthook.yml` (install + setup + manual run instructions).

### Findings

**M-12 (MEDIUM). No documented pre-commit failure recovery for the lefthook formatting reformat**
- Evidence: `.claude/rules/git-workflow.md` mentions "if it fails due to formatting, re-stage all changed files and commit again" — informal. No equivalent in `README.md` for human contributors.
- Operational risk: low — this is a solo dev project. But if a contributor ever joins, the reformat-and-restage flow is non-obvious.
- Suggested remediation: nothing now. Out of scope for solo workflow.

---

## Dimension 7 — Incident Response (6/10)

### Strengths

- **Incident runbooks present in `docs/ops/`**:
  - `age-rating-runbook.md` (Play age rating + SafetyNet-style).
  - `freerasp-runbook.md` (anti-tampering hits).
  - `gcp-alerting-runbook.md` (this is the alerting doc the orchestrator points to but at a different path — see H-10).
  - `llm-kill-switch-runbook.md` (cost / abuse circuit breaker).
  - `moderation-runbook.md` (UGC reports).
  - `play-data-safety-runbook.md` (Play Console disclosure).
  - `presence-ttl-runbook.md` (RTDB cleanup).
  - `storage-lifecycle-runbook.md` (orphan-image GC).
- **`gcp-alerting-runbook.md` exists** even though orchestrator looked for it at `docs/operations/FIREBASE_ALERTING_GUIDE.md`. So orchestrator's claim is half-stale.

### Findings

**H-11 (HIGH). No incident-response playbook for app crash spike or data corruption**
- Evidence: the runbook list above covers domain-specific failure modes but not generic "crash spike" or "data corruption discovery". The PITR runbook (`backups.md`) covers the mechanism for data restore but not the **decision tree** (when to invoke, how to triage, how to communicate to users).
- Operational risk: when a P0 fires, the maintainer must improvise the response. For a single dev that's recoverable; for any future on-call rotation it isn't.
- Suggested remediation: add `docs/ops/crash-spike-runbook.md` (1 page: detect via Crashlytics, assess via crash-free %, decide kill-switch vs hotfix vs rollback). Effort: 1h.

**M-13 (MEDIUM). No post-incident retrospective process documented**
- Evidence: no `docs/ops/postmortem-template.md` or similar. Ad-hoc remediation lives in commit messages and Linear issues.
- Operational risk: low for solo dev. Knowledge-loss risk on team scaling.
- Suggested remediation: defer until team grows.

---

## Dimension 8 — CI/CD Security (8/10)

### Strengths

- **Trivy vulnerability scanner** runs on every PR (`build-validation.yml:67-75`) — scans full filesystem, severity HIGH/CRITICAL, `exit-code: 1` to fail PR.
- **TruffleHog** runs on every PR with `fetch-depth: 0` and `--only-verified` (`build-validation.yml:78-90`) — full git-history secret scan, only flags real (not example) secrets.
- **OSV Scanner** for pubspec.lock (`dep-audit.yml:50-73`), with SARIF upload to GitHub Security tab and explicit re-fail gate (line 69-73).
- **`npm audit --audit-level=high`** for functions (`dep-audit.yml:96`) and **`npm audit --audit-level=critical`** in firebase.json predeploy (line 7).
- **Conventional Commits + commit-msg validation** via lefthook commit-msg hook.
- **Secrets injected via GitHub Secrets, not committed**: 17 distinct secrets used in `build-validation.yml:121-144` (Firebase keys, app IDs, OCR API keys, keystore credentials).
- **No `.firebaserc` committed** is actually a feature here — prevents accidental project-scoped deploys.

### Findings

**H-12 (HIGH). Multiple GitHub Actions versions are inconsistent across workflows**
- Evidence:
  - `actions/checkout`: v6 in `architecture-validation.yml`, `build-validation.yml`, `e2e_tests.yml`, `test.yml`; v4 in `dep-audit.yml`, `firestore-rules.yml`.
  - `actions/setup-node`: v4 used uniformly.
  - `actions/setup-java`: v4 used uniformly.
  - `actions/upload-artifact`: v7 used uniformly.
  - `actions/cache`: v5 used uniformly.
  - `subosito/flutter-action`: v2 used uniformly.
- Operational risk: low (functional differences between v4/v6 of checkout are minor) but confusing to audit. Dependabot will eventually unify them on the next bump cycle.
- Suggested remediation: align all workflows on `actions/checkout@v6`. Effort: trivial.

**M-14 (MEDIUM). No GITHUB_TOKEN permission scoping at workflow level**
- Evidence:
  - `architecture-validation.yml:33-36` correctly scopes permissions (`contents: read, pull-requests: write, issues: write`).
  - `dep-audit.yml:19-22` correctly scopes permissions (`contents: read, security-events: write`).
  - `build-validation.yml`, `test.yml`, `e2e_tests.yml`, `firestore-rules.yml` — **no `permissions:` block**. Defaults to whatever the repo default is (typically `write-all` if not changed in repo settings).
- Operational risk: blast radius of a malicious workflow injection (e.g. via a malicious Dependabot-targeted dependency) is wider than necessary. Defense in depth.
- Suggested remediation: add `permissions: contents: read` (and any specific writes needed) to each workflow's top level. Effort: trivial.

**M-15 (MEDIUM). No SLSA provenance / supply-chain attestation**
- Evidence: no `slsa-github-generator` action in any workflow. Build artifacts (when they exist) carry no signed provenance.
- Operational risk: low for current state. Becomes important if/when distributing to app stores or third parties.
- Suggested remediation: defer. Add when store deployment is added.

**L-5 (LOW). Pin GitHub Actions by SHA, not by tag**
- Evidence: all third-party actions are pinned by major tag (e.g. `subosito/flutter-action@v2`). Tag mutability means a compromised tag could land malicious code on next workflow run.
- Operational risk: low (the named publishers are reputable) but non-zero given the broad reach of `setGlobalOptions`-style supply-chain attacks.
- Suggested remediation: pin to commit SHAs for highest-privilege actions (the secret-scan and code-signing ones). Dependabot can still bump SHA-pinned actions. Effort: small.

---

## Required diagrams

### CI/CD pipeline flow

```
                         ┌──────────────────────────────────────┐
                         │ git commit (lefthook pre-commit)     │
                         │  ├─ dart format + restage            │
                         │  ├─ secret-scan (regex)              │
                         │  ├─ dart analyze --fatal-infos       │
                         │  └─ commit-msg conventional check    │
                         └─────────────────┬────────────────────┘
                                           │
                                       git push
                                           │
              ┌────────────────────────────┼────────────────────────────────┐
              ▼                            ▼                                ▼
   architecture-validation.yml      build-validation.yml (4 jobs)    test.yml (2 jobs)
   ├─ flutter pub get               ├─ validate                       ├─ unit-tests (3-OS matrix)
   ├─ flutter analyze               │   ├─ dart format check          │   ├─ real-time guard
   ├─ AppColors keep-set            │   ├─ flutter analyze --fatal    │   ├─ flutter test (unit/widget/views/golden)
   ├─ test/architecture/...         │   └─ test/architecture/...      │   ├─ filtered lcov + per-area floors
   ├─ tools/validate_architecture   ├─ security-scan (Trivy)          │   └─ Codecov upload (60% target)
   └─ PR comment with scores        ├─ secret-scan (TruffleHog)       │
                                    └─ build matrix (Android/iOS/Web)  ├─ integration-tests (firebase emulator)
                                        ├─ .env from secrets          │   └─ flutter test test/integration
                                        ├─ keystore decode + verify   │
                                        ├─ AAB --obfuscate --split    └─ artifact: coverage-lcov (14d)
                                        ├─ AAB cert-owner != "Debug"
                                        └─ NO ARTIFACT UPLOAD ◄──── H-1
              ┌─────────────────┐      ┌───────────────────┐        ┌───────────────────┐
              │ e2e_tests.yml   │      │ dep-audit.yml     │        │ firestore-rules.yml│
              │ (matrix mock+   │      │ (PR + Mon 05 UTC) │        │ (PR + push main +  │
              │  emulator)      │      │  ├─ pub OSV       │        │  manual)           │
              │ scripts/        │      │  └─ npm audit     │        │  ├─ firestore emu  │
              │ run_e2e_tests.sh│      │ + SARIF upload    │        │  └─ npm test:rules │
              └─────────────────┘      └───────────────────┘        └───────────────────┘

  ✗ MISSING: store-deploy.yml, rules-deploy.yml, hosting-deploy.yml, version-bump.yml
```

### Disaster recovery posture

```
         BUTLERY-APP-1 (single Firebase project, no .firebaserc)

  Firestore (europe-west3)             Cloud Functions (europe-west1)
  ├─ PITR ✓ (7-day window)             └─ no backup needed (code in git)
  ├─ Weekly export ✓ (Sun 03:00 UTC)
  │  → gs://butlery-firestore-backups
  │     (europe-west3, 30-day lifecycle)
  └─ Restore drill ✗ ◄──── C-3

  Firebase Auth                        Firebase Storage
  └─ no documented backup ◄── H-8      └─ no Object Versioning ◄── H-9

         RPO target  → 7 days (PITR) / 7 days (export) / unknown (Auth, Storage)
         RTO target  → < 1h PITR / < 4h GCS import / NEVER VERIFIED
         Documented at: docs/ops/backups.md (status: ACTIVE)
```

### Production readiness blockers — verified state

| Blocker (orchestrator) | Verified state | Status |
|---|---|---|
| No automated deployment | No Fastlane, no store upload | OPEN — by user choice (no submission yet) |
| Placeholder package name | `se.butlery.app` live | RESOLVED |
| Debug signing only | Release keystore + cert verify | RESOLVED |
| No ProGuard/minification | R8 + isShrinkResources on | RESOLVED |
| Single Firebase project | Confirmed single project | OPEN — H-6 |
| No Firestore PITR | PITR enabled (7d) | RESOLVED |
| No Firestore scheduled backups | Weekly GCS export | RESOLVED |
| (added) No restore drill | Never performed | OPEN — C-3 |
| (added) No Auth/Storage backup | Not documented | OPEN — H-8/H-9 |
| (added) Firestore rules manual deploy | No CI deploy job | OPEN — H-7 |

### Quick wins vs strategic (for Phase 2)

| Quick win (≤4h, high impact) | Strategic (≥1d, medium impact) |
|---|---|
| Schedule first restore drill (C-3) | Stand up staging Firebase project (H-6) |
| Add AAB/IPA artifact upload (H-1) | Fix TestServiceLocator dispose-leak (C-1) |
| Auto-merge for patch Dependabot PRs (H-2) | Add Fastlane store-upload lane (C-2) |
| Add wait-for-emulator loop in test.yml (H-5) | Auth + Storage backup wiring (H-8/H-9) |
| Add `permissions:` block to 4 workflows (M-14) | Add ViewModel/Services area floors (H-3) |
| Add `flutter analyze` to test.yml (M-2) | Stand up SLO doc + alert routing (H-10/M-10) |
| Add `crash-spike-runbook.md` (H-11) | Pin GitHub Actions by SHA (L-5) |
| Add `firestore:rules` deploy workflow (H-7) | Release-please version automation (M-6) |

---

## DORA metrics (estimated, no production data)

- **Deployment frequency:** zero deployments (no automated path; no current store presence). Estimated post-submission: solo-dev cadence ~1-2 / week.
- **Lead time for changes:** commit-to-build-green typically <15 min (sum of timeouts above) given concurrency cancel + parallel matrix. Commit-to-production: indeterminate (no deploy automation).
- **Change failure rate:** unmeasured. No production deploys to fail. Test-suite failure rate (pre-merge): impossible to estimate from captured data given the test-infra hang masks the signal.
- **Mean time to recovery:** unknown. PITR restore is theoretically <1h per `docs/ops/backups.md:18`, but C-3 makes this an untested claim.

---

## Summary of all findings

| ID | Severity | Title | Evidence |
|---|---|---|---|
| C-1 | CRITICAL | Test pipeline silently passes through known multi-min hang | `test/views/helpers/infrastructure_integration_test.dart`, `test.yml:36,70` |
| C-2 | CRITICAL (deferred) | No automated store deployment | absence in `.github/workflows/` |
| C-3 | CRITICAL | Restore drill never performed | `docs/ops/backups.md:32` |
| H-1 | HIGH | No AAB/IPA artifact retention | `build-validation.yml:194-229` |
| H-2 | HIGH | Dependabot opens up to 13 PRs/week, no auto-merge | `.github/dependabot.yml:18,60,98` |
| H-3 | HIGH | ViewModel/Services coverage targets not enforced | `test.yml:139-178` |
| H-4 | HIGH | Integration tests silently no-op if path moves | `test.yml:273-279` |
| H-5 | HIGH | E2E-emulator waits with `sleep 10` not readiness probe | `test.yml:265-269` |
| H-6 | HIGH | Single Firebase project, no env separation | `firebase.json:71-87`, no `.firebaserc` |
| H-7 | HIGH | Firestore rules deploy is manual | `firestore-rules.yml` (no deploy step) |
| H-8 | HIGH | No Firebase Auth user export | `docs/ops/backups.md` (omits Auth) |
| H-9 | HIGH | No Firebase Storage backup | `docs/ops/backups.md` (omits Storage) |
| H-10 | HIGH | No SLO definitions document | `docs/operations/` does not exist |
| H-11 | HIGH | No crash-spike or data-corruption playbook | `docs/ops/` (gap) |
| H-12 | HIGH | Inconsistent GitHub Actions versions | `actions/checkout@v4` vs `@v6` mix |
| M-1 | MEDIUM | dep-audit Mon 05 UTC schedule largely redundant w/ Dependabot | `dep-audit.yml:16` |
| M-2 | MEDIUM | No `flutter analyze` in test.yml | `test.yml` |
| M-3 | MEDIUM | Pre-analysis flutter-analyze capture is stale | `2026-05-codex/_pre-analysis/flutter-analyze.txt:3` |
| M-4 | MEDIUM | No flaky-test detection / quarantine | all workflows |
| M-5 | MEDIUM | Test pyramid distribution unknown | n/a |
| M-6 | MEDIUM | No version-bump automation | absence of release-please |
| M-7 | MEDIUM | No staged-rollout config | tied to C-2 |
| M-8 | MEDIUM | Functions and Firestore in different EU regions | `functions/src/index.ts:20` vs `docs/ops/backups.md:30` |
| M-9 | MEDIUM | Single Firebase admin SPOF | n/a (out-of-band) |
| M-10 | MEDIUM | No documented alert routing | `docs/ops/` (gap) |
| M-11 | MEDIUM | No Firebase budget alerts in repo | n/a |
| M-12 | MEDIUM | Pre-commit recovery flow not documented for contributors | `lefthook.yml` |
| M-13 | MEDIUM | No post-incident retro process | `docs/ops/` (gap) |
| M-14 | MEDIUM | No `permissions:` scoping in 4 workflows | `build-validation.yml`, `test.yml`, `e2e_tests.yml`, `firestore-rules.yml` |
| M-15 | MEDIUM | No SLSA provenance | n/a |
| L-1 | LOW | No build-cache hit-rate metrics | n/a |
| L-2 | LOW | No web-deploy workflow | `firebase.json:21-46` |
| L-3 | LOW | RTO/RPO has no measurement evidence | tied to C-3 |
| L-4 | LOW | PII-in-logs check not automated | `lefthook.yml:19-21` |
| L-5 | LOW | GitHub Actions pinned by tag, not SHA | all workflows |

**Counts:** CRITICAL 3 (one is user-deferred → effectively 2 active), HIGH 12, MEDIUM 15, LOW 5.

---

## Cross-prompt deferrals

- Compile error in `notification_service.dart` (`ConsentPurpose`) — owned by prompt 01. M-3 above flags only the CI implication.
- Static-analysis count discrepancy — owned by prompt 12 (doc drift).
- Coverage claim drift (100/96/88 target) — owned by prompt 12 for accuracy assessment; H-3 here flags the absence of enforcement.
- Functions-region claim and Stockholm comments — owned by prompt 11 (legal data residency); the Stockholm mentions are timezone strings (`Europe/Stockholm` IANA), not region drift.
- Rules-deployment security model — owned by prompt 02 (the rules content); H-7 flags the operational gap.

---

**Done.**
