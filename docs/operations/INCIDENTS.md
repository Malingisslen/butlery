# Incident Response Runbook (BUT-452)

This runbook is the first thing to open when something is on fire. Triage
checklist first, then post-mortem template at the bottom.

## Severity buckets

| Sev | Definition | Response |
| --- | ---------- | -------- |
| **Sev-1** | Production down, data loss, security breach, regulatory exposure | Drop everything. Mitigate within 1h. |
| **Sev-2** | Major feature broken for >10% of users, or any payment / privacy regression | Mitigate same day. |
| **Sev-3** | Minor feature degraded, edge-case crash, non-blocking regression | Fix in next sprint. |
| **Sev-4** | Cosmetic / non-functional | Backlog. |

Default to one severity higher when uncertain. Solo dev — a misclassified
Sev-3 that's actually Sev-1 means hours of silent harm.

## Triage checklist (first 15 minutes)

1. **Confirm impact.** Open Crashlytics + Firebase Functions logs side-by-
   side. Is the error rate up? Single user or many? Single platform or all?
2. **Classify severity.** Use the table above.
3. **Capture state.** Screenshot the dashboards. Note the time window.
   These get lost if you don't grab them now.
4. **Identify the trigger.** Git log of the last 12h. Recent deploy? Recent
   rule change? Recent Linear merge? External provider status page?
5. **Pick the response:**
   - Sev-1 / Sev-2: mitigate first (roll back, disable feature flag, push
     a hotfix). Root-cause later.
   - Sev-3 / Sev-4: file a Linear ticket with all the evidence gathered
     above; investigate when you can give it focus.
6. **Communicate** (if user-impacting):
   - Status page update (if one exists — not yet).
   - In-app notification via Remote Config flag, if widespread.
   - DM affected users individually if scoped to a small set.

## Where to look

| Surface | URL / command |
| ------- | ------------- |
| Crashlytics | Firebase Console → Crashlytics |
| Cloud Functions logs | `gcloud functions logs read --project=butlery-app-1 --region=europe-west1 --limit=200` |
| Firestore reads/writes | Firebase Console → Firestore → Usage |
| Auth signups | Firebase Console → Authentication → Users (sort by Created) |
| Storage errors | Firebase Console → Storage (no good usage view; tail logs) |
| Hosting deploys | `firebase hosting:releases:list --project=butlery-app-1` |
| Vertex AI errors | Cloud Console → Vertex AI → Logs Explorer |
| Algolia errors | Algolia dashboard → Analytics |
| Provider outages | https://status.firebase.google.com/ , https://status.cloud.google.com/ , https://status.algolia.com/ |

## Common scenarios → first action

| Symptom | First action |
| ------- | ------------ |
| Spike in `permission-denied` in Crashlytics | Diff `firestore.rules` against the last known-good commit. Roll back per `DEPLOY_ROLLBACK.md` §2 if a rule change is the cause. |
| New users can't sign up | Check Auth Console for a quota error. Then Crashlytics for `auth/internal-error`. |
| OCR / import broken | Verify OCR.space + Vertex AI status pages. Check `lib/services/ocr_extraction_service.dart` for a recent change in the last 24h. |
| App crashes on launch (single platform) | Crashlytics → filter by platform. If <hour old: pull the offending build off Play / TestFlight (see `DEPLOY_ROLLBACK.md` §6). |
| Functions 5xx on a specific trigger | `gcloud functions logs read --project=butlery-app-1 --filter='resource.labels.function_name=<FN>' --limit=50`. Look for unhandled exception. |
| Sudden Firestore cost spike | Console → Usage → identify which collection. Likely a new infinite-loop subscription or unbounded query. Disable the offending feature flag if available; hotfix the query otherwise. |

## Mitigation patterns

**Feature flags first.** If the broken surface is gated by a Remote Config
flag (most should be, per `ADR-001`), flip the flag off rather than rolling
back code. Faster + reversible.

**Rollback over hotfix.** Don't ship a same-hour hotfix during a Sev-1.
Roll back, breathe, fix properly.

**Don't fix in prod.** No `firebase deploy` without running the rules test
suite + lefthook locally first. Sev-1 + bad rollback = compounded outage.

## Communications

If users are visibly impacted:

> Hej! Vi har ett tillfälligt problem med [funktion]. Vi felsöker. Era data
> är säkra. Vi återkommer när det är löst.

For privacy / data-loss incidents specifically: see GDPR notification
obligations in `docs/operations/audit-logs-retention.md` — 72h to notify
the supervisory authority for risk-to-rights breaches.

## Post-mortem template

Use within 72h of any Sev-1 or Sev-2. File as `docs/postmortems/YYYY-MM-DD-<slug>.md`.

```markdown
# Postmortem: <one-line summary>

**Date:** YYYY-MM-DD
**Severity:** Sev-X
**Duration:** Detected HH:MM — mitigated HH:MM (<N>h)
**Affected:** <user surface + scope>

## Summary
<3-5 sentence narrative — what broke, what users saw, what we did.>

## Timeline (UTC)
- HH:MM — First signal (Crashlytics alert / user report / monitor).
- HH:MM — Triage started.
- HH:MM — Root cause identified.
- HH:MM — Mitigation deployed.
- HH:MM — Confirmed resolved.

## Root cause
<Single concrete cause. Not "the code was bad" — *which* line, *why* it
slipped through. Reference commit SHA.>

## Impact
- Users affected: <count + how computed>
- Data impact: <none / lost / corrupted / exposed>
- Revenue impact: <N/A pre-monetization>

## What went well
<2-3 bullets — what the response did right.>

## What went poorly
<2-3 bullets — gaps in detection, triage, mitigation, or tooling.>

## Action items
- [ ] **<owner>** — <concrete, time-bounded follow-up>. Linear: BUT-XXX
- [ ] ...
```
