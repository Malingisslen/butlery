# Read a Friend's Recipe from the Feed — Design

**Date:** 2026-06-21
**Status:** Approved (design) — pending implementation plan
**Approach:** B (friends read the live recipe directly), Phases 1 + 2

## Problem

The friends activity feed shows items like "Anna cooked X" and "Anna shared Y".
Tapping a recipe in the feed today fails: `_navigateToRecipe` calls
`UnifiedRecipeService.getRecipeById(recipeId)`, a **user-scoped** cache lookup
that returns `null` for any recipe the current user doesn't own. The feed then
shows "Receptet är inte tillgängligt" (`feedRecipeUnavailable`). There is no
read path for another user's recipe.

### Why no read path exists

- A friend's recipe lives at `/users/{ownerId}/recipes/{recipeId}` and the
  security rule is **owner-only read** (`firestore.rules:232`).
- Feed items (`cook_snaps`, `activity_events`) are friend-readable but carry
  only `recipeId` + `recipeTitle` + photo — **no ingredients or instructions**.
- The explicit-share system (`shared_content`) stores only **denormalized
  metadata** for new (V2) shares (`shared_recipe.dart:280` `toFirestore`); the
  full recipe is never persisted there. The model's "fetched on-demand" comment
  was never implemented, so importing a V2 share yields an *empty* recipe
  (`createImportRecipe` returns `null` when there's no snapshot —
  `shared_recipe.dart:250`).

### The latent gap this fixes

When a user shares a recipe with friends, the recipe is converted to
**collaborative** and each recipient's uid is written into
`socialData.memberPermissions` **on the recipe document**
(`social_recipe_sharing_service.dart:94-122`). But the recipe stays in
owner-only storage, so **recipients still cannot read the recipe they were
granted access to**. The "shared-with list" exists; the read rule ignores it.

## Decisions (locked)

1. **Privacy scope:** a user may open **only recipes explicitly shared with
   them** (not a friend's whole library; not merely-cooked recipes).
2. **Data source — Approach B:** friends read the **live** recipe directly,
   gated by the existing `memberPermissions` shared-with list. Chosen over
   storing a snapshot (A) because it always shows the current version and
   repairs the recipient-can't-read gap. Accepted cost: a read-only widening of
   the recipe security rule.
3. **Cooked-but-not-shared tap:** offer to **request** the recipe from the
   friend (Phase 2). Until a recipe is shared to the viewer it is not readable.
4. **Both phases in scope.**

## Architecture

### Phase 1 — Open an explicitly-shared recipe (read-only)

**1a. Security rule (the sensitive change).**
Extend the recipe read rule at `firestore.rules:232` to also allow members of
the shared-with map. Read-only; the allergen-critical `create`/`update`
validation stays owner-only and untouched.

```
match /users/{userId}/recipes/{recipeId} {
  allow read: if isOwner(userId)
    || (isAuthenticated()
        && request.auth.uid in resource.data.get('socialData', {})
                                       .get('memberPermissions', {}));
  // create/update/delete unchanged (owner-only + admin moderation)
}
```

`memberPermissions` serializes as `{uid: enumIndex}` under the `socialData` key
(`recipe_serialization.dart:46`, `recipe_unified.dart:1032`). The rule checks
**key membership only**, so the integer values don't matter. A non-member or
stranger fails the read.

**1b. Cross-user read method.**
Add a repository method that reads an arbitrary owner's recipe doc, letting the
rule enforce permission:

```dart
// RecipeRepository (interface) + FirebaseRecipeRepository
Future<Recipe?> readSharedRecipe({required String ownerId, required String recipeId});
```

It reads `/users/{ownerId}/recipes/{recipeId}`. A permission-denied result
returns `null` (the caller treats null as "not shared with me" → Phase 2 path).
Wrapped by a unified-service method `UnifiedRecipeService.fetchFriendRecipe(...)`
for the view layer. Must carry `PermissionValidationMixin` semantics — the read
is authorized by Firestore rules, not bypassed client-side.

**1c. Feed tap resolution.**
`feed_tab.dart` `_navigateToRecipe(context, ownerId, recipeId)` becomes async:
1. Try the local user-scoped cache first (own recipe → unchanged behavior).
2. Else `await fetchFriendRecipe(ownerId, recipeId)`.
   - Non-null → push `Routes.recipeDetail` with the recipe + a `readOnly` flag.
   - Null → Phase 2 (request flow); pre-Phase-2 fallback shows the existing
     `feedRecipeUnavailable` note.

The caller must pass the **actor's uid** (`event.actorId`), which the feed
event already carries — today only `recipeId` is passed.

**1d. Read-only recipe detail.**
`RecipeDetailView` already accepts a `Recipe` via route args
(`app_router.dart:225`). Add a `readOnly` (foreign-recipe) flag that:
- hides edit/delete/favorite-as-owner actions,
- shows an **"Importera"** action reusing the existing import path,
- keeps view-only social affordances (comments/ratings) per existing rules.

Loading/empty/error states handled by `BaseViewModel` conventions.

### Phase 2 — Request a cooked-but-not-shared recipe

Reuse the existing `social_requests` infrastructure (model
`social_request.dart`, callable `functions/src/notifications/send-notification.ts`,
cleanup `cleanup-expired-social-requests.ts` with 7-day expiry). No new
collection, no new scheduled function.

**2a. New request type.**
Add `SocialRequestType.recipeShareRequest` to `social_request.dart:13` with a
`SocialRequest.recipeShareRequest({fromUserId, toUserId, recipeId, recipeTitle})`
factory. Carries `recipeId` + `recipeTitle` in its payload.

**2b. Send the request.**
Tapping a not-shared recipe → confirm dialog
*"[Friend] har inte delat det här receptet. Vill du be om det?"* → on confirm,
write the `social_requests` doc and call `sendNotification` (social category,
respects existing rate caps) to the owner: *"[Requester] vill se ditt recept
'[title]'."* Deterministic; no LLM. Idempotent on (fromUserId, toUserId,
recipeId, status=pending) to avoid duplicate nudges.

