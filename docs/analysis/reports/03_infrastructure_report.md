# Infrastructure & Operations Analysis — Phase 1 Report

**Prompt**: 03 of 06
**Analyst**: Claude (Opus 4.6)
**Date**: 2026-02-26
**Scope**: 8-dimension DevOps lifecycle audit (investigation only, zero changes)

---

## Executive Summary

```
INFRASTRUCTURE AND OPERATIONS ANALYSIS - PHASE 1
===================================================
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6)

OVERALL SCORE: 57/100
DevOps Maturity Level: 2.5 / 5 (Defined — approaching Managed)

DIMENSION SCORES:
  1. Build Pipeline and Automation:    10/15
  2. Testing Strategy and Coverage:    12/15
  3. Deployment and Release:            3/15
  4. Backup and Disaster Recovery:      5/15
  5. Monitoring and Observability:      9/12
  6. Development Workflow:              7/8
  7. Incident Response:                 4/10
  8. CI/CD Security:                    7/10

DORA METRICS (estimated — no production deployments exist):
  Deployment Frequency:     0 per month (no automated deployment)
  Lead Time for Changes:    ∞ (no deployment pipeline)
  Change Failure Rate:      N/A (no deployments to measure)
  Mean Time to Recovery:    Unknown (no incident history)

PRODUCTION READINESS: NOT READY — 3 Critical Blockers

CRITICAL FINDINGS: 5
HIGH FINDINGS:     6
MEDIUM FINDINGS:   8
LOW FINDINGS:      4
```

### Maturity Profile

The project demonstrates a **split maturity**: development-side infrastructure (CI, testing, code quality, monitoring) is strong (Level 3-4), while delivery-side infrastructure (deployment, DR, incident response) is minimal (Level 1). The codebase has 1,052 Dart files / 330K lines with 460 test files — the engineering is mature but the operations pipeline is absent.

---

## Dimension 1: Build Pipeline and Automation — 10/15

### Strengths

**Well-structured CI with 5 active workflows:**

| Workflow | Trigger | Purpose | Key Config |
|----------|---------|---------|------------|
| `analyze.yml` | push/PR → main, develop | Static analysis + format check | `--no-fatal-infos` |
| `test.yml` | push/PR → main, develop | Unit/widget/view + integration tests | Codecov upload, Firebase emulators |
| `build-validation.yml` | push/PR → main, develop | Strict analysis + Android/web builds | `--fatal-infos --fatal-warnings`, matrix build |
| `architecture-validation.yml` | push/PR → main, develop + manual | Architecture compliance + PR comments | 30-day artifact retention, auto PR comment |
| `e2e_tests.yml` | push/PR + nightly 2AM UTC + manual | Mock + emulator E2E tests | 20-min timeout, tier selection |

**Ref**: `.github/workflows/` (5 files)

**Flutter version consistency**: All 5 workflows pin `FLUTTER_VERSION: '3.32.4'` as env var. Confirmed at:
- `analyze.yml:14`, `test.yml:14`, `build-validation.yml:14`, `architecture-validation.yml:15`, `e2e_tests.yml:28`

**Concurrency**: All workflows use `cancel-in-progress: true` — prevents resource waste on rapid pushes.

**Caching strategy:**
- Flutter SDK: `subosito/flutter-action@v2` with `cache: true` (all 5 workflows)
- Gradle: `actions/cache@v4` with hash-based key (`build-validation.yml:75-81`)
- Pub cache: `actions/cache@v4` keyed on `pubspec.lock` hash (`e2e_tests.yml:61-65`)

**Build configuration:**
- Android APK built with obfuscation + split debug info (`build-validation.yml:87`)
- R8/ProGuard enabled for release: `isMinifyEnabled = true`, `isShrinkResources = true` (`build.gradle.kts:39-40`)
- compileSdk 36, targetSdk 36, minSdk 24 (`build.gradle.kts:10,27-28`)
- Java 17 compatibility (`build.gradle.kts:14-15`)
- Gradle 8.13 (`gradle-wrapper.properties`)

