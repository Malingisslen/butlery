# Performance & Scalability Analysis

**Prompt 04 of 6 -- Consolidated Analysis Series**

---

## Header

```
Analyst:        Claude (Opus 4.6)
Scope:          App performance, Firebase data layer, scalability projections
Consolidates:   Performance (v3, 9 dims), Scalability (v3, 8 dims),
                Firebase dims 1/3/4/5 (Schema, Queries, Streams, Offline)
Cross-prompt:   Security rules covered in 02. Dependencies covered in 05.
                Testing covered in 03. Monitoring/observability covered in 03.
```

**Mission:** Elite mobile performance and future-proof scaling. Sub-2-second startup, 60fps rendering, minimal memory footprint, cost-efficient Firebase usage, and an architecture that handles 10x-1000x growth without rewrites.

---

## Two-Phase Approach

### Phase 1: Investigation Only (Your Current Task)

No code changes. No config edits. No optimizations. Your deliverable is a comprehensive findings report with file:line references, metrics, and projections.

Do not:
- Edit any source files
- Modify Firestore indexes or rules
- Change any configurations or assets
- Suggest "let me fix this quickly"

### Phase 2: Smart Optimization Plan (After Phase 1)

Only after Phase 1 is 100% complete:
1. Analyze all findings holistically
2. Prioritize by user impact, cost savings, and effort
3. Group related optimizations to avoid conflicting changes
4. Sequence work to prevent regressions
5. Produce a phased roadmap (now / 10x / 100x / 1000x)

Investigation first. Planning second. Document everything. Change nothing.

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase
DI system:           ServiceLocator.get<T>(), modular DI modules
                     Constructor injection in DI modules, ServiceLocator in widgets/ViewModels
Platforms:           Android, iOS, Web, macOS, Windows
Firebase services:   Firestore, Auth, Storage, FCM, Cloud Functions
Firestore indexes:   34 composite indexes (firestore.indexes.json)
Cloud Functions:     structureRecipe, ocrRecipeImage, updateRecipeRatingStats,
                     sendNotification, sendNotificationBatch
