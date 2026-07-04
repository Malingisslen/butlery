# Scan — Role 24: Data Analyst / BI

Two passes through the analytics lens (metric correctness, retention/cohort math,
anomaly false-trigger logic, experiment-assignment integrity, snapshot job correctness).

Owned paths: `functions/src/analytics/**`, `lib/repositories/firebase/firebase_analytics_repository.dart`,
`lib/services/analytics/**`.

Date: 2026-06-27

Dedup checked against: `tasks/_scan_dedup_titles.txt` (BUT-162 BigQuery export),
`.claude/linear-tracker.json` (BUT-436 unused events, BUT-437 nav observer, BUT-438 win-back prefs),
`.claude/rules/accepted-deviations.md`, dossier #24 watch-items (platform-bucket missing-return,
05:00 schedule collision, RECIPE_SCAN_CAP=5000 floor).

---

## PASS 1 — metric computation, retention math, anomaly logic

The retention/anomaly core is largely sound and matches its documented contracts:

- `compute-feature-retention.ts` DAU pass scans all `lastActiveAt >= now-28d` users and writes a
  per-user flag doc (even all-false) so the WAU rollup over `todayUserFlags` covers every 28d-active
  user — no silent omission of users who were active earlier in the window but idle today. Correct.
- WAU/MAU OR-reduction (`accumulateInto` / `bumpAggregate`) is true set-membership, not a sum — a user
  active 5 days counts once. `wau28d`-as-MAU-proxy is documented and intentional. No double-count.
- `detect-anomalies.ts` z-score gates are correct: sample stddev (n−1), MIN_SAMPLES=14, stddev>0 guard,
  ABSOLUTE_FLOOR to suppress 3σ on tiny counts, run-day excluded from baseline. No false-trigger logic
  found. Non-numeric/absent fields are skipped (`readNumericField`), so a missing field can't poison mean.

### NEW-1 (High) — Feedback daily snapshot mis-buckets by UTC day; corrupts `feedback_total` + its anomaly series
`runFeedbackSnapshot` (daily-snapshots.ts:415–455) range-queries `feedback.createdAt` as ISO strings,
building boundaries with `new Date(startMs).toISOString()` (always `…Z`, UTC) and relying on lexicographic
= chronological ordering (comment lines 404–405). But the writer stores a **local, zoneless** ISO string:
`feedback_service.dart:60` writes `createdAt: clock.now()` and `feedback_entry.dart:66` serializes
`createdAt.toIso8601String()`. In Dart, `clock.now()`/`DateTime.now()` returns a **local** DateTime, and
`toIso8601String()` on a local DateTime emits **no `Z` and no offset** (e.g. `2026-06-27T01:30:00.000`).
Two breakages: (a) the stored value is wall-clock local, so a Swedish user's (UTC+2) feedback at 01:30
local = 23:30 UTC prior day is bucketed into the wrong UTC day; (b) lexicographic comparison of a
zoneless string against a `…Z` boundary is not a like-for-like compare, so boundary rows can be
mis-included/excluded. `feedback_total` is also one of the five `MONITORED_SERIES` in detect-anomalies.ts
(metric `feedback_total`), so the daily count fed to the anomaly baseline is itself wrong — garbage in.
Fix: normalize the writer to UTC (`clock.now().toUtc().toIso8601String()`) or store a `Timestamp` and
range-query like the other four snapshots; a backfill is needed for already-written zoneless docs.
_Evidence: functions/src/analytics/daily-snapshots.ts:415–455 (boundaries via toISOString, lexicographic compare); lib/services/feedback/feedback_service.dart:60; lib/models/feedback_entry.dart:66; functions/src/analytics/detect-anomalies.ts:97–102 (feedback_total monitored)_

---

## PASS 2 — experiment assignment, lifecycle classifier, snapshot correctness

