/**
 * Firestore collection name constants.
 * Single source of truth — use these instead of string literals.
 */

export const Collections = {
  users: "users",
  publicProfiles: "public_profiles",
  recipes: "recipes",
  ingredients: "ingredients",
  sharedRecipes: "shared_recipes",
  realtimeRecipes: "realtime_recipes",
  realtimeMenus: "realtime_menus",
  messages: "messages",
  conversations: "conversations",
  // The roster subcollection under `conversations/{id}`, and the collection-group
  // id its cross-conversation queries use. Added for the account cascade's
  // `participantId` sweep (BUT-1822). Two local copies of this literal remain —
  // `enforce-group-minor-membership.ts` and `admin/reset-user-data.ts` — so a
  // rename still needs three edits. (Three copies until BUT-1838 deleted
  // `leave-group-conversation.ts`.) This is the home the next writer should use,
  // not yet the only one.
  participants: "participants",
  // BUT-1832: one row per voter under `messages/{messageId}`, doc id == voter
  // uid. Votes moved off the message document because only a message's SENDER
  // may update it, which denied the vote to everyone but the poll's author. The
  // cascade sweeps this as a COLLECTION GROUP keyed on `voterId` (BUT-1835), so
  // the Dart writer (`FirestoreCollections.pollVotes`) and this constant must
  // stay the same string — a mismatch is a query that matches nothing and
  // throws nothing.
  pollVotes: "poll_votes",
  // BUT-1838: the shared group object a group chat now hangs off. Named
  // `chat_groups`, not `groups`, because this repo already calls three unrelated
  // things a "group": `friend_categories` (a user's own list of friends, used for
  // recipe sharing), `group_invitations` below (invitations into THOSE), and the
  // old `isGroup: true` conversation this replaces. A bare `groups` would make
  // every future grep ambiguous.
  chatGroups: "chat_groups",
  // BUT-1979: a group's weekly menu plans, doc id `{groupId}_{ISO week}`. Swept
  // whole by the group-collapse path in `remove-chat-group-member.ts`, and
  // scrubbed per-user by the account cascade. The Dart
  // writer is `FirestoreCollections.groupWeeklyMenuPlans`; the two must stay the
  // same string, since a mismatch is a query that matches nothing and throws
  // nothing.
  groupWeeklyMenuPlans: "group_weekly_menu_plans",
  // A user's own list of friends, at `users/{ownerId}/friend_categories/{id}`.
  // Read server-side only by BUT-1856's `ensureCategoryChat`, which resolves the
  // roster of a meal-vote chat from it. The document id is a client-chosen UUID
  // with no uniqueness across accounts, so anything keyed on it must carry the
  // owner too.
  friendCategories: "friend_categories",
  recipeComments: "recipe_comments",
  unifiedShoppingLists: "unified_shopping_lists",
  unifiedSharedShoppingLists: "unified_shared_shopping_lists",
  groupInvitations: "group_invitations",
  // BUT-772: collection renamed friend_requests → social_requests in BUT-761
  // (clients + rules already migrated). The const name follows the same path
  // so that a stale `Collections.friendRequests` lookup is a compile error,
  // not a silent zero-results read.
  socialRequests: "social_requests",
  notifications: "notifications",
  feedback: "feedback",
  // BUT-1917: user block relationships, doc id `{blockerId}_{blockedId}`.
  // Written only by the client (`FirebaseBlockRepository`); this constant is
  // the first server-side reader, added because account deletion never reached
  // the collection. The Dart writer is `FirestoreCollections.blocks` and the
  // two must stay the same string — a mismatch is a query that matches nothing
  // and throws nothing.
  blocks: "blocks",
} as const;
