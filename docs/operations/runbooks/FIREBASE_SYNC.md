# Firebase Sync Failures Runbook

**Priority:** HIGH
**Last Updated:** 2025-12-25

---

## Detection

### Alerts
- Performance Monitoring: Firestore write latency spike
- Crashlytics: Sync-related exceptions
- User reports: Data not appearing across devices

### Symptoms
- Recipes not syncing between devices
- Offline changes not uploading
- Conflict resolution failures
- "Sync pending" indicator stuck

### Key Metrics
- Sync success rate (target: >99%)
- Offline queue size
- Time-to-sync after coming online

---

## Impact

| Severity | Condition | User Impact |
|----------|-----------|-------------|
| P0 | All sync operations failing | Data loss risk, cross-device unusable |
| P1 | >10% sync failures | Inconsistent data across devices |
| P2 | Slow sync (<30s delay) | Minor inconvenience |

### Affected Functionality
- Recipe synchronization
- Shopping list real-time updates
- Collaborative features
- Offline mode data persistence

---

## Diagnosis

### Step 1: Check Firestore Status
1. Go to [Firebase Console](https://console.firebase.google.com/) → Firestore
2. Check "Usage" tab for operation errors
3. Review "Rules" for recent changes

### Step 2: Review Offline Queue
```
Key files to check:
- lib/services/offline_service.dart
- lib/core/storage/drift/daos/upload_queue_dao.dart
```

Check for:
- Queue size and oldest pending item
- Failed operation types
- Network connectivity status

### Step 3: Check Firestore Security Rules
1. Firebase Console → Firestore → Rules
2. Verify rules allow current user operations
3. Check for recent rule deployments

### Step 4: Verify Network Connectivity
1. Check device network status
2. Verify Firestore endpoints are reachable
3. Test with different network (WiFi vs cellular)

---

## Resolution

### Immediate Mitigation

**If Firestore is down:**
1. App continues in offline mode automatically
2. Communicate expected delay via in-app message
3. Monitor Firestore status for resolution

**If offline queue stuck:**
1. Check `upload_queue` table in Drift database
2. Identify failing operations
3. Clear corrupted entries if necessary

**If conflict resolution failing:**
1. Review `OfflineService` conflict logic
2. Check timestamp-based resolution
3. Force server-wins for critical conflicts

### Root Cause Fix

| Issue | Fix | File |
|-------|-----|------|
| Queue processing stuck | Reset queue processor | `offline_service.dart` |
| Security rules blocking | Update Firestore rules | Firebase Console |
| Conflict resolution bug | Review merge logic | `offline_service.dart` |
| Network detection false positive | Fix connectivity check | `offline_service.dart` |

### Verification Steps
1. Create test recipe on Device A
2. Verify appears on Device B within 10 seconds
3. Test offline → online transition
4. Verify conflict resolution with simultaneous edits

---

## Prevention

- [ ] Add sync health indicator in app
- [ ] Implement sync retry with exponential backoff
- [ ] Add offline queue size monitoring
- [ ] Set up Firestore quota alerts
- [ ] Regular testing of offline scenarios

---

## Escalation

| Condition | Action | Contact |
|-----------|--------|---------|
| Data loss confirmed | Immediate escalation | Engineering lead |
| Firestore outage >30 min | Monitor, prepare comms | On-call rotation |
| Security rules misconfiguration | Rollback immediately | Security team |

---

## References

- Offline Service: `lib/services/offline_service.dart`
- Upload Queue DAO: `lib/core/storage/drift/daos/upload_queue_dao.dart`
- Firestore Repository: `lib/repositories/firestore_repository.dart`
- SLO Definitions: `docs/operations/SLO_DEFINITIONS.md`
