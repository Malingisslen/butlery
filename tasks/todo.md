# Sprint Backlog

## Sprint: iter-67 — BUT-1072 drop dead _activeListeners — 2026-05-25 (Mon)

Theme: Tech-debt cleanup — `_activeListeners` map in `RealtimeSyncService` is never populated. `isResourceWatched` lies (always false), `_closeAllListeners` is a no-op, `_closeListener` in deleteResource does nothing. P4 backend tech-debt.

### Step 0 — premise verification

- Ticket matches `lib/services/realtime_sync_service.dart` lines 53, 76, 104, 300, 355-367, 421-423, 427 exactly.
- Verified: `watchResource` returns `docRef.snapshots()` transformed, never `.listen(...)` storing a subscription. Map is structurally dead.
- Test at line 592 "isResourceWatched is false for never-watched ids" pins the dead-API contract — must delete.
- Only external "users" of the dead API: testing-specialist.knowledge.md + a docs analysis file. No production code outside this file references them.
- Ticket presents two options: (A) delete dead code or (B) populate properly. **Option A** chosen — matches current behavior (consumer-owned subscriptions), Option B would change semantics.
- Classification: **fits** — implement Option A.

### Design choices

- **Delete**: `_activeListeners` field, `activeListenersCount` getter, `_closeListener` method, `_closeAllListeners` method, `isResourceWatched` method.
- **Delete callers**: `_closeAllListeners()` in `onUserLoggedOut` callback and `onDispose`; `_closeListener(resourceId)` in `deleteResource`.
- **Drop `StreamSubscription`/`DocumentSnapshot` imports** if unused after deletion.
- **Update test**: remove `isResourceWatched` test, update test file's header docstring on lines 19-20 to drop the "_activeListeners visibility" claim.
- **Don't touch `_cachedResources.clear()`** in onUserLoggedOut/onDispose — that's a real cache, not dead.

### Ship this sprint

- [ ] **A1. Delete dead `_activeListeners` code** — `lib/services/realtime_sync_service.dart`: field + 5 methods + 3 callers. (BUT-1072)
- [ ] **A2. Update tests** — `test/unit/services/realtime_sync_service_test.dart`: remove isResourceWatched test, fix header docstring. (BUT-1072)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/services/realtime_sync_service_test.dart` passes (24 tests, was 25).
- [ ] `grep _activeListeners lib/` → 0 hits.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1072 with commit hash

---

## Archived iter-66 (commit `291194ca2`) — 2026-05-25 (Mon)

BUT-1071 P4 fix — RealtimeRecipe.fromMap throws FormatException on missing required (ownerId, createdAt, lastEditedAt, lastEditedBy). Added requiredString/requiredDateTime to SerializationUtils. +125 / −24. 55/55 + 25/25 tests pass. BUT-1089 filed for sibling model parity.
