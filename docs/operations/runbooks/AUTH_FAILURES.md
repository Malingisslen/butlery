# Authentication Failures Runbook

**Priority:** HIGH
**Last Updated:** 2025-12-25

---

## Detection

### Alerts
- Crashlytics: Auth-related crash spike
- Firebase Analytics: `login_failed` event spike
- User reports: Unable to sign in

### Symptoms
- Users cannot log in or register
- "Session expired" errors appearing frequently
- Token refresh failures in logs
- Increased password reset requests

### Key Metrics
- Login success rate (target: >99%)
- Token refresh failure rate
- Session timeout frequency

---

## Impact

| Severity | Condition | User Impact |
|----------|-----------|-------------|
| P0 | All users cannot log in | Complete app access blocked |
| P1 | >10% login failures | Significant user frustration |
| P2 | Intermittent failures | Minor inconvenience |

### Affected Functionality
- User authentication (login/register)
- Session persistence
- All authenticated features (recipes, shopping, social)

---

## Diagnosis

### Step 1: Check Firebase Auth Status
1. Go to [Firebase Console](https://console.firebase.google.com/) → Authentication
2. Check "Usage" tab for error rates
3. Review "Sign-in method" settings

### Step 2: Review Application Logs
```
Key files to check:
- lib/services/auth_service.dart
- lib/repositories/firebase/firebase_auth_repository.dart
```

Check for:
- `AuthException` occurrences
- Token refresh failures
- Network timeout errors

### Step 3: Check Firebase Status
1. Visit [Firebase Status Dashboard](https://status.firebase.google.com/)
2. Check Authentication service status
3. Review recent incidents

### Step 4: Verify Configuration
1. Check `firebase_options.dart` for correct project ID
2. Verify OAuth providers are enabled
3. Check authorized domains list

---

## Resolution

### Immediate Mitigation

**If Firebase Auth is down:**
1. Enable maintenance mode message in app
2. Communicate via social media/status page
3. Monitor Firebase status for resolution

**If token refresh failing:**
1. Check `SessionTimeoutService` configuration
2. Verify token refresh interval settings
3. Review `firebase_auth_repository.dart:119-140` for caching logic

**If specific provider failing:**
1. Disable failing provider temporarily
2. Enable alternative sign-in methods
3. Communicate workaround to users

### Root Cause Fix

| Issue | Fix | File |
|-------|-----|------|
| Token caching bug | Review `_cachedUser` logic | `firebase_auth_repository.dart` |
| Session timeout too aggressive | Adjust `SessionTimeoutService` | `session_timeout_service.dart` |
| Firebase config mismatch | Update `firebase_options.dart` | `firebase_options.dart` |

### Verification Steps
1. Test login flow in staging environment
2. Verify token refresh works
3. Check session persistence across app restart
4. Monitor error rates for 30 minutes

---

## Prevention

- [ ] Add retry logic for transient auth failures
- [ ] Implement circuit breaker for auth service
- [ ] Add auth health check to app startup
- [ ] Set up proactive auth monitoring alerts
- [ ] Regular review of Firebase Auth quotas

---

## Escalation

| Condition | Action | Contact |
|-----------|--------|---------|
| >50% users affected for 15+ min | Page on-call engineer | On-call rotation |
| Firebase service outage | Monitor status, no action needed | Firebase support |
| Security incident suspected | Immediate escalation | Security team |

---

## References

- Auth Service: `lib/services/auth_service.dart`
- Auth Repository: `lib/repositories/firebase/firebase_auth_repository.dart`
- Session Timeout: `lib/services/session_timeout_service.dart`
- SLO Definitions: `docs/operations/SLO_DEFINITIONS.md`