**Quality gates**: Two-level analysis enforcement:
- `analyze.yml:41`: `flutter analyze --no-fatal-infos` (lenient — infos pass)
- `build-validation.yml:37`: `flutter analyze --fatal-infos --fatal-warnings` (strict — blocks build)

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F1-1: No iOS build in CI | Medium | Matrix only includes `[android, web]` (`build-validation.yml:52`). iOS builds untested. |
| F1-2: No AAB output | Medium | Builds APK only (`flutter build apk`). Google Play requires AAB (App Bundle). |
| F1-3: Artifact retention inconsistent | Low | Architecture: 30 days (`architecture-validation.yml:77`), E2E: 7 days (`e2e_tests.yml:99`), test.yml: no retention set (default 90 days). |
| F1-4: Outdated upload-artifact | Low | `test.yml:52,136` uses `actions/upload-artifact@v3` (deprecated). E2E and architecture use `@v4`. |
| F1-5: No build performance tracking | Low | No build time metrics collected. Cold/warm cache times unknown. |

### Score Rationale: 10/15

Strong CI with 5 workflows, consistent versioning, good caching, architecture validation with PR comments. Loses points for no iOS CI builds, no AAB format, and minor inconsistencies.

---

## Dimension 2: Testing Strategy and Coverage — 12/15

### Strengths

**Test inventory (460 test files):**

| Category | Files | Location | CI Workflow |
|----------|-------|----------|-------------|
| Unit | 286 | `test/unit/` | `test.yml` (blocking) |
| Widget | 109 | `test/widget/` | `test.yml` (blocking) |
| View | 23 | `test/views/` | `test.yml` (blocking) |
| Integration | 23 | `test/integration/` | `test.yml` (blocking) |
| E2E | 12 | `test/e2e/` | `e2e_tests.yml` (non-blocking for PRs) |
| Architecture | 1 | `test/architecture/` | `build-validation.yml`, `architecture-validation.yml` |
| Golden | varies | `test/golden/` | Not in active CI |
| Performance | varies | `test/performance/` | Not in active CI |
| Benchmark | varies | `test/benchmark/` | Not in active CI |

**Test pyramid distribution:**
- Unit: 62% (286/460) — target 70%, slightly under
- Widget: 24% (109/460) — target 20%, slightly over
- Integration: 5% (23/460) — target 10%, under
- E2E: 3% (12/460) — supplementary tier

**Coverage tracking**: Codecov integration with `lcov.info` upload (`test.yml:41-47`). `fail_ci_if_error: false` — coverage is reported but not enforced as a gate.

**Mature test infrastructure** (`test/infrastructure/`, 26 files):
- `TestServiceLocator` (`test/infrastructure/di/test_service_locator.dart`): Production-aligned DI with 13 repos, 14 services, 13 VMs
- 7 test data builders (`test/infrastructure/builders/`)
- 5 mock factories (`test/infrastructure/factories/`)
- 7 mock files with Mocktail (`test/infrastructure/mocks/`)
- `FakeCloudFirestore` singleton with `clearData()` / `hardReset()` methods
- Fallback value registration for Mocktail
- 12 test support utilities (`test/test_support/`)

**Three-tier E2E strategy:**
- Mock tier (fastest, no Firebase)
- Emulator tier (Firebase emulator integration)
- Staging tier (defined but not configured)
- Runner script: `scripts/run_e2e_tests.sh` (149 lines)

**Firebase testing**: Integration tests use Firebase emulators (Auth:9099, Firestore:8080, Storage:9199) started in CI (`test.yml:86-114`).