**2c. Owner acts on it.**
Notification deep-links the owner to the recipe with a one-tap
**"Dela med [Requester]"** action that calls the existing
`shareRecipeWithUsers(recipeId, [requesterUid], viewer)`. That writes the
requester into `memberPermissions` → the recipe becomes readable → the
requester can now open it from the feed (Phase 1 path). Mark the request
`accepted`.

**2d. Expiry & decline.** Pending requests expire after 7 days via the existing
cleanup job (already queries `status == pending`). Owner may decline (status
`declined`), mirroring friend-request handling.

## Data flow (Phase 1, happy path)

```
feed item tap (actorId, recipeId)
  → UnifiedRecipeService.fetchFriendRecipe(actorId, recipeId)
    → FirebaseRecipeRepository.readSharedRecipe → /users/{actorId}/recipes/{recipeId}
      → rule: requester ∈ memberPermissions? allow : deny
  → non-null → RecipeDetailView(recipe, readOnly: true)
  → null     → Phase 2 request dialog
```

## Security & privacy

- Read widening is **minimal**: a recipe is readable only by uids the owner
  deliberately placed in `memberPermissions`. Verified by rules unit tests:
  owner reads ✓, shared member reads ✓, non-member denied ✗, stranger denied ✗,
  and write paths remain owner-only ✗ for members.
- No client-side permission bypass; Firestore rules are the gate.
- No raw uids logged (use `.maskedUserId` per project rule).
- Group shares snapshot membership at share-time (existing behavior; later group
  joiners are not auto-added). Documented limitation, not a regression.

## Error handling

- Permission-denied / not-found on `readSharedRecipe` → `null` → request path
  (Phase 2) or `feedRecipeUnavailable` note (pre-Phase-2).
- Offline / transient read failure → surfaced via `BaseViewModel.setError`, feed
  stays intact (no crash, no navigation).
- Phase 2 duplicate request → no-op (idempotent), friendly "already requested"
  toast.
- Notification send failure → request doc still written; owner sees it in-app on
  next open (notification is best-effort, mirrors existing social-request
  behavior).

## Testing

- **Rules unit tests** (`firestore-rules-tester`): the four allow/deny cases
  above + write-stays-owner-only.
- **Repository test**: `readSharedRecipe` returns recipe for member, null for
  denied.
- **Feed VM/widget test**: tap own recipe → opens (cache); tap shared → opens
  read-only; tap not-shared → request dialog.
- **Read-only view test**: edit/delete hidden, Import present.
- **Phase 2**: request creation idempotency; accept calls `shareRecipeWithUsers`
  and flips status; expiry covered by existing cleanup test.

## Scope / non-goals

- No new top-level recipes collection; recipes stay under their owner.
- No snapshot duplication (that was Approach A, rejected).
- No auto-propagation of group membership changes to shared recipes.
- No LLM anywhere in this feature.

## What this means in plain language

- Tapping a friend's recipe in your feed will actually open it — read-only —
  when they've shared it with you. Today it just says "not available."
- You'll see their real ingredients and steps (the current version), with an
  "Importera" button to copy it into your own cookbook.
- This quietly fixes an existing bug: people you share recipes with currently
  can't really see them — only a title and photo. Now they can.
- If a friend only *cooked* something (didn't share it), tapping offers to ping
  them to share it; they get a notification and can share back in one tap.
- The one thing to keep an eye on: this slightly opens the strictest security
  rule in the app — but only so that people you deliberately shared a recipe
  with can *read* it. Nobody else gains access, and no one can change your
  recipes. It's covered by automated security tests before it ships.
- Low risk to undo: Phase 1 is a rule tweak plus a new read path and a read-only
  screen; nothing existing is removed.
