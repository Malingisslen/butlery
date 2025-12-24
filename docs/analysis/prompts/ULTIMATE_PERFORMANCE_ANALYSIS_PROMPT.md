# ULTIMATE BUTLERY MOBILE PERFORMANCE & OPTIMIZATION ANALYSIS PROMPT

**Copy and paste this entire prompt to Claude to trigger the most comprehensive mobile performance investigation.**

---

## Mission: Lightning-Fast Mobile Experience

Perform the most thorough, uncompromising mobile performance analysis of the Butlery Flutter application. The goal is to achieve **elite mobile performance** with:
- Sub-2-second app startup
- Buttery smooth 60fps animations
- Minimal memory footprint
- Excellent battery efficiency
- Responsive UI (no jank)
- Optimized network usage
- Small app bundle size
- Seamless offline experience

This is not a superficial performance check. This is a **comprehensive mobile optimization audit** across 9 performance dimensions.

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH - READ CAREFULLY

This analysis follows a **strict two-phase approach**:

### PHASE 1: INVESTIGATION & DOCUMENTATION (Your Current Task)

**🚫 ABSOLUTELY NO CODE CHANGES ALLOWED**

Your **ONLY** task is to:
1. **INVESTIGATE** - Thoroughly examine performance characteristics
2. **DOCUMENT** - Record every finding with file:line references and metrics
3. **CATEGORIZE** - Classify issues by severity (Critical/High/Medium/Low)
4. **ESTIMATE** - Provide effort estimates and performance gain projections

**DO NOT:**
- ❌ Make ANY code edits
- ❌ Fix ANY performance issues
- ❌ Optimize ANY code
- ❌ Change ANY configurations
- ❌ Modify ANY assets
- ❌ Even suggest "let me fix this quickly"

**Your output is a COMPREHENSIVE PERFORMANCE FINDINGS REPORT** - nothing else.

### PHASE 2: SMART OPTIMIZATION PLAN (After Documentation Complete)

**Only after Phase 1 is 100% complete**, you will:
1. **ANALYZE** all documented findings together
2. **PRIORITIZE** by user impact, effort, and performance gain
3. **GROUP** related optimizations for efficient implementation
4. **CREATE** a smart, sequenced optimization roadmap
5. **ESTIMATE** performance improvements (startup time, fps, memory, battery)

**This is a separate step that happens AFTER all investigation is done.**

---

## Why This Approach?

✅ **Complete Picture**: See ALL performance issues before deciding what to optimize
✅ **Smart Prioritization**: Understand which optimizations give biggest gains
✅ **Efficient Planning**: Group related optimizations, avoid conflicting changes
✅ **Risk Management**: Sequence optimizations to avoid performance regressions
✅ **Better Decisions**: Full context before making optimization trade-offs

**Remember: Investigation first, action later. Document everything, change nothing.**

---

## Analysis Framework: 9 Performance Dimensions

### 1. APP STARTUP PERFORMANCE (Weight: 18%)

**Gold Standard:** Time to interactive < 2 seconds on mid-range devices.

**Investigate:**

1. **Startup Time Analysis**
   - Estimate current startup time (cold start, warm start)
   - Identify blocking operations on startup
   - Check for synchronous initialization (should be async)
   - Review main() execution (minimal work?)

2. **ApplicationBootstrap Analysis**
   - Review lib/main.dart initialization
   - Check DI initialization (ApplicationBootstrap)
   - Identify eager vs. lazy service registration
   - Find services initialized but not immediately needed
   - Check for blocking Firebase initialization

3. **First Frame Rendering**
   - Identify widget tree build during startup
   - Check for expensive build methods on first frame
   - Verify splash screen strategy
   - Review initial route complexity

4. **Asset Loading**
   - Check for assets loaded synchronously on startup
   - Verify image preloading strategy
   - Review font loading (preloaded?)
   - Check for unnecessary asset loading

5. **Network Calls on Startup**
   - Identify Firebase queries executed before first frame
   - Check for blocking API calls
   - Verify auth state check (async?)
   - Review cache strategy (show cached data first?)

