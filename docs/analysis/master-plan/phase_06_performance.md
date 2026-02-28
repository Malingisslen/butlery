# Phase 6: Performance & Scalability (~2 days)

Unbounded listeners, startup optimization, subcollection TTL.

---

## P6-01 — `subscribeToUserRecipes` unbounded listener [CRIT]

**Source**: R04:dim3-1
**Files**: `lib/repositories/firebase/firebase_recipe_repository.dart:591-606`
**Fix**: Add `.limit(50)` — reads ALL user recipes on every change. Power users with 200+ recipes pay N reads per single edit.
**Effort**: 30 min

---

## ~~P6-02~~ — ~~Add `.limit()` to friend/invitation streams~~ [FIXED]

**Status**: Verified fixed — all streams have `.limit(50)` or `.limit(200)`.

---

## ~~P6-03~~ — ~~Schedule audit log retention~~ [FIXED]

**Status**: Verified fixed — `cleanup-audit-logs.ts` exists with weekly cron and 90-day retention.

---

## P6-04 — Subcollection TTL for views/engagements/dismissals [HIGH]

**Source**: R04:dim3-2
**Files**: `shared_recipes/{id}/views`, `shared_recipes/{id}/engagements`, `shared_recipes/{id}/dismissals`
**Fix**: Add Firestore TTL policy or Cloud Function cleanup (delete docs > 90 days). Viral recipes accumulate 10K+ subcollection docs.
**Effort**: 4h

---

## P6-05 — Parallelize independent DI module initialization [HIGH]

**Source**: R04:dim1-1
**Files**: `lib/core/di/di_container.dart`
**Fix**: 9 modules initialize sequentially — blocks startup 800-1500ms. Parallelize independent modules (Tagging + Social can init concurrently).
**Effort**: 2-3d

---

## P6-06 — Convert non-critical singletons from eager to lazy [HIGH]

**Source**: R04:dim1-3
**Files**: Various DI modules
**Fix**: 36 eager singletons at startup; convert non-critical ones (MenuService, FriendsService, ParserService, PresenceService) to lazy. Saves ~200-400ms.
**Effort**: 1d

---

## ~~P6-07~~ — ~~Configure `flutter_cache_manager`~~ [IRRELEVANT]

**Status**: Package has 0 imports in lib/. Custom cache implementations used instead. Remove from plan.

---

## P6-08 — Inject shared HTTP client into import pipelines [MED]

**Source**: R04:dim2-2
**Files**: `lib/services/import/fetchers/http_content_fetcher.dart:24`
**Fix**: Creates new `http.Client()` per request. Inject shared client for connection pooling.
**Effort**: 1h

---

## P6-09 — Add `hasPendingWrites` sync indicator [HIGH]

**Source**: R04:dim7-3
**Fix**: User doesn't know if data is synced. Show sync indicator when `hasPendingWrites` is true.
**Effort**: 4h

---

## ~~P6-10~~ — ~~Add StreamManagementMixin to collaborative recipe flows~~ [FIXED]

**Status**: Verified fixed — `recipe_collaborative_manager.dart:17` has `with StreamManagementMixin`.

---

## P6-11 — Convert high-traffic ListViews to .builder [MED]

**Source**: R04:dim1-4
**Files**: `friends_list_view.dart`, `conversations_list_view.dart`, `personal_tags_view.dart`, 17 more
**Fix**: 20 ListView/GridView without .builder — eagerly builds all children.
**Effort**: 2h per file (prioritize 3 high-traffic ones)

---

## P6-12 — Add Cloud Function for Storage cleanup on recipe delete [MED]

**Source**: R04:dim6-2
**Fix**: Deleted recipes leave orphaned images in Firebase Storage. Add trigger.
**Effort**: 4h

---

## P6-13 — No cache-first read patterns [HIGH]

**Source**: R04:dim7-2
**Files**: Firestore repository files
**Fix**: All Firestore reads default to server-first even if cached data is available. Use `GetOptions(source: Source.cache)` with server fallback for non-critical reads.
**Effort**: 1-2d
