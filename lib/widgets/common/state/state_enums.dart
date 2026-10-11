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

/// What an empty state is about. It alone decides whether the state draws a
/// vegetable illustration or an icon.
enum EmptyStateKind {
  /// Something of the user's own collection is empty: illustration.
  ownCollection,

  /// A search or filter result, or a small section: icon.
  resultOrSection,
}

/// Enum for different empty state variants. Each variant carries its
/// [EmptyStateKind].
enum EmptyStateVariant {
  noRecipes(EmptyStateKind.ownCollection),
  noSearchResults(EmptyStateKind.resultOrSection),
  noFriendsSearchResults(EmptyStateKind.resultOrSection),
  noGroupsSearchResults(EmptyStateKind.resultOrSection),
  noMenu(EmptyStateKind.ownCollection),
  noShoppingList(EmptyStateKind.ownCollection),
  noFriends(EmptyStateKind.ownCollection),
  noCategories(EmptyStateKind.resultOrSection),
  noImages(EmptyStateKind.resultOrSection),
  noTargets(EmptyStateKind.resultOrSection),
  noSavedMenus(EmptyStateKind.ownCollection),
  noSharedShoppingLists(EmptyStateKind.ownCollection),
  noTags(EmptyStateKind.ownCollection),
  noNotifications(EmptyStateKind.ownCollection),
  noComments(EmptyStateKind.resultOrSection),
  noGroups(EmptyStateKind.ownCollection),
  noConversations(EmptyStateKind.ownCollection),
  noPantryItems(EmptyStateKind.ownCollection),
  nothingQueued(EmptyStateKind.resultOrSection),
  generic(EmptyStateKind.resultOrSection)
  ;

  const EmptyStateVariant(this.kind);

  final EmptyStateKind kind;
}

/// Enum for different loading variants
enum LoadingVariant {
  /// Tallrikslinjen med text (beslut B-18; produktregler.md:163). Ingen
  /// snurra och ingen ärtbalja ritas.
  plateLine,

  /// Skeleton card placeholder
  skeletonRecipeCard,

  /// Skeleton list with multiple cards
  skeletonRecipeList,

  /// Generic skeleton placeholder
  skeletonGeneric,

  /// Stillastående ruta, visas efter 300 ms. Ingen shimmer (beslut B-18).
  staticBox,
}
