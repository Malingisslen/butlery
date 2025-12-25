# Notification Failures Runbook

**Priority:** MEDIUM
**Last Updated:** 2025-12-25

---

## Detection

### Alerts
- Firebase Cloud Messaging: Delivery failure spike
- User reports: Not receiving notifications
- Analytics: Low notification engagement rate

### Symptoms
- Push notifications not delivered
- In-app notifications missing
- FCM token refresh failures
- Topic subscription errors

### Key Metrics
- Notification delivery rate (target: >95%)
- FCM token validity rate
- Topic subscription success rate

---

## Impact

| Severity | Condition | User Impact |
|----------|-----------|-------------|
| P1 | All notifications failing | Missing critical updates |
| P2 | >10% delivery failures | Inconsistent experience |
| P3 | Delayed notifications | Minor inconvenience |

### Affected Functionality
- Friend request notifications
- Recipe sharing alerts
- Shopping list collaboration updates
- Chat message notifications
- Cooking timer reminders

---

## Diagnosis

### Step 1: Check FCM Status
1. Go to [Firebase Console](https://console.firebase.google.com/) → Cloud Messaging
2. Check "Reports" for delivery stats
3. Review error breakdown

### Step 2: Review FCM Service Logs
```
Key files to check:
- lib/services/notifications/fcm_service.dart
- functions/src/notifications/ (Cloud Functions)
```

Check for:
- Token registration failures
- Topic subscription errors
- Message send failures

### Step 3: Verify FCM Configuration
1. Check `google-services.json` (Android)
2. Check `GoogleService-Info.plist` (iOS)
3. Verify APNs certificate validity (iOS)
4. Check Cloud Functions deployment

### Step 4: Test Token Validity
1. Get current FCM token from device
2. Send test message via Firebase Console
3. Verify delivery in app logs

---

## Resolution

### Immediate Mitigation

**If FCM service down:**
1. Fall back to in-app polling for critical updates
2. Communicate via app banner
3. Monitor FCM status page

**If token refresh failing:**
1. Force token refresh on app start
2. Clear cached token
3. Re-register with FCM

**If topic subscriptions failing:**
1. Unsubscribe and resubscribe to topics
2. Check topic name format
3. Verify user permissions

### Root Cause Fix

| Issue | Fix | File |
|-------|-----|------|
| Token not refreshing | Fix token refresh listener | `fcm_service.dart` |
| Topic subscription race | Add retry logic | `fcm_service.dart` |
| APNs certificate expired | Renew in Apple Developer Console | iOS config |
| Cloud Function error | Fix and redeploy function | `functions/src/` |

### Verification Steps
1. Register new FCM token
2. Send test notification from Firebase Console
3. Verify notification appears on device
4. Test background notification handling

---

## Prevention

- [ ] Monitor FCM token refresh success rate
- [ ] Set up APNs certificate expiry alerts
- [ ] Regular testing of notification flows
- [ ] Implement notification delivery confirmation
- [ ] Add fallback for critical notifications

---

## Escalation

| Condition | Action | Contact |
|-----------|--------|---------|
| FCM outage confirmed | Monitor status, prepare comms | On-call rotation |
| APNs certificate expiring | Immediate renewal | iOS developer |
| Security issue with tokens | Rotate tokens, audit access | Security team |

---

## References

- FCM Service: `lib/services/notifications/fcm_service.dart`
- Cloud Functions: `functions/src/notifications/`
- Firebase Console: `https://console.firebase.google.com/`
- APNs Configuration: Apple Developer Console
- SLO Definitions: `docs/operations/SLO_DEFINITIONS.md`
