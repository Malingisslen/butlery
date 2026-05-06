# Infrastructure & Operations Analysis

**Prompt**: 03 of 06
**Analyst**: Claude (Opus 4.7)
**Consolidates**: CI/CD Analysis, Testing Analysis, Monitoring Analysis, Disaster Recovery Analysis

## Mission

Perform a comprehensive DevOps lifecycle audit of the Butlery Flutter application covering
build automation, test strategy, deployment pipeline, monitoring infrastructure, and disaster
recovery. This investigation evaluates operational maturity across the full software delivery
and production operations lifecycle.

## Two-Phase Approach

### Phase 1: Investigation and Documentation (THIS PHASE)

Document everything, change nothing.

- Investigate all 8 dimensions systematically
- Document findings with file:line references
- Build inventories, diagrams, and matrices
- ZERO code changes, ZERO pipeline modifications, ZERO configuration changes
- Output: Complete analysis report with scored findings

### Phase 2: Smart Remediation Planning (AFTER Phase 1 Complete)

- Review ALL Phase 1 findings
- Prioritize improvements by impact, effort, and risk
- Create phased implementation plan with cost estimates
- Plan with minimal disruption to current workflow

DO NOT START PHASE 2 UNTIL PHASE 1 IS COMPLETE.

## Cross-Prompt Boundaries

- **App store compliance**: Covered in prompt 06 (User Experience and Platform). Skip here.
- **Firebase security rules analysis**: Covered in prompt 02 (Security and Compliance). Reference only.
- **Dependency CVEs and licenses**: Covered in prompt 05 (Dependencies and Supply Chain). Skip here.
- **Test coverage and strategy**: Owned by THIS prompt. Other prompts defer here.
- **CI/CD pipeline design**: Owned by THIS prompt.
- **Monitoring and observability**: Owned by THIS prompt.
- **Disaster recovery**: Owned by THIS prompt.

---

## Known Project Context

```
Firebase project:    butlery-app-1 (single project, no .firebaserc)
Flutter version:     3.32.4 (pinned via FLUTTER_VERSION env var)
CI/CD platform:      GitHub Actions (5 active workflows)
Dependabot:          Weekly updates (Monday 06:00 CET), grouped by category
Static analysis:     flutter_lints + custom_lint + very_good_analysis
Test coverage:       ViewModels 100%, Services 96%, Firebase Repos 88%
Integration tests:   13 tests
GDPR:                Phase 1 complete (Articles 7, 15, 17, 30)
Firestore rules:     1465 lines, 74 match rules
Storage rules:       61 lines
Composite indexes:   34
```

---

## Dimension 1: Build Pipeline and Automation (15 points)

### Investigation Scope

Build automation, CI configuration, build performance, artifact management, platform builds.

### Investigation Tasks

**1.1 GitHub Actions Workflow Audit**

Audit each of the 5 active workflows in `.github/workflows/`:

| Workflow | Purpose |
|----------|---------|
| `analyze.yml` | Static analysis and formatting checks |
| `test.yml` | Unit, widget, and integration tests |
| `build-validation.yml` | Strict analysis and platform builds (Android/iOS/web) |
| `architecture-validation.yml` | Custom architecture validation with PR comments |
| `e2e_tests.yml` | Mock/emulator tier E2E tests |

Also note the disabled legacy workflow: `.flutter_ci.yml.disabled`.

For each workflow, document:
- Trigger conditions (push, PR, tag, schedule)
- Branch protection rules
- Build matrix (debug/release, platforms)
- Environment variables and secrets references
- Flutter version pinning (confirm FLUTTER_VERSION = 3.32.4 across all 5)
- Build steps and execution order
- Concurrency settings and job dependencies

**1.2 Build Performance Analysis**

Document build duration metrics:
- Full build time (cold cache)
- Incremental build time (warm cache)
- Test execution time per workflow
- Total pipeline time (commit to green)

Analyze caching strategy:
- Dependency caching (pub cache)
- Flutter build cache
- GitHub Actions cache hit rates
- Parallelization across jobs

**1.3 Artifact Management**