**Test templates**: 4 templates in `test/templates/` (DI-heavy, simple unit, ViewModel, model).

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F2-1: No coverage enforcement | Medium | `fail_ci_if_error: false` (`test.yml:46`). No minimum threshold, no PR delta check. Disabled workflow had 90% threshold (`.flutter_ci.yml.disabled:101`). |
| F2-2: Integration tests thin | Medium | Only 23 integration test files vs target of 30+. Firebase repository integration coverage at 88% vs 85% target (passing but low margin). |
| F2-3: Golden/performance tests not in CI | Low | `test/golden/` and `test/performance/` directories exist but no workflow runs them. |
| F2-4: No flaky test tracking | Low | No mechanism to identify or quarantine flaky tests. |
| F2-5: Staging E2E tier not configured | Low | `E2EConfig.staging` defined but no staging Firebase project exists. |

### Score Rationale: 12/15

Excellent test infrastructure with 460 files, comprehensive mocking, three-tier E2E design, and Firebase emulator CI. Loses points for no coverage enforcement, thin integration layer, and unused golden/performance tests.

---

## Dimension 3: Deployment and Release — 3/15

### Critical Findings

This is the weakest dimension. **No automated deployment pipeline exists.**

| Finding | Severity | Detail |
|---------|----------|--------|
| F3-1: No automated deployment | **Critical** | No Fastlane, no store upload workflows, no Firebase App Distribution. All releases require manual builds and uploads. |
| F3-2: Placeholder package name | **Critical** | `com.example.butlery` in 8+ production files. Google Play and App Store reject `com.example.*` packages. Files: `build.gradle.kts:9,24`, `google-services.json:12`, `GoogleService-Info.plist:12`, `project.pbxproj:371,550,572` |
| F3-3: Debug signing for release | **Critical** | `signingConfig = signingConfigs.getByName("debug")` (`build.gradle.kts:38`). No production keystore exists. Release builds are signed with debug keys. |
| F3-4: No iOS team configured | High | `CODE_SIGN_STYLE = Automatic` but no `DEVELOPMENT_TEAM` set in Xcode project. Cannot build for App Store. |
| F3-5: Single Firebase project | High | Only `butlery-app-1` exists. No `.firebaserc` file. No dev/staging/prod separation. Development errors can affect production data. |

### What Does Exist

**Version management:**
- `pubspec.yaml:4`: version `1.0.0+1`
- `CHANGELOG.md`: Keep a Changelog format, semantic versioning
- Manual release process documented (`CHANGELOG.md:39-45`): bump version, move unreleased items, commit, tag, push
- Conventional commits enforced via `scripts/validate-commit-msg.js` (52 lines) + lefthook

**Deployment gates (build verification only, not deployment):**

| Gate | Automated | Blocking | Status |
|------|-----------|----------|--------|
| Tests passing | Yes | Yes | `test.yml` |
| Code review | Yes | Depends on branch protection | GitHub PRs |
| Architecture validation | Yes | No (warns only) | `architecture-validation.yml` |
| Static analysis (strict) | Yes | Yes | `build-validation.yml:37` |
| Format check | Yes | Yes | `analyze.yml:45` |
| Coverage threshold | No | No | Disabled |
| Manual QA sign-off | No | No | Not configured |
| Security scan | No | No | Not configured |

**Cloud Functions**: 19+ functions in `functions/` (Node.js 20), deployed manually via `firebase deploy --only functions`.

### Score Rationale: 3/15

Only 3 points for existing version management, changelog process, and conventional commits. Zero deployment automation, critical placeholder values, and debug-only signing make this dimension nearly non-functional for production.

---

## Dimension 4: Backup and Disaster Recovery — 5/15

### Firebase Backup Status

| Feature | Status | Evidence |
|---------|--------|----------|
| Firestore PITR | **Unknown — likely not enabled** | No references in codebase. Must check Firebase Console. |
| Firestore Scheduled Backups | **Unknown — likely not configured** | No references in codebase. Must check Firebase Console. |
| Firebase Storage backups | **Not configured** | No backup mechanism for uploaded files. |
| Firebase Auth export | **Available via CLI** | `firebase auth:export` available but not automated. |

**BackupService** (`lib/services/backup_service.dart`, 330 lines): Local-only recipe export to JSON. Platform-specific save locations (Android Downloads, iOS Documents). Duplicate detection on import. **Not a disaster recovery solution** — user-initiated, single-device, recipes only.