Key mixin:           FirebaseServiceMixin (820 lines) -- centralizes Firebase operations
Sharing pattern:     Subcollection-based (Issue #014) -- members subcollections
Known collections:   users/{userId}/recipes, menus, shopping_lists,
                     shared_recipes, groups, friend_requests, notifications

Generated file exclusions (skip during analysis):
  - *.g.dart, *.freezed.dart, app_localizations*.dart
```

---

## Analysis Framework: 7 Dimensions

Weights total 100 points.

### Dimension 1: App Startup & Frame Rate (18 points)

**Target:** Sub-2-second cold start. Consistent 60fps with zero jank.

**1A. Startup Performance**

Investigate:
- ApplicationBootstrap initialization sequence in lib/main.dart
- Blocking operations before first frame (synchronous Firebase init, network calls, heavy computation)
- DI registration strategy: which services are eager vs lazy
- Services initialized at startup but not needed until later
- Firebase initialization timing (blocking the main isolate?)
- Asset loading on startup (fonts, images, data files)
- Auth state check (async or blocking?)
- Cache-first strategy (show cached data before network response?)

Performance targets:
- Cold start: less than 2.0s on mid-range device
- Warm start: less than 1.0s
- Time to first frame: less than 500ms
- Time to interactive: less than 2.0s

Output required:
- Startup time breakdown estimate (init, first frame, interactive)
- Blocking operations with file:line references
- Services that should be lazy-loaded
- Startup optimization opportunities with projected time savings

**1B. Widget Build & Frame Rate**

Investigate:
- Missing const constructors (wasted rebuilds)
- Expensive build methods (complex calculations, loops, conditionals exceeding 16ms budget)
- Unnecessary rebuilds: ChangeNotifier.notifyListeners called too broadly, context.watch on large providers
- Missing widget keys causing unnecessary recreation
- ListView/GridView without .builder (loading all items eagerly)
- Missing RepaintBoundary on independently-updating subtrees
- Animation performance: controllers disposed?, smooth curves?, layout-thrashing animations?
- Shader compilation jank on first run
- DCM widget quality rules if dart_code_metrics is available

Performance targets:
- UI rendering: 16.67ms per frame (60fps)
- Jank: less than 1% of frames dropped
- Smooth scrolling maintained at 60fps
- Animations at 60fps throughout

Output required:
- Expensive widget builds with estimated frame cost
- Missing const constructors (file:line list)
- Unnecessary rebuild patterns
- List rendering optimization opportunities
- Animation performance issues

---

### Dimension 2: Memory & Resource Management (15 points)

**Target:** Typical session under 150MB, zero memory leaks.

Investigate:

1. **Memory Leak Detection**
   - StreamSubscription without cancel (check all services and ViewModels)
   - StreamManagementMixin adoption: all services with streams should use it
   - ChangeNotifier listeners not removed
   - TextEditingController, AnimationController, ScrollController not disposed
   - Timer/Future not cancelled on dispose
   - Static references preventing garbage collection

2. **State Management Efficiency**
   - Unnecessary notifyListeners() calls (triggering full subtree rebuilds)
   - State scope: data kept globally that should be local to a screen
   - ViewModel disposal: properly cleared on navigation?
   - Provider disposal: services cleaned up on logout?

3. **Image & Cache Memory**
   - CachedNetworkImage usage vs raw Image.network
   - Image cache size limits configured?
   - Large images held in memory when off-screen
   - Thumbnail vs full-size strategy
   - IntelligentCacheManager (lib/services/performance/intelligent_cache_manager.dart): expiration policies, hit rates

4. **Resource Exhaustion**
   - Too many concurrent Firebase listeners (cost + memory)
   - Large objects retained across navigation (recipe lists, image data)
   - Background tasks running when app is backgrounded
   - Battery efficiency: GPS usage, wake locks, unnecessary network polling

Performance targets:
- App memory: less than 150MB typical, less than 250MB peak
- Memory leaks: 0 detected
- Image cache: less than 50MB
- Memory growth: less than 5MB/hour during typical use

Output required:
- Memory leak risks with file:line references
- Undisposed resources (controllers, subscriptions, listeners)
- State management inefficiencies
- Image memory optimization opportunities
- Battery drain sources

---

### Dimension 3: Firebase Query & Schema Design (18 points)

**Target:** Efficient schema optimized for actual query patterns, no unbounded growth, all queries indexed.

**Note:** Security rules are covered in prompt 02. This dimension focuses on schema design, query performance, and cost efficiency.

**3A. Collection & Document Structure**

Investigate:
- Map ALL Firestore collections with their fields, approximate document counts, and average document sizes
  - User-scoped: users/{userId}/recipes, /menus, /shopping_lists, /notifications, /personal_tags
  - Global: shared_recipes, groups, friend_requests
  - Subcollection sharing: shared_recipes/{id}/members, groups/{id}/members
- Document size analysis: any documents approaching 1MB limit?
- Field types: appropriate choices? Timestamps as Timestamp vs int?
- Array fields: any exceeding 100 elements? Any approaching 20K element Firestore limit?
- Map nesting depth: deeply nested maps that prevent querying?
- Data duplication strategy: intentional denormalization, consistency mechanisms (Cloud Functions triggers? batch updates?)
- Hot spots: high write rate to same document (e.g., counters, shared state)
- Unbounded document growth: arrays or maps that grow without limit per user activity

**3B. Query Patterns & Indexing**

Investigate:
- Inventory all Firestore queries across repositories and services
- Query types found: simple (single field), compound (multiple where clauses), range (>, <), array-contains, orderBy
- N+1 query problems: loops fetching individual documents that should be batched
- Sequential queries that could run in parallel
- Queries without limits (unbounded reads on growing collections)
- Pagination: all list queries must use limits with startAfter/endBefore cursor-based pagination
- Composite indexes: cross-reference queries against firestore.indexes.json (34 indexes)
  - Missing indexes (would cause runtime errors)
  - Unnecessary indexes (maintenance cost, storage)
- Query optimization: redundant queries fetching same data, missing client-side caching, over-fetching fields

Output required:
- Complete Firestore collection structure map with fields, queries, and issues
- N+1 query problems with file:line references
- Missing or unnecessary composite indexes
- Unbounded queries (no limits)
- Query cost estimates (reads per operation)
- Schema refactoring recommendations with migration complexity

---

### Dimension 4: Real-time Listeners & Stream Management (12 points)

**Target:** Minimal concurrent listeners, all properly scoped and disposed, graceful offline behavior.

Investigate:

1. **Stream Listener Inventory**
   - Find all .snapshots() calls (real-time listeners)
   - Classify by scope: document listener, collection listener, collection group listener
   - What data is listened to in real-time: recipes, menus, shopping lists, friend requests, presence, notifications
   - Count concurrent listeners per typical user session

2. **Listener Lifecycle**
   - StreamSubscription cancellation: every .listen() must have a corresponding .cancel()
   - ViewModel onDispose: do all ViewModels with listeners call cancel?
   - StreamManagementMixin adoption: services using streams should use this mixin
   - Identify potential memory leaks from uncancelled listeners

3. **Listener Efficiency**
   - Overly broad listeners: listening to entire collections without where/limit constraints
   - Redundant listeners: multiple listeners on the same data path
   - Listener count: too many concurrent listeners degrades performance and increases cost
   - Firebase connection limits: 100K concurrent per project (projected usage at scale)

4. **Offline Behavior**
   - Cached data shown when offline?
   - Reconnection handling: listeners resume correctly after network loss?
   - Error recovery: what happens when a listener fails?
   - Pending writes indicator shown to user?

Output required:
- Real-time listener inventory with scope, lifecycle, and cost analysis
- Memory leak risks from undisposed listeners
- Overly broad listeners with cost implications
- Concurrent listener count estimate per user
- Offline behavior gaps

---

### Dimension 5: Scalability Projections (15 points)

**Target:** Architecture supports 10x-1000x user growth with predictable cost scaling.

Investigate:

1. **Growth Capacity Analysis**
   - 10x users: what breaks first? Data structure limits, query performance, listener counts?
   - 100x users: where does cost become non-linear? Architecture bottlenecks?
   - 1000x users: is Firebase still viable? What requires a hybrid approach?

2. **Firebase Limits at Scale**
   - 1MB document size: any documents that grow with user count?
   - 500 batch operations limit: any batch operations approaching this?
   - 1 write/sec per document: any hot-spot documents (counters, shared state)?
   - 10K concurrent listeners per project: projected listener count at scale?
   - Cloud Functions: 540s execution time, 1000 concurrent executions

3. **Cost Scaling**
   - Estimated reads/writes per user per day for major operations
   - Cost projections at current / 1K / 10K / 100K active users
   - Cost hot spots: most expensive operations, unbounded queries, broad real-time listeners
   - Per-user cost trend: linear, sub-linear, or super-linear?
   - Break-even analysis: when does Firebase vs custom backend make sense?

4. **Architecture Bottlenecks**
   - Single points of contention (shared documents, global counters)
   - Shared state limits (groups with many members, popular shared recipes)
   - Feature extensibility: how easy to add new data types, new sharing models, new platforms?
   - Data migration complexity at scale

Output required:
- Scalability limits table at 1x / 10x / 100x / 1000x users
- Cost projections table with per-user cost
- Top bottlenecks with scale threshold (breaks at Nx)
- Architecture decision points (Firebase-only vs hybrid vs custom)
- Feature extensibility assessment

---

### Dimension 6: Bundle Size & Network Efficiency (12 points)

**Target:** APK under 50MB, minimal network usage, effective caching.

Investigate:

1. **App Bundle Size**
   - Current APK/AAB/IPA size estimate (or build output)
   - Largest contributors: Dart compiled code, assets, native libraries
   - Unused code: tree-shaking effectiveness
   - Unused assets: images, fonts, data files not referenced in code
   - Split APKs/App Bundles configured (per-ABI)?
   - Deferred imports: features that could be lazy-loaded

2. **Image & Asset Optimization**
   - Image formats: PNG vs JPEG vs WebP (appropriate choices?)
   - Image compression: applied before Firebase Storage upload?
   - Thumbnail generation strategy (server-side via Cloud Functions?)
   - CDN usage for media delivery
   - Download URL caching: Firebase Storage URLs re-fetched or cached?

3. **Network Request Efficiency**
   - Request batching: multiple Firestore operations combined?
   - Request deduplication: same data fetched multiple times in a session?
   - Caching strategy: HTTP caching, client-side caching (IntelligentCacheManager)
   - Cache hit rates for common operations
   - Data transfer per session estimate

4. **Firebase Storage**
   - Orphaned files: images uploaded but recipe deleted
   - Bandwidth optimization: serving appropriate image sizes
   - Storage cleanup processes in place?

Performance targets:
- Android APK: less than 50MB
- iOS IPA: less than 60MB
- Asset size: less than 20MB
- Data transfer: less than 5MB/hour typical use
- Cache hit rate: greater than 70%

Output required:
- Bundle size breakdown
- Asset optimization opportunities
- Network efficiency assessment
- Firebase Storage cleanup recommendations

---

### Dimension 7: Offline Performance & Sync (10 points)

**Target:** Core features functional offline, automatic sync on reconnect, no data loss.

Investigate:

1. **Firestore Offline Persistence**
   - Enabled? Check FirebaseFirestore.instance.settings
   - Cache size configuration: default 40MB or custom?
   - Cache eviction strategy: LRU? Age-based?
   - What data is available offline?

2. **Cache-First Patterns**
   - GetOptions(source: Source.cache) usage for read operations
   - Fallback patterns: cache first, then server on cache miss
   - Cache invalidation: when is stale data refreshed?

3. **Offline CRUD Capabilities**
   - Which operations work offline:
     - View recipes: expected yes (cached)
     - View menus: expected yes (cached)
     - View shopping lists: expected yes (cached)
     - Create/edit recipes: TBD (pending writes queue?)
     - Shopping list updates: TBD (real-time sync offline?)
   - Error messaging: does the user know they are offline?

4. **Sync Strategy**
   - Reconnection behavior: automatic sync of pending writes?
   - Sync priority: important data synced first?
   - Pending writes count/indicator shown to user?
   - Conflict resolution: simultaneous offline edits by collaborators
     - Last-write-wins vs merge strategy
     - Shopping list shared editing offline scenario

5. **Data Loss Scenarios**
   - Write failures: what happens if a pending write fails on sync?
   - Partial sync: app killed mid-sync
   - Cache corruption recovery

Performance targets:
- Core features: 100% functional offline (view operations)
- Sync time: less than 5s after reconnect
- Data loss: 0 scenarios identified
- Conflict resolution: defined strategy for shared data

Output required:
- Offline functionality matrix (feature / works offline? / notes)
- Cache configuration assessment
- Sync strategy issues
- Data loss risk scenarios
- Conflict resolution gaps

---

## Investigation Process

### Stage 1: Automated Profiling

Run or review output from:
- `flutter analyze` (lint issues affecting performance)
- Bundle size from build output (if available)
- Startup sequence trace through main.dart and ApplicationBootstrap
- DCM widget quality metrics (if dart_code_metrics installed)

Tools: Grep, Glob, Read, Bash (flutter analyze). No Edit.

### Stage 2: Deep Investigation

Work through all 7 dimensions systematically:

1. **Startup & Frame Rate** (2 hours)
   - Trace startup sequence, identify blocking operations
   - Audit widget builds, const constructors, rebuild patterns, list rendering
   - Document jank sources with frame budget impact

2. **Memory & Resources** (1.5 hours)
   - Audit resource disposal across all ViewModels and services
   - Check StreamManagementMixin adoption
   - Review image caching and state management efficiency

3. **Firebase Schema & Queries** (2.5 hours)
   - Map all Firestore collections with fields and queries
   - Cross-reference queries against firestore.indexes.json
   - Identify N+1 problems, missing pagination, unbounded reads

4. **Listeners & Streams** (1.5 hours)
   - Inventory all .snapshots() calls with scope and lifecycle
   - Verify disposal in every ViewModel and service
   - Count concurrent listeners per session

5. **Scalability Projections** (1.5 hours)
   - Project every bottleneck at 10x/100x/1000x
   - Build cost model from reads/writes per operation
   - Identify architecture decision points

6. **Bundle & Network** (1 hour)
   - Analyze bundle composition and asset optimization
   - Audit network request patterns and caching

7. **Offline & Sync** (1 hour)
   - Test offline persistence configuration
   - Map offline capabilities per feature
   - Assess sync and conflict resolution strategy

### Stage 3: Report Compilation

- Compile all findings with metrics and file:line references
- Score each dimension
- Build performance benchmarks table (current vs target)
- Build scalability limits table
- Build cost projections table
- Classify issues by severity
- Produce executive summary
- Prepare Phase 2 optimization roadmap structure

---

## Output Format

### Executive Summary

```
BUTLERY PERFORMANCE & SCALABILITY ANALYSIS -- PHASE 1
======================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.6)
Firebase Project: butlery-app-1
Platforms: Android, iOS, Web, macOS, Windows

