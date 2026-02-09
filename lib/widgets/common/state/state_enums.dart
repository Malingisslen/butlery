// lib/widgets/common/state/state_enums.dart

/// Enum för olika state-typer
enum StateType {
  loading,
  skeleton,
  empty,
  error,
  success,
  info,
  warning,
}

/// Enum för olika empty state varianter
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
  generic,
}

/// Enum för olika loading varianter
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
