# Firebase Alerting Configuration Guide

**Last Updated:** 2025-12-25

This guide provides step-by-step instructions for configuring Firebase Console alerts for the Butlery application.

---

## Prerequisites

- Firebase Console access with **Admin** or **Editor** role
- Project: `butlery-app-1`
- Crashlytics and Performance Monitoring enabled

---

## Crashlytics Alerts

### Alert 1: Crash-Free Rate Drop (P0 - Critical)

**Threshold:** Crash-free rate drops below 99.5%

**Setup Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/) → Crashlytics
2. Click **Alerts** in the left sidebar
3. Click **Create Alert**
4. Configure:
   - **Alert type:** Crash-free users
   - **Threshold:** Less than 99.5%
   - **Time window:** 1 hour
5. Add notification channels (see below)
6. Click **Save**

### Alert 2: New Crash Type (P1 - High)

**Threshold:** Any new crash type detected

**Setup Steps:**
1. Go to Firebase Console → Crashlytics → Alerts
2. Click **Create Alert**
3. Configure:
   - **Alert type:** New issue
   - **Severity:** All crashes
4. Add notification channels
5. Click **Save**

### Alert 3: Crash Velocity Spike (P1 - High)

**Threshold:** More than 10 crashes in 1 hour

**Setup Steps:**
1. Go to Firebase Console → Crashlytics → Alerts
2. Click **Create Alert**
3. Configure:
   - **Alert type:** Velocity alert
   - **Threshold:** 10 crashes
   - **Time window:** 1 hour
4. Add notification channels
5. Click **Save**

---

## Performance Monitoring Alerts

### Alert 4: Screen Load Time (P2 - Medium)

**Threshold:** p95 screen load time exceeds 2000ms

**Setup Steps:**
1. Go to Firebase Console → Performance
2. Click **Alerts** in the left sidebar
3. Click **Create Alert**
4. Configure:
   - **Metric:** Screen rendering → Time to interactive
   - **Percentile:** 95th
   - **Threshold:** Greater than 2000ms
   - **Time window:** 1 hour
5. Add notification channels
6. Click **Save**

### Alert 5: HTTP Request Time (P2 - Medium)

**Threshold:** p95 HTTP request time exceeds 3000ms

**Setup Steps:**
1. Go to Firebase Console → Performance → Alerts
2. Click **Create Alert**
3. Configure:
   - **Metric:** Network requests → Response time
   - **Percentile:** 95th
   - **Threshold:** Greater than 3000ms
   - **Time window:** 1 hour
4. Add notification channels
5. Click **Save**

### Alert 6: App Startup Time (P2 - Medium)

**Threshold:** p95 app startup time exceeds 5000ms

**Setup Steps:**
1. Go to Firebase Console → Performance → Alerts
2. Click **Create Alert**
3. Configure:
   - **Metric:** App start → Time to first frame
   - **Percentile:** 95th
   - **Threshold:** Greater than 5000ms
   - **Time window:** 1 hour
4. Add notification channels
5. Click **Save**

---

## Notification Channels

### Email Configuration

1. Go to Firebase Console → Project Settings → Integrations
2. Under **Alerting**, click **Add email**
3. Add team distribution email (e.g., `butlery-alerts@team.com`)
4. Verify the email address

### Slack Integration (Optional)

1. Go to Firebase Console → Project Settings → Integrations
2. Click **Slack** → **Link**
3. Authorize Firebase in your Slack workspace
4. Select the channel for alerts (e.g., `#butlery-alerts`)
5. Configure alert types to send to Slack

---

## Alert Summary

| # | Alert | Threshold | Severity | Action |
|---|-------|-----------|----------|--------|
| 1 | Crash-free rate | <99.5% | P0 | Immediate investigation |
| 2 | New crash type | Any new | P1 | Triage within 4 hours |
| 3 | Crash velocity | >10/hour | P1 | Investigate spike cause |
| 4 | Screen load time | p95 >2000ms | P2 | Performance review |
| 5 | HTTP request time | p95 >3000ms | P2 | Network/backend check |
| 6 | App startup time | p95 >5000ms | P2 | Startup optimization |

---

## Verification Checklist

After configuring alerts, verify they work:

- [ ] **Crashlytics alerts visible** in Firebase Console → Crashlytics → Alerts
- [ ] **Performance alerts visible** in Firebase Console → Performance → Alerts
- [ ] **Email notification** received for test alert
- [ ] **Slack notification** received (if configured)
- [ ] **On-call rotation** understands alert escalation

### Test Alert (Optional)

To test Crashlytics alerting:
1. Trigger a test crash in debug build
2. Verify crash appears in Crashlytics dashboard
3. Confirm alert notification received

---

## Escalation Matrix

| Severity | Response Time | Escalation |
|----------|--------------|------------|
| P0 | 15 minutes | Immediate page to on-call |
| P1 | 4 hours | Team lead notification |
| P2 | 24 hours | Weekly review |

---

## References

- [Firebase Crashlytics Alerts Documentation](https://firebase.google.com/docs/crashlytics/alerting)
- [Firebase Performance Monitoring Alerts](https://firebase.google.com/docs/perf-mon/alerting)
- SLO Definitions: `docs/operations/SLO_DEFINITIONS.md`
- Monitoring Action Plan: `docs/analysis/actionplans/MONITORING_ACTION_PLAN.md`
