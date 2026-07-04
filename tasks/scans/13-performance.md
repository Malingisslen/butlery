# Role 13 — Performance Engineer · scan findings

Lens: 60fps, resource disposal, cold start, caching, image loading, unbounded streams.
Owned paths only. Dedup checked against `_scan_dedup_titles.txt`, `linear-tracker.json`
(BUT-430/431/468/469/470/473/474/998/1001/1376 already exist), `accepted-deviations.md`,
and the role-13 dossier watch-items (which already cover: ICM timer-fired-after-pause race,
OptimizedImageLoader cache-miss flag never reset, ImageMemoryCacheManager 100 vs 50 MB
mismatch, PerformanceNavigatorObserver unbounded `_activeTraces`, ICM 'anonymous' userId leak).
Those five are NOT re-filed below.

---

### Image cache-HIT is recorded on every rebuild, not once per load
type: bug
area: performance
pass: 1
- finding: `_OptimizedImageLoaderState._buildFullImage` calls
  `_cacheManager.recordCacheAccess(true, 0)` unconditionally inside `imageBuilder`
  (optimized_image_loader.dart:414). `imageBuilder` re-runs on every widget rebuild
  while the image is resident, so a single cached image inflates `_cacheHits` by one
  per rebuild. The dossier already notes the *miss*-side flag bug (`_hasRecordedCacheMiss`
  never reset); this is the distinct *hit*-side defect — there is no equivalent guard at
  all, so the two sides count on incompatible bases.
- why: `ImageMemoryCacheManager.getCacheStats()` hitRate is fed to product/Drift dashboards
  and to the 80%-min-hit-rate health check; an over-counted hit total makes the cache look
  far healthier than it is, masking real grid-thrash regressions on tablets.
- fix: gate the hit record behind a per-load flag (mirror `_hasRecordedCacheMiss`, both
  reset in `didUpdateWidget` when `imageUrl` changes), or record the hit in `initState`/
  on first successful build only. optimized_image_loader.dart:414, 390-393, 206.

### Upload progress listener subscription is never cancelled
type: bug
area: performance
pass: 1
- finding: `uploadImageData` does `uploadTask.snapshotEvents.listen(...)` (firebase_storage_repository.dart:302)
  and discards the `StreamSubscription`. The stream is bound to the upload task, but the
  callback closure captures `onProgress` and is never explicitly cancelled; on a long or
  stalled upload the listener stays live for the task's lifetime with no disposal seam.
- why: contradicts the role mandate on listener disposal (and BUT-1001 "audit listener
  disposal across services"); a captured `onProgress` that outlives its caller (e.g. a
  dismissed upload sheet) can fire `setState` on a disposed widget. Low blast radius but
  it's an undisposed stream in an owned file.
- fix: capture the subscription and `await sub.cancel()` in a `finally`, or use
  `uploadTask.snapshotEvents` via `await for` inside the traced body so completion
  tears it down. firebase_storage_repository.dart:301-306.

### Frame-timing / dropped-frame monitoring is compiled out of release builds
type: improvement
area: performance
pass: 1
- finding: `PerformanceMonitoringService._startFrameMonitoring` only registers
  `addTimingsCallback` when `!kReleaseMode` (performance_monitoring_service.dart:159), and
  `onDispose` mirrors the guard. So `_frameCount`, `_droppedFrames`, `frameRate`, and the
  "Severe frame drop" warnings are ALWAYS zero in production. The 5-minute
  `performanceReport` analytics event still fires (`_sendReport`) reporting frameRate 0.0 /
  0 dropped frames for every real user.
- why: the role's headline metric (60fps target, jank detection) has zero production signal —
  jank regressions on real devices are invisible, and the analytics stream is actively
  misleading (always-green frame health). Distinct from Firebase Performance traces, which
  measure screen *duration*, not frame drops.
- fix: either enable frame timing in release behind a sampled/consent gate, or stop
  emitting frameRate/droppedFrames fields in the release report so dashboards don't read
  fabricated zeros. performance_monitoring_service.dart:159, 374-385, 467.

### uploadImage validates permission twice per upload
type: improvement
area: performance
pass: 2
- finding: `uploadImage` calls `_validateUploadPermission(userId, path)` (firebase_storage_repository.dart:233),
  then delegates to `uploadImageData`, which calls `_validateUploadPermission` again on the
  same args (line 277). Each call does an awaited `logPermissionCheck` audit write. So every
  single-image upload performs two identical permission checks and two audit-log writes; in
  `uploadMultipleImages` (which fans `uploadImage` across N files in parallel) this doubles
  the audit-write count for the whole batch.
- why: redundant Firestore audit writes on the hot upload path violate the cost principle
  (avoid unnecessary writes) and inflate audit volume. The second check is pure waste — the
  first already proved ownership on identical inputs within the same call.
- fix: drop the validation in `uploadImage` and rely on `uploadImageData`'s check (it is the
  shared entry point), or have `uploadImageData` accept a `permissionAlreadyValidated` flag
  from internal callers. firebase_storage_repository.dart:233 vs 277.

### Predictive prefetch streams up to 20 recipes every 5 min regardless of foreground state
type: improvement
area: performance
pass: 2
- finding: `IntelligentCacheManager._startPrefetchTimer` fires `preloadLikelyContent` every
  5 minutes (intelligent_cache_manager.dart:492), which calls `getRecipeById` for up to
  `_prefetchLimit = 20` recipes in batches of 5 (`_preloadRecipes`, lines 293-322). These
  are speculative reads not driven by any user action. `onAppPaused` cancels the timer, but
  a foregrounded-but-idle app keeps issuing ~20 recipe fetches every 5 min indefinitely.
- why: speculative reads cost Firestore reads + bandwidth for content the user may never
  open — directly counter to the cost principle. The prefetch hit-value is unmeasured
  (`_preloadFriendsActivity` is a documented no-op stub, lines 324-341), so this is paying
  read cost with no evidence of benefit.
- fix: gate prefetch on a measured prefetch-hit-rate signal before keeping it on, cap
  per-session prefetch volume, or back the interval off (10-15 min) and only prefetch the
  top 5. Tie to the existing BUT-998 "switch open-ended listeners to cached get/poll"
  cost-reduction theme. intelligent_cache_manager.dart:152-153, 232-259, 492-498.

---

COVERAGE: Reviewed all role-13 owned paths (main.dart, theme_service.dart,
performance_navigator_observer.dart, firebase_storage_repository.dart, parsing_context.dart,
intelligent_cache_manager.dart, optimized_image_loader.dart, firebase_performance_service.dart,
performance_monitoring_service.dart). Cold-start path (main.dart) is already well-handled
(BUT-431 post-frame defer, BUT-468 theme prewarm) — no new cold-start finding. Theme-flash
(pass-2 target) already fixed via BUT-468. RepaintBoundary / image-cache-sizing / rating-stream
already ticketed (BUT-469/470/430). Five dossier watch-items intentionally not re-filed.
5 NEW findings (3 pass-1, 2 pass-2).