### Resilience Patterns (Strong)

| Pattern | Location | Lines | Purpose |
|---------|----------|-------|---------|
| ErrorHandlingMixin | `lib/core/mixins/error_handling_mixin.dart` | 606 | Retry with exponential backoff, error classification, DNS-aware recovery |
| FirebaseServiceMixin | `lib/core/mixins/firebase_service_mixin.dart` | 817 | DNS resilience, connection health, multi-strategy fallback |
| RateLimiter | `lib/core/rate_limiting/rate_limiter.dart` | 410 | Token bucket (client-side), 41 operation types |
| Offline persistence | `unified_recipe_service.dart` | — | `persistenceEnabled: true`, `CACHE_SIZE_UNLIMITED` |
| Firebase App Check | `lib/main.dart:116-122` | — | PlayIntegrity (Android), DeviceCheck (iOS), reCAPTCHA v3 (web) |

### Recovery Capabilities

| Scenario | Current Recovery | RTO | RPO |
|----------|-----------------|-----|-----|
| Data corruption | No automated recovery. Manual Firestore export only. | Days | Unknown (no backups = complete loss possible) |
| Accidental deletion | No recovery. Offline cache may retain data temporarily. | N/A | Infinite (data lost) |
| Security breach | Isolate account, no automated data restore. | 24-48h | Unknown |
| Firebase region outage | Offline persistence serves cached data (read-only). | Depends on Firebase | 0 (cached reads), unknown (writes) |
| Code deployment bug | Manual app version rollback via stores. | 1-2h (if stores approve) | 0 (data unchanged) |

### Single Points of Failure

| SPOF | Blast Radius | Redundancy |
|------|--------------|------------|
| Single Firebase project (`butlery-app-1`) | Total app failure | None |
| No environment separation | Dev errors affect production | None |
| Single Firebase admin account | Account lockout blocks everything | Investigate |
| No code signing certificates | Cannot deploy to stores | None |
| No backup location | Complete data loss possible | None |

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F4-1: No Firestore PITR | **Critical** | Quick win — minutes to enable in Firebase Console. Provides 7-day, minute-granularity recovery. |
| F4-2: No scheduled backups | **Critical** | Quick win — minutes to configure. Daily exports with 14-week retention. |
| F4-3: BackupService is not DR | High | Local-only, user-initiated, recipes-only. Not a substitute for server-side backups. |
| F4-4: No recovery playbooks | High | No documented procedures for any disaster scenario. |
| F4-5: Client-side rate limiting only | Medium | `RateLimiter` (`rate_limiter.dart`) operates client-side — can be bypassed. Server-side enforcement via Firestore security rules exists but rate limiting does not. |

### Score Rationale: 5/15

Strong resilience patterns (ErrorHandlingMixin, DNS resilience, offline persistence) earn 5 points. But no PITR, no scheduled backups, no recovery playbooks, and single Firebase project are critical gaps that limit DR capability.

---

## Dimension 5: Monitoring and Observability — 9/12

### Strengths

**Error tracking (comprehensive):**
- `FlutterError.onError` → Crashlytics (native) or `presentError` (web) — `main.dart:128-137`
- `PlatformDispatcher.instance.onError` → Crashlytics fatal errors — `main.dart:139-142`
- `runZonedGuarded` for async errors — `main.dart:152-159`
- Crashlytics collection disabled in debug mode — `main.dart:114`
- Web excluded from Crashlytics (not supported) — `main.dart:126-130`

**Performance monitoring (three-layer):**

| Service | File | Purpose |
|---------|------|---------|
| `PerformanceMonitoringService` | `lib/services/performance/performance_monitoring_service.dart` | Frame rate, network, cache, memory. Thresholds: 16ms frame, 3s network, 80% cache hit, 200MB memory. 5-minute periodic reports. |
| `FirebasePerformanceService` | `lib/services/performance/firebase_performance_service.dart` | Custom traces for recipes, search, images, screens, Firestore queries, social interactions. HTTP metric tracking. |
| `AppMonitoringService` | `lib/services/monitoring/app_monitoring_service.dart` | Business metrics, error severity (info/warning/error/critical), health checks, breadcrumb logging, user properties. |