OVERALL SCORE: X/100
  1. App Startup & Frame Rate:         X/18
  2. Memory & Resource Management:     X/15
  3. Firebase Query & Schema Design:   X/18
  4. Real-time Listeners & Streams:    X/12
  5. Scalability Projections:          X/15
  6. Bundle Size & Network Efficiency: X/12
  7. Offline Performance & Sync:       X/10

STATUS: [Elite | Good | Needs Optimization | Critical Issues]

CRITICAL ISSUES: X found
HIGH PRIORITY:   X found
MEDIUM PRIORITY: X found
LOW PRIORITY:    X found
```

### Performance Benchmarks Table

```
| Metric                  | Current (est.) | Target    | Gap       | Status |
|-------------------------|----------------|-----------|-----------|--------|
| Cold start time         | X.Xs           | < 2.0s    | +/- X.Xs  | ...    |
| Warm start time         | X.Xs           | < 1.0s    | +/- X.Xs  | ...    |
| Average FPS             | XXfps          | 60fps     | -XXfps    | ...    |
| Jank percentage         | X%             | < 1%      | +X%       | ...    |
| Memory usage (typical)  | XXXmb          | < 150MB   | +XXmb     | ...    |
| Memory usage (peak)     | XXXmb          | < 250MB   | +XXmb     | ...    |
| Bundle size (Android)   | XXmb           | < 50MB    | +XXmb     | ...    |
| Firestore queries/screen| X              | < 5       | +X        | ...    |
| Data transfer/hour      | XXmb           | < 5MB     | +XXmb     | ...    |
| Offline features        | X%             | 100%      | -X%       | ...    |
```

### Firestore Collection Structure Map

For each collection, document:
- Path and scope (user-scoped vs global)
- Fields with types
- Average document size and count
- Queries hitting this collection (with index status)
- Issues identified (unbounded growth, hot spots, missing indexes)

### Cost Analysis

```
| Scale       | Active Users | Est. Reads/Day | Est. Writes/Day | Est. Monthly Cost | Per User/Month |
|-------------|-------------|----------------|-----------------|-------------------|----------------|
| Current     | X           | X,XXX          | XXX             | $XX               | $X.XX          |
| 10x         | X0          | XX,XXX         | X,XXX           | $XXX              | $X.XX          |
| 100x        | X00         | XXX,XXX        | XX,XXX          | $X,XXX            | $X.XX          |
| 1000x       | X,000       | X,XXX,XXX      | XXX,XXX         | $XX,XXX           | $X.XX          |
```

Include: cost hot spots, optimization potential, break-even point for alternative architecture.

### Scalability Limits Table

```
| Bottleneck                    | Hits at | Impact                        | Mitigation Effort |
|-------------------------------|---------|-------------------------------|-------------------|
| [specific bottleneck]         | ~Nx     | [what breaks]                 | X days            |
| ...                           | ...     | ...                           | ...               |
```

### Detailed Findings by Dimension

For each of the 7 dimensions:

```
## [DIMENSION NAME] -- Score: X/Y

