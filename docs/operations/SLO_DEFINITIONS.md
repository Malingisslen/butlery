# SLO Definitions (BUT-879)

Service Level Objectives for Butlery. Each entry records the numeric target,
its source, the burn-rate alert threshold that guards it, and the metric query
that measures it.

> **Baseline note:** targets marked **provisional — confirm against 30-day
> baseline** are starting points chosen from Google-default guidance or product
> judgement. They must be revisited once the monitoring stack has 30 days of
> real data. Do not treat them as committed until that review is done.

---

## SLO-1 — Firestore read latency (client-perceived)

| Attribute | Value |
|-----------|-------|
| **Target** | p50 < 150 ms, p95 < 500 ms **provisional — confirm against 30-day baseline** |
| **Source** | Google-default-guidance |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget |
| **Metric query** | Firebase Performance Monitoring → Custom traces → `firestore_read_latency`; or Cloud Monitoring `firestore.googleapis.com/api/request_latencies` filtered to `method=RunQuery` + `method=Get`, aggregated by p50 / p95. |

**Why these numbers:** Google's own client-SDK benchmarks show cold-start
Firestore reads landing ~50–200 ms in west-EU; 500 ms p95 is the threshold
above which perceived lag becomes a UX complaint. Both are provisional until
measured.

---

## SLO-2 — Firestore write latency (client-perceived)

| Attribute | Value |
|-----------|-------|
| **Target** | p50 < 300 ms, p95 < 800 ms **provisional — confirm against 30-day baseline** |
| **Source** | Google-default-guidance |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget |
| **Metric query** | Cloud Monitoring `firestore.googleapis.com/api/request_latencies` filtered to `method=Commit`, aggregated by p50 / p95. |

**Why these numbers:** Writes are slower than reads due to replication
acknowledgement. 800 ms p95 is the standard Google guidance for client-facing
write acknowledgement on a single-region Firestore database.

---

## SLO-3 — Crash-free sessions

Two tiers reflect different user-impact thresholds:

| Attribute | Tier 1 (critical flows) | Tier 2 (overall) |
|-----------|-------------------------|-------------------|
| **Target** | ≥ 99.5% crash-free sessions | ≥ 99.0% crash-free sessions |
| **Source** | business-commitment | business-commitment |
| **Error budget window** | 28 days rolling (Crashlytics default) | 28 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget | Same thresholds |
| **Metric query** | Firebase Crashlytics → Overview dashboard → "Crash-free users" (sessions). Raw: `crashlytics/crash_count` vs `crashlytics/session_count` via Firebase Data Connect or BigQuery export. |

Tier 1 "critical flows" = recipe-detail load, auth sign-in, menu generation.
Tier 2 = the app-wide Crashlytics headline number.

---

## SLO-4 — Push notification delivery rate (FCM-reported)

| Attribute | Value |
|-----------|-------|
| **Target** | ≥ 95% delivery rate **provisional — confirm against 30-day baseline** |
| **Source** | Google-default-guidance |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget |
| **Metric query** | Firebase Console → Cloud Messaging → Message delivery data. Computed as `(accepted_by_device / sent_to_FCM) × 100`. BigQuery export: `firebase_messaging.message_accepted` / `firebase_messaging.message_sent`. |

FCM-reported delivery covers messages accepted by the device transport layer;
it does not cover OS-level notification suppression (do-not-disturb, battery
saver). 95% is the Google-default starting target.

---

## SLO-5 — OCR success rate

| Attribute | Value |
|-----------|-------|
| **Target** | ≥ 90% of OCR attempts succeed (gated by image-quality pre-check) **provisional — confirm against 30-day baseline** |
| **Source** | Google-default-guidance / provisional |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget |
| **Metric query** | Cloud Functions logs: `functions/src/` OCR handler — count `status=success` / `status=attempted` per day. Structured log field `type=ocr_extraction_result` with `success: boolean`. Firestore `system_events` collection if OCR results are written there. |