- `resolveWinbackVariant` (winback-variant.ts:72–90) is deterministic and uniform for the live 2-variant
  set (48-bit hash, modulo bias negligible at 2 variants). Per-threshold independence is intentional.
  No determinism/bias defect at current config. (If `DEFAULT_VARIANTS` ever grows to 3, modulo bias stays
  < 2^-47 — not actionable.)
- `WinbackAttributionService` single-attribution latch, 7-day window re-check, and bridge-field clearing
  are correct; latch-before-emit trades a missed conversion for never over-counting (documented, sound).
- `lifecycle_stage_classifier.dart` priority order (churned > dormant > habitual > activated > new) is
  internally consistent and recency-dominant as documented.

### NEW-2 (Medium) — Lifecycle classifier double-counts the dormant/churned boundary day via `inDays` truncation
`classifyLifecycleStage` uses `now.difference(lastCookAt).inDays` (line 58), which **truncates toward
zero**. A last-cook 30.9 days ago yields `inDays == 30`, so `> 30` is false and the user is classified
**dormant**, not **churned**, for nearly a full extra day; the same off-by-truncation affects the `>= 14`
dormant boundary. The dossier already flags a related concern about the 13.5-day edge, but the underlying
issue is that day-bucket thresholds are compared against a floored integer rather than a fractional-day or
explicit midnight boundary. Re-engagement cohorts (churned drives win-back-strong eligibility) are
therefore shifted by up to ~1 day at each boundary. Low blast radius at beta scale; flag for when cohort
sizing matters. Fix: compare against millisecond thresholds (`now - lastCook >= 30*MS_PER_DAY`) rather
than `inDays`, consistent with how the server jobs do day math.
_Evidence: lib/services/analytics/lifecycle_stage_classifier.dart:58,66,72–74_

### NEW-3 (Low) — Lapsed-user detection is point-in-time, not cumulative — irregular users escape all three win-back windows
`runDetectLapsedUsers` (detect-lapsed-users.ts:125–138) selects users whose `lastActiveAt` falls in a
±12h window centered on exactly `now − {7,14,30}` days. A user whose `lastActiveAt` lands between windows
(e.g. last active 10 or 20 days ago) is detected by **none** of the three thresholds and receives no
win-back at all; only users who happen to be inactive for almost-exactly 7/14/30 days are ever pinged.
This systematically under-counts the win-back-eligible population and biases the A/B denominator toward
a non-representative slice (users with regular ~weekly cadence). Not a code defect per se — a detection-
design limitation — but it means `lapsed_users/events` and the win-back experiment populations are not
the cohorts a BI reader would assume. Worth a ticket to switch to a "crossed the threshold since last
run AND not yet pinged at this stage" predicate. Distinct from BUT-438 (which is about prefs/quiet-hours,
already tracked).
_Evidence: functions/src/analytics/detect-lapsed-users.ts:125–138 (±12h windows around exact day offsets)_

---

## Verified-not-a-bug (so the next pass doesn't re-open these)
- WAU rollup omitting earlier-active-but-idle-today users — NOT a bug (DAU pass writes all-false flag docs
  for every scanned user; rollup covers them). compute-feature-retention.ts:287–333.
- Anomaly baseline over non-contiguous days when snapshots have gaps — acceptable; count gate still applies.
- 48-bit hash modulo bias in variant assignment — negligible; not actionable at 2 variants.
- Platform-bucket missing-return in `_platformBucket()`/`_resolvePlatformBucket()` — already a dossier
  watch-item; not re-filed. (Note: Dart's exhaustive-switch over a sealed enum makes the missing trailing
  return harmless in practice — both functions cover all 7 `TargetPlatform` cases — but the dossier owns it.)

COVERAGE: all 10 owned analytics files reviewed across both passes. 3 NEW findings (1 High, 1 Medium,
1 Low). Dossier watch-items (platform return, 05:00 collision, RECIPE_SCAN_CAP floor) confirmed still
accurate, not re-filed per dedup.