### Summary
[2-3 sentence overview]

### Issues Found

#### CRITICAL
1. **[Issue Title]** -- [file:line or collection path]
   - Impact: [what breaks, cost implication, user impact]
   - Current: [description of current state]
   - Best Practice: [what should be done]
   - Scale Threshold: [at what user count this becomes a problem]
   - Effort: [hours/days]

#### HIGH
[Same format]

#### MEDIUM
[Same format]

#### LOW
[Same format]

### Quick Wins
- [High impact, low effort items]
```

### Remediation Roadmap

Group findings into phases:
- **Immediate** (CRITICAL items, quick wins): specific items, total effort
- **Short-term** (HIGH items, 10x readiness): specific items, total effort
- **Medium-term** (MEDIUM items, 100x readiness): specific items, total effort
- **Long-term** (architecture decisions, 1000x readiness): decision points

---

## Butlery-Specific Performance Checks

These are known patterns in the Butlery codebase. Verify their status during investigation.

1. **FirebaseServiceMixin (820 lines)**
   - All Firebase-accessing services should use this mixin
   - Check: executeFirebaseOperation(), executeFirebaseOperationWithRetry()
   - Check: DNS-aware error handling via executeFirebaseOperationWithDNSResilience()

2. **Stream Disposal (StreamManagementMixin)**
   - Services should use StreamManagementMixin for proper stream lifecycle
   - Check adoption across all services with active streams

3. **IntelligentCacheManager**
   - lib/services/performance/intelligent_cache_manager.dart
   - Check: cache expiration policies, cache hit rates, memory limits

4. **Firebase Performance Traces**
   - traceOperation<T>() wrapper for critical operations
   - Check: trace coverage for critical user journeys (startup, recipe load, list sync)

5. **Image Compression**
   - FirebaseStorageRepository includes compression before upload
   - Verify: compression applied before Firebase Storage upload
   - Check: thumbnail generation strategy

6. **Stream Pagination Limits**
   - Butlery limits recipe streams to 50 items to prevent memory bloat
   - Verify: all real-time watchers have proper limits
   - Check: pagination for large collections (fetchAllUserRecipes uses cursor-based batching)

7. **Cloud Functions Performance**
   - structureRecipe / ocrRecipeImage: LLM integration (Mistral AI) -- check timeout config
   - updateRecipeRatingStats: denormalized rating aggregation trigger -- check for hot spots
   - sendNotification / sendNotificationBatch: FCM delivery -- check batch size limits

8. **Multi-Platform Considerations**
   - 5 platforms (Android, iOS, Web, macOS, Windows) with different performance characteristics
   - Platform-specific checks in firebase_config.dart
   - Web: no native compilation, different memory model
   - Desktop: different screen sizes, input patterns

---

## Phase 1 Completion Criteria

This investigation is complete when:

1. All 7 dimensions scored and documented
2. Startup sequence traced with blocking operations identified
3. Widget build performance audited (const constructors, rebuild patterns)
4. Memory leak risks documented with file:line references
5. All Firestore collections mapped with fields, queries, and issues
6. Composite indexes cross-referenced (34 indexes vs actual query needs)
7. Real-time listeners inventoried with lifecycle and cost analysis
8. Cost projections calculated at 4 scale levels
9. Scalability bottlenecks identified with scale thresholds
10. Offline functionality mapped per feature
11. Bundle size breakdown complete
12. All issues classified by severity with effort estimates
13. Zero code changes made -- documentation only
14. Phase 2 roadmap structure prepared

**Phase 1 Output:** Comprehensive performance and scalability findings report with metrics, cost projections, and scalability limits.

**Phase 2 Input:** Use this report to build a prioritized optimization roadmap with phased implementation plan.

---

## Begin Phase 1 Investigation

Execute comprehensive performance and scalability investigation. Profile startup, audit widgets, map Firestore schema, inventory queries and listeners, project costs at scale, test offline behavior. Document every finding with file:line references and metrics. Change nothing.

Phase 1 Goal: A complete, detailed findings report ready for Phase 2 smart optimization planning.