Review artifact handling for each build type:
- APK files (Android debug/release)
- AAB files (Android App Bundle -- mandatory for Play Store)
- IPA files (iOS release)
- Debug symbols (dSYMs, symbols.zip)
- Coverage reports (lcov format)
- Build logs

Document: artifact storage location, retention policy, versioning scheme, size trends.

**1.4 Platform Build Configuration**

Android (review `android/app/build.gradle.kts` -- Kotlin DSL):
- Gradle version and plugins
- compileSdk / targetSdk (must be 35 since August 2025)
- Build variants and flavors
- ProGuard/R8 configuration (currently disabled)
- Signing configurations (debug keystore only -- no production signing)
- 16KB memory page alignment for Android 15+
- AAB output format (required for Play Store)

iOS (review `ios/Runner.xcodeproj`):
- Xcode version requirements
- Provisioning profiles and code signing certificates
- Build schemes and configurations
- CocoaPods / Swift Package Manager

**1.5 Build Failure Patterns**

Common failure types, notification channels, retry mechanisms, flaky build identification.

---

## Dimension 2: Testing Strategy and Coverage (15 points)

### Investigation Scope

Test execution in CI, coverage tracking, test infrastructure, test pyramid, Firebase testing,
flaky test management.

### Investigation Tasks

**2.1 Test Execution in CI**

Document how tests execute across workflows:

| Test Type | Workflow | Trigger | Blocking |
|-----------|----------|---------|----------|
| Unit tests | test.yml | PR, push | Yes/No |
| Widget tests | test.yml | PR, push | Yes/No |
| Integration tests | test.yml | PR, push | Yes/No |
| E2E tests (mock) | e2e_tests.yml | PR, push | Yes/No |
| E2E tests (emulator) | e2e_tests.yml | Manual/Schedule | Yes/No |

Review: test timeout settings, retry logic, test environment setup, sharding.

**2.2 Coverage Tracking**

Review coverage tracking setup:
- `flutter test --coverage` configuration
- Coverage report generation (lcov)
- Coverage thresholds (overall minimum, file-level requirements)
- PR coverage delta checks (increase/decrease enforcement)
- Coverage reporting tools (Codecov, Coveralls, or built-in)
- Coverage trend tracking over time

Current known state:

| Layer | Coverage | Target |
|-------|----------|--------|
| ViewModels | 100% | 95%+ |
| Services | 96% | 90%+ |
| Firebase Repositories | 88% | 85%+ |
| Integration | 13 tests | 30+ tests |

**2.3 Test Pyramid Balance**

Assess actual distribution against targets:
- Unit tests: ~70% target
- Widget tests: ~20% target
- Integration tests: ~10% target

Identify imbalances and their impact on feedback speed and confidence.

**2.4 Test Infrastructure**

Inventory existing test infrastructure:

| Tool | Purpose | Location |
|------|---------|----------|
| MockTail | Type-safe mocking | test dependencies |
| FakeFirestore | Firestore testing without emulator | fake_cloud_firestore |
| RepositoryTestBase | Base class for repository tests | test/infrastructure/ |
| ServiceTestBase | Base class for service tests | test/infrastructure/ |
| TestDataFactory | Test data builders | test/infrastructure/ |
| production_mocks.dart | Centralized mock definitions | test/infrastructure/mocks/ |
| fallback_values.dart | MockTail fallback registrations | test/infrastructure/mocks/ |
| Stream test utilities | Async stream testing | test/infrastructure/ |

Verify: mock completeness, builder coverage for all models, TestServiceLocator pattern usage,
production ServiceLocator bridge pattern (see MEMORY.md).

**2.5 Firebase Testing Strategy**

Review Firebase testing approach:
- FakeFirestore usage patterns vs mock-based testing
- Security rules testing (emulator-based or skipped?)
- Stream/real-time listener testing patterns
- Auth testing approach (firebase_auth_mocks)
- Storage testing approach

**2.6 Test Performance and Reliability**

Document:
- Total test suite execution time
- Slowest test files (>1s for unit, >10s for integration)
- Flaky test identification and tracking
- Test isolation issues (shared state, execution order)
- fakeAsync patterns for debounced ViewModel methods (300ms debounce)

**2.7 Three-Tier E2E Strategy**

Assess the three tiers: mock (70%), emulator (25%), staging (5%).
Check proper tier distribution and `scripts/run_e2e_tests.sh` configuration.

