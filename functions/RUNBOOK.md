# Cloud Functions Runbook

Operations notes for things that aren't deploy-time code.

## parse_events TTL policy (BUT-1478) — REQUIRED for the 30-day retention claim

`logParseEvent` stamps every `parse_events` doc with an `expireAt` timestamp
(now + 30 days). That field is **inert until a Firestore TTL policy exists** —
without the policy, docs (raw userId + sanitized URL) are retained forever and
the GDPR Art. 5(1)(e) retention claim in the code comment is false.

One-time setup (deploy-day for BUT-1478), **two steps**:

1. Enable the TTL policy:

```
gcloud firestore fields ttls update expireAt \
  --collection-group=parse_events \
  --enable-ttl \
  --project=butlery-app-1
```

(or Cloud Console → Firestore → Time-to-live → Create policy →
collection group `parse_events`, field `expireAt`).

2. Backfill pre-existing docs — TTL never touches docs that LACK the field,
so events written before BUT-1478 shipped would otherwise be retained forever:

```
cd functions
npm run backfill-parse-event-expiry:dry-run   # counts, no writes
npm run backfill-parse-event-expiry           # stamps expireAt = timestamp + 30d
```

Docs already past their 30-day window get a past `expireAt` and are reaped by
the policy within ~24h. The script is idempotent (skips docs that have the field).

Verify: `gcloud firestore fields ttls list --project=butlery-app-1` shows
`parse_events/expireAt` with state `ACTIVE`. TTL deletion is best-effort
(typically within 24h of expiry) — fine for retention purposes.

## Firestore TTL policies — full registry

Every collection group whose docs carry an `expireAt` field. Each needs the
same one-time `gcloud firestore fields ttls update expireAt
--collection-group=<name> --enable-ttl --project=butlery-app-1` (the field is
inert without it). Check actual prod state with
`gcloud firestore fields ttls list --project=butlery-app-1` — nothing in the
repo can prove a policy is on; this table tracks *which groups need one*, the
gcloud listing is the ground truth for *whether it's on*.

| Collection group             | Retention | Written by                                  | Notes |
|------------------------------|-----------|---------------------------------------------|-------|
| `parse_events`               | 30 days   | `events/log-parse-event.ts`                 | BUT-1478; run the backfill above once |
| `llm_response_samples`       | 30 days   | `llm/llm-sample-capture.ts`                 | |
| `notification_send_events`   | 30 days   | `shared/notification-send-events.ts`        | |
| `notification_opened_events` | 30 days   | `notifications/record-notification-opened.ts` | |
| `scheduled_notifications`    | 7 days    | `shared/scheduled-notifications.ts`         | |
| `report_processing_markers`  | 180 days  | `feedback/on-report-created.ts`             | |
| `system_ip_audit_caps`       | 2 hours   | `account/verify-signup-age.ts`              | |
| `deletion_audit_logs`        | 180 days  | `account/request-account-deletion.ts`       | Optional — `cleanupOldAuditLogs` (scheduled CF) already deletes expired docs; TTL is belt-and-braces |

(The presence system's `expiresAt` field — note the different spelling — has
its own runbook: `docs/ops/presence-ttl-runbook.md`.)

## structureRecipe latency monitoring (BUT-483)

`structureRecipe` emits a structured log on every exit path:

```
event=structure_recipe.complete
durationMs=<int ms>
textLength=<int>
mode=<extract|enhance|spoken|ingredientLines>
success=<bool>
```

To wire a Cloud Logging distribution metric (p50/p95/p99) when latency
monitoring becomes a need:

1. Cloud Console → Logging → Logs Explorer → Create Metric.
2. Filter: `jsonPayload.event = "structure_recipe.complete"`.
3. Metric type: Distribution; Field name: `jsonPayload.durationMs`.
4. Add label: `jsonPayload.mode` so you can slice by extract/enhance/spoken.
5. Save as `structure_recipe.duration_ms`. Charts in Metrics Explorer.

No deploy needed — the structured fields are already emitted in production.