"Succeeded" = extraction returned parseable text. "Attempted" = user submitted
an image and the pipeline started (images rejected by the quality pre-check
before submission are excluded from denominator). Numbers below 90% indicate
OCR.space or Vertex Vision degradation worth paging.

---

## SLO-6 — Vertex AI (Gemini) request success rate

| Attribute | Value |
|-----------|-------|
| **Target** | ≥ 99% success rate **provisional — confirm against 30-day baseline** |
| **Source** | Google-default-guidance |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 1 h burn-rate > 14.4× budget, OR 6 h burn-rate > 6× budget |
| **Metric query** | Cloud Monitoring `aiplatform.googleapis.com/prediction/online/response_count` filtered by `response_code!=OK` vs total. Or Cloud Functions logs: count `type=vertex_ai_request` with `success=false` vs total. Region filter: `europe-west1`. |

"Success" = HTTP 200 from Vertex AI within the timeout window. 429 rate-limit
errors should be retried by the client; persistent 429s count as failures if
they surface to the user.

---

## SLO-7 — Signup-funnel completion

| Attribute | Value |
|-----------|-------|
| **Target** | ≥ 40% of users who reach the signup screen complete activation **provisional — confirm against 30-day baseline** |
| **Source** | provisional / business-commitment |
| **Error budget window** | 30 days rolling |
| **Burn-rate alert** | Alert if 7-day rolling rate drops below 35% (early warning) or 30% (page). Funnel SLOs are slow-moving; 1 h / 6 h burn-rate thresholds are less meaningful here than weekly trending. |
| **Metric query** | Firebase Analytics: `sign_up` event count / `screen_view {screen_name=SignupScreen}` event count, filtered to new users, 30-day window. Or BigQuery: `events_*` table filtered by `event_name IN ('screen_view','sign_up')`. |

"Activated" = `sign_up` event fired (email-verified + first session complete).
40% is a product-judgement starting target; typical mobile app signup
completion rates run 30–60% depending on friction. Revisit after the first
30-day baseline read.

---

## Burn-rate alert reference

The standard multiwindow burn-rate formula used above:

| Alert | Window | Burn-rate threshold | Budget consumed if triggered |
|-------|--------|---------------------|------------------------------|
| Fast | 1 h | 14.4× | ~2% in 1 h |
| Slow | 6 h | 6× | ~5% in 6 h |

These match the Google SRE Workbook chapter 5 defaults for a 30-day error
budget. Set both as AND-gates on the same alert policy to reduce noise.

---

## Alert policies (BUT-813)

When BUT-813 implements Cloud Monitoring alert policies, each policy guards the
following SLOs:

| Alert policy (to be named) | Guards SLO(s) |
|---|---|
| `butlery-firestore-read-latency-burn` | SLO-1 |
| `butlery-firestore-write-latency-burn` | SLO-2 |
| `butlery-crash-free-sessions-tier1` | SLO-3 (Tier 1) |
| `butlery-crash-free-sessions-tier2` | SLO-3 (Tier 2) |
| `butlery-fcm-delivery-burn` | SLO-4 |
| `butlery-ocr-success-burn` | SLO-5 |
| `butlery-vertex-success-burn` | SLO-6 |
| `butlery-signup-funnel-weekly` | SLO-7 |

---

## Severity-bucket alignment (INCIDENTS.md)

Reviewed `docs/operations/INCIDENTS.md` severity buckets against the SLO
definitions above. No tightening is required: the existing bucket definitions
(Sev-1 = production down / data loss / security / regulatory; Sev-2 = major
feature broken for >10% of users or payment/privacy regression) remain the
right escalation thresholds when these SLOs breach. An SLO burn-rate alert
alone does not automatically constitute a Sev-1 — apply the triage checklist
to classify. **No severity-bucket change required.**

---

## Bump history

| Date | Change |
|------|--------|
| 2026-06-13 | Initial draft — BUT-879. All targets provisional pending 30-day baseline. |
