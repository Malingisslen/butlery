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
  // BUT-1838: the shared group object a group chat now hangs off. Named
  // `chat_groups`, not `groups`, because this repo already calls three unrelated
  // things a "group": `friend_categories` (a user's own list of friends, used for
  // recipe sharing), `group_invitations` below (invitations into THOSE), and the
  // old `isGroup: true` conversation this replaces. A bare `groups` would make
  // every future grep ambiguous.
  chatGroups: "chat_groups",
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
} as const;
