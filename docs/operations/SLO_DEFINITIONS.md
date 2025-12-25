# Service Level Objectives (SLO) Definitions

**Last Updated:** 2025-12-25

This document defines the Service Level Objectives (SLOs) and rate limiting configurations for the Butlery application. These thresholds are implemented in code and used for real-time monitoring.

---

## Performance SLOs

Performance thresholds are defined in `lib/services/performance/performance_monitoring_service.dart` (lines 61-67).

| Metric | Threshold | Rationale | Warning Behavior |
|--------|-----------|-----------|------------------|
| **Frame Time** | ≤16ms | 60 FPS target for smooth UI | Dropped frame logged; severe warning if >50ms |
| **Network Request** | ≤3 seconds | User patience threshold | Warning logged for slow requests |
| **Cache Hit Rate** | ≥80% | Efficient resource usage | Warning if rate drops below threshold |
| **Memory Usage** | ≤200MB | Device resource limits | Warning on high memory consumption |
| **User Interaction** | ≤100ms | Responsive UI feedback | Warning on slow interaction response |

### Measurement Details

- **Frame Time**: Measured via `SchedulerBinding.addTimingsCallback()`, includes build + raster duration
- **Network Request**: Per-request timing tracked with `recordNetworkRequest()`
- **Cache Hit Rate**: Tracked via `recordCacheAccess()` hit/miss ratio
- **Memory Usage**: Monitored via `recordMemoryUsage(usedMB, totalMB)`
- **User Interaction**: Tracked via `recordUserInteraction()` response time

---

## Rate Limiting

Rate limits are implemented using a token bucket algorithm in `lib/core/rate_limiting/rate_limiter.dart` (lines 161-283).

### Authentication Operations (Restrictive - DoS Prevention)

| Operation | Max Tokens | Refill Rate | Interval | Purpose |
|-----------|-----------|-------------|----------|---------|
| `login` | 5 | 1 | 1 min | Brute force prevention |
| `register` | 3 | 1 | 1 hr | Spam account prevention |
| `passwordReset` | 3 | 1 | 1 hr | Abuse prevention |

### Recipe CRUD Operations (Moderate)

| Operation | Max Tokens | Refill Rate | Interval | Purpose |
|-----------|-----------|-------------|----------|---------|
| `createRecipe` | 10 | 5 | 1 min | API protection |
| `updateRecipe` | 30 | 10 | 1 min | Frequent saves allowed |
| `deleteRecipe` | 10 | 5 | 1 min | Accidental mass delete prevention |
| `fetchRecipes` | 50 | 20 | 1 min | Read-heavy workload support |

### Import Operations (Expensive - Cost Control)

| Operation | Max Tokens | Refill Rate | Interval | Purpose |
|-----------|-----------|-------------|----------|---------|
| `importRecipe` | 10 | 3 | 1 min | Resource protection |
| `ocrExtraction` | 5 | 2 | 1 min | External API cost control |
| `webScraping` | 10 | 3 | 1 min | External service limits |

### Social Operations (Higher - Engagement Priority)

| Operation | Max Tokens | Refill Rate | Interval | Purpose |
|-----------|-----------|-------------|----------|---------|
| `sendMessage` | 60 | 30 | 1 min | Chat functionality |
| `postComment` | 30 | 15 | 1 min | Recipe discussion |
| `addReaction` | 100 | 50 | 1 min | Quick engagement |
| `shareContent` | 20 | 10 | 1 min | Social sharing |
| `addFriend` | 20 | 10 | 1 min | Network growth |
| `removeFriend` | 10 | 5 | 1 min | Deliberate action |

### Shopping & Menu Operations

| Operation | Max Tokens | Refill Rate | Interval | Purpose |
|-----------|-----------|-------------|----------|---------|
| `createShoppingList` | 10 | 5 | 1 min | List management |
| `updateShoppingList` | 50 | 20 | 1 min | Frequent item updates |
| `deleteShoppingList` | 10 | 5 | 1 min | Deliberate action |
| `createMenu` | 10 | 5 | 1 min | Menu planning |
| `updateMenu` | 30 | 15 | 1 min | Menu editing |
| `deleteMenu` | 10 | 5 | 1 min | Deliberate action |

---

## Error Budgets

Based on a 99.9% availability target:

| Period | Allowed Downtime | Error Budget |
|--------|-----------------|--------------|
| Daily | 1.44 minutes | 0.1% |
| Weekly | 10.08 minutes | 0.1% |
| Monthly | 43.8 minutes | 0.1% |
| Yearly | 8.76 hours | 0.1% |

### Error Budget Consumption

- **P0 (Critical)**: Auth failures, data loss - consumes 10x normal budget
- **P1 (High)**: Sync failures, offline issues - consumes 5x normal budget
- **P2 (Medium)**: Performance degradation - consumes 2x normal budget
- **P3 (Low)**: Minor UI issues - consumes 1x normal budget

---

## Alerting Thresholds (Phase 6)

Recommended Firebase Console alert configuration:

### Crashlytics Alerts

| Condition | Threshold | Severity |
|-----------|-----------|----------|
| Crash-free rate drop | <99.5% | P0 |
| New crash type | Any new | P1 |
| Crash velocity spike | >10/hour | P1 |

### Performance Alerts

| Condition | Threshold | Severity |
|-----------|-----------|----------|
| Screen load time | p95 > 2000ms | P2 |
| HTTP request time | p95 > 3000ms | P2 |
| App startup time | p95 > 5000ms | P2 |

---

## References

- **Performance Service**: `lib/services/performance/performance_monitoring_service.dart`
- **Rate Limiter**: `lib/core/rate_limiting/rate_limiter.dart`
- **Logger**: `lib/core/utils/logger.dart`
- **Monitoring Action Plan**: `docs/analysis/actionplans/MONITORING_ACTION_PLAN.md`
