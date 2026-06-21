# Read a Friend's Recipe from the Feed — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the activity feed open a friend's recipe — read-only when they've explicitly shared it with you, and offer a request-to-share nudge when they only cooked it.

**Architecture:** Approach B (friends read the *live* recipe). The recipe read rule is widened, read-only, to also admit uids in the recipe's existing `socialData.memberPermissions` shared-with map. A new cross-user repository read (`readSharedRecipe`) fetches the friend's recipe; the existing `RecipeDetailView` renders it with owner actions gated off. Phase 2 reuses the `social_requests` collection + `sendNotification` callable for the request-to-share nudge.

**Tech Stack:** Flutter/Dart (MVVM + Repository), Firebase Firestore + security rules, Firebase Cloud Functions (TypeScript) for notifications, `@firebase/rules-unit-testing` for rules tests, `flutter_test` for unit/widget tests.

## Global Constraints

- **MVVM + Repository**: Views → ViewModels → Services → Repositories → Firebase. Never call `FirebaseFirestore.instance` in a view; use the repository's `firestore` getter / `getCollectionForUser`.
- **Permission audit**: repository reads must be authorized by Firestore rules, never bypassed client-side. No raw uids in logs — use `.maskedUserId`.
- **Data sources**: `userService.currentUserProfile` for user data; `permissionService.currentUserId` for auth/permission checks. Never mix.
- **l10n**: every user-facing string is a `context.l10n.<key>` (view) or `AppLocale.current.<key>` (VM/service). Add each new key to BOTH `lib/l10n/app_sv.arb` and `lib/l10n/app_en.arb`, then run `flutter gen-l10n`. UI strings are Swedish; English mirrors.
- **File size**: 500-line max per file (facade/delegate if exceeded).
- **Cost**: deterministic logic only (no LLM); avoid extra Firestore reads/writes; the request flow is idempotent to prevent duplicate notifications.
- **Commit gates**: `.dart` diffs require `code-reviewer` + `testing-specialist`; repository/service/functions diffs add `firebase-backend-security`; `firestore.rules` diffs add `firestore-rules-tester`. Dispatch the named agent against the staged diff, `touch .claude/state/<marker>`, then commit. Run `/code-review high` (or `xhigh` for rules/repository/functions) before each commit and `touch .claude/state/simplify-done.marker`.
- **Rules tests need the emulator**: `firebase emulators:start --only firestore` (127.0.0.1:8080) before running any `*-rules.test.ts`.
- **Flutter test on Windows**: run via the `cmd.bat` native-PATH wrapper (see `memory/flutter_test_windows_path.md`); `flutter analyze` works directly.

---

## File Structure

**Phase 1**
- `firestore.rules` (modify ~line 232) — widen recipe read to shared members.
- `functions/src/__tests__/recipe-shared-read-rules.test.ts` (create) — allow/deny proof.
- `lib/repositories/interfaces/recipe_repository.dart` (modify) — declare `readSharedRecipe`.
- `lib/repositories/firebase/firebase_recipe_repository.dart` (modify) — implement it.
- `lib/services/unified/unified_recipe_service.dart` (modify ~line 944) — `fetchFriendRecipe` wrapper.
- `lib/views/recipe_detail_view.dart` (modify) — `readOnly` flag gates owner actions.
- `lib/views/social/friends_list/feed_tab.dart` (modify ~line 305/353) — async tap, pass `actorId`.
- `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb` (modify) — Phase 1 needs no new keys (reuses `feedRecipeUnavailable`); Phase 2 keys added in its tasks.
- Tests: `test/unit/repositories/firebase_recipe_repository_shared_read_test.dart`, `test/widget/views/recipe_detail_read_only_test.dart`, `test/widget/views/feed_tab_navigation_test.dart`.

**Phase 2**
- `lib/models/social_request.dart` (modify) — add `recipeShareRequest` type + factory.
- `lib/services/notifications/notification_payload_type.dart` (modify) — add `recipeShareRequest` payload constant.
- `lib/services/social_recipe_service.dart` (modify) — `requestRecipeShare` + `acceptRecipeShareRequest`.
- `lib/services/notifications/fcm_service.dart` (modify ~line 514 switch) — nav case.
- `lib/views/recipe_detail_view.dart` (modify) — owner-side "share with requester" banner driven by route args.
- `lib/views/social/friends_list/feed_tab.dart` (modify) — null-branch opens the request dialog.
- `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb` (modify) — request/notification/banner strings.
- Tests: `test/unit/models/social_request_recipe_test.dart`, `test/unit/services/request_recipe_share_test.dart`.

---

# PHASE 1 — Open an explicitly-shared recipe (read-only)

### Task 1: Widen the recipe read rule + prove it

**Files:**
- Modify: `firestore.rules:230-260` (the `match /recipes/{recipeId}` read rule)
- Create: `functions/src/__tests__/recipe-shared-read-rules.test.ts`

**Interfaces:**
- Produces: a recipe doc at `/users/{ownerId}/recipes/{recipeId}` is readable by any uid present as a key in `socialData.memberPermissions`; owner read unchanged; all write paths unchanged.

- [ ] **Step 1: Write the failing rules test**