**Output Required:**
- Startup time breakdown (init, first frame, interactive)
- Blocking operations with file:line references
- Services that should be lazy-loaded
- Startup optimization opportunities with time savings
- Effort estimates for startup improvements

**Performance Targets:**
- Cold start: < 2.0s on mid-range device
- Warm start: < 1.0s
- Time to first frame: < 500ms
- Time to interactive: < 2.0s

---

### 2. FRAME RATE & UI SMOOTHNESS (Weight: 16%)

**Gold Standard:** Consistent 60fps (16.67ms per frame) with no dropped frames or jank.

**Investigate:**

1. **Widget Build Performance**
   - Find expensive build methods (complex calculations, loops)
   - Check for const constructors (missing const = wasted rebuilds)
   - Verify widget keys usage (prevent unnecessary rebuilds)
   - Identify overly complex widget trees (too deep?)
   - Review build method purity (no side effects?)

2. **Rebuild Optimization**
   - Find widgets rebuilding unnecessarily
   - Check ChangeNotifier usage (notifyListeners called too often?)
   - Verify selective rebuilding (Consumer vs. context.watch)
   - Identify widgets that should use RepaintBoundary
   - Check for AnimatedBuilder vs. full rebuilds

3. **List Performance**
   - Verify ListView.builder usage (not ListView with all items)
   - Check GridView.builder usage
   - Review itemExtent usage (improves performance)
   - Identify lists without lazy loading
   - Check for addAutomaticKeepAlives (memory vs. scroll performance)

4. **Image Performance**
   - Check image loading strategy (caching? precaching?)
   - Verify image sizing (exact size or scaled?)
   - Review Image.network vs. cached_network_image
   - Check for unoptimized images (large file sizes)
   - Verify image decode strategy

5. **Animation Performance**
   - Review animation implementations (smooth? 60fps?)
   - Check for jank during animations
   - Verify animation controllers disposed properly
   - Review animation curves and durations
   - Check for layout-heavy animations (expensive)

**Output Required:**
- Expensive widget builds with profiling data
- Missing const constructors (file:line references)
- Unnecessary rebuild patterns
- List rendering optimization opportunities
- Image loading improvements
- Animation performance issues
- Effort estimates with fps improvement projections

**Performance Targets:**
- UI rendering: 16.67ms per frame (60fps)
- Jank: < 1% of frames
- Smooth scrolling: 60fps maintained
- Animation smoothness: 60fps throughout

---

### 3. MEMORY MANAGEMENT (Weight: 14%)

**Gold Standard:** Memory usage < 150MB for typical session, no memory leaks.

**Investigate:**

1. **Memory Usage Patterns**
   - Estimate typical memory usage
   - Identify memory growth patterns (leaks?)
   - Check for memory spikes during operations
   - Review memory usage during navigation (released?)

2. **Memory Leak Detection**
   - Find StreamSubscription without cancel
   - Check ChangeNotifier listeners not removed
   - Identify TextEditingController not disposed
   - Verify AnimationController disposal
   - Check for Timer/Future not cancelled
   - Review static references (prevent GC)

3. **Image Memory Management**
   - Check image caching strategy (ImageCache)
   - Review image cache size limits
   - Verify large images are released when off-screen
   - Check for image memory leaks
   - Review thumbnail vs. full-size image strategy

4. **List Memory Optimization**
   - Verify lists release off-screen items
   - Check for AutomaticKeepAlive usage (necessary?)
   - Review cacheExtent configuration
   - Identify lists holding too many items in memory

5. **State Management Memory**
   - Check ViewModel disposal (properly cleared?)
   - Review Provider disposal
   - Verify service cleanup on logout
   - Check for cached data cleared appropriately

**Output Required:**
- Memory leak risks with file:line references
- Undisposed resources (controllers, subscriptions, listeners)
- Image memory optimization opportunities
- Memory usage reduction strategies
- Effort estimates with memory savings projections

**Performance Targets:**
- App memory usage: < 150MB typical, < 250MB peak
- Memory leaks: 0 detected
- Image cache: < 50MB
- Memory growth: < 5MB/hour during typical use

