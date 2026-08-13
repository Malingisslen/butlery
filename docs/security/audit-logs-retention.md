# Audit Logs — Retention Policy (BUT-665)

GDPR Article 30 record covering the `audit_logs` collection.

## Status

Active. Enforced by `functions/src/audit_logs/purge-expired.ts`
(`purgeExpiredAuditLogs`), scheduled Sunday 05:00 UTC, region `europe-west1`.
**Corrected 2026-08-13.** This paragraph used to say the purge co-exists with a
legacy `cleanupOldAuditLogs` CF applying a flat Remote Config retention to the
same collection. That stopped being true at BUT-808: `cleanupOldAuditLogs`
(`functions/src/cleanup/cleanup-audit-logs.ts`) now handles only
`deletion_audit_logs`. It keeps its old export name so the deployed scheduler
binding does not churn, which is why it still reads like a second purge of
`audit_logs` and is not one. `purgeExpiredAuditLogs` is the sole enforcer.

## Retention windows

| Category | Operation values | Retention | Justification |
|---|---|---|---|
| Consent events | The five values enumerated in `CONSENT_OPERATIONS`, and only those: `consent_age_verification`, `consent_granted`, `consent_updated`, `consent_revoked`, `consent_deleted`. The purge matches by EXACT membership, not by the `consent_` prefix (it did match by prefix until BUT-1404, 2026-06-28), so a sixth spelling would silently fall into the 6-month bucket. Live writers today: `consent_age_verification` (verify-signup-age.ts) and `consent_updated` (firebase_consent_repository.dart). `consent_revoked` is the spelling `deleteConsent` emits, but that method has had no caller since BUT-788 (2026-05-22) — the token is listed so it is already classified when a caller is wired. `consent_granted` has never been written; `consent_deleted` was written 2026-04-27 to 2026-05-22 and is retained as a legacy token. | **24 months** | GDPR Art 7(1) requires the controller to *demonstrate* that the data subject consented. Swedish DPA guidance + standard legal-defence horizon = 24 months from the event. Shorter periods risk the controller being unable to evidence consent for in-flight complaints. |
| General access events | All other operations (`read`, `write`, `delete`, `tag_modified`, etc.) | **6 months** | GDPR Art 5(1)(c) — data minimisation. Six months covers SOC2-style incident-response window (typical mean-time-to-detect for cloud breaches is ~200 days; 180 day floor balances forensic value against minimisation). Longer than the 90-day default that `cleanup-audit-logs.ts` applied to this collection until BUT-808, which was set without a documented Art 30 record. |

## Per-field justification (Art 30 record)

Every field stored in `audit_logs/{id}`. If a field is added to
[`AuditLog.toFirestore`](../../lib/models/audit_log.dart) it must also be
added here.

| Field | Purpose | Lawful basis | Retention applies? |
|---|---|---|---|
| `userId` | Identify the data subject for Art 15 (right of access) | Art 6(1)(c) — legal obligation (Art 30 record) | Yes — purged by category. |
| `operation` | Categorise event (used to pick retention bucket above) | Art 6(1)(c) | Yes. |
| `resourceType` | Identify what was accessed (recipe, user, etc.) | Art 6(1)(c) | Yes. |
| `resourceId` | Identify which specific resource (nullable for bulk ops) | Art 6(1)(c) | Yes. |
| `granted` | Boolean — outcome of permission check. Required for security incident review (Art 32 — security of processing) | Art 6(1)(f) — legitimate interest in security | Yes. |
| `timestamp` | Server timestamp. Drives the retention cutoff. | Art 6(1)(c) | N/A — the purge field. |
| `expireAt` | **Not written.** `AuditLog.toFirestore` deliberately stamps no `expireAt` (removed in BUT-808; the model says so in its own header). The claim that it carries a 365-day TTL was stale and wrong in the dangerous direction — 365 days is shorter than the 24-month consent window, so a reader could conclude the consent trail expires a year early. Note the TTL POLICY is still armed on this field (`firestore.indexes.json`, `audit_logs.expireAt`, `"ttl": true`): inert while nothing writes the field, but a future writer would hand retention to the TTL reaper silently. | Art 5(1)(e) — storage limitation | N/A — no writer. |
| `metadata.details` | Free-text human-readable context (e.g., why permission was denied). Risk of inadvertent PII; see *Privacy review* below. | Art 6(1)(f) | Yes. |
| `metadata.consentVersion` | For `consent_updated` events only — version of the consent terms accepted. | Art 7(1) — demonstrate consent | Yes (24mo bucket). |
| `metadata.purposes` | For `consent_updated` events only — map of consent-purpose flags. | Art 7(1) | Yes (24mo bucket). |
| `metadata.timestamp` | For `consent_updated` events only — client-side ISO timestamp (defence in depth vs server clock skew). | Art 7(1) | Yes (24mo bucket). |
| `metadata.previousAllergenStatus` / `newAllergenStatus` | For `tag_modified` events — health-data trace (Art 9 special category). Recorded so a user with allergy-related complications can inspect the chain of automated decisions about their health. | Art 9(2)(h) — preventive medicine context (loose fit; conservative interpretation requires this audit trail) | Yes (6mo bucket). |
| `metadata.previousDietaryStatus` / `newDietaryStatus` | Same as above. | Art 9(2)(h) | Yes (6mo bucket). |
| `metadata.previousCoverage` / `newCoverage` | Tag-coverage scoring change. Not personal data on its own; included in audit for diagnostics. | Art 6(1)(f) | Yes (6mo bucket). |
| `metadata.source` | For `tag_modified` events — origin of the change (`auto_tagging`, `manual_retag`, `import`). | Art 6(1)(c) | Yes (6mo bucket). |
| `metadata.wasFirstTagging` | For `tag_modified` events — boolean. | Art 6(1)(c) | Yes (6mo bucket). |

