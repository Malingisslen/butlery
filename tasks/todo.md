# Sprint Backlog

## Sprint: GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H)

Theme: cluster of 7 backend-security micro-hardening + tech-debt tickets — denormalized PII tombstones on user delete (BUT-466), friend_categories rule tightening (BUT-464), members rules-doc + test (BUT-463), Android cleartext debug-only scope (BUT-462), cosmetic cleanup (BUT-461), version bump (BUT-613), and a stream-lifecycle migration (BUT-471). **7 implementations across 3 batches.**

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (4 candidates remaining; deserves own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip (Play Integrity / App Attest registration).

**Step 0 verification — done:**
- **BUT-466** plan-stale (path-stale) — `functions/src/cleanup/on-user-deleted.ts` exists, comprehensive cascade (11 steps including BUT-477/647/651/654/753). Ticket's PII orphan is real: `sharedByDisplayName` is a denormalised string on `user_shared_recipes`/`user_shared_menus`/`user_shared_shopping_lists` docs (per `lib/models/shared_*.dart`). The existing `cleanupLegacySharedWithArrays` only scrubs the top-level `shared_content/{}.sharedWith` array. Add step 12: tombstone the `sharedByDisplayName` field across all top-level shared-content docs where `sharedByUserId == userId`. Tombstone string: `'[Raderad användare]'` (Swedish, matches app locale). The existing code-comment at `:115` already acknowledges the rules-restriction → admin-cascade pattern; this fits the same architecture.
- **BUT-464** plan-stale (line numbers shifted) — Real location is `firestore.rules:333-339` (not `:292-304`). Current rule allows non-owner members to update `friendUserIds` up to size 200, with rate-limit 5. This permits a member to add arbitrary userIds. Tighten with a symmetric-difference check: the only userIds that can move in/out of the array are the requesting user's UID. Use `request.resource.data.diff(resource.data).affectedKeys().hasOnly(['friendUserIds', 'updatedAt'])` (already there) + the member-set diff constraint.
- **BUT-463** plan-stale (path-stale) — Real location is `firestore.rules:1589-1591` (`match /{path=**}/members/{memberId}`), not `:1224` (which is now `match /presence/{userId}`). Existing comment at `:1587-1588` already documents the safety assumption: "only shared content members have a `userId` field; friend_category members use `friendId`". Strengthen the comment with explicit failure-mode example ("if a future `members` subcollection adds `{userId: foreignUid, ...}` without proper isolation, this rule would leak access — guard upstream by enforcing `members/{id}.userId == path-derived-id` or namespacing"). Add a rules-unit-test that proves the safety contract: a foreign collection-group `members` doc with mismatched userId is denied.
- **BUT-462** valid — `android/app/src/main/res/xml/network_security_config.xml` confirmed at 16 lines, holds the localhost+10.0.2.2 cleartext exception. Standard variant pattern: `src/debug/res/xml/network_security_config.xml` overrides for debug builds. Move the cleartext-domain-config to a debug-only variant and keep `src/main` strict (deny all cleartext).
- **BUT-461** valid — `lib/viewmodels/auth_viewmodel.dart:31, 37, 159, 201` all confirm example password strings (`'säkertLösenord123'`, `'starkLösenord456'`). Replace with `'<password>'` placeholder.
- **BUT-613** valid — `pubspec.yaml:4` confirms `version: 1.0.0+1`. Per ticket suggestion ("0.9.x during beta, 1.0.0 at GA"), bump to `0.9.0+1` for beta. CI bump-automation deferred (out of scope; ticket calls it explicit "consider").
- **BUT-471** valid — `lib/services/unified/friends/friends_state_manager.dart` (632 lines) confirmed: 7 `StreamSubscription?` fields (lines 33-40), 21 cancel-call sites scattered across 4 dispose+reset blocks (lines 197-211, 230-237, 306-307, 349-407, 614-625). `StreamManagementMixin` (`lib/core/mixins/stream_management_mixin.dart`) already adopted by 15 services (incl. `unified_friends_service.dart:83` — same domain). Migration replaces manual `.cancel()` lifecycle with `listenToStream(stream, listener, name: 'incoming_requests')` keys + a `disposeStreamManagement()` call from the existing `dispose()` override. Since the class extends `ChangeNotifier`, the mixin's lifecycle is additive — no constraint conflict.

### Agent A: Backend security micro-hardening — firebase-backend-security + cloud-functions-specialist

- [x] **A1. BUT-466 — Tombstone `sharedByDisplayName` on user delete** —
  - `functions/src/cleanup/on-user-deleted.ts`:
    - Add new step 12 in `cleanupUserSocialData` after step 11 (content-guard subcollections):
      ```ts
      // 12. BUT-466: tombstone the denormalised `sharedByDisplayName` field
      //     on top-level shared_content docs where the deleted user was the
      //     sharer. The string is a recipient-side PII residue (display name
      //     embedded in collaboration metadata). Replace with locale-aware
      //     tombstone so recipient UIs render gracefully without leaking the
      //     deleted user's name.
      results.shareDisplayNameTombstoned =
          await tombstoneSharedByDisplayName(userId);
      ```
    - Add result key `shareDisplayNameTombstoned: 0` to the `results` object.
    - New helper `tombstoneSharedByDisplayName(userId)` plus exported `tombstoneSharedByDisplayNameWithDb(database, userId)` test seam:
      - Query `shared_content` collection where `sharedByUserId == userId`. Best-effort batched `update({ sharedByDisplayName: '[Raderad användare]' })`, BATCH_LIMIT 500.
      - Idempotent: re-running on already-tombstoned docs sets the same value (no-op write semantically). Skip docs whose `sharedByDisplayName` already equals the tombstone (cost saver).
      - Best-effort per chunk: `onChunkFailure` logs a `v1.logger.warn` and continues; matches `cleanupLegacySharedWithArrays` pattern.
  - Tests: `functions/src/__tests__/share-display-name-tombstone.test.ts` (new) — emulator or stub-driven (match the BUT-753 test seam pattern):
    - Seeds `shared_content/{a, b, c}` with `sharedByUserId: targetUid` + a 4th doc `sharedByUserId: otherUid`.
    - Calls `tombstoneSharedByDisplayNameWithDb(stub, targetUid)`.
    - Asserts a/b/c got `sharedByDisplayName: '[Raderad användare]'`; the 4th doc untouched.
    - Re-runs the tombstone — asserts no additional writes (idempotent skip).
  - **Out of scope**: nested per-recipient subcollections (`user_shared_recipes/{recipientId}/...`). Those are already cascaded via the existing `removeFromSharedContent` path (client-side) and via D1/D3 friend-cleanup. The orphan vector is specifically the top-level `shared_content` doc that recipients render attribution from. (BUT-466)

- [x] **A2. BUT-464 — Tighten `friend_categories.friendUserIds` member-update rule** —
  - `firestore.rules:333-339`:
    - Replace the current non-owner-member update rule with a tighter version that allows members to add or remove ONLY their own UID. Use a single-direction diff:
      ```
      allow update: if isAuthenticated()
        && isInList('friendUserIds')
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['friendUserIds', 'updatedAt'])
        && request.resource.data.friendUserIds.size() <= 200
        // BUT-464: members can only add/remove themselves. Bloat protection.
        && request.resource.data.friendUserIds.toSet()
             .difference(resource.data.friendUserIds.toSet())
             .union(resource.data.friendUserIds.toSet()
                .difference(request.resource.data.friendUserIds.toSet()))
             .hasOnly([request.auth.uid])
        && rateLimitWrite('friend_category_member', 5);
      ```
    - Note: the `toSet().difference(...).union(...)` symmetric-diff captures both add-self and remove-self. Owner-driven bulk edits remain unchanged via the separate `allow update: if isOwner(userId) && cannotModify(...)` rule above.
  - Tests: `functions/src/__tests__/friend-categories-rules.test.ts` (new or extend if exists — grep first for `friend_categor` in `__tests__`):
    - **Allow**: member adds self (was outsider → now in `friendUserIds`).
    - **Allow**: member removes self.
    - **Deny**: member adds an unrelated UID (not theirs).
    - **Deny**: member removes someone else.
    - **Deny**: member adds 2 UIDs in one update (their own + a stranger).
    - **Allow**: owner does a bulk-edit (no member-cap constraint).
  - **Out of scope**: removing the `size() <= 200` cap (still useful as a coarse fence). (BUT-464)

- [x] **A3. BUT-463 — Document collectionGroup `members` safety + add rules unit test** —
  - `firestore.rules:1586-1591`: replace the existing 2-line comment with a stronger version that documents the failure mode explicitly:
    ```
    // ⚠️ SAFETY CONTRACT (BUT-463): Matches ALL `members/{id}` subcollections
    // across the database via collection-group. The rule depends on TWO
    // invariants that must hold for every existing AND future `members`
    // subcollection:
    //   (1) Each `members/{id}` doc carries a `userId` field equal to the
    //       owning user's UID (i.e. `members/{id}.userId == id`).
    //   (2) The doc is created/updated only by trusted server code or by
    //       the user themself, gated by a NARROWER rule on the parent path.
    // If a future feature adds a `members` subcollection that violates (1)
    // — e.g. stores `userId` of a foreign user — this collection-group
    // rule would unintentionally allow the foreign user to read/delete it.
    // Mitigation: any new `members` subcollection MUST add a stricter
    // explicit rule on its parent path BEFORE relying on this catch-all.
    // Rules unit test in `audit-logs-rules.test.ts` enforces the contract
    // by attempting a foreign-userId fixture and asserting deny.
    // friend_categories does NOT use a `members` subcollection (it stores
    // membership inline as `friendUserIds`), so it isn't affected.
    ```
  - Tests: extend `functions/src/__tests__/audit-logs-rules.test.ts` (already exists from BUT-627 work) OR new `functions/src/__tests__/members-collection-group-rules.test.ts` (preferred — keep audit tests focused). Test cases:
    - **Allow**: `members/{auth.uid}` doc with `userId == auth.uid` → read OK.
    - **Deny**: `members/{otherUid}` doc with `userId == otherUid` and reader is `auth.uid` → no match (silent deny via the `resource.data.userId == request.auth.uid` predicate).
    - **Safety regression guard**: a hypothetical doc at any `members/{anything}` path with `userId == auth.uid` reads OK — the rule is path-agnostic (this proves the catch-all is the only gate; a future leaky parent-rule would surface here as an unexpected allow).
  - **Out of scope**: actually narrowing the collection-group rule to specific paths. Doing so would break BUT-407 collectionGroup queries that rely on the universal match. Documentation + test is the right scope. (BUT-463)

### Agent B: Quick hygiene — flutter-developer

- [x] **B1. BUT-462 — Scope cleartext exception to debug-only Android builds** —
  - Create `android/app/src/debug/res/xml/network_security_config.xml` with the current full content (base-config strict + localhost/10.0.2.2 cleartext exception). Keeps dev workflow intact.
  - Replace `android/app/src/main/res/xml/network_security_config.xml` with a strict release-only variant — no domain-config, just:
    ```xml
    <?xml version="1.0" encoding="utf-8"?>
    <network-security-config>
        <!-- Release: enforce HTTPS for all connections. Cleartext exceptions
             live in src/debug/res/xml/network_security_config.xml and are
             merged in for debug builds only. -->
        <base-config cleartextTrafficPermitted="false">
            <trust-anchors>
                <certificates src="system" />
            </trust-anchors>
        </base-config>
    </network-security-config>
    ```
  - **Verification**: `android/app/build.gradle.kts` already resolves variant-specific resources via Android's standard merge order. No build.gradle changes needed.
  - No test (Gradle merge behavior is platform-guaranteed). Manual smoke after sprint: confirm `flutter run --debug` still hits emulator localhost. (BUT-462)

- [x] **B2. BUT-461 — Remove example password strings from auth_viewmodel docstrings** —
  - `lib/viewmodels/auth_viewmodel.dart:31`: `'säkertLösenord123'` → `'<password>'`
  - `lib/viewmodels/auth_viewmodel.dart:37`: `'starkLösenord456'` → `'<password>'`
  - `lib/viewmodels/auth_viewmodel.dart:159`: `'säkertLösenord123'` → `'<password>'`
  - `lib/viewmodels/auth_viewmodel.dart:201`: `'starkLösenord456'` → `'<password>'`
  - Pure docstring change; no behavior. (BUT-461)

- [x] **B3. BUT-613 — Bump pubspec version to 0.9.0+1 for beta** —
  - `pubspec.yaml:4`: `version: 1.0.0+1` → `version: 0.9.0+1`
  - Per ticket scheme: 0.9.x during beta → 1.0.0 at GA. Build number stays at 1 (this is the first explicit release-track version).
  - **Out of scope**: CI auto-bump script (separate ticket; ticket itself flags as "consider", not required).
  - No test (config change). (BUT-613)

### Agent C: Stream lifecycle hardening — performance-optimizer + flutter-developer

- [x] **C1. BUT-471 — Migrate `friends_state_manager.dart` to StreamManagementMixin** —
  - `lib/services/unified/friends/friends_state_manager.dart`:
    - Class declaration: `class FriendsStateManager extends ChangeNotifier with StreamManagementMixin {`
    - Add import: `import 'package:butlery/core/mixins/stream_management_mixin.dart';`
    - **Delete** all 7 `StreamSubscription?` field declarations (lines 33-40).
    - Replace each `.listen(...)` call with `listenToStream(stream, listener, name: '<key>')` using stable keys:
      - `incoming_requests`, `sent_requests`, `group_invitations`, `categories`, `member_categories`, `friends`, `blocked_users`.
    - Replace pre-listen `?.cancel()` calls with `cancelSubscription('<key>')` (mixin's reassignment-safe cancel).
    - In `dispose()` (and any `_resetState`-like helper): replace the manual cancel-and-null block with `disposeStreamManagement()` (mixin disposal). Keep `super.dispose()` last.
    - Audit all 21 `.cancel()` sites — every one should map to either a `cancelSubscription(name)` (replace-and-renew) or be subsumed by `disposeStreamManagement()` (terminal cleanup).
    - Logging: the mixin already provides leak-detection warnings; keep existing `AppLogger` info/error around stream errors but drop redundant lifecycle logs that the mixin handles.
  - Verification — should reduce file size (632 → ~580 lines target) given 7 fields + 21 cancel sites collapse to ~7 listen calls + 1 disposal hook.
  - Tests: `test/unit/services/unified/friends/friends_state_manager_test.dart` (extend if exists; grep first):
    - Disposing the manager cancels every subscription (no leak warnings emitted).
    - Re-initializing after a userId change cancels the prior subs (no double-listener).
    - Stream-error path still surfaces `_error` and `notifyListeners()` fires.
  - **Out of scope**: BUT-472 (`realtime_session_manager.dart` — 15 streams + 15 timers — same pattern but bigger surface; deferred). (BUT-471)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Functions: `cd functions && npm run build && npm test`
- [ ] Affected Dart unit tests: `friends_state_manager_test`
- [ ] Affected TS tests: `share-display-name-tombstone.test.ts`, `friend-categories-rules.test.ts`, `members-collection-group-rules.test.ts` (new); existing rules tests must still pass
- [ ] Tier-2 specialist gates: `code-reviewer` (any .dart), `testing-specialist` (any lib/), `firebase-backend-security` (cleanup + repos touched), `cloud-functions-specialist` (functions/src/ touched), `firestore-rules-tester` (rules changed — A2 + A3)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-466/464/463/462/461/613/471 → Done

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint, paired with friends/state perf review)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Deleted users no longer leak their name on shared content**: when an account is deleted, any recipe/menu/list they'd shared still shows their name as the "shared by" attribution — this sprint replaces that name with `[Raderad användare]` (Swedish for "Deleted user") so recipients see a clean placeholder instead.
- **Tighter friend-group permissions**: members of a friend-category group could previously add anyone (up to 200 IDs) to the membership list. After this sprint, members can only add/remove themselves; bulk edits stay owner-only.
- **Better safety documentation in our security rules**: a key rule that matches "members" subcollections gets a clearer comment explaining why it's safe today and what would break it in the future, plus an automated test that catches regressions.
- **Production Android builds now refuse plain-text traffic entirely**: the dev-only "allow localhost over HTTP" exception is moved to debug-only builds; release APKs deny all cleartext.
- **Cosmetic: example passwords in code comments removed**: secret-scanning tools won't flag them as false positives anymore.
- **Version number bumped from 1.0.0+1 to 0.9.0+1**: signals "in beta" honestly. Will go back to 1.0.0 at general availability.
- **Friends screen memory hygiene**: the part of the app that tracks your friends list, requests, and group invitations now uses the same shared resource-cleanup helper as 15 other parts of the app. Should prevent rare memory leaks on long-running sessions.
- **Risk**: low. All security changes are tightening (rules become stricter, never looser). The stream migration is a refactor of well-tested existing behavior — covered by tests. Easy to revert per task.

---

## Archived prior sprint (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627. See git log for full task breakdown.

## Archived sprint before (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.

## Archived sprint before (completed in commit 75873d1e1)

Pre-beta moderation + anti-spam + UGC compliance — 2026-05-04 (E) — shipped BUT-537/544/649/651/654/659. See git log for full task breakdown.
