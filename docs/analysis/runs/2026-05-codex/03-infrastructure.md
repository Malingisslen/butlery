INFRASTRUCTURE AND OPERATIONS ANALYSIS - PHASE 1
===================================================
Analysis Date: 2026-05-04
Analyst: Claude (Opus 4.7)

OVERALL SCORE: 57/100
DevOps Maturity Level: 2

DIMENSION SCORES:
  Build Pipeline and Automation:    11/15
  Testing Strategy and Coverage:    7/15
  Deployment and Release:           4/15
  Backup and Disaster Recovery:     9/15
  Monitoring and Observability:     8/12
  Development Workflow:             5/8
  Incident Response:                6/10
  CI/CD Security:                   7/10

DORA METRICS (measure or estimate):
  Deployment Frequency:     0 automated production deployments/week (manual-only path)
  Lead Time for Changes:    Not directly measurable from repo telemetry; estimated 1-3 days manual release path
  Change Failure Rate:      Not measurable from deployment telemetry; pre-release signal currently degraded (analysis error + hanging tests)
  Mean Time to Recovery:    Estimated 4-24 hours depending incident class

PRODUCTION READINESS: Not Ready

CRITICAL FINDINGS: 3
HIGH FINDINGS:     6
MEDIUM FINDINGS:   7
LOW FINDINGS:      2

## 1. CI/CD pipeline diagram (source -> build -> test -> deploy)

```text
Git push / PR
  |
  +-- architecture-validation.yml
  |     -> flutter analyze
  |     -> architecture tests
  |     -> validate_architecture.dart
  |
  +-- build-validation.yml
  |     -> validate (format + fatal analyze + architecture test)
  |     -> security-scan (Trivy)
  |     -> secret-scan (TruffleHog)
  |     -> build matrix (android/web/ios)
  |     -> summary gate
  |
  +-- test.yml
  |     -> unit-tests (unit/widget/views/golden + coverage)
  |     -> integration-tests (test/integration only)
  |
  +-- e2e_tests.yml
  |     -> matrix tier: mock + emulator (nightly + push/PR)
  |
  +-- firestore-rules.yml (path-gated)
  |     -> Firestore emulator + rules test suite
  |
  +-- dep-audit.yml (path/schedule)
        -> OSV (pub) + npm audit (functions)

Deploy stage: not automated in current workflows.
```