Create `functions/src/__tests__/recipe-shared-read-rules.test.ts`:

```ts
/**
 * Rules test: a recipe under /users/{ownerId}/recipes/{id} is readable by the
 * owner AND by any uid in socialData.memberPermissions (the shared-with map).
 * Non-members and strangers are denied. Writes stay owner-only.
 * Prerequisite: Firestore emulator (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/recipe-shared-read-rules.test.ts
 */
import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-recipe-shared-read-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const OWNER = "owner-uid";
const MEMBER = "member-uid";
const STRANGER = "stranger-uid";
const RECIPE = "recipe-1";
const DOC = `users/${OWNER}/recipes/${RECIPE}`;

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}
async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}
async function seedRecipe(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(DOC).set({
      core: { id: RECIPE, title: "Pannkakor", tagResult: { version: 1 } },
      socialData: { ownerId: OWNER, memberPermissions: { [MEMBER]: 2 } },
      type: "collaborative",
    });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void { tests.push({ name, fn }); }

test("owner can read own recipe", async () => {
  await seedRecipe();
  await assertSucceeds(env.authenticatedContext(OWNER).firestore().doc(DOC).get());
});
test("shared member can read the recipe", async () => {
  await seedRecipe();
  await assertSucceeds(env.authenticatedContext(MEMBER).firestore().doc(DOC).get());
});
test("stranger (not in memberPermissions) is denied read", async () => {
  await seedRecipe();
  await assertFails(env.authenticatedContext(STRANGER).firestore().doc(DOC).get());
});
test("shared member CANNOT write the recipe", async () => {
  await seedRecipe();
  await assertFails(
    env.authenticatedContext(MEMBER).firestore().doc(DOC).update({ "core.title": "hacked" })
  );
});

(async () => {
  await setup();
  let failed = 0;
  for (const t of tests) {
    try { await t.fn(); console.log(`✓ ${t.name}`); }
    catch (e) { failed++; console.error(`✗ ${t.name}\n  ${e}`); }
  }
  await teardown();
  process.exit(failed === 0 ? 0 : 1);
})();
```

- [ ] **Step 2: Run it to verify the member-read + stranger-deny tests FAIL**

Run (emulator must be up): `cd functions && npx ts-node src/__tests__/recipe-shared-read-rules.test.ts`
Expected: "shared member can read the recipe" FAILS (current rule is owner-only); "stranger denied" and "owner can read" PASS; "member cannot write" PASS.

- [ ] **Step 3: Widen the read rule**

In `firestore.rules`, replace the recipe read rule (currently `firestore.rules:231-232`):

```
        // Read access for owner
        allow read: if isOwner(userId);
```

with:

```
        // Read access for the owner, OR any uid the owner explicitly shared
        // this recipe with (key in socialData.memberPermissions). Read-only —
        // the allergen-critical create/update validation below stays owner-only.
        allow read: if isOwner(userId)
          || (isAuthenticated()
              && request.auth.uid in resource.data.get('socialData', {})
                                             .get('memberPermissions', {}));
```

Leave the `create`, `update`, `delete`, and admin-moderation rules in this block unchanged.

- [ ] **Step 4: Run the rules test to verify all PASS**

Run: `cd functions && npx ts-node src/__tests__/recipe-shared-read-rules.test.ts`
Expected: all four tests `✓`, exit 0.

- [ ] **Step 5: Dispatch firestore-rules-tester + firebase-backend-security on the staged diff, then commit**

```bash
git add firestore.rules functions/src/__tests__/recipe-shared-read-rules.test.ts
# after agents report clean:
#   touch .claude/state/rules-tester-done.marker .claude/state/firebase-security-done.marker
git commit -m "feat(rules): allow shared members to read a friend's recipe (read-only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Cross-user repository read `readSharedRecipe`

**Files:**
- Modify: `lib/repositories/interfaces/recipe_repository.dart` (add method ~after line 64)
- Modify: `lib/repositories/firebase/firebase_recipe_repository.dart` (add impl near `fetchUserRecipes`, ~line 639)
- Test: `test/unit/repositories/firebase_recipe_repository_shared_read_test.dart`

**Interfaces:**
- Produces: `Future<Recipe?> readSharedRecipe({required String ownerId, required String recipeId})` — returns the recipe if the rules permit, `null` on not-found or `permission-denied`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/repositories/firebase_recipe_repository_shared_read_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

void main() {
  test('readSharedRecipe returns the recipe doc of another user when present', () async {
    final fake = FakeFirebaseFirestore();
    await fake.doc('users/owner-1/recipes/r1').set({
      'core': {'id': 'r1', 'title': 'Pannkakor'},
      'socialData': {'ownerId': 'owner-1', 'memberPermissions': {'me': 2}},
      'type': 'collaborative',
    });
    final repo = FirebaseRecipeRepository(
      firestore: fake,
      requireCurrentUserId: () => 'me',
    );

    final recipe = await repo.readSharedRecipe(ownerId: 'owner-1', recipeId: 'r1');

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Pannkakor');
  });

  test('readSharedRecipe returns null when the doc does not exist', () async {
    final fake = FakeFirebaseFirestore();
    final repo = FirebaseRecipeRepository(
      firestore: fake,
      requireCurrentUserId: () => 'me',
    );
    final recipe = await repo.readSharedRecipe(ownerId: 'owner-1', recipeId: 'missing');
    expect(recipe, isNull);
  });
}
```