---

## Dimension 3: Deployment and Release (15 points)

### Investigation Scope

Deployment pipeline, environment management, approval gates, rollback, version management,
staged rollouts, app store readiness.

### Investigation Tasks

**3.1 Deployment Pipeline Audit**

Document current deployment process (or lack thereof):
- Internal testing distribution (Firebase App Distribution, TestFlight)
- Beta testing pipeline (Google Play Beta, TestFlight)
- Production deployment (Google Play, App Store)
- Environment promotion flow (dev -> staging -> prod)

CRITICAL: Verify whether ANY automated deployment exists. Known blocker:
no Fastlane, no store upload workflows.

**3.2 Environment Management**

Document environment configuration:
- Firebase projects per environment: butlery-app-1 only (single project, no .firebaserc)
- Environment-specific config files (.env, flavor-based)
- API endpoints per environment
- Feature flags per environment

Analyze: environment parity (dev vs prod), secrets management, configuration drift.

**3.3 Deployment Approval Gates**

Review quality gates before deployment:

| Gate | Automated | Blocking | Status |
|------|-----------|----------|--------|
| All tests passing | Yes/No | Yes/No | |
| Code review approved | Yes/No | Yes/No | |
| Security scan passed | Yes/No | Yes/No | |
| Architecture validation | Yes/No | Yes/No | |
| Manual QA sign-off | Yes/No | Yes/No | |
| Coverage threshold met | Yes/No | Yes/No | |

**3.4 Rollback Capabilities**

Assess rollback for each scenario:
- App rollback (revert to previous store version)
- Firestore PITR (7-day window, minute granularity) -- check if enabled on butlery-app-1
- Firestore scheduled backups -- check if configured
- Firebase rules rollback (manual vs CI-managed)
- Data consistency during rollback
- RTO for each rollback type

**3.5 Version Management**

Review versioning in `pubspec.yaml`:
- Semantic versioning scheme (major.minor.patch+build)
- Version bumping process (manual or automated)
- Build number automation
- Git tag creation and changelog generation
- Version consistency across platforms

**3.6 Release Notes and Staged Rollouts**

Audit release notes (source, localization, app store descriptions).
Document phased rollout strategy: percentages, crash monitoring per phase, rollback triggers.
Evaluate Shorebird for OTA code push.

**3.7 Production Readiness Blockers (CRITICAL)**

These must be resolved before any app store submission:

| Blocker | Severity | Details |
|---------|----------|---------|
| No automated deployment | Critical | No Fastlane, no store upload workflows |
| Placeholder package name | Critical | `com.example.butlery` in 8+ files |
| Debug signing only | Critical | No production keystore or iOS certificates |
| No ProGuard/minification | Medium | R8/ProGuard disabled in release builds |
| Single Firebase project | Medium | No dev/staging/prod separation |
| No Firestore PITR | Medium | No point-in-time recovery configured |
| No Firestore scheduled backups | Medium | No automated backup/export schedule |


---

## Dimension 4: Backup and Disaster Recovery (15 points)

### Investigation Scope

Firestore PITR, scheduled backups, recovery playbooks, RTO/RPO targets, business continuity,
single points of failure.

### Investigation Tasks

**4.1 Firebase Backup Assessment**

Check the following on the butlery-app-1 project:

| Feature | Status | Quick Win |
|---------|--------|-----------|
| Firestore PITR (7-day, minute granularity) | Check if enabled | Yes -- minutes to enable |
| Firestore Scheduled Backups (daily/weekly, 14-week retention) | Check if configured | Yes -- minutes to configure |
| Firebase Storage backups | Check | No |
| Firebase Auth export | Check | No |

Best practice: Use BOTH PITR and scheduled backups together.
PITR for recent accidents (7-day window), scheduled backups for longer retention.

Also investigate:
- `BackupService` at `lib/services/backup_service.dart` -- scope and capabilities
- Any Cloud Functions for backup automation
- Manual export processes

**4.2 Recovery Playbooks**

Document recovery procedures for each scenario:

| Scenario | Detection | Recovery Method | Estimated RTO |
|----------|-----------|-----------------|---------------|
| Data corruption | Crashlytics alert, user reports | PITR restore (if enabled) | 4-8h |
| Accidental deletion | User report | PITR or scheduled backup | 4-8h |
| Security breach | Monitoring alert | Isolate, restore, rotate creds | 24-48h |
| Firebase region outage | Status page, error spike | Wait or failover | Depends |
| Code deployment bug | Crashlytics crash spike | Rollback app version | 1-2h |

For each scenario: detection method, assessment checklist, recovery steps (with PITR,
with scheduled backup, without backups), verification checklist, communication plan.

**4.3 RTO/RPO Analysis**

Define current vs target recovery objectives:

| Function | Target RTO | Current RTO | Target RPO | Current RPO |
|----------|------------|-------------|------------|-------------|
| User authentication | 4h | Investigate | 0 | 0 (Firebase Auth) |
| Recipe access (read) | 4h | Investigate | 1h | Investigate |
| Recipe creation (write) | 8h | Investigate | 1h | Investigate |
| Shopping lists | 8h | Investigate | 4h | Investigate |
| Social features | 24h | Investigate | 24h | Investigate |

With PITR enabled: RPO = minutes. With daily scheduled backups: RPO = 24h.
Without backups: RPO = infinity (complete data loss possible).

**4.4 Single Points of Failure**

| SPOF | Blast Radius | Redundancy | Priority |
|------|--------------|------------|----------|
| Single Firebase project (butlery-app-1) | Total app failure | None | Critical |
| No environment separation | Prod risk from dev errors | None | Critical |
| Single Firebase admin account | Account lockout | Investigate | High |
| Single code signing certificate | Cannot deploy | None | Medium |
| Single backup location | Data loss | None | High |

**4.5 Business Continuity**

Document existing resilience patterns:
- Offline persistence: ENABLED (persistenceEnabled: true, CACHE_SIZE_UNLIMITED)
- ErrorHandlingMixin: see `docs/architecture/adoption-status.md` (BUT-810; auto-generated)
- DNS-aware resilience: `executeFirebaseOperationWithDNSResilience()`
- Circuit breaker-like patterns: via FirebaseServiceMixin
- Rate limiting: `lib/core/rate_limiting/rate_limiter.dart`
- Soft delete/archival: present in some models

Assess degraded operation modes:
- Read-only mode (offline cache serving)
- Maintenance mode capability
- Emergency shutdown procedure

**4.6 Data Export (GDPR)**

Verify backup retention respects right to erasure (Article 17).
Reference: DataExportService (14 tests), AccountDeletionService (15 tests),
ConsentService (38 tests).


---

## Dimension 5: Monitoring and Observability (12 points)

### Investigation Scope

Error tracking, performance monitoring, analytics, logging strategy, SLOs/SLIs, dashboards.

### Investigation Tasks

**5.1 Error Tracking**

Document error tracking integrations:
- Crashlytics integration and configuration
- `FlutterError.onError` handler setup
- `PlatformDispatcher.onError` handler setup
- `Zone.runZonedGuarded` usage
- ErrorHandlingMixin error reporting (see `docs/architecture/adoption-status.md`)
- Error grouping, tagging, and context capture (breadcrumbs, device info)

**5.2 Performance Monitoring**

Audit Firebase Performance Monitoring:
- Custom performance traces (Trace.start/stop)
- App startup time tracking
- Screen transition time tracking
- Network request duration tracking
- Frame rate monitoring (jank detection)
- `lib/services/performance/performance_monitoring_service.dart`
- `lib/services/performance/firebase_performance_service.dart`

**5.3 Analytics**

Document Firebase Analytics integration:
- Custom event tracking (FirebaseAnalytics.logEvent calls)
- Screen view tracking
- User journey tracking completeness
- Event naming conventions and consistency
- User property tracking
- PII exclusion from analytics events

**5.4 Logging Strategy**

Audit logging across the codebase:
- Logging framework in use (logger package, custom, or print statements)
- Log level usage (debug, info, warning, error)
- Production vs debug logging (kDebugMode checks)
- Sensitive data protection in logs (PII, auth tokens, passwords)
- Log aggregation and centralization approach

CRITICAL: Search for PII in log statements (emails, tokens, user names).