Evidence: workflow inventory lists six CI workflows (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`); build pipeline validates and builds but stops at summary checks (`.github/workflows/build-validation.yml:47-58`, `.github/workflows/build-validation.yml:69-90`, `.github/workflows/build-validation.yml:97-108`, `.github/workflows/build-validation.yml:188-230`, `.github/workflows/build-validation.yml:231-249`).

## 2. Build performance benchmarks (cold/warm cache times)

| Metric | Observed | Source Quality | Evidence |
|---|---:|---|---|
| `flutter analyze` runtime | 220.3s | Measured | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:5` |
| Full `flutter test --coverage` runtime | terminated at ~45m | Measured (partial run) | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525` |
| Test progress before hang point | 10122 tests reached at `24:23` | Measured | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508` |
| Per-hung-test timeout | 10m default timeout | Measured | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31511-31512`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31517-31518` |
| CI unit-test job timeout budget | 20m | Configured | `.github/workflows/test.yml:36` |
| Cold-cache build time | Not captured | Unknown | No duration export step present; only static timeout controls in workflows (`.github/workflows/build-validation.yml:32`, `.github/workflows/build-validation.yml:95`, `.github/workflows/test.yml:36`, `.github/workflows/e2e_tests.yml:45`) |
| Warm-cache build time | Not captured | Unknown | Same as above |

## 3. Test automation workflow (which tests run when)

| Test type | Workflow | Trigger | Blocking |
|---|---|---|---|
| Unit + widget + views + golden | `test.yml` unit-tests job | push/PR to `main,develop` | Yes (workflow job) |
| Integration (`test/integration`) | `test.yml` integration-tests job | push/PR to `main,develop` | Yes (workflow job) |
| E2E mock/emulator | `e2e_tests.yml` | push `main,develop`; PR `main`; nightly; manual | Yes (workflow job) |
| Firestore rules suite | `firestore-rules.yml` | path-gated PR + push `main`; manual | Yes (workflow job) |
| Architecture compliance tests | `architecture-validation.yml` + `build-validation.yml` | push/PR | Yes |

Evidence: `.github/workflows/test.yml:3-20`, `.github/workflows/test.yml:67-71`, `.github/workflows/test.yml:211-279`; `.github/workflows/e2e_tests.yml:3-23`, `.github/workflows/e2e_tests.yml:47-51`, `.github/workflows/e2e_tests.yml:108-110`; `.github/workflows/firestore-rules.yml:8-33`, `.github/workflows/firestore-rules.yml:87-90`; `.github/workflows/architecture-validation.yml:80-83`; `.github/workflows/build-validation.yml:55-58`.

## 4. Deployment pipeline (current state vs target state)

| Stage | Current state | Target state |
|---|---|---|
| Build | Android AAB/web/iOS IPA built in CI | Keep |
| Signing | Android release signing enforced in CI; iOS build is no-codesign | Fully signed Android+iOS release artifacts in CI |
| Distribution | No store upload / beta distribution stage in workflows | Automated promotion path (internal -> beta -> production) |
| Environment promotion | Single Firebase project config used across app configs | Environment-separated projects/config (`dev/staging/prod`) |
| Release governance | No CI deployment telemetry (DORA unmeasured) | Deployment telemetry + rollback metrics |

Evidence for current state: Android signed release checks (`.github/workflows/build-validation.yml:152-170`, `.github/workflows/build-validation.yml:196-213`), iOS no-codesign build (`.github/workflows/build-validation.yml:225-230`), workflow inventory (no dedicated deploy workflow in captured list) (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`), single project IDs in app config (`lib/firebase_options.dart:38`, `lib/firebase_options.dart:48`, `lib/firebase_options.dart:56`, `lib/firebase_options.dart:65`, `lib/firebase_options.dart:74`, `firebase.json:71`, `firebase.json:78`).

## 5. Disaster recovery assessment (PITR, backups, RTO/RPO)

| Control | Status | RTO/RPO implication | Evidence |
|---|---|---|---|
| Firestore PITR | Enabled (documented) | Enables near-term restore window | `docs/ops/backups.md:3`, `docs/ops/backups.md:26` |
| Weekly Firestore export | Scheduled (documented) | Longer-window restore safety net | `docs/ops/backups.md:3`, `docs/ops/backups.md:27` |
| Backup retention target | 30-day lifecycle | Longer retention than PITR window | `docs/ops/backups.md:29`, `docs/ops/backups.md:203-205` |
| Restore drill | Never performed | Real recovery time unvalidated | `docs/ops/backups.md:31` |
| Storage object versioning | Runbook contradictory (`PENDING` vs `Activated`) | Operational ambiguity risk | `docs/ops/storage-lifecycle-runbook.md:3`, `docs/ops/storage-lifecycle-runbook.md:187-190` |
| Storage policy automation | Script exists + verifies versioning/lifecycle | Enables repeatable enforcement | `infrastructure/storage/setup-storage-versioning.sh:35-66`, `infrastructure/storage/setup-storage-versioning.sh:73-89` |
| Infra topology SPOF | Single Firebase project references in app config | Larger blast radius for config/deploy errors | `lib/firebase_options.dart:38`, `lib/firebase_options.dart:48`, `lib/firebase_options.dart:56`, `lib/firebase_options.dart:65`, `lib/firebase_options.dart:74` |

## 6. Production readiness blockers list

| Blocker | Severity | Why it blocks readiness | Evidence |
|---|---|---|---|
| No automated production deployment pipeline | Critical | CI stops at build/validation; no automated promotion/upload path | `docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`, `.github/workflows/build-validation.yml:231-249` |
| Test suite hang/timeouts in views helper infra tests | Critical | Coverage run stalls and terminates before full completion | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508-31519`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529` |
| Static-analysis compile error (`ConsentPurpose` undefined) | Critical | Current analyzer gate is red | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3-5` |
| iOS CI artifacts are not code-signed for release | High | No signed IPA release path in CI | `.github/workflows/build-validation.yml:225-230`, `ios/exportOptions.plist:5-10` |
| Single Firebase project for all environments | High | No environment isolation/promotion safety | `lib/firebase_options.dart:38`, `lib/firebase_options.dart:48`, `lib/firebase_options.dart:56`, `lib/firebase_options.dart:65`, `lib/firebase_options.dart:74`, `firebase.json:71`, `firebase.json:78` |

## 7. Quick wins vs strategic improvements matrix

| Item | Impact | Effort | Class |
|---|---|---|---|
| Fix analyzer error in `notification_service.dart` (`ConsentPurpose`) | High | XS (<0.5d) | Quick win |
| Raise/shard unit-test runtime budget; isolate hanging helper tests | High | S (0.5-1d) | Quick win |
| Wire E2E tier contract (`all`/staging) end-to-end | Medium | S-M (1-2d) | Quick win |
| Align local setup Flutter version with CI pin | Medium | XS (<0.5d) | Quick win |
| Complete iOS signing automation in CI | Critical | M-L (2-4d) | Strategic |
| Add automated deployment lanes (internal/beta/prod) | Critical | L (3-5d) | Strategic |
| Split Firebase environments (`dev/staging/prod`) | High | XL (1-2 weeks) | Strategic |
| Expand alert policy coverage + budget alert automation | High | M (1-2d) | Strategic |

Evidence anchors: analyzer error (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3-5`), hang/timeouts (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508-31519`), E2E mismatch (`.github/workflows/e2e_tests.yml:24-33`, `scripts/run_e2e_tests.sh:31-35`, `.claude/agents/e2e-test-specialist.knowledge.md:37-40`), setup drift (`scripts/setup.sh:7`, `scripts/setup.ps1:6`, `.github/workflows/test.yml:26`), iOS/signing/deploy (`.github/workflows/build-validation.yml:225-230`, `ios/exportOptions.plist:5-10`, `docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`).

---

## Dimension 1: Build Pipeline and Automation (11/15)

**Strengths**
- CI coverage breadth is strong: six active workflows cover architecture, builds, tests, E2E, dependency audits, and Firestore-rules checks (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`).
- Flutter version pinning is consistent in core workflows at `3.35.1` (`.github/workflows/architecture-validation.yml:27`, `.github/workflows/build-validation.yml:26`, `.github/workflows/dep-audit.yml:24`, `.github/workflows/e2e_tests.yml:40`, `.github/workflows/test.yml:26`).
- Build validation applies strict gates (format + fatal analyze + architecture tests) before build matrix fan-out (`.github/workflows/build-validation.yml:47-58`, `.github/workflows/build-validation.yml:97-108`).
- Android release hardening is in place (keystore secret checks, signed-AAB verification, minify/shrink on release) (`.github/workflows/build-validation.yml:152-170`, `.github/workflows/build-validation.yml:196-213`, `android/app/build.gradle.kts:70-75`).

**Gaps**
- Build pipeline has no production deployment stage; it ends at summary validation (`.github/workflows/build-validation.yml:231-249`).
- Build performance observability is limited to static timeout budgets; cold/warm cache timing is not emitted (`.github/workflows/build-validation.yml:32`, `.github/workflows/build-validation.yml:95`, `.github/workflows/test.yml:36`, `.github/workflows/e2e_tests.yml:45`).
- Local setup scripts still instruct Flutter `3.32.4`, diverging from CI `3.35.1` (`scripts/setup.sh:7`, `scripts/setup.ps1:6`, `.github/workflows/test.yml:26`).

**Risk assessment**
- **Medium**: robust validation exists, but throughput predictability and release-path completeness are not yet operationally mature.

**Findings**
- `INFRA-11` (Medium, Effort: S): Build performance telemetry gap (timeouts configured, but no measured cold/warm benchmark export) (`.github/workflows/build-validation.yml:32`, `.github/workflows/build-validation.yml:95`, `.github/workflows/test.yml:36`).
- `INFRA-17` (Low, Effort: XS): `validate_architecture.dart` reports violations but intentionally does not fail the process (`tools/validate_architecture.dart:215-220`).

## Dimension 2: Testing Strategy and Coverage (7/15)

**Strengths**
- Multi-OS unit-test matrix and coverage upload pipeline are configured (`.github/workflows/test.yml:31-35`, `.github/workflows/test.yml:183-201`).
- Anti-flake guardrail for real-time APIs is wired into CI (`.github/workflows/test.yml:53-55`, `scripts/check_test_real_time.sh:1-5`, `scripts/check_test_real_time.sh:93-105`).
- Coverage governance exists both in workflow floors and Codecov policy (`.github/workflows/test.yml:120-180`, `codecov.yml:13-21`).

**Gaps**
- Pre-analysis coverage run hangs repeatedly in `test/views/helpers/infrastructure_integration_test.dart`, with repeated 10-minute timeouts and early termination (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508-31519`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`).
- CI unit-test timeout is 20 minutes, while the pre-analysis run had already spent `24:23` reaching the hang point (`.github/workflows/test.yml:36`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508`).
- E2E contract drift: workflow input advertises `all`, knowledge includes staging entrypoint, but runner script only accepts `mock|emulator` (`.github/workflows/e2e_tests.yml:24-33`, `.github/workflows/e2e_tests.yml:47-51`, `.claude/agents/e2e-test-specialist.knowledge.md:37-40`, `scripts/run_e2e_tests.sh:31-35`).
- View helper setup duplicates ServiceLocator initialization/reset path, increasing setup churn (`test/views/helpers/view_test_helpers.dart:85-88`, `test/test_support/base_unit_test.dart:55`, `test/test_support/base_test.dart:34`, `test/infrastructure/di/test_service_locator.dart:95-97`, `test/infrastructure/di/test_service_locator.dart:168-170`).

**Risk assessment**
- **High**: test reliability and runtime budgets currently threaten CI trust and full-suite executability.

**Findings**
- `INFRA-02` (Critical, Effort: M): Test run hangs with repeated default timeout failures in helper infrastructure tests (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31511-31512`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31517-31518`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`).
- `INFRA-06` (High, Effort: S): Unit-test timeout budget (20m) is likely under-provisioned relative to observed suite progression (`.github/workflows/test.yml:36`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508`).
- `INFRA-07` (High, Effort: S-M): E2E tier mismatch prevents intended staging/all-tier execution through the canonical runner (`.github/workflows/e2e_tests.yml:24-33`, `scripts/run_e2e_tests.sh:31-35`, `.claude/agents/e2e-test-specialist.knowledge.md:37-40`).
- `INFRA-10` (Medium, Effort: M): View-helper test bootstrap performs redundant locator initialize/reset cycles; plausible contributor to instability/latency (`test/views/helpers/view_test_helpers.dart:85-88`, `test/infrastructure/di/test_service_locator.dart:95-97`, `test/infrastructure/di/test_service_locator.dart:168-170`).

## Dimension 3: Deployment and Release (4/15)

**Strengths**
- CI reliably produces Android/web/iOS build outputs (`.github/workflows/build-validation.yml:97-108`, `.github/workflows/build-validation.yml:188-230`).
- Android release signing pipeline is explicitly enforced and debug-sign leakage is checked (`.github/workflows/build-validation.yml:152-170`, `.github/workflows/build-validation.yml:196-213`).

**Gaps**
- No automated production deployment/promotion path appears in workflow inventory (validation/build/test only) (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`, `.github/workflows/build-validation.yml:231-249`).
- iOS path is build-only and explicitly no-codesign (`.github/workflows/build-validation.yml:225-230`).
- Environment isolation is absent in app config (single Firebase project ID across platforms) (`lib/firebase_options.dart:38`, `lib/firebase_options.dart:48`, `lib/firebase_options.dart:56`, `lib/firebase_options.dart:65`, `lib/firebase_options.dart:74`).
- Versioning appears manual in `pubspec.yaml` (`pubspec.yaml:4`).

**Risk assessment**
- **Critical**: release engineering is incomplete for production-grade automated delivery.

**Findings**
- `INFRA-01` (Critical, Effort: L): No automated production deployment stage exists in current CI workflow set (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`, `.github/workflows/build-validation.yml:231-249`).
- `INFRA-04` (High, Effort: M-L): iOS CI artifacts are unsuited for release automation due to `--no-codesign` and development export profile (`.github/workflows/build-validation.yml:225-230`, `ios/exportOptions.plist:5-10`).
- `INFRA-05` (High, Effort: XL): Single Firebase project configuration increases release blast radius and blocks clean environment promotion (`lib/firebase_options.dart:38`, `lib/firebase_options.dart:48`, `lib/firebase_options.dart:56`, `lib/firebase_options.dart:65`, `lib/firebase_options.dart:74`, `firebase.json:71`, `firebase.json:78`).

## Dimension 4: Backup and Disaster Recovery (9/15)

**Strengths**
- Runbook state documents PITR enabled and weekly exports scheduled (`docs/ops/backups.md:3`, `docs/ops/backups.md:26-28`).
- DR targets and retention are explicitly documented (`docs/ops/backups.md:16-19`, `docs/ops/backups.md:202-205`).
- Storage versioning/lifecycle automation exists with fail-loud verification (`infrastructure/storage/setup-storage-versioning.sh:35-66`, `infrastructure/storage/setup-storage-versioning.sh:73-89`).

**Gaps**
- Storage DR runbook has conflicting activation state (`docs/ops/storage-lifecycle-runbook.md:3`, `docs/ops/storage-lifecycle-runbook.md:187-190`).
- Restore drill has never been performed, leaving practical RTO unvalidated (`docs/ops/backups.md:31`).
- App-level `BackupService` covers user recipe export/import, not infrastructure-grade Firestore restore workflows (`lib/services/backup_service.dart:20-57`, `lib/services/backup_service.dart:142-250`).

**Risk assessment**
- **Medium**: DR controls appear designed and mostly documented, but drill maturity and status consistency remain gaps.

**Findings**
- `INFRA-14` (Medium, Effort: XS): Storage DR runbook status inconsistency introduces execution ambiguity (`docs/ops/storage-lifecycle-runbook.md:3`, `docs/ops/storage-lifecycle-runbook.md:187-190`).
- `INFRA-15` (Medium, Effort: S): No recorded restore drill means documented RTO/RPO are not operationally validated (`docs/ops/backups.md:31`).

## Dimension 5: Monitoring and Observability (8/12)

**Strengths**
- Global exception capture is implemented via zone + FlutterError + PlatformDispatcher integration (`lib/main.dart:130`, `lib/main.dart:228-238`, `lib/main.dart:255-259`).
- Consent-aware telemetry gating is implemented for Analytics, Crashlytics, and Performance (`lib/main.dart:210-213`, `lib/main.dart:287-289`, `lib/main.dart:305-334`).
- Logger integrates Crashlytics with message sanitization (`lib/core/utils/logger.dart:182-229`).
- AppMonitoringService records custom metrics/errors and performance traces (`lib/services/monitoring/app_monitoring_service.dart:39-45`, `lib/services/monitoring/app_monitoring_service.dart:60-99`, `lib/services/monitoring/app_monitoring_service.dart:107-142`).

**Gaps**
- Frame timing callback is disabled in release mode, reducing production jank visibility (`lib/services/performance/performance_monitoring_service.dart:155-159`).
- Web uses `NoOpAnalyticsRepository`, reducing parity of analytics observability (`lib/core/di/modules/core_module.dart:211-213`, `lib/repositories/noop/noop_analytics_repository.dart:13-28`).
- GCP alerting currently covers only two CF policies; Firestore/Auth policy gaps and budget alerts remain TODO/manual (`docs/ops/gcp-alerting-runbook.md:31-35`, `docs/ops/gcp-alerting-runbook.md:45-55`).

**Risk assessment**
- **Medium**: core telemetry stack is present, but platform parity and alert breadth are incomplete.

**Findings**
- `INFRA-12` (Medium, Effort: S): Release-mode frame performance monitoring is disabled (`lib/services/performance/performance_monitoring_service.dart:155-159`).
- `INFRA-13` (Medium, Effort: M): Web analytics repository is no-op, leaving cross-platform analytics blind spots (`lib/core/di/modules/core_module.dart:211-213`, `lib/repositories/noop/noop_analytics_repository.dart:13-28`).

## Dimension 6: Development Workflow (5/8)

**Strengths**
- Cross-platform onboarding scripts exist for Unix/Windows and include dependency + lint verification (`scripts/setup.sh:1-4`, `scripts/setup.sh:49-74`, `scripts/setup.ps1:1-2`, `scripts/setup.ps1:52-79`).
- Pre-commit and commit-msg quality gates are codified via Lefthook (`lefthook.yml:8-29`, `lefthook.yml:31-37`).
- Conventional commit validation script is present (`scripts/validate-commit-msg.js:20-23`).

**Gaps**
- Setup scripts are pinned to Flutter `3.32.4` while CI and captured tooling output use `3.35.1`, creating local-vs-CI drift (`scripts/setup.sh:7`, `scripts/setup.ps1:6`, `.github/workflows/test.yml:26`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-version.txt:1`).
- Branch protection/review enforcement cannot be validated from repository files alone (unknown).

**Risk assessment**
- **Medium**: contributor workflow is structured, but version drift and governance visibility are friction points.

**Findings**
- `INFRA-09` (High, Effort: XS): Local setup version pin drift from CI/runtime Flutter version (`scripts/setup.sh:7`, `.github/workflows/test.yml:26`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-version.txt:1`).

## Dimension 7: Incident Response (6/10)

**Strengths**
- Alerting runbook states live paging channel and two active policies (`docs/ops/gcp-alerting-runbook.md:3`, `docs/ops/gcp-alerting-runbook.md:29-32`).
- Data-loss incident communication steps are documented with explicit escalation clock (`docs/ops/backups.md:211-222`).

**Gaps**
- Alerting scope is incomplete (Firestore/Auth policies deferred; budget alerting manual) (`docs/ops/gcp-alerting-runbook.md:33-35`, `docs/ops/gcp-alerting-runbook.md:161-172`).
- Slack/PagerDuty are explicitly deferred for later scale, indicating current email-only route (`docs/ops/gcp-alerting-runbook.md:171-172`).

**Risk assessment**
- **Medium**: basic incident detection exists, but channel redundancy and coverage depth are limited.

**Findings**
- `INFRA-08` (High, Effort: M): Incident detection scope is narrow (2 active policies; key cost/traffic alerts still deferred/manual) (`docs/ops/gcp-alerting-runbook.md:31-35`, `infrastructure/alerting/setup-gcp-alerts.sh:63-123`, `infrastructure/alerting/setup-gcp-alerts.sh:125-137`).

## Dimension 8: CI/CD Security (7/10)

**Strengths**
- Multi-layer CI security checks are enabled: Trivy, TruffleHog, OSV, npm audit (`.github/workflows/build-validation.yml:69-90`, `.github/workflows/dep-audit.yml:50-73`, `.github/workflows/dep-audit.yml:96-97`).
- Dependabot coverage spans pub, npm, and GitHub Actions on weekly cadence (`.github/dependabot.yml:13-18`, `.github/dependabot.yml:55-60`, `.github/dependabot.yml:91-96`).
- Lockfiles are committed for both Dart and Functions ecosystems (`pubspec.lock:1-3`, `functions/package-lock.json:1-6`).
- Android release-signing controls are explicit and fail-loud in CI (`.github/workflows/build-validation.yml:152-170`, `.github/workflows/build-validation.yml:196-213`, `android/app/build.gradle.kts:59-66`).

**Gaps**
- iOS signing controls are not present in CI release path (`.github/workflows/build-validation.yml:225-230`).
- Functions audit runs with Node 20 while declared runtime is Node 22, reducing audit/runtime parity (`.github/workflows/dep-audit.yml:89`, `firebase.json:9`, `functions/package.json:56`).
- Third-party GitHub Actions are version-tag pinned, not commit-SHA pinned (supply-chain hardening gap) (`.github/workflows/build-validation.yml:36`, `.github/workflows/build-validation.yml:70`, `.github/workflows/test.yml:39`, `.github/workflows/architecture-validation.yml:40`).
- CI materializes secrets into a plaintext `.env` file for build steps (`.github/workflows/build-validation.yml:121-144`).

**Risk assessment**
- **Medium**: strong baseline scanning exists, with remaining gaps in iOS signing and reproducible supply-chain hardening.

**Findings**
- `INFRA-16` (Medium, Effort: XS-S): Functions dependency audit runtime mismatch (Node 20 audit vs Node 22 runtime) (`.github/workflows/dep-audit.yml:89`, `firebase.json:9`, `functions/package.json:56`).
- `INFRA-18` (Low, Effort: S): Build pipeline writes full secret set into workspace `.env`; functional but increases exposure surface if downstream steps are compromised (`.github/workflows/build-validation.yml:121-144`).

---

## Cross-dimension critical findings

### INFRA-01 — No automated production deployment workflow
- Severity: **Critical**
- Effort: **L (3-5 days)**
- Evidence: workflow inventory contains validation/test/audit/rules/E2E only (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`); build workflow ends at validation summary (`.github/workflows/build-validation.yml:231-249`).

### INFRA-02 — Test-suite hang in helper-infrastructure tests
- Severity: **Critical**
- Effort: **M (1-2 days)**
- Evidence: repeated 10-minute timeouts in `test/views/helpers/infrastructure_integration_test.dart` (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31511-31512`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31517-31518`) and run termination around 45 minutes (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`).

### INFRA-03 — Current analyzer run has blocking compile error
- Severity: **Critical**
- Effort: **XS (<0.5 day)**
- Evidence: `Undefined name 'ConsentPurpose'` in `notification_service.dart` (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`) with 1 issue found (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:5`).

---

## Unknowns (explicit)

- Branch protection requirements (required checks, review gates) cannot be verified from repository files alone.
- Real deployment frequency/lead-time/CFR are not measurable from in-repo telemetry because automated production deploy lanes are absent in current workflow inventory (`docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1-6`).
- Cold-cache/warm-cache build timings are not captured in workflow outputs; only timeout ceilings are configured (`.github/workflows/build-validation.yml:32`, `.github/workflows/build-validation.yml:95`, `.github/workflows/test.yml:36`).
