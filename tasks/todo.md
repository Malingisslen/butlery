# Sprint Backlog

## Sprint: forward web critical errors to WebErrorReporter — 2026-06-28

Single clean Tier-A observability fix (Dart-only). No UI.

### Agent A: web error observability (direct) — Stakeholders: Customer Support/Ops, DevOps/SRE
- [x] **A1. AppMonitoringService.recordError forwards error/critical to WebErrorReporter on web** `[Tier A]` (BUT-1405)
  - Step 0: CONFIRMED. `app_monitoring_service.dart:69` recordError early-returns on kIsWeb (no
    Crashlytics web SDK), so deliberate recordError(severity:critical) business errors are dropped on
    web — only uncaught FlutterError/PlatformDispatcher errors reach WebErrorReporter (main.dart:237).
    WebErrorReporter.reportError(error, stack, {fatal, context}) is the sink (consent-gated, PII-scrubbed).
    It's created ad-hoc in main.dart, not in DI → inject one into AppMonitoringService.
  - Files: `lib/services/monitoring/app_monitoring_service.dart`, `lib/core/di/modules/performance_module.dart`, test.
  - Acceptance: recordError on kIsWeb forwards error+critical severities to WebErrorReporter.reportError
    with fatal = (severity==critical) and context = category (instead of silently returning) · info/warning
    not forwarded (avoid flooding the rate-limited logWebError) · native path unchanged · DI provides a
    WebErrorReporter on web only · a unit test pins the severity-forward policy (kIsWeb branch itself is
    untestable under the VM runner — kIsWeb is a compile-time false there) · analyze clean.

### Post-Sprint Steps
- [ ] dart analyze + run the new test · Phase 2.7 verifier · code-reviewer + testing-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1407 (ac9ffb80d), BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