**5.5 SLOs and SLIs**

Document defined targets:

| SLI | Target SLO | Measurement |
|-----|------------|-------------|
| Availability (crash-free users) | 99.9% | Crashlytics |
| App startup time (p95) | <5000ms | Firebase Performance |
| Screen load time (p95) | <2000ms | Firebase Performance |
| HTTP response time (p95) | <3000ms | Firebase Performance |
| Frame rate | 60fps | Performance monitoring |

Reference existing docs:
- `docs/operations/SLO_DEFINITIONS.md` (99.9% target, error budgets)
- `docs/operations/FIREBASE_ALERTING_GUIDE.md`
- Crashlytics alerts: crash-free <99.5% = P0, new crash type = P1, velocity >10/hr = P1
- Performance alerts: screen load p95 >2000ms, HTTP p95 >3000ms, startup p95 >5000ms

**5.6 Custom Dashboards**

Review Firebase Console dashboard usage, cost monitoring and budget alerts,
real-time vs historical metrics visibility, stakeholder-specific views.
Reference: `lib/services/monitoring/app_monitoring_service.dart`.


---

## Dimension 6: Development Workflow (8 points)

### Investigation Scope

Branching strategy, local dev setup, developer tooling, hot reload workflow, DX friction.

### Investigation Tasks

**6.1 Branching Strategy**

Document Git workflow:
- GitHub Flow / Git Flow / trunk-based development
- Branch naming conventions
- Branch lifecycle (creation, development, review, merge, deletion)
- Protected branches and merge requirements
- Merge vs rebase strategy

**6.2 Local Development Setup**

Audit developer setup scripts:
- `scripts/setup.sh` (Unix/macOS)
- `scripts/setup.ps1` (Windows PowerShell)

Document setup steps: Flutter SDK, IDE, clone, dependencies, environment config,
emulator/simulator setup, Firebase configuration.

Assess: onboarding time for new developer, common setup issues, setup documentation quality.

**6.3 Developer Tooling Inventory**

| Tool | Purpose | Location |
|------|---------|----------|
| `scripts/setup.sh` / `setup.ps1` | Environment setup | scripts/ |
| `scripts/run_e2e_tests.sh` | E2E test runner | scripts/ |
| `scripts/validate-commit-msg.js` | Commit message validation | scripts/ |
| `scripts/migrate_tag_configs.dart` | Data migration | scripts/ |
| `tools/validate_architecture.dart` | Architecture validation + PR comments | tools/ |
| `tools/code_intelligence_platform.dart` | Code metrics | tools/ |
| Pre-commit hooks | Formatting, linting | .husky or similar |
| build_runner | Code generation | dev dependency |

**6.4 Hot Reload, Debugging, and Developer Experience**

Assess: hot reload effectiveness, Flutter DevTools usage, local build-and-run cycle time.
Identify DX friction points: slow builds, flaky local tests, environment config issues,
dependency resolution problems, platform-specific issues.


---

## Dimension 7: Incident Response (10 points)

### Investigation Scope

Alerting, notification channels, escalation, incident playbooks, post-incident process.

### Investigation Tasks

**7.1 Alerting Configuration**

Document all configured alerts:

| Alert | Threshold | Severity | Channel | Source |
|-------|-----------|----------|---------|--------|
| Build failure | Any | - | GitHub notifications | GitHub Actions |
| Test failure | Any | - | GitHub notifications | GitHub Actions |
| Crash-free rate drop | <99.5% | P0 | Investigate | Crashlytics |
| New crash type | First occurrence | P1 | Investigate | Crashlytics |
| Crash velocity | >10/hr | P1 | Investigate | Crashlytics |
| Screen load p95 | >2000ms | P2 | Investigate | Firebase Performance |
| HTTP p95 | >3000ms | P2 | Investigate | Firebase Performance |
| Startup p95 | >5000ms | P2 | Investigate | Firebase Performance |
| Dependabot PR | Weekly | - | GitHub | Dependabot |

**7.2 Notification Channels**

Review notification routing:
- Email notifications
- Slack/Teams integration (if any)
- GitHub notifications
- Mobile push for critical failures

Analyze: notification noise vs signal ratio, deduplication.

**7.3 Escalation Procedures**

