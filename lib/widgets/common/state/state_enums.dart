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
  spinner,
  skeletonRecipeCard,
  skeletonRecipeList,
  skeletonGeneric,
  shimmerBox,
}