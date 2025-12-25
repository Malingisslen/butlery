# Performance Degradation Runbook

**Priority:** MEDIUM
**Last Updated:** 2025-12-25

---

## Detection

### Alerts
- Firebase Performance: Screen load time p95 >2000ms
- Firebase Performance: App startup time p95 >5000ms
- Crashlytics: ANR (App Not Responding) reports

### Symptoms
- Slow screen transitions
- Janky scrolling (dropped frames)
- High memory usage warnings
- App freezes or ANRs
- Slow network requests

### Key Metrics (from SLO_DEFINITIONS.md)
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Frame Time | ≤16ms | >50ms (severe) |
| Network Request | ≤3 seconds | p95 >3000ms |
| Cache Hit Rate | ≥80% | <80% |
| Memory Usage | ≤200MB | >200MB |
| User Interaction | ≤100ms | p95 >100ms |

---

## Impact

| Severity | Condition | User Impact |
|----------|-----------|-------------|
| P1 | App unresponsive (ANR) | Cannot use app |
| P2 | Significant slowdown | Frustrating experience |
| P3 | Minor jank | Noticeable but usable |

### Affected Functionality
- All app navigation and interactions
- Recipe loading and display
- Image loading
- Search and filtering

---

## Diagnosis

### Step 1: Check Firebase Performance Dashboard
1. Go to [Firebase Console](https://console.firebase.google.com/) → Performance
2. Review "Dashboard" for trends
3. Check "Screen rendering" traces
4. Review "Network requests" timing

### Step 2: Identify Hot Spots
```
Key files to check:
- lib/services/performance/performance_monitoring_service.dart
- lib/services/performance/intelligent_cache_manager.dart
```

Check performance reports for:
- Dropped frame percentage
- Average frame time
- Cache hit rate
- Memory usage trends

### Step 3: Profile Specific Screens
1. Identify slowest screens from Firebase dashboard
2. Check corresponding ViewModel for heavy operations
3. Review widget rebuild frequency

### Step 4: Check Memory Usage
1. Review `recordMemoryUsage()` logs
2. Check for memory leaks in image loading
3. Verify cache eviction is working

---

## Resolution

### Immediate Mitigation

**If high memory usage:**
1. Trigger cache cleanup via `IntelligentCacheManager`
2. Reduce image quality temporarily
3. Disable non-essential background tasks

**If slow network requests:**
1. Check backend service health
2. Enable aggressive caching
3. Reduce payload sizes

**If dropped frames:**
1. Identify heavy widgets
2. Add `const` constructors where missing
3. Defer non-critical UI updates

### Root Cause Fix

| Issue | Fix | File |
|-------|-----|------|
| Memory leak | Fix dispose() calls | Affected ViewModel |
| Heavy widget rebuilds | Use `Selector` or memoization | Widget file |
| Slow database queries | Add indexes, optimize queries | Repository file |
| Large image loading | Implement progressive loading | Image widget |
| Cache inefficiency | Tune cache parameters | `intelligent_cache_manager.dart` |

### Verification Steps
1. Run app with Flutter DevTools profiler
2. Verify frame rate stays above 55 FPS
3. Check memory stays under 200MB
4. Test on low-end device

---

## Prevention

- [ ] Regular performance profiling in CI
- [ ] Set up automated performance regression tests
- [ ] Add performance budgets for new features
- [ ] Monitor cache hit rates continuously
- [ ] Regular review of image asset sizes

---

## Escalation

| Condition | Action | Contact |
|-----------|--------|---------|
| ANR rate >1% | Investigate immediately | Engineering lead |
| Performance regression after release | Consider rollback | Release manager |
| Memory crash spike | Emergency patch | On-call engineer |

---

## References

- Performance Service: `lib/services/performance/performance_monitoring_service.dart`
- Cache Manager: `lib/services/performance/intelligent_cache_manager.dart`
- SLO Definitions: `docs/operations/SLO_DEFINITIONS.md`
- Firebase Performance: `https://console.firebase.google.com/`