Document existing escalation matrix:

| Priority | Response Time | Criteria |
|----------|---------------|----------|
| P0 | 15 minutes | Total outage, data loss, crash-free <99.5% |
| P1 | 4 hours | Major feature broken, new crash type, velocity >10/hr |
| P2 | 24 hours | Performance degradation, minor feature broken |

**7.4 Incident Playbooks**

Document or assess existence of playbooks for:
- App crash spike (sudden increase in crash reports)
- Data breach or security incident
- Service degradation (Firebase outage)
- Failed deployment with user impact
- Data corruption discovery

For each: detection, assessment, response steps, verification, communication, post-incident.

**7.5 Post-Incident Process**

Review retrospective/postmortem process, root cause analysis documentation,
action item tracking, and knowledge sharing.


---

## Dimension 8: CI/CD Security (10 points)

### Investigation Scope

Secrets management, code signing, supply chain security, Firebase rules deployment,
audit logging, Dependabot configuration.

### Investigation Tasks

**8.1 Secrets Management**

Audit secrets handling in CI:
- GitHub Secrets inventory (API keys, Firebase credentials, store credentials)
- Secrets rotation process and frequency
- Secrets exposure risks (logs, artifacts, environment variables)
- No hardcoded secrets in repository (search for API keys, tokens)

**8.2 Code Signing Security**

Review signing certificate management:
- Android: debug keystore only (CRITICAL -- no production keystore)
- iOS: provisioning profiles and certificates (investigate status)
- Certificate expiration tracking
- Certificate access control and storage

**8.3 Supply Chain Security**

Audit dependency integrity:
- `pubspec.lock` committed to repository (verify)
- Dependency pinning strategy (exact versions vs ranges)
- Checksum verification capability
- Private package registry usage (if any)
- Build reproducibility assessment

**8.4 Dependabot Configuration**

Review `.github/dependabot.yml`:

| Package Ecosystem | Schedule | Time | Grouping | PR Limit |
|-------------------|----------|------|----------|----------|
| pub (Dart) | Weekly | Monday 06:00 CET | firebase_, testing, minor/patch | 5 |
| github-actions | Weekly | Monday 06:30 CET | - | 3 |

Reviewer: Malingisslen.

Assess: update testing strategy, breaking change handling, merge velocity.

**8.5 Firebase Rules Deployment**

Review Firebase rules management:
- Deployment method: manual (`firebase deploy --only firestore:rules`) vs CI
- Rules versioning (git-controlled: firestore.rules, storage.rules)
- Rules rollback capability
- Rules testing before deployment

**8.6 Audit Logging**

Document audit trail capabilities:
- Build logs (GitHub Actions retention)
- Deployment audit trails
- Access logs (who deployed what, when)
- `FirebaseAuditRepository` -- scope and usage


---

## Static Analysis Configuration

Reference `analysis_options.yaml`:
- Base: `package:flutter_lints/flutter.yaml`
- Plugin: `custom_lint`
- Dev dependency: `very_good_analysis: ^10.0.0`
- Architecture enforcement lint rules enabled
- Excludes: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`
- Line length > 80 chars: allowed (rule disabled)

Quality gate enforcement:
- `flutter analyze` blocking PR merge (verify)
- `dart format --set-exit-if-changed` in CI (verify)
- Architecture validation with PR comments (architecture-validation.yml)

---

## Modern Tooling Recommendations

Evaluate each tool for cost/benefit during analysis:

### Deployment Automation

| Tool | Purpose | Effort | Impact |
|------|---------|--------|--------|
| Fastlane | Automate builds, signing, store deployment | Medium | Critical -- fills largest gap |
| Firebase App Distribution | Internal/beta testing distribution | Low | High -- quick win for testing |
| Shorebird | OTA code push for Flutter (bypass store review) | Low | Medium -- fast hotfixes |

### Code Quality

| Tool | Purpose | Effort | Impact |
|------|---------|--------|--------|
| DCM (Dart Code Metrics) | 475+ rules, complexity analysis, unused code | Low | Medium -- deeper than flutter_lints |
| osv-scanner | Vulnerability scanning for Dart packages (OSS DB) | Low | Medium -- catches CVEs |

### Metrics and Observability

| Tool | Purpose | Effort | Impact |
|------|---------|--------|--------|
| DORA metrics GitHub Action | Track deployment frequency, lead time, MTTR, CFR | Low | Medium -- data-driven improvement |
| Codecov | Coverage tracking with PR comments and trends | Low | Medium |

### Data Protection

| Tool | Purpose | Effort | Impact |
|------|---------|--------|--------|
| Firestore PITR | Point-in-time recovery (7-day, minute granularity) | Low | High -- disaster recovery |
| Firestore scheduled backups | Daily/weekly exports, 14-week retention | Low | High -- data safety net |

---

## Output Format

### Executive Summary

```
INFRASTRUCTURE AND OPERATIONS ANALYSIS - PHASE 1
===================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.7)