---

### 4. APP BUNDLE SIZE & ASSETS (Weight: 12%)

**Gold Standard:** App bundle < 50MB, optimized assets, minimal dependencies.

**Investigate:**

1. **App Bundle Size Analysis**
   - Check current APK/IPA size
   - Identify largest contributors to bundle size
   - Review code size (Dart code compiled size)
   - Check for unused code (tree-shaking effective?)
   - Verify split APKs/App Bundles used (per-ABI)

2. **Asset Optimization**
   - Audit all assets (images, fonts, data files)
   - Check image formats (PNG vs. JPEG vs. WebP)
   - Verify image compression levels
   - Review asset size (any unnecessarily large?)
   - Check for duplicate assets
   - Verify unused assets (assets not referenced in code)

3. **Dependency Analysis**
   - Review pubspec.yaml dependencies
   - Identify large dependencies (bundle size impact)
   - Check for unused dependencies
   - Verify alternative lighter dependencies exist
   - Review dependency versions (newer = smaller?)

4. **Code Splitting Opportunities**
   - Identify features that could be lazy-loaded
   - Check for code splitting implementation
   - Review deferred loading usage
   - Verify feature modules (can be split?)

**Output Required:**
- App bundle size breakdown
- Asset optimization opportunities (file sizes, formats)
- Large dependencies to review
- Unused assets/dependencies
- Bundle size reduction projections
- Effort estimates for size optimizations

**Performance Targets:**
- Android APK: < 50MB
- iOS IPA: < 60MB
- Asset size: < 20MB
- Code size: < 30MB

---

### 5. NETWORK EFFICIENCY (Weight: 12%)

**Gold Standard:** Minimal network usage, intelligent batching, effective caching.

**Investigate:**

1. **Network Request Patterns**
   - Inventory all network requests (APIs, Firebase, images)
   - Check request frequency (polling? push?)
   - Verify request batching (multiple requests combined?)
   - Identify redundant requests (same data fetched multiple times)
   - Review request timing (all at once or spread out?)

2. **Data Transfer Optimization**
   - Check response sizes (fetching too much data?)
   - Verify compression usage (gzip?)
   - Review payload efficiency (JSON minimal? Protocol Buffers?)
   - Check for over-fetching (get all fields when only need few?)
   - Verify pagination (not fetching all data at once)

3. **Caching Strategy**
   - Review HTTP caching (Cache-Control headers)
   - Check for client-side caching (SharedPreferences, Hive)
   - Verify image caching (cached_network_image)
   - Identify data that should be cached
   - Review cache invalidation strategy

4. **Offline-First Patterns**
   - Check for offline data availability
   - Verify cache-first then network pattern
   - Review data sync strategy (background sync?)
   - Check for conflict resolution (offline edits)

**Output Required:**
- Network request inventory with frequency
- Request optimization opportunities (batching, caching)
- Data transfer reduction strategies
- Cache-first implementation gaps
- Network efficiency improvement projections
- Effort estimates for network optimizations

**Performance Targets:**
- Data transfer: < 5MB/hour typical use
- Request count: < 100 requests/hour
- Cache hit rate: > 70%
- Offline capability: Core features work offline

---

### 6. BATTERY CONSUMPTION (Weight: 10%)

**Gold Standard:** Minimal battery drain, efficient background operations.

**Investigate:**

1. **Location Services**
   - Check if location services used
   - Verify location accuracy (high accuracy = high battery)
   - Review location update frequency
   - Check for location services stopped when not needed

2. **Background Operations**
   - Identify background tasks (timers, polling)
   - Check for Wake Lock usage
   - Verify background sync frequency
   - Review background notification handling

3. **Real-time Listeners**
   - Count active Firebase listeners
   - Check listener scope (too broad?)
   - Verify listeners stopped when app backgrounded
   - Review listener efficiency

4. **Network Activity**
   - Check for unnecessary network polling
   - Verify push notifications used (not polling)
   - Review network request batching
   - Check for network activity when app inactive

5. **Animation & Rendering**
   - Check for animations running when app backgrounded
   - Verify unnecessary redraws stopped
   - Review video player battery usage