## Privacy review (truncation/hashing of sensitive fields)

The doc-comment on
[`FirebaseAuditRepository.logPermissionCheck`](../../lib/repositories/firebase/firebase_audit_repository.dart)
shows an example with `metadata: {'ip': '192.168.1.1', 'app_version': '1.0.0'}`.
**As of 2026-04-30 no production call site passes `ip` or `userAgent` into
`metadata`.** A repo-wide grep confirms zero occurrences of `'ip'` /
`'userAgent'` / `'user_agent'` keys in audit metadata write paths
(`compliance_export_manager.dart` reads `userAgent` from consent records
during EXPORT, but never writes it to audit metadata).

If this changes, the audit repository MUST truncate before write:

- **IPv4** → `/24` (drop the last octet); **IPv6** → `/64` prefix.
  Storing full IP without explicit GDPR DPIA is hard to justify against
  Art 5(1)(c). `192.168.1.42` → `192.168.1.0/24`.
- **User-Agent** → keep family + major version (e.g. `Chrome/120`); drop
  minor version, OS leaf, and any vendor-injected fingerprint string.

The truncation logic should live in a `_truncateSensitiveMetadata` helper
on `FirebaseAuditRepository` and be called from both `logPermissionCheck`
and `logTagModification` BEFORE `_collection.add(...)`. A failing test
should be added at the same time. Current code does not need this change
(no PII in flight); leaving the helper unimplemented avoids dead code.
**This decision is the privacy-review outcome — do not silently re-add
IP/UA to call sites without revisiting this document.**

## Coordination with account deletion (BUT-671 cross-cut)

`AccountDeletionService` does **not** delete `audit_logs/{id}` rows
authored by the deleted user. Per Art 17(3)(b)/(e), the right to erasure
yields to "compliance with a legal obligation" and "establishment,
exercise or defence of legal claims". The retention windows above
*are* the erasure schedule for audit data — eventual deletion via this
purge CF, not synchronous deletion at account-close time.

Nothing in `test/` documents these exceptions today: the test that did was
deleted with the client-side deletion path in BUT-788, and no successor took
the section over.

## Operational

- Cron: `0 5 * * 0` (Sunday 05:00 UTC). Two hours after the legacy
  `cleanupOldAuditLogs` (03:00) and one hour after `cleanupOldNotifications`
  (04:00) to avoid concurrent batch writes on the same Firestore shard.
- Region: `europe-west1` (matches the Firestore database region; required
  to avoid cross-region read costs).
- Batch size: 200 deletes per batch (well under the 500 Firestore limit
  + safety margin for indexed-field deletes).
- Idempotency: a same-day re-run finds zero documents matching
  `timestamp < cutoff` for already-purged categories and is a no-op.
- Observability: a structured log line per category with `deleted`,
  `cutoffDate`, and `category` fields. A `system_events` row is appended
  with `type: 'audit_log_retention_purge'` for the dashboard.