**Analytics (GDPR-compliant):**
- `AnalyticsService` (`lib/services/analytics_service.dart`): Facade with 6 tracker modules (Recipe, Menu, Shopping, Social, Import, System)
- Consent check via `ConsentService` before logging — auth/security events exempt
- `FirebaseAnalyticsObserver` for automatic screen tracking
- Custom events: `recipe_created`, `menu_created`, `social_share`, `import_success`, etc.

**Logging strategy:**
- `AppLogger` usage: 193 occurrences across 20+ files
- `kDebugMode` guards: 35 occurrences across 6 files
- Only 1 PII-adjacent log found: `fcm_token_manager.dart:49` — in a doc comment (`///`), not actual code. No PII logged in production.

**Audit logging:**
- `FirebaseAuditRepository` (`lib/repositories/firebase/firebase_audit_repository.dart`): GDPR Article 30 compliance
- Write-only for users, read-only for admins, immutable logs
- Logs: permission checks, tag modifications (health data), access attempts

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F5-1: No SLO documentation | Medium | No `docs/operations/` directory. SLOs referenced in analysis prompt but not formally defined in codebase. |
| F5-2: No alerting documentation | Medium | Firebase alerting likely configured in Console but not documented in version control. No Slack/Teams integration found. |
| F5-3: No custom Firebase dashboards documented | Low | Dashboard configuration not exported or documented. |

### SLO Status (Defined in Code, Not Documented)

| SLI | Target | Implementation | Measurement |
|-----|--------|----------------|-------------|
| Crash-free users | 99.9% | Crashlytics integration | Firebase Console |
| App startup time (p95) | <5000ms | Not explicitly tracked | Firebase Performance |
| Screen load time (p95) | <2000ms | `traceScreenLoad` traces | Firebase Performance |
| HTTP response time (p95) | <3000ms | `traceHttpRequest` traces | Firebase Performance |
| Frame rate | 60fps (16ms) | `PerformanceMonitoringService` thresholds | In-app monitoring |

### Score Rationale: 9/12

Excellent three-layer monitoring, GDPR-compliant analytics, comprehensive error handling with Crashlytics, and structured audit logging. Loses points only for missing formal SLO/alerting documentation.

---

## Dimension 6: Development Workflow — 7/8

### Strengths

**Setup automation:**
- `scripts/setup.sh` (95 lines): Flutter version check, `.env` creation, `flutter pub get`, lefthook install, `flutter analyze`
- `scripts/setup.ps1` (102 lines): Windows PowerShell equivalent
- `scripts/validate-commit-msg.js` (52 lines): Conventional commit enforcement

**Pre-commit hooks** (`lefthook.yml`):
- `dart format --set-exit-if-changed {staged_files}` (parallel, auto-stage fixes)
- `flutter analyze --no-fatal-infos` (non-blocking for infos)
- `node scripts/validate-commit-msg.js` on commit-msg

**Developer tooling inventory:**

| Tool | Purpose | Location |
|------|---------|----------|
| `scripts/setup.sh` / `setup.ps1` | Environment setup | `scripts/` |
| `scripts/run_e2e_tests.sh` | E2E test runner with tier selection | `scripts/` |
| `scripts/validate-commit-msg.js` | Conventional commit validation | `scripts/` |
| `scripts/migrate_tag_configs.dart` | Config migration (1134 lines) | `scripts/` |
| `tools/validate_architecture.dart` | Architecture compliance (225 lines) | `tools/` |
| `tools/sync_ingredients.dart` | CSV→Firestore sync (428 lines) | `tools/` |
| `lefthook.yml` | Git hook manager | Root |
| `build_runner` | Code generation | Dev dependency |
| 4 test templates | Test scaffolding | `test/templates/` |