**Output Required:**
- Battery drain sources identified
- Background operation audit
- Listener and network optimization for battery
- Battery efficiency improvements
- Effort estimates for battery optimizations

**Performance Targets:**
- Battery drain: < 5% per hour active use
- Background drain: < 1% per hour
- Location services: Only when needed
- Background tasks: Minimal and efficient

---

### 7. OFFLINE PERFORMANCE & DATA SYNC (Weight: 8%)

**Gold Standard:** Full functionality offline with intelligent sync.

**Investigate:**

1. **Offline Functionality**
   - Test core features offline (which work? which break?)
   - Verify offline data availability:
     - View recipes
     - View menus
     - View shopping lists
     - Create/edit content
   - Check offline error handling (clear messaging)

2. **Data Persistence**
   - Review local data storage strategy
   - Check Firestore offline persistence enabled
   - Verify critical data cached locally
   - Review cache size and eviction strategy

3. **Sync Strategy**
   - Check automatic sync on reconnect
   - Verify pending operations queued (offline writes)
   - Review conflict resolution (simultaneous offline edits)
   - Check sync priority (important data synced first)

4. **Offline UX**
   - Verify offline indicator shown to user
   - Check operations queued communicated to user
   - Review sync progress feedback
   - Check for data loss prevention (unsaved changes)