OVERALL SCORE: __/100
DevOps Maturity Level: [1-5]

DIMENSION SCORES:
  Build Pipeline and Automation:    __/15
  Testing Strategy and Coverage:    __/15
  Deployment and Release:           __/15
  Backup and Disaster Recovery:     __/15
  Monitoring and Observability:     __/12
  Development Workflow:             __/8
  Incident Response:                __/10
  CI/CD Security:                   __/10

DORA METRICS (measure or estimate):
  Deployment Frequency:     [X per week/month]
  Lead Time for Changes:    [X hours/days from commit to production]
  Change Failure Rate:      [X%]
  Mean Time to Recovery:    [X hours]

PRODUCTION READINESS: [Ready / Blockers Remain / Not Ready]

CRITICAL FINDINGS: [count]
HIGH FINDINGS:     [count]
MEDIUM FINDINGS:   [count]
LOW FINDINGS:      [count]
```

### Required Deliverables

For each dimension: score, strengths, gaps, risk assessment, findings with severity, effort estimates.

Required diagrams and tables:
1. CI/CD pipeline diagram (source -> build -> test -> deploy)
2. Build performance benchmarks (cold/warm cache times)
3. Test automation workflow (which tests run when)
4. Deployment pipeline (current state vs target state)
5. Disaster recovery assessment (PITR status, backup status, RTO/RPO)
6. Production readiness blockers list
7. Quick wins vs strategic improvements matrix

---

## Success Criteria

Phase 1 complete when all 8 dimensions are investigated and scored, all diagrams created,
DORA metrics measured or estimated, production readiness blockers listed, and executive
summary written. ZERO code changes, ZERO pipeline modifications, ZERO configuration changes.

Documentation quality: all findings have severity ratings, all gaps have impact assessments,
all recommendations have effort estimates, confirmed facts distinguished from unknowns.

---

## Investigation Process

**Stage 1 -- Build and CI (3-4h)**: Audit all 5 workflows, build performance, artifacts, quality gates.
**Stage 2 -- Testing (3-4h)**: Test execution in CI, coverage tracking, infrastructure, Firebase testing.
**Stage 3 -- Deployment and DR (3-4h)**: Deployment pipeline, environment management, PITR/backup status, RTO/RPO, SPOF.
**Stage 4 -- Operations (2-3h)**: Monitoring, alerting, incident response, dev workflow, CI/CD security.
**Stage 5 -- Synthesis (1-2h)**: Score dimensions, DORA metrics, executive summary, prioritized findings.

Total estimated time: 12-17 hours.

---

## Critical Reminders

1. DOCUMENT, DO NOT FIX: This is investigation only
2. CHECK PITR AND BACKUPS: Firestore PITR and scheduled backups are the number one quick wins
3. PRODUCTION READINESS: Placeholder package name, debug signing, and no automated deployment are critical blockers
4. DORA METRICS: Measure deployment frequency, lead time, change failure rate, MTTR
5. SECURITY: Secrets management and code signing are critical gaps
6. SINGLE PROJECT SPOF: butlery-app-1 has no dev/staging/prod separation
7. COMPREHENSIVE: Do not skip dimensions -- completeness matters
8. FACTS OVER SPECULATION: State confirmed findings, mark unknowns explicitly
9. CREDIT EXISTING WORK: Document resilience patterns already in place (offline persistence, error handling, DNS resilience)
10. USE FILE REFERENCES: All findings must include file:line where applicable
