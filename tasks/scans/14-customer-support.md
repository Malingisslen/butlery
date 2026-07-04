# Customer Support / Operations — scan findings

Lens: ROLE_RESPONSIBILITY_MAP §14 (feedback intake reliability, error
monitoring/reporting, suggestion handling, ops visibility, kill switches /
feature flags, moderation pipeline). Owned paths only.

Dedup: skipped items already in dossier watch-items (BUT-417 email stubs,
web-error analytics-consent drop, missing Firestore-read/Auth alerts,
MODERATOR_EMAIL undeclared, Remote Config 12h kill-switch lag) and
.claude/linear-tracker.json (BUT-449 web error tracking). Findings below are NEW.

Verified against: functions/src/feedback/on-feedback-created.ts,
functions/src/feedback/on-report-created.ts,
functions/src/ingredients/on-suggestion-created.ts, firestore.rules:2027-2081,
lib/services/feedback/feedback_service.dart, lib/models/feedback_entry.dart,
lib/services/monitoring/{web_error_reporter,app_monitoring_service}.dart,
lib/services/feature_flags/feature_flag_service.dart.

---

### Feedback intake has no ops-visible fallback when the Resend email fails — silent drop
- type: bug  area: backend
- pass: 1
- finding / why / fix:
  `onFeedbackCreated` (on-feedback-created.ts:22-39) is fire-and-forget: it logs
  one `info` line then calls `notifyByEmail`, which on any failure (missing
  secret/recipient, Resend non-2xx, network throw) only emits a `logger.error`
  and returns (lines 54-60, 98-108). Unlike `onReportCreated`, it writes NO
  `system_events` doc and NO durable marker. The admin dashboard inbox reads the
  `feedback` collection directly so the doc itself survives — but the
  *notification path* has zero durable signal: if email is misconfigured or
  Resend is down, the only trace is a Cloud Logging line. There is no alert
  (the GCP policies watch CF error-rate >5% / p99, not a single logged error),
  so a beta report can sit unseen exactly as the role mandate warns against.
  This is distinct from the BUT-417 *moderation* email stub (that path is
  knowingly unimplemented; this one is implemented-but-can-silently-fail).
  Fix: on email failure write a deterministic `system_events`
  doc (`feedback_email_failed_{feedbackId}`, severity warning) so the Drift /
  ops_log surface shows undelivered feedback, mirroring onReportCreated's
  system_events pattern; or rethrow to use the trigger's at-least-once retry
  (notifyByEmail is idempotent enough — duplicate emails are a lesser evil than
  a dropped one).

### `feedback` create rule does not constrain field shape or size — unbounded-doc / cost vector
- type: security  area: backend
- pass: 1
- finding / why / fix:
  `match /feedback/{feedbackId}` create allows `isAuthenticated() &&
  isCreatingOwnDocument()` only (firestore.rules:2027-2040). There is no
  `keys().hasOnly(...)`, no `hasRequiredFields`, and no length caps on
  `description`, `email`, `screenshotUrl`, or `recentInteractions`. Compare the
  sibling collections: `ingredient_suggestions` caps `ingredientName` to 100
  chars (line 2079) and `notification_history` pins keys + caps `data` size
  (lines 2092-2097). The feedback email function's own comment
  (on-feedback-created.ts:66-73) explicitly notes "Firestore create rules don't
  constrain its shape" and defensively re-validates `screenshotUrl` server-side
  — an acknowledgement that the rule is permissive. A beta user can write a
  near-1MB feedback doc (Firestore doc cap) or a giant `recentInteractions`
  array, inflating admin-dashboard reads and Storage/Firestore cost, and the
  triage email embeds `description`/`email`/`deviceInfo` (escaped, so not XSS,
  but unbounded). Fix: add `keys().hasOnly([...])`, `hasRequiredFields(['userId',
  'category','description','createdAt'])`, a `description.size()` cap (e.g.
  ≤5000), and a `recentInteractions.size()` cap; add allow/deny cases to
  recipe-comments/feedback rules tests.

### Web error reporter is silently a no-op for every platform except web — native crashes never reach `logWebError`, and that's fine, but there is no non-web reporting path wired here
- type: ops  area: backend
- pass: 1
- finding / why / fix:
  `WebErrorReporter.reportError` returns immediately when `!kIsWeb`
  (web_error_reporter.dart:110) — correct by design (native uses Crashlytics).
  But `AppMonitoringService` (app_monitoring_service.dart) — the *only* native
  error sink — early-returns on `kIsWeb` in EVERY method
  (recordBusinessMetric:41, recordError:69, setUserProperty:153,
  logBreadcrumb:175). So business metrics and severity-tagged errors recorded
  via `AppMonitoringService.recordError(...)` from shared (non-platform-guarded)
  code produce ZERO signal on web: Crashlytics has no web SDK and the web path
  only captures uncaught `FlutterError`/`PlatformDispatcher` errors, not the
  deliberate `recordError(category, severity:critical)` calls business logic
  makes. Result: a `severity: critical` business error logged on web is dropped
  on the floor (no Crashlytics, not routed to `logWebError`). Fix: have
  `AppMonitoringService.recordError` forward to `WebErrorReporter` (or a thin
  `logWebError` call) when `kIsWeb` instead of silently returning, so
  deliberately-recorded critical errors are observable on web too.