**Output Required:**
- Offline functionality assessment (what works, what doesn't)
- Offline data gaps (features broken offline)
- Sync strategy issues (conflicts, data loss)
- Offline UX improvements
- Effort estimates for offline enhancements

**Performance Targets:**
- Core features: 100% functional offline
- Offline data: Recipes, menus, shopping lists available
- Sync time: < 5s after reconnect
- Conflict resolution: Automatic with user override option

---

### 8. PLATFORM-SPECIFIC OPTIMIZATIONS (Weight: 6%)

**Gold Standard:** Optimized for iOS and Android platform characteristics.

**Investigate:**

1. **Platform-Specific Performance**
   - Check for platform checks (kIsWeb, Platform.isIOS, Platform.isAndroid)
   - Verify platform-specific optimizations
   - Review different performance on iOS vs. Android
   - Check for platform-specific memory limits

2. **Native Features**
   - Verify platform channels performance (method channels)
   - Check native plugin performance
   - Review image compression (native?)
   - Check for platform-specific APIs (faster alternatives?)

3. **iOS Optimizations**
   - Review iOS Metal rendering
   - Check for iOS-specific performance issues
   - Verify iOS memory warnings handled
   - Review iOS background refresh

4. **Android Optimizations**
   - Check Android-specific performance issues
   - Verify Android memory management
   - Review Android background restrictions
   - Check for Doze mode handling

**Output Required:**
- Platform-specific performance differences
- Platform optimization opportunities
- Native feature performance issues
- Effort estimates for platform optimizations

---

### 9. DEVELOPMENT & DEBUGGING PERFORMANCE (Weight: 4%)

**Gold Standard:** Fast development iteration, efficient debugging, no debug code in production.

**Investigate:**

1. **Debug Code in Production**
   - Check for print() statements (should use debugPrint or logger)
   - Verify assert() statements (removed in release builds?)
   - Review debug-only code (properly gated?)
   - Check for development endpoints (not in production)

2. **Build Performance**
   - Review Flutter build configuration
   - Check for obfuscation in release builds
   - Verify tree-shaking enabled
   - Review minification settings

3. **Performance Profiling Hooks**
   - Check if performance monitoring integrated (Firebase Performance?)
   - Verify Timeline.startSync/finishSync usage (for profiling)
   - Review custom performance metrics
   - Check for performance logging

**Output Required:**
- Debug code in production (should be removed)
- Build configuration issues
- Performance monitoring gaps
- Effort estimates for cleanup

---

## Investigation Execution Plan

**Remember: This is INVESTIGATION ONLY - Document findings, make NO changes.**

### Stage 1: Static Analysis (2-3 hours)
1. Review app bundle size and dependencies
2. Audit widget trees for performance issues
3. Search for common performance anti-patterns
4. Check for memory leak patterns (undisposed resources)
5. Review asset optimization

**Tools to use:** Grep, Glob, Read, Flutter analyze (no Edit, no optimization)

### Stage 2: Performance Deep Dive (10-12 hours)

#### Startup Performance (2 hours)
- Trace startup sequence
- Identify blocking operations
- Review DI initialization
- **Document startup bottlenecks with time estimates**

#### UI Performance (2.5 hours)
- Audit widget builds and rebuilds
- Check list rendering patterns
- Review image loading
- Test animation smoothness
- **Document jank sources with fps impact**

#### Memory Analysis (2 hours)
- Audit resource disposal
- Check for memory leaks
- Review image memory management
- **Document memory issues with leak severity**

#### Network & Battery (1.5 hours)
- Audit network request patterns
- Check battery-draining operations
- Review background tasks
- **Document efficiency issues**

#### Offline & Platform (1.5 hours)
- Test offline functionality
- Review platform-specific code
- **Document offline gaps and platform issues**

#### Bundle Size & Assets (0.5 hours)
- Analyze bundle composition
- Audit asset sizes
- **Document size optimization opportunities**

### Stage 3: Performance Report Compilation (2-3 hours)
- Compile ALL findings with metrics
- Classify every issue by severity and user impact
- Add effort estimates and performance gain projections
- Create performance metrics dashboard
- Generate executive summary with performance score
- **Output: Complete performance findings document ready for Phase 2 planning**

**Total Investigation Time: 14-18 hours**

**Deliverable:** Comprehensive mobile performance findings report. NO CODE CHANGES.

---

## Output Format Required

### Executive Summary
```
BUTLERY MOBILE PERFORMANCE ANALYSIS - PHASE 1
===============================================
Analysis Date: [Date]
Analyst: Claude (Sonnet 4.5)
Platform: Flutter Mobile (iOS/Android)

OVERALL PERFORMANCE SCORE: X/100
├─ Startup Performance:      X/18 points
├─ Frame Rate & Smoothness:  X/16 points
├─ Memory Management:        X/14 points
├─ Bundle Size:              X/12 points
├─ Network Efficiency:       X/12 points
├─ Battery Consumption:      X/10 points
├─ Offline Performance:      X/8 points
├─ Platform Optimization:    X/6 points
└─ Debug/Build Config:       X/4 points

PERFORMANCE STATUS: [Elite | Good | Needs Optimization | Critical Issues]

CRITICAL ISSUES: X found (app freezes, crashes, severe jank)
HIGH PRIORITY: X found (slow startup, poor fps, memory leaks)
MEDIUM PRIORITY: X found (battery drain, bundle size, network waste)
LOW PRIORITY: X found (minor optimizations)

CURRENT METRICS:
- Startup Time: X.Xs (Target: < 2.0s)
- Frame Rate: XXfps (Target: 60fps)
- Memory Usage: XXXmb (Target: < 150MB)
- Bundle Size: XXmb (Target: < 50MB)
- Battery Drain: X%/hour (Target: < 5%/hour)

OPTIMIZATION POTENTIAL:
- Startup: -X.Xs improvement possible
- Frame Rate: +XXfps improvement possible
- Memory: -XXmb reduction possible
- Bundle Size: -XXmb reduction possible
```

### Detailed Findings by Dimension

[Same format as other analysis prompts with performance-specific metrics]

### Performance Metrics Dashboard

```markdown
## Current vs. Target Performance

| Metric | Current | Target | Gap | Status |
|--------|---------|--------|-----|--------|
| Cold Start Time | X.Xs | 2.0s | +X.Xs | ⚠️/✅ |
| Warm Start Time | X.Xs | 1.0s | +X.Xs | ⚠️/✅ |
| Average FPS | XXfps | 60fps | -XXfps | ⚠️/✅ |
| Jank Percentage | X% | <1% | +X% | ⚠️/✅ |
| Memory Usage (avg) | XXXmb | 150MB | +XXmb | ⚠️/✅ |
| Memory Usage (peak) | XXXmb | 250MB | +XXmb | ⚠️/✅ |
| Bundle Size (Android) | XXmb | 50MB | +XXmb | ⚠️/✅ |
| Bundle Size (iOS) | XXmb | 60MB | +XXmb | ⚠️/✅ |
| Network (per hour) | XXmb | 5MB | +XXmb | ⚠️/✅ |
| Battery (per hour) | X% | 5% | +X% | ⚠️/✅ |
| Offline Features | X% | 100% | +X% | ⚠️/✅ |

### Optimization Impact Projections

| Optimization | Startup | FPS | Memory | Bundle | Effort |
|--------------|---------|-----|--------|--------|--------|
| Lazy DI initialization | -0.5s | - | - | - | 2 days |
| Const constructors | - | +5fps | - | - | 1 day |
| Image optimization | - | +3fps | -30MB | -5MB | 1 day |
| Remove unused deps | -0.1s | - | - | -8MB | 4 hours |
| [... more optimizations] |
```

---

## Phase 1 Success Criteria

**This performance investigation phase is complete when:**

1. ✅ All 9 performance dimensions scored and documented
2. ✅ Startup sequence traced and bottlenecks identified
3. ✅ Widget build performance audited
4. ✅ Memory leak risks documented
5. ✅ Bundle size breakdown complete
6. ✅ Network request patterns inventoried
7. ✅ Battery drain sources identified
8. ✅ Offline functionality tested
9. ✅ All issues categorized by severity with metrics
10. ✅ Performance gain projections estimated
11. ✅ **ZERO code changes made** - documentation only
12. ✅ Phase 2 preparation complete (optimization roadmap ready)

**Phase 1 Output:** Comprehensive mobile performance findings report with metrics.

**Phase 2 Input:** Use this report to create smart optimization plan with performance targets.

---

## Butlery-Specific Performance Checks

### Offline Storage Performance (Drift Database)
1. **Drift DAO Query Efficiency**
   - Butlery migrated from Hive to Drift database
   - Check: DAO query patterns and index usage
   - Verify: `RecipeDao`, `SyncQueueDao` query performance
   - Look for: N+1 queries in Drift operations

2. **Stream Pagination Limits**
   - Butlery limits recipe streams to 50 items to prevent memory bloat
   - Verify: All real-time watchers have proper limits
   - Check: Pagination implementation for large collections

3. **Image Compression**
   - `FirebaseStorageRepository` includes compression before upload
   - Verify: Images compressed before Firebase Storage upload
   - Check: Thumbnail generation strategy

4. **Firebase Performance Traces**
   - `traceOperation<T>()` wrapper for critical operations
   - Check: Trace coverage for critical user journeys
   - Verify: Proper attribute tagging on traces

5. **Stream Disposal (StreamManagementMixin)**
   - Services should use `StreamManagementMixin` for proper stream lifecycle
   - Check: All stream subscriptions properly disposed
   - Verify: Mixin adoption across services with streams

6. **Intelligent Cache Manager**
   - `lib/services/performance/intelligent_cache_manager.dart` provides caching
   - Check: Cache expiration policies
   - Verify: Cache hit rates for common operations

---

## 🚀 BEGIN PHASE 1 PERFORMANCE INVESTIGATION NOW

**CRITICAL REMINDERS:**
- 🚫 **NO CODE CHANGES** - Investigation and documentation ONLY
- 📋 Document every finding with file:line references
- 📊 Include metrics (fps, memory, time, size) wherever possible
- 🏷️ Categorize all issues by severity (Critical/High/Medium/Low)
- 📈 Estimate performance gains for optimizations
- ⏱️ Provide effort estimates (hours/days)
- 🎯 Follow all 9 performance dimensions systematically
- ✅ Complete deliverables checklist before finishing

**Your Mission:**
Execute comprehensive mobile performance investigation. Profile startup, measure frame rates, audit memory, analyze network patterns. Document everything. Change nothing.

**This app deserves elite mobile performance** - and this investigation is the blueprint.

**Phase 1 Goal:** A complete, detailed performance findings report with metrics, ready for Phase 2 smart optimization planning.
