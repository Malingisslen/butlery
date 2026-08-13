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
  // `participantId` sweep (BUT-1822). Three local copies of this literal remain —
  // `enforce-group-minor-membership.ts`, `leave-group-conversation.ts` and
  // `admin/reset-user-data.ts` — so a rename still needs four edits; this is the
  // home the next writer should use, not yet the only one.
  participants: "participants",
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
