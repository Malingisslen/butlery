# Sprint Backlog

## Sprint: CI-test verification sweep + LRU/GDPR hardening — 2026-05-19 (Tu)

Theme: Step 0 caught 4 stale CI-fix tickets (all premise-gone — work already shipped). Real-work delivered for BUT-817 (5-cache LruMap migration) + BUT-842 (GDPR catch-swallow → transient/fatal split).

### Step 0 results
- **BUT-855** — premise gone. `flutter test` shows 58/58 tests pass; commit 8ebcb75a7 explicitly fixed this.
- **BUT-856** — premise gone. 7/7 sharing-manager tests pass; commits 751151488 + 34e02e1f7 addressed the concrete-override mock pattern.
- **BUT-853** — premise gone. 15/15 Drift tests pass; commit 310f95cad fixed Drift setup.
- **BUT-857** — premise gone. 334/334 tests across all 11 listed residual files pass; commits b09dc9c7a, 36c334b7b, 814d2cc75, 94420f3e5, 7065682e1, cbbbbd40a, 5a70c8ba1, 4d0b6fdc6 cleared the cluster.

### Agent B: performance-optimizer — LRU cache migration (BUT-817)
- [x] **B1. BUT-817** — All 5 caches migrated to `LruMap`:
  - `lib/utils/text/compound_splitter.dart` — FIFO Map → LruMap (200)
  - `lib/services/parsing/cache/parsed_recipe_cache.dart` — TTL-only Map → LruMap (50) + TTL retained
  - `lib/repositories/site_config_repository.dart` — manual FIFO → LruMap (50)
  - `lib/services/cache/permission_cache_service.dart` — Map+List<Key> manual LRU → LruMap (deletes ~30 lines of bookkeeping)
  - `lib/services/ocr_extraction_service.dart` — timestamp-sort batch eviction (O(n log n)) → LruMap (O(1)) on both `_cache` and `_rawHashToPreprocessedHash`; also fixed pre-existing dispose() leak of `_rawHashToPreprocessedHash`
  - Added `LruMap.removeWhere` to enable the permission_cache_service migration
  - All caches emit `cache_eviction service=… key=… bound=…` at `info` level (matches BUT-779 precedent)

### Agent C: firebase-backend-security — GDPR export error handling (BUT-842)
- [x] **C1. BUT-842** — `ComplianceExportManager` broad catch-swallow → typed differentiation:
  - New `ComplianceExportException` raised on fatal CF errors so `Future.wait(...eagerError: true)` aborts cleanly
  - Transient `FirebaseFunctionsException` codes (`unavailable`, `deadline-exceeded`, `internal`, `cancelled`, `aborted`, `resource-exhausted`) return recoverable `{error, error_code, note}` map so the rest of the bundle still ships
  - `unauthenticated` deliberately stays fatal (session-level breakage affects every export call)
  - Consent path (no CF) re-throws on all failures (no transient distinction without a network call to disambiguate)
  - 4 new tests pin transient + fatal + unexpected branches; `data_export_service_test` upgraded with a real empty-page CF fake + injected `FirebaseDataExportRepository`

### Tier-2 agent reviews
- [x] code-reviewer (BUT-817) — clean.
- [x] code-reviewer (BUT-842 + remaining BUT-817) — 3 findings. H1: added `resource-exhausted` to transient set (clear fix). H3: kept `info` log level per BUT-779 explicit precedent. H2 (downstream surfacing of `error_code`) → filed as follow-up.
- [x] testing-specialist — clean. Two non-blocking nits (partial-recovery shape test + cast assumption doc) → filed as follow-ups.
- [x] firebase-backend-security — knowledge file updated.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` — clean
- [x] Tier-2 markers written
- [ ] File follow-ups (3) in Linear before commit
- [ ] Commit (inline), push
- [ ] Linear close: BUT-855, BUT-856, BUT-853, BUT-857 (premise gone), BUT-817, BUT-842 (shipped)

### Known follow-ups (filed in Linear before commit)
- **BUT-842 surfacing** — DataExportService should aggregate per-section `error_code` markers into a top-level `warnings: []` array so partial-bundle consumers see the failure prominently rather than buried.
- **BUT-842 partial-recovery test** — add a test where the first audit-log page succeeds and the second throws transient: bundle should ship page-1 rows alongside the `error_code` marker.
- **Test infra hardening** — document the `T == Map<dynamic, dynamic>` assumption on `_EmptyHttpsCallable.call` in `data_export_service_test.dart`.

---

## Archived prior sprint (commit c11afc720)

high-priority backlog drain — 2026-05-19 (Tu) — BUT-812/805/822 done; BUT-787/806 obsolete; BUT-798/782 deferred. Follow-ups BUT-861/862/863 filed.