(Confirm the exact `FirebaseRecipeRepository` constructor parameters in the file header at `firebase_recipe_repository.dart:66-97` and match them — the repo takes `firestore` and a `requireCurrentUserId` callback.)

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/unit/repositories/firebase_recipe_repository_shared_read_test.dart`
Expected: FAIL — `readSharedRecipe` is not defined.

- [ ] **Step 3: Declare the interface method**

In `lib/repositories/interfaces/recipe_repository.dart`, after `fetchPublicUserRecipes` (line 64), add:

```dart
  /// Read a single recipe owned by [ownerId] (cross-user). Authorized by
  /// Firestore rules — succeeds only when the current user is the owner or a
  /// member in the recipe's `socialData.memberPermissions`. Returns null on
  /// not-found or permission-denied so callers can fall back gracefully.
  Future<Recipe?> readSharedRecipe({
    required String ownerId,
    required String recipeId,
  });
```

- [ ] **Step 4: Implement it**

In `lib/repositories/firebase/firebase_recipe_repository.dart`, add (it needs the `cloud_firestore` import already present at line 2; `getCollectionForUser` is the user-scoped collection helper used at line 87/643):

```dart
  @override
  Future<Recipe?> readSharedRecipe({
    required String ownerId,
    required String recipeId,
  }) async {
    try {
      final doc = await getCollectionForUser(ownerId).doc(recipeId).get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } on FirebaseException catch (e) {
      // permission-denied → the recipe isn't shared with us; treat as absent.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cmd.bat flutter test test/unit/repositories/firebase_recipe_repository_shared_read_test.dart`
Expected: PASS (both tests).

- [ ] **Step 6: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/repositories/firebase/firebase_recipe_repository.dart lib/repositories/interfaces/recipe_repository.dart
git add lib/repositories/interfaces/recipe_repository.dart lib/repositories/firebase/firebase_recipe_repository.dart test/unit/repositories/firebase_recipe_repository_shared_read_test.dart
# after code-reviewer + testing-specialist + firebase-backend-security report clean, touch their markers
git commit -m "feat(recipes): add readSharedRecipe cross-user read path

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Service wrapper `fetchFriendRecipe`

**Files:**
- Modify: `lib/services/unified/unified_recipe_service.dart` (add near `getRecipeById`, line 944)
- Test: `test/unit/services/unified_recipe_service_friend_fetch_test.dart`

**Interfaces:**
- Consumes: `RecipeRepository.readSharedRecipe` (Task 2).
- Produces: `Future<Recipe?> fetchFriendRecipe({required String ownerId, required String recipeId})` on `UnifiedRecipeService` — checks the local cache first (own recipe), then delegates to the repository.

- [ ] **Step 1: Write the failing test**

Create `test/unit/services/unified_recipe_service_friend_fetch_test.dart`. Mirror the existing service-test setup in `test/unit/services/` (production ServiceLocator bridge in `setUpAll`, `MockUnifiedRecipeService` patterns per `memory/MEMORY.md`). The behavioral assertions:

```dart
// 1. fetchFriendRecipe returns the cached recipe when getRecipeById(id) != null
//    (does NOT hit the repository).
// 2. When the cache misses, it calls repository.readSharedRecipe(ownerId, recipeId)
//    and returns its result.
// 3. When the repository returns null, fetchFriendRecipe returns null.
```

Write these three tests against a `UnifiedRecipeService` with a mocked `RecipeRepository` whose `readSharedRecipe` is stubbed. (Use the repository mock already present in `test/` test doubles; if none exists, add a minimal `Mock` via `mocktail` matching the test files in `test/unit/services/`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/unit/services/unified_recipe_service_friend_fetch_test.dart`
Expected: FAIL — `fetchFriendRecipe` not defined.

- [ ] **Step 3: Implement the wrapper**

In `lib/services/unified/unified_recipe_service.dart`, immediately after `getRecipeById` (line 944-946), add:

```dart
  /// Resolve a recipe that may belong to a friend. Returns a locally-cached
  /// recipe (the user's own) when present, otherwise reads the owner's doc via
  /// the repository (authorized by Firestore rules). Null = not visible to us.
  Future<Recipe?> fetchFriendRecipe({
    required String ownerId,
    required String recipeId,
  }) async {
    final cached = getRecipeById(recipeId);
    if (cached != null) return cached;
    return _recipeRepository.readSharedRecipe(
      ownerId: ownerId,
      recipeId: recipeId,
    );
  }
```

(Confirm the repository field name on the service — search the file for the injected `RecipeRepository` field; replace `_recipeRepository` with the actual name.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd.bat flutter test test/unit/services/unified_recipe_service_friend_fetch_test.dart`
Expected: PASS (all three).

- [ ] **Step 5: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/services/unified/unified_recipe_service.dart
git add lib/services/unified/unified_recipe_service.dart test/unit/services/unified_recipe_service_friend_fetch_test.dart
# markers: code-review, testing-review, firebase-security
git commit -m "feat(recipes): fetchFriendRecipe service wrapper (cache-first, repo fallback)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Read-only mode on `RecipeDetailView`

**Files:**
- Modify: `lib/views/recipe_detail_view.dart` (constructor ~line 89-97; build ~line 132; owner actions: favorite ~line 337, edit menu item ~line 439, editTags item ~line 513, delete)
- Test: `test/widget/views/recipe_detail_read_only_test.dart`

**Interfaces:**
- Produces: `RecipeDetailView({required Recipe recipe, bool scrollToComments = false, bool readOnly = false})`. When `readOnly` is true, the favorite toggle, Edit, Edit-tags, and Delete actions are hidden; the Save-a-copy (fork) action and comments/ratings remain.

**Why a flag (not just `createdBy`):** the favorite toggle and Edit/Delete menu items are currently shown unconditionally (`recipe_detail_view.dart:337,439`) — they assume the recipe is the user's own. A friend's recipe must suppress them explicitly. Fork is already gated for non-owners via `showForkInAppBar`/`showForkInOverflow` (BUT-972) and needs no change.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/views/recipe_detail_read_only_test.dart`. Pump `RecipeDetailView(recipe: friendRecipe, readOnly: true)` inside the standard test harness used by other `test/widget/views/` recipe tests (ServiceLocator bridge + Providers). Assertions:

```dart
// readOnly: true →
expect(find.byKey(const ValueKey('test-recipe-detail-favorite')), findsNothing);
expect(find.byKey(const ValueKey('test-recipe-detail-edit')), findsNothing); // after opening overflow menu
// Save-a-copy remains:
expect(find.byKey(const ValueKey('test-recipe-detail-save-copy')), findsOneWidget);
```

Add a contrasting `readOnly: false` case asserting the favorite key `findsOneWidget`.

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/widget/views/recipe_detail_read_only_test.dart`
Expected: FAIL — `readOnly` is not a parameter / favorite still present.

- [ ] **Step 3: Thread the flag**

In `lib/views/recipe_detail_view.dart`:
1. Add the field + constructor param on `RecipeDetailView` (after line 91):

```dart
  final bool scrollToComments;
  final bool readOnly;

  const RecipeDetailView({
    super.key,
    required this.recipe,
    this.scrollToComments = false,
    this.readOnly = false,
  });
```

2. Pass it into `_RecipeDetailViewContent` (build, ~line 132):

```dart
      child: _RecipeDetailViewContent(
        recipe: widget.recipe,
        scrollToComments: widget.scrollToComments,
        readOnly: widget.readOnly,
      ),
```

3. Add `final bool readOnly;` to `_RecipeDetailViewContent` and its constructor.
4. Gate the owner actions. Wrap the favorite `Padding` (line 337-) and the Edit (`test-recipe-detail-edit`), Edit-tags (`editTags`), and Delete `PopupMenuItem`s in `if (!readOnly) ...`. Concretely, the favorite block:

```dart
                  // Favorite toggle — owner-only (hidden for a friend's recipe)
                  if (!readOnly)
                    Padding(
                      key: const ValueKey('test-recipe-detail-favorite'),
                      // ...unchanged children...
                    ),
```

and in the overflow `itemBuilder` return list, prefix the Edit / editTags / Delete items with `if (!readOnly)`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd.bat flutter test test/widget/views/recipe_detail_read_only_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/views/recipe_detail_view.dart
git add lib/views/recipe_detail_view.dart test/widget/views/recipe_detail_read_only_test.dart
# markers: code-review, testing-review
git commit -m "feat(recipe-detail): readOnly mode hides owner actions for friend recipes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Wire the feed tap to open shared recipes

**Files:**
- Modify: `lib/views/social/friends_list/feed_tab.dart` (caller ~line 305; `_navigateToRecipe` ~line 353-368)
- Test: `test/widget/views/feed_tab_navigation_test.dart`

**Interfaces:**
- Consumes: `UnifiedRecipeService.fetchFriendRecipe` (Task 3); `RecipeDetailView(readOnly:)` (Task 4); `ActivityEvent.actorId`, `.recipeId`.
- Produces: tapping a feed recipe opens it read-only when visible; shows `feedRecipeUnavailable` when not (Phase 2 replaces this branch).

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/views/feed_tab_navigation_test.dart`. With a `MockUnifiedRecipeService` whose `fetchFriendRecipe(ownerId, recipeId)` returns a friend recipe, tap the recipe-preview row and assert navigation pushed `Routes.recipeDetail` with `readOnly: true`. Add a second case where `fetchFriendRecipe` returns null and assert the `feedRecipeUnavailable` SnackBar text appears. Use a `NavigatorObserver` mock (mocktail) to capture the pushed route settings, mirroring existing navigation tests in `test/widget/views/`.

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/widget/views/feed_tab_navigation_test.dart`
Expected: FAIL — current `_navigateToRecipe` is sync, ignores `actorId`, and passes no `readOnly`.

- [ ] **Step 3: Make the tap async and owner-aware**

In `lib/views/social/friends_list/feed_tab.dart`:
1. Update the caller (line 305):

```dart
        onTap: () => _navigateToRecipe(context, event.actorId, event.recipeId),
```

2. Replace `_navigateToRecipe` (line 353-368) with:

```dart
  static Future<void> _navigateToRecipe(
    BuildContext context,
    String ownerId,
    String recipeId,
  ) async {
    final recipe = await ServiceLocator.get<UnifiedRecipeService>()
        .fetchFriendRecipe(ownerId: ownerId, recipeId: recipeId);
    if (!context.mounted) return;
    if (recipe != null) {
      Navigator.of(context).pushNamed(
        Routes.recipeDetail,
        arguments: {'recipe': recipe, 'readOnly': true},
      );
    } else {
      // Phase 2 replaces this branch with the request-to-share dialog.
      SnackBarUtils.showError(context, context.l10n.feedRecipeUnavailable);
    }
  }
```

3. Teach the router to read `readOnly` from the map args. In `lib/core/router/app_router.dart:227-230`, extend the map branch:

```dart
          } else if (arguments is Map<String, dynamic>) {
            recipe = arguments['recipe'] as Recipe?;
            scrollToComments = arguments['scrollToComments'] as bool? ?? false;
            readOnly = arguments['readOnly'] as bool? ?? false;
          }
```

and pass `readOnly: readOnly` into `RecipeDetailView(...)` (declare `bool readOnly = false;` next to `scrollToComments` at line 224).

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd.bat flutter test test/widget/views/feed_tab_navigation_test.dart`
Expected: PASS (both cases).

- [ ] **Step 5: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/views/social/friends_list/feed_tab.dart lib/core/router/app_router.dart
git add lib/views/social/friends_list/feed_tab.dart lib/core/router/app_router.dart test/widget/views/feed_tab_navigation_test.dart
# markers: code-review, testing-review
git commit -m "feat(feed): open a friend's shared recipe read-only from the activity feed

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

**Phase 1 done:** shared recipes open read-only from the feed; unshared recipes show the existing unavailable note. Run the full Phase-1 test set + `cmd.bat flutter analyze` before moving on.

---

# PHASE 2 — Request a cooked-but-not-shared recipe

### Task 6: Add the `recipeShareRequest` social-request type

**Files:**
- Modify: `lib/models/social_request.dart` (enum line 13; add factory; serialization lines 98-148 carry `recipeId`/`recipeTitle`)
- Test: `test/unit/models/social_request_recipe_test.dart`

**Interfaces:**
- Produces: `SocialRequestType.recipeShareRequest`; `SocialRequest.recipeShareRequest({required String fromUserId, required String toUserId, required String recipeId, required String recipeTitle, String? fromUserName})`; round-trips `recipeId` + `recipeTitle` through `toFirestore`/`fromMap`; getter `bool get isRecipeShareRequest`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/models/social_request_recipe_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/social_request.dart';

void main() {
  test('recipeShareRequest factory sets type + payload', () {
    final r = SocialRequest.recipeShareRequest(
      fromUserId: 'a', toUserId: 'b', recipeId: 'r1', recipeTitle: 'Pannkakor',
    );
    expect(r.type, SocialRequestType.recipeShareRequest);
    expect(r.isRecipeShareRequest, isTrue);
    expect(r.recipeId, 'r1');
    expect(r.recipeTitle, 'Pannkakor');
  });

  test('recipeShareRequest round-trips through Firestore map', () {
    final r = SocialRequest.recipeShareRequest(
      fromUserId: 'a', toUserId: 'b', recipeId: 'r1', recipeTitle: 'Pannkakor',
    );
    final back = SocialRequest.fromMap(r.id, r.toFirestore());
    expect(back.type, SocialRequestType.recipeShareRequest);
    expect(back.recipeId, 'r1');
    expect(back.recipeTitle, 'Pannkakor');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/unit/models/social_request_recipe_test.dart`
Expected: FAIL — enum value / factory / fields don't exist.

- [ ] **Step 3: Extend the model**

In `lib/models/social_request.dart`:
1. Enum (line 13): `enum SocialRequestType { friend, groupInvitation, recipeShareRequest }`
2. Add nullable fields near the group fields (after line 34): `final String? recipeId;` and `final String? recipeTitle;` — add them to the constructor param list (line 36-49) as `this.recipeId,` `this.recipeTitle,`.
3. Add the factory after `groupInvitation` (line 96):

```dart
  /// Request that [toUserId] share recipe [recipeId] with [fromUserId].
  factory SocialRequest.recipeShareRequest({
    required String fromUserId,
    required String toUserId,
    required String recipeId,
    required String recipeTitle,
    String? fromUserName,
  }) {
    final now = clock.now().toUtc();
    return SocialRequest(
      id: const Uuid().v4(),
      type: SocialRequestType.recipeShareRequest,
      fromUserId: fromUserId,
      toUserId: toUserId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      fromUserName: fromUserName,
      sentAt: now,
      expiresAt: now.add(_expiryDuration),
    );
  }
```

4. `fromMap` (after line 127): `recipeId: SerializationUtils.safeNullableString(data, 'recipeId'),` and `recipeTitle: SerializationUtils.safeNullableString(data, 'recipeTitle'),`.
5. `toFirestore` (after line 146): `if (recipeId != null) 'recipeId': recipeId,` and `if (recipeTitle != null) 'recipeTitle': recipeTitle,`.
6. `copyWith` (line 150-169): thread `recipeId: recipeId,` `recipeTitle: recipeTitle,` through unchanged.
7. Getter (after line 175): `bool get isRecipeShareRequest => type == SocialRequestType.recipeShareRequest;`

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd.bat flutter test test/unit/models/social_request_recipe_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/models/social_request.dart
git add lib/models/social_request.dart test/unit/models/social_request_recipe_test.dart
# markers: code-review, testing-review
git commit -m "feat(social): add recipeShareRequest social-request type

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Send + accept the recipe-share request (service)

**Files:**
- Modify: `lib/services/notifications/notification_payload_type.dart` (add constant — confirm exact file from `NotificationPayloadType.friendRequest` usage in `fcm_service.dart:514`)
- Modify: `lib/services/social_recipe_service.dart` (add `requestRecipeShare`, `acceptRecipeShareRequest`)
- Modify: `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb`
- Test: `test/unit/services/request_recipe_share_test.dart`

**Interfaces:**
- Consumes: `SocialRequest.recipeShareRequest` (Task 6); the `social_requests` write pattern from `firebase_friends_repository.dart:95`; the `sendNotification` callable wrapper in `notification_service.dart:524`; `shareRecipeWithUsers` (`social_recipe_sharing_service.dart:50`).
- Produces:
  - `Future<bool> requestRecipeShare({required String ownerId, required String recipeId, required String recipeTitle})` — idempotent: no-op + returns true if a `pending` recipeShareRequest already exists for (fromUserId, ownerId, recipeId).
  - `Future<bool> acceptRecipeShareRequest(SocialRequest request)` — calls `shareRecipeWithUsers(request.recipeId!, [request.fromUserId], ResourcePermission.viewer)`, marks the request `accepted`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/services/request_recipe_share_test.dart`. With a fake/mock Firestore + mocked notification sender, assert:

```dart
// 1. requestRecipeShare writes one social_requests doc (type recipeShareRequest,
//    pending) and calls the notification sender once.
// 2. Calling it again for the same (from,owner,recipe) while pending does NOT
//    write a second doc and does NOT send a second notification (idempotent).
// 3. acceptRecipeShareRequest calls shareRecipeWithUsers(recipeId, [fromUserId], viewer)
//    and flips the request status to accepted.
```

Mock `shareRecipeWithUsers` and the notification sender; mirror the existing `test/unit/services/` doubles for `SocialRecipeService`.

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/unit/services/request_recipe_share_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Add the payload type constant**

In `lib/services/notifications/notification_payload_type.dart`, add `recipeShareRequest` alongside `friendRequest`/`recipeShared` (match the existing declaration style — string-backed constant, value `'recipe_share_request'`).

- [ ] **Step 4: Implement the service methods**

In `lib/services/social_recipe_service.dart` add (using the service's existing user-id getter and injected friends repository / firestore access — match the file's existing dependencies):

```dart
  /// Ask [ownerId] to share [recipeId] with the current user. Idempotent on a
  /// pending request for the same (requester, owner, recipe).
  Future<bool> requestRecipeShare({
    required String ownerId,
    required String recipeId,
    required String recipeTitle,
  }) async {
    final me = getCurrentUserId();
    if (me == null) return false;

    final existing = await _firestore
        .collection('social_requests')
        .where('type', isEqualTo: SocialRequestType.recipeShareRequest.name)
        .where('fromUserId', isEqualTo: me)
        .where('toUserId', isEqualTo: ownerId)
        .where('recipeId', isEqualTo: recipeId)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return true; // already requested

    final request = SocialRequest.recipeShareRequest(
      fromUserId: me,
      toUserId: ownerId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      fromUserName: _currentUserDisplayName(),
    );
    await _firestore
        .collection('social_requests')
        .doc(request.id)
        .set(request.toFirestore());

    await _notificationService.sendNotification(
      ownerId,
      type: NotificationPayloadType.recipeShareRequest,
      data: {'recipeId': recipeId, 'fromUserId': me, 'recipeTitle': recipeTitle},
    );
    return true;
  }

  /// Owner accepts: share the recipe with the requester and close the request.
  Future<bool> acceptRecipeShareRequest(SocialRequest request) async {
    final recipeId = request.recipeId;
    if (recipeId == null) return false;
    final shared = await _sharingService.shareRecipeWithUsers(
      recipeId,
      [request.fromUserId],
      ResourcePermission.viewer,
    );
    if (!shared) return false;
    await _firestore.collection('social_requests').doc(request.id).update({
      'status': SocialRequestStatus.accepted.name,
      'respondedAt': AppTimestamp.fromDateTime(clock.now().toUtc()).toFirestore(),
    });
    return true;
  }
```

(Match the exact injected field names — `_firestore`, `_notificationService`, `_sharingService`, `getCurrentUserId`, `_currentUserDisplayName` — to what `SocialRecipeService` already exposes; adjust the `sendNotification` signature to the real wrapper in `notification_service.dart:524`.)

- [ ] **Step 5: Add the l10n strings (used in Task 8/9 UI + notification text)**

Add to `lib/l10n/app_sv.arb` (and English mirrors in `app_en.arb`), then run `cmd.bat flutter gen-l10n`:

```json
"feedRequestRecipeTitle": "Be om receptet",
"feedRequestRecipeBody": "{name} har inte delat det här receptet. Vill du be om det?",
"@feedRequestRecipeBody": { "placeholders": { "name": { "type": "String" } } },
"feedRequestRecipeConfirm": "Be om receptet",
"feedRecipeRequestSent": "Förfrågan skickad",
"feedRecipeRequestAlreadySent": "Du har redan bett om det här receptet",
"recipeShareRequestNotifTitle": "Receptförfrågan",
"recipeShareRequestNotifBody": "{name} vill se ditt recept \"{title}\"",
"@recipeShareRequestNotifBody": { "placeholders": { "name": { "type": "String" }, "title": { "type": "String" } } },
"recipeShareRequestBanner": "{name} vill se det här receptet",
"@recipeShareRequestBanner": { "placeholders": { "name": { "type": "String" } } },
"recipeShareRequestShareAction": "Dela med {name}",
"@recipeShareRequestShareAction": { "placeholders": { "name": { "type": "String" } } },
"recipeShareRequestShared": "Delat med {name}",
"@recipeShareRequestShared": { "placeholders": { "name": { "type": "String" } } }
```

English (`app_en.arb`): "Request recipe" / "{name} hasn't shared this recipe. Ask for it?" / "Request recipe" / "Request sent" / "You've already requested this recipe" / "Recipe request" / "{name} wants to see your recipe \"{title}\"" / "{name} wants to see this recipe" / "Share with {name}" / "Shared with {name}".

- [ ] **Step 6: Run the test to verify it passes**

Run: `cmd.bat flutter test test/unit/services/request_recipe_share_test.dart`
Expected: PASS (all three).

- [ ] **Step 7: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/services/social_recipe_service.dart lib/services/notifications/notification_payload_type.dart
git add lib/services/social_recipe_service.dart lib/services/notifications/notification_payload_type.dart lib/l10n/app_sv.arb lib/l10n/app_en.arb lib/l10n/ test/unit/services/request_recipe_share_test.dart
# markers: code-review, testing-review, firebase-security
git commit -m "feat(social): requestRecipeShare + acceptRecipeShareRequest (idempotent)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Notification tap → owner sees a one-tap "share back" banner

**Files:**
- Modify: `lib/services/notifications/fcm_service.dart` (nav switch ~line 514; add a `_navigateToOwnRecipeForShareRequest`)
- Modify: `lib/views/recipe_detail_view.dart` (owner-side banner driven by route args; only when the current user IS the owner)
- Test: covered by `test/widget/views/recipe_detail_read_only_test.dart` extension (new case)

**Interfaces:**
- Consumes: `acceptRecipeShareRequest` (Task 7); `RecipeDetailView` route args.
- Produces: a `recipeShareRequest` notification opens the **owner's own** recipe with a dismissible banner "{name} wants to see this recipe → [Dela med {name}]"; tapping it calls `acceptRecipeShareRequest` and shows `recipeShareRequestShared`.

- [ ] **Step 1: Write the failing widget test**

Extend `test/widget/views/recipe_detail_read_only_test.dart` with a case: pump `RecipeDetailView` with route args `{recipe: ownRecipe, shareRequest: <SocialRequest>}` and a mocked `SocialRecipeService`. Assert the banner text (`recipeShareRequestBanner`) and the share action (`recipeShareRequestShareAction`) render, and tapping the action calls `acceptRecipeShareRequest` once.

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/widget/views/recipe_detail_read_only_test.dart`
Expected: FAIL — no banner support.

- [ ] **Step 3: Add the FCM nav case**

In `lib/services/notifications/fcm_service.dart` switch (after the `friendRequest` case, line 514):

```dart
        case NotificationPayloadType.recipeShareRequest:
          await _navigateToOwnRecipeForShareRequest(navigator, data);
          break;
```

Add the helper (mirroring `_navigateToSharedRecipe`): resolve the owner's own recipe via `UnifiedRecipeService.getRecipeById(data['recipeId'])`, build a `SocialRequest` view-payload from `data` (or fetch the pending request by recipeId+fromUserId), and `navigator.pushNamed(Routes.recipeDetail, arguments: {'recipe': recipe, 'shareRequest': request})`.

- [ ] **Step 4: Render the banner**

In `lib/views/recipe_detail_view.dart`, accept an optional `SocialRequest? shareRequest` (constructor + route map arg `arguments['shareRequest']`). When non-null AND the current user owns the recipe, render a top banner (above the content) with the `recipeShareRequestBanner` text and a `recipeShareRequestShareAction` button that calls `ServiceLocator.get<SocialRecipeService>().acceptRecipeShareRequest(shareRequest)` then shows the `recipeShareRequestShared` SnackBar and hides the banner. Keep this in a small private `_ShareRequestBanner` widget (file-size discipline).

- [ ] **Step 5: Run the test to verify it passes**

Run: `cmd.bat flutter test test/widget/views/recipe_detail_read_only_test.dart`
Expected: PASS (all cases).

- [ ] **Step 6: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/services/notifications/fcm_service.dart lib/views/recipe_detail_view.dart
git add lib/services/notifications/fcm_service.dart lib/views/recipe_detail_view.dart test/widget/views/recipe_detail_read_only_test.dart
# markers: code-review, testing-review, firebase-security (fcm_service)
git commit -m "feat(social): recipe-share-request notification → one-tap share-back banner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Replace the feed unavailable-branch with the request dialog

**Files:**
- Modify: `lib/views/social/friends_list/feed_tab.dart` (`_navigateToRecipe` null branch from Task 5)
- Test: `test/widget/views/feed_tab_navigation_test.dart` (extend)

**Interfaces:**
- Consumes: `SocialRecipeService.requestRecipeShare` (Task 7); `ActivityEvent.actorId`, `.recipeId`, `.recipeTitle`, `.actorDisplayName`.
- Produces: tapping an unshared recipe opens a confirm dialog; on confirm, calls `requestRecipeShare` and toasts `feedRecipeRequestSent`.

- [ ] **Step 1: Write the failing test**

In `test/widget/views/feed_tab_navigation_test.dart`, change the null-`fetchFriendRecipe` case: assert that tapping shows a dialog with `feedRequestRecipeBody` text, and that confirming calls `requestRecipeShare(ownerId: actorId, recipeId:, recipeTitle:)` once and shows `feedRecipeRequestSent`.

- [ ] **Step 2: Run it to verify it fails**

Run: `cmd.bat flutter test test/widget/views/feed_tab_navigation_test.dart`
Expected: FAIL — null branch still shows the plain unavailable SnackBar.

- [ ] **Step 3: Implement the dialog branch**

Replace the `else` branch in `_navigateToRecipe` (added in Task 5). The method needs the event's title + actor name, so change the caller (line 305) to pass the whole event:

```dart
        onTap: () => _navigateToRecipe(context, event),
```

and the signature to `static Future<void> _navigateToRecipe(BuildContext context, ActivityEvent event)`, using `event.actorId`, `event.recipeId`. The null branch:

```dart
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.feedRequestRecipeTitle),
          content: Text(ctx.l10n.feedRequestRecipeBody(event.actorDisplayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.feedRequestRecipeConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final ok = await ServiceLocator.get<SocialRecipeService>().requestRecipeShare(
        ownerId: event.actorId,
        recipeId: event.recipeId,
        recipeTitle: event.recipeTitle,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(
        context,
        ok ? context.l10n.feedRecipeRequestSent : context.l10n.feedRecipeRequestAlreadySent,
      );
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd.bat flutter test test/widget/views/feed_tab_navigation_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, dispatch reviewers, commit**

```bash
cmd.bat flutter analyze lib/views/social/friends_list/feed_tab.dart
git add lib/views/social/friends_list/feed_tab.dart test/widget/views/feed_tab_navigation_test.dart
# markers: code-review, testing-review
git commit -m "feat(feed): offer to request a cooked-but-unshared recipe from a friend

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

**Phase 2 done:** tapping an unshared recipe requests it; the owner gets a notification and shares back in one tap, after which the requester can open it (Phase 1 path). Run the full test suite + `cmd.bat flutter analyze`.

---

## Self-Review notes

- **Spec coverage:** rule widening (Task 1) ↔ spec §1a; cross-user read (Task 2) ↔ §1b; service wrapper (Task 3) ↔ §1b; read-only view (Task 4) ↔ §1d; feed tap (Task 5) ↔ §1c; request type (Task 6) ↔ §2a; send/accept (Task 7) ↔ §2b/2c; notification nav + banner (Task 8) ↔ §2c; feed request dialog (Task 9) ↔ §2b. Expiry/decline (§2d) is satisfied by the existing `cleanupExpiredSocialRequests` job, which already queries `status == 'pending'` — no new code; verified, not a gap.
- **Type consistency:** `readSharedRecipe({ownerId, recipeId})` and `fetchFriendRecipe({ownerId, recipeId})` named identically across Tasks 2/3/5; `SocialRequest.recipeShareRequest({fromUserId, toUserId, recipeId, recipeTitle, fromUserName})` consistent across Tasks 6/7/8/9; `NotificationPayloadType.recipeShareRequest` consistent across Tasks 7/8; route map keys `recipe`/`readOnly`/`shareRequest` consistent across Tasks 5/8.
- **Verify-before-implement note:** Tasks 3/7 say "confirm the actual injected field name" because the exact private field identifiers (`_recipeRepository`, `_firestore`, `_notificationService`, `_sharingService`) must be read from the target file at implementation time — the names above are the expected ones but the file is the source of truth.

## What this means in plain language

- We build it in nine small, separately-testable steps, each ending in its own commit and review — nothing lands half-finished.
- Phase 1 (steps 1–5) makes a friend's shared recipe actually open from your feed, read-only, and is useful on its own.
- Phase 2 (steps 6–9) adds the "ask them to share it" flow for recipes they only cooked.
- The riskiest single step (step 1, the security-rule change) is also the most heavily tested — four pass/fail security tests must go green before it commits.
- Every step that touches security or data goes past the automated reviewers before it's committed, same as all our other work.
