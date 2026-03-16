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
  noGroups,
  noConversations,
  generic,
}

/// Enum for different loading variants
enum LoadingVariant {
  /// Standard circular progress indicator
  spinner,

  /// Animated pea pod (UI Redesign branded loading)
  peaAnimation,

  /// Skeleton card placeholder
  skeletonRecipeCard,

  /// Skeleton list with multiple cards
  skeletonRecipeList,

  /// Generic skeleton placeholder
  skeletonGeneric,

  /// Simple shimmer box
  shimmerBox,
}