**Branching**: GitHub Flow (main + feature branches). Push/PR triggers on `main` and `develop`. Conventional commits enforced.

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F6-1: Branch protection not documented | Low | GitHub branch protection rules not visible in repo. Likely configured in GitHub settings but not as code. |

### Score Rationale: 7/8

Excellent DX with cross-platform setup scripts, lefthook hooks, conventional commits, architecture tooling, and test templates. Nearly perfect for a single-developer project.

---

## Dimension 7: Incident Response — 4/10

### What Exists

**Detection mechanisms:**
- Crashlytics: Crash-free rate monitoring, new crash type detection, crash velocity tracking
- Firebase Performance: Screen load, HTTP response, startup time monitoring
- GitHub Actions: CI failure notifications
- Dependabot: Weekly dependency update PRs

**Notification channels:**
- GitHub notifications (CI failures, Dependabot PRs)
- Firebase Console alerts (Crashlytics, Performance — manual configuration)
- **No Slack/Teams integration**
- **No PagerDuty/Opsgenie**
- **No email alerts configured in code**

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F7-1: No incident playbooks | High | No documented procedures for crash spikes, data breaches, Firebase outages, or failed deployments. |
| F7-2: No escalation matrix | High | No defined response times, priority levels, or escalation paths. |
| F7-3: No notification routing | Medium | All alerts go through Firebase Console or GitHub — no centralized incident management. |
| F7-4: No post-incident process | Medium | No retrospective/postmortem template, no action item tracking, no knowledge base. |
| F7-5: No on-call rotation | Low | Single developer project — acceptable now but will need structure when team grows. |

### Alerting Configuration (Estimated from Code)

| Alert | Threshold | Source | Channel |
|-------|-----------|--------|---------|
| Build failure | Any | GitHub Actions | GitHub notifications |
| Test failure | Any | GitHub Actions | GitHub notifications |
| Crash-free rate drop | Configured in Console | Crashlytics | Firebase Console |
| New crash type | First occurrence | Crashlytics | Firebase Console |
| Dependabot PR | Weekly | Dependabot | GitHub notifications |
| Screen load p95 | Configured in Console | Firebase Performance | Firebase Console |

### Score Rationale: 4/10

Detection mechanisms exist through Crashlytics and Performance Monitoring, but no documented playbooks, escalation paths, or structured notification routing. Single-developer context makes this partially acceptable.

---

## Dimension 8: CI/CD Security — 7/10

### Strengths

**Secrets management:**
- **No hardcoded secrets** in Dart source code
- All API keys loaded from environment variables via `FirebaseConfig` (`lib/core/config/firebase_config.dart`)
- `.env` files correctly in `.gitignore`
- GitHub Actions uses only 1 secret: `CODECOV_TOKEN` (`test.yml:47`)
- Disabled workflow references `FIREBASE_SERVICE_ACCOUNT` and `GITHUB_TOKEN` (`.flutter_ci.yml.disabled:341,122`)

**Supply chain security:**
- `pubspec.lock` committed to git (verified via `git ls-files`)
- Dependabot configured for both pub and GitHub Actions (`dependabot.yml`)
- Weekly updates on Monday (pub at 06:00, Actions at 06:30 CET)
- Grouped updates: Firebase, testing, minor/patch separated
- Reviewer assigned: `Malingisslen`
- PR limits: 5 pub, 3 Actions

**Firebase rules version-controlled:**
- `firestore.rules` (1,465 lines, 74 match rules)
- `storage.rules` (61 lines)
- Both tracked in git, referenced in `firebase.json`

**Security dependencies:**
- `http_certificate_pinning` — MITM protection
- `flutter_jailbreak_detection` — Root/jailbreak detection
- `flutter_secure_storage` — Platform keychain/keystore
- `sqlcipher_flutter_libs` — Encrypted local DB
- `firebase_app_check` — Bot protection (PlayIntegrity, DeviceCheck, reCAPTCHA v3)

**Audit logging**: `FirebaseAuditRepository` with immutable, write-only (user), read-only (admin) model.