### Ingredient-suggestion threshold has no escalation — suggestions accumulate with no ops signal beyond per-doc logs
- type: ops  area: backend
- pass: 2
- finding / why / fix:
  `onSuggestionCreated` (on-suggestion-created.ts) claims the doc, logs, and
  (when email lands) would notify per-suggestion — but unlike `onReportCreated`
  there is no aggregate counter and no `system_events` write at all. Reports get
  a `moderation_threshold_reached` critical system_event at 5 strikes
  (on-report-created.ts:111-136); suggestions get nothing comparable. With email
  stubbed (BUT-417) the ONLY way to see a backlog of pending ingredient
  suggestions is to query the collection by hand or scan Cloud Logging. For a
  crowdsourced-DB feature this means a spike of suggestions (or a single user
  spamming) is invisible to ops until someone manually looks. Fix: write a
  lightweight `system_events` doc on suggestion create (deterministic id,
  severity info) so the ops_log / Drift dashboard surfaces suggestion volume,
  and/or a daily aggregate count — cheap, deterministic, no email dependency.

### `audit_log_retention_days` Remote Config default (90) contradicts the BUT-665 tiered server policy (730/180)
- type: bug  area: backend
- pass: 2
- finding / why / fix:
  `FeatureFlagService._defaults` still ships `'audit_log_retention_days': 90`
  (feature_flag_service.dart:61) and exposes `FeatureFlags.auditLogRetentionDays`
  (line 306). Per the Privacy/DPO dossier (§5 watch-items) the authoritative
  retention is now `purgeExpiredAuditLogs` with CONSENT_RETENTION_DAYS=730 /
  GENERAL_RETENTION_DAYS=180 (BUT-665), and the legacy 90-day
  `cleanupOldAuditLogs` CF is slated for retirement. This flag is the
  Remote-Config knob the legacy CF reads — its continued presence is the
  *operational lever* behind the DPO's "dual-source drift" risk: an operator who
  tunes this flag believing it controls retention would silently re-introduce a
  90-day cutoff that conflicts with the 730/180 tiers, creating audit-trail
  gaps. From the ops/feature-flag owner's seat this is a stale lever that should
  be removed (or documented as legacy-only) once the legacy CF is retired. Fix:
  delete `audit_log_retention_days` from `_defaults` and `FeatureFlags` when
  `cleanupOldAuditLogs` is retired; until then, add an inline comment flagging it
  as legacy + non-authoritative so no operator tunes it.

### `app_maintenance_mode` kill switch and `enable_social/sharing/messaging` flags have no analytics signal when flipped — ops can't confirm propagation
- type: ops  area: backend
- pass: 2
- finding / why / fix:
  `isEnabled()` emits `feature_flag_evaluated` once per (flag,variant) per
  session (feature_flag_service.dart:126-137, 212-231). That's a *client read*
  event, not a *value-change* event. When an operator flips `app_maintenance_mode`
  or a social kill switch in Remote Config, there is no telemetry that tells ops
  how many clients have actually picked up the new value — the dossier already
  notes the 12h propagation lag, but the deeper gap is that ops has no *measure*
  of propagation at all. The per-session dedup also means a client that read the
  flag early in the session won't re-emit after a mid-session real-time update
  (`addOnConfigUpdatedListener`, line 264) unless `resetSessionDedup` is called —
  so even the read-event count understates adoption of a freshly-flipped kill
  switch. Fix: on a real-time config update (the `onConfigUpdated` listener),
  call `resetSessionDedup()` so the next reads re-emit, giving ops a rough
  client-adoption curve for a flipped kill switch; consider a distinct
  `feature_flag_changed` event when a watched safety flag's value differs from
  the last activated value.

---

COVERAGE: §14 owned paths fully read (3 Cloud Functions, feedback service +
model, content_report model, both monitoring services, feature_flag_service,
firestore.rules feedback/reports/ingredient_suggestions blocks). 6 NEW findings
(3 pass-1, 3 pass-2). All 5 existing dossier watch-items + BUT-449 confirmed
present and excluded; no new finding duplicates them.
