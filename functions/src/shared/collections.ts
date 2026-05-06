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