### Gaps

| Finding | Severity | Detail |
|---------|----------|--------|
| F8-1: Firebase API keys in repo | Medium | `google-services.json` and `GoogleService-Info.plist` contain API keys. These are **public by design** (Firebase relies on rules, not key secrecy), but could be moved to CI-generated files. |
| F8-2: No secrets rotation process | Medium | No documented process for rotating API keys, Firebase credentials, or Codecov token. |
| F8-3: No vulnerability scanning | Medium | No `osv-scanner`, no Snyk, no dependency audit in CI. Dependabot handles version updates but not CVE scanning. |
| F8-4: Firebase rules deployed manually | Medium | `firebase deploy --only firestore:rules` is manual. No CI deployment or diff preview. |

### Score Rationale: 7/10

Good fundamentals: no hardcoded secrets, lock file committed, Dependabot configured, security dependencies present, audit logging. Loses points for no vulnerability scanning, manual rules deployment, and no secrets rotation process.

---

## CI/CD Pipeline Diagram (Current State)

```
Developer Workstation
  │
  ├── lefthook pre-commit ──→ dart format + flutter analyze
  ├── lefthook commit-msg ──→ conventional commit validation
  │
  └── git push ──→ GitHub
                    │
                    ├── analyze.yml ──→ flutter analyze + dart format
                    │
                    ├── test.yml ──→ unit/widget/view tests ──→ Codecov
                    │              └──→ integration tests (Firebase emulators)
                    │
                    ├── build-validation.yml ──→ strict analyze + arch tests
                    │                         └──→ Android APK + Web build
                    │
                    ├── architecture-validation.yml ──→ validate_architecture.dart
                    │                                └──→ PR comment with metrics
                    │
                    └── e2e_tests.yml ──→ mock tier + emulator tier
                                       (also nightly at 2 AM UTC)

  ╔═══════════════════════════════════════════╗
  ║  MISSING: No deployment pipeline          ║
  ║  No staging → No production → No stores   ║
  ╚═══════════════════════════════════════════╝
```

## Test Automation Matrix

```
Trigger       │ analyze │ test   │ build-val │ arch-val │ e2e
──────────────┼─────────┼────────┼───────────┼──────────┼────────
Push main     │   ✓     │   ✓    │    ✓      │    ✓     │   ✓
Push develop  │   ✓     │   ✓    │    ✓      │    ✓     │   ✓
PR → main     │   ✓     │   ✓    │    ✓      │    ✓     │   ✓
PR → develop  │   ✓     │   ✓    │    ✓      │    ✓     │   ✗
Nightly       │   ✗     │   ✗    │    ✗      │    ✗     │   ✓
Manual        │   ✗     │   ✗    │    ✗      │    ✓     │   ✓
```

## Production Readiness Blockers

| # | Blocker | Severity | Effort | Detail |
|---|---------|----------|--------|--------|
| 1 | Placeholder package name | **Critical** | 2-4h | `com.example.butlery` in 8+ files across Android, iOS, macOS, Linux, `.env` |
| 2 | Debug signing only | **Critical** | 2-4h | Generate production keystore (Android), configure Team ID + provisioning (iOS) |
| 3 | No automated deployment | **Critical** | 2-5 days | Implement Fastlane or equivalent for Android + iOS + beta distribution |
| 4 | No Firestore backups | **Critical** | 30 min | Enable PITR + scheduled backups in Firebase Console |
| 5 | Single Firebase project | High | 1-2 days | Create dev/staging projects, configure `.firebaserc`, environment-specific configs |
| 6 | No AAB format | High | 1h | Change `flutter build apk` to `flutter build appbundle` in `build-validation.yml` |

## Quick Wins vs Strategic Improvements

### Quick Wins (< 1 day effort, high impact)

