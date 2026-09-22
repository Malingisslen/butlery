// lib/widgets/common/state/state_enums.dart

/// Enum for different state types
enum StateType {
  loading,
  skeleton,
  empty,
  error,
  success,
  info,
  warning,
}

/// Enum for different empty state variants
enum EmptyStateVariant {
  noRecipes,
  noSearchResults,
  noFriendsSearchResults,
  noGroupsSearchResults,
  noMenu,
  noShoppingList,
  noFriends,
  noCategories,
  noImages,
  noTargets,
  noSavedMenus,
  noSharedShoppingLists,
  noTags,
  noNotifications,
  noComments,
  noGroups,
  noConversations,
  generic,
}

/// Enum for different loading variants
enum LoadingVariant {
  /// Tallrikslinjen med text. Namnet är historiskt: ingen snurra ritas
  /// (beslut B-18). Byter namn i bortstädningen (paket 7).
  spinner,

  /// Ritar tallrikslinjen. Ärtbaljan är ingen laddningsindikator
  /// (produktregler.md:163, :304). Värdet tas bort i paket 7.
  peaAnimation,

  /// Skeleton card placeholder
  skeletonRecipeCard,

  /// Skeleton list with multiple cards
  skeletonRecipeList,

  /// Generic skeleton placeholder
  skeletonGeneric,

  /// Stillastående ruta, visas efter 300 ms. Ingen shimmer (beslut B-18).
  shimmerBox,
}