| Item | Effort | Impact | Action |
|------|--------|--------|--------|
| Enable Firestore PITR | 10 min | **Critical** — enables 7-day, minute-granularity recovery | Firebase Console → Database → PITR |
| Enable scheduled backups | 10 min | **Critical** — daily exports, 14-week retention | Firebase Console → Database → Backups |
| Add coverage enforcement | 30 min | High — prevents regression | Add threshold to `test.yml` or Codecov config |
| Fix upload-artifact v3→v4 | 15 min | Low — prevents deprecation warnings | Update `test.yml:52,136` |
| Add AAB build | 15 min | High — required for Play Store | Change `build apk` → `build appbundle` in `build-validation.yml` |

### Strategic Improvements (multi-day, foundational)

| Item | Effort | Impact | Priority |
|------|--------|--------|----------|
| Change package name | 2-4h | **Critical** — store submission blocker | P0 |
| Set up production signing | 2-4h | **Critical** — store submission blocker | P0 |
| Implement Fastlane | 2-5 days | **Critical** — automated deployment | P0 |
| Create dev/staging Firebase projects | 1-2 days | High — environment isolation | P1 |
| Firebase App Distribution | 4h | High — beta testing pipeline | P1 |
| Add incident playbooks | 1 day | High — operational readiness | P1 |
| CI-managed Firebase rules deployment | 4h | Medium — rules deployment safety | P2 |
| Add vulnerability scanning (osv-scanner) | 2h | Medium — supply chain security | P2 |
| iOS CI builds | 4h | Medium — requires macOS runner | P2 |
| SLO documentation | 4h | Medium — formalize existing monitoring | P2 |
| Automated version bumping | 4h | Low — nice to have | P3 |
| DORA metrics tracking | 2h | Low — data-driven improvement | P3 |

---

## Appendix A: Workflow File Reference

| File | Lines | Last Confirmed |
|------|-------|----------------|
| `.github/workflows/analyze.yml` | 51 | 2026-02-26 |
| `.github/workflows/test.yml` | 139 | 2026-02-26 |
| `.github/workflows/build-validation.yml` | 113 | 2026-02-26 |
| `.github/workflows/architecture-validation.yml` | 113 | 2026-02-26 |
| `.github/workflows/e2e_tests.yml` | 123 | 2026-02-26 |
| `.github/workflows/.flutter_ci.yml.disabled` | ~350 | Disabled |
| `.github/dependabot.yml` | 78 | 2026-02-26 |
| `lefthook.yml` | ~20 | 2026-02-26 |
| `android/app/build.gradle.kts` | 69 | 2026-02-26 |
| `firestore.rules` | 1,465 | 2026-02-26 |
| `storage.rules` | 61 | 2026-02-26 |

## Appendix B: Infrastructure File Reference

| File | Lines | Purpose |
|------|-------|---------|
| `lib/core/mixins/error_handling_mixin.dart` | 606 | Retry, error classification, DNS resilience |
| `lib/core/mixins/firebase_service_mixin.dart` | 817 | Firebase connection management, DNS fallback |
| `lib/core/rate_limiting/rate_limiter.dart` | 410 | Client-side token bucket, 41 operation types |
| `lib/services/backup_service.dart` | 330 | Local JSON recipe export/import |
| `lib/services/performance/performance_monitoring_service.dart` | — | Frame, network, cache, memory monitoring |
| `lib/services/performance/firebase_performance_service.dart` | — | Custom Firebase Performance traces |
| `lib/services/monitoring/app_monitoring_service.dart` | — | Business metrics, error severity, health checks |
| `lib/services/analytics_service.dart` | — | GDPR-compliant analytics facade |
| `lib/repositories/firebase/firebase_audit_repository.dart` | — | GDPR Article 30 audit logging |
| `lib/main.dart:110-159` | — | Error handler setup (Crashlytics, zones) |

## Appendix C: Codebase Scale

| Metric | Value |
|--------|-------|
| Dart source files | 1,052 |
| Lines of Dart code | 330,406 |
| Test files | 460 |
| Production dependencies | 67 |
| Dev dependencies | 24 |
| Cloud Functions | 19+ |
| Firestore rules | 1,465 lines, 74 match rules |
| Composite indexes | 34 |
