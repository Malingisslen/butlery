/// Route management system for unified navigation constants.

/// Central source for all navigation routes in the Butlery application.
class Routes {
  /// Home route
  static const String home = '/';

  /// Authentication route
  static const String auth = '/auth';

  /// Onboarding wizard route
  static const String onboarding = '/onboarding';

  /// Add recipe route. URL value kept as-is to preserve existing deep
  /// links and analytics paths; only the Dart identifier was renamed
  /// from Swedish (laggTill) to English (BUT-967).
  static const String addRecipe = '/laggTill';

  /// URL import route
  static const String importViaUrl = '/importViaUrl';

  /// Photo import route
  static const String photoImport = '/photoImport';

  /// Quick capture route (title-only recipe save)
  static const String quickCapture = '/quickCapture';

  /// Manual recipe creation route. URL value kept (BUT-967).
  static const String manualEntry = '/skrivSjalv';

  /// Social media import route. URL value kept (BUT-967).
  static const String fromSocialMedia = '/franSocialaMedier';

  /// Archive import route. URL value kept (BUT-967).
  static const String importFromArchive = '/importFranArkiv';

  /// File import route (CSV/Excel)
  static const String fileImport = '/fileImport';

  /// Smart import route (unified URL/text import)
  static const String smartImport = '/smartImport';

  /// Recipe detail route. URL value kept (BUT-967).
  static const String recipeDetail = '/receptDetalj';

  /// Recipe editing route. URL value kept (BUT-967).
  static const String editRecipe = '/redigeraRecept';

  /// Shared recipe reception route
  static const String receiveShare = '/receiveShare';

  /// Weekly menu route. URL value kept (BUT-967).
  static const String weeklyMenu = '/veckomeny';

  /// Collaborative realtime menu route
  static const String realtimeMenu = '/realtime-menu';

  /// Unified shopping list route. URL value kept (BUT-967).
  static const String shoppingList = '/inkopslista';

  // Social routes
  static const String profileEdit = '/profile/edit';
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String shared = '/shared';
  static const String collaborativeShopping = '/collaborative-shopping';
  static const String menuPreview = '/menu-preview';
  static const String createSharedShopping = '/create-shared-shopping';
  static const String friendProfile = '/friend-profile';
  static const String publicProfile = '/public-profile';
  static const String sharedShoppingLists = '/shared-shopping-lists';
  static const String groupDetail = '/group-detail';

  // Messaging routes
  static const String messages = '/messages';
  static const String chat = '/chat';

  // Cooking mode
  static const String cookingMode = '/cooking-mode';

  // Ingredient search
  static const String ingredientSearch = '/ingredient-search';

  // Notifications
  static const String notifications = '/notifications';

  // Settings routes
  static const String settings = '/settings';
  static const String settingsFamily = '/settings/family';
  static const String settingsMenuTaste = '/settings/menu-taste';
  static const String settingsAllergens = '/settings/allergens';
  static const String settingsPersonalTags = '/settings/personal-tags';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsAccountSecurity = '/settings/account-security';
  static const String collectionStats = '/settings/collection-stats';
  static const String moderatorReview = '/admin/moderation';
  static const String myReports = '/settings/my-reports';

  // Legal routes
  static const String termsOfService = '/legal/terms';
  static const String privacyPolicy = '/legal/privacy';
  static const String communityGuidelines = '/legal/community-guidelines';

  // Help routes
  static const String faq = '/faq';

  // Route aliases
  static const Map<String, String> aliases = {
    '/home': home, // Explicit hem-alias
    '/shopping': shoppingList, // Alias for unified shopping
  };

  /// Routes requiring authentication
  static const Set<String> authenticatedRoutes = {
    addRecipe,
    importViaUrl,
    photoImport,
    quickCapture,
    manualEntry,
    fromSocialMedia,
    importFromArchive,
    smartImport,
    fileImport,
    recipeDetail,
    editRecipe,
    receiveShare,
    weeklyMenu,
    realtimeMenu,
    shoppingList,
    ingredientSearch,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    publicProfile,
    sharedShoppingLists,
    groupDetail,
    messages,
    chat,
    cookingMode,
    notifications,
    settings,
    settingsFamily,
    settingsMenuTaste,
    settingsAllergens,
    settingsPersonalTags,
    settingsNotifications,
    settingsAccountSecurity,
    collectionStats,
    faq,
  };

  /// Routes using slide-from-bottom animation
  static const Set<String> bottomSlideRoutes = {
    importViaUrl,
    photoImport,
    quickCapture,
    manualEntry,
    fromSocialMedia,
    importFromArchive,
    smartImport,
    fileImport,
    receiveShare,
  };

  /// Routes using slide-from-right animation
  static const Set<String> rightSlideRoutes = {
    termsOfService,
    privacyPolicy,
    communityGuidelines,
    shoppingList,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    publicProfile,
    sharedShoppingLists,
    groupDetail,
    messages,
    chat,
    cookingMode,
    ingredientSearch,
    notifications,
    settings,
    settingsFamily,
    settingsMenuTaste,
    settingsAllergens,
    settingsPersonalTags,
    settingsNotifications,
    settingsAccountSecurity,
    collectionStats,
    moderatorReview,
    faq,
  };

  /// Routes using fade animation
  static const Set<String> fadeRoutes = {
    home,
    auth,
    onboarding,
  };

  /// Resolves route alias to main route
  static String resolveRoute(String route) {
    return aliases[route] ?? route;
  }

  /// Checks if route is valid
  static bool isValidRoute(String route) {
    final resolvedRoute = resolveRoute(route);
    return allRoutes.contains(resolvedRoute);
  }

  /// Checks if route requires authentication
  static bool requiresAuth(String route) {
    final resolvedRoute = resolveRoute(route);
    return authenticatedRoutes.contains(resolvedRoute);
  }

  /// Gets animation type for route
  static RouteAnimationType getAnimationType(String route) {
    final resolvedRoute = resolveRoute(route);

    if (fadeRoutes.contains(resolvedRoute)) {
      return RouteAnimationType.fade;
    } else if (bottomSlideRoutes.contains(resolvedRoute)) {
      return RouteAnimationType.slideFromBottom;
    } else if (rightSlideRoutes.contains(resolvedRoute)) {
      return RouteAnimationType.slideFromRight;
    } else {
      return RouteAnimationType.slideFromRight;
    }
  }

  /// All valid routes
  static const Set<String> allRoutes = {
    // Base routes
    home,
    auth,
    onboarding,

    // Recipe management
    addRecipe,
    importViaUrl,
    photoImport,
    quickCapture,
    manualEntry,
    fromSocialMedia,
    importFromArchive,
    smartImport,
    fileImport,
    recipeDetail,
    editRecipe,
    receiveShare,

    // Menu & Shopping
    weeklyMenu,
    realtimeMenu,
    shoppingList,

    // Cooking
    cookingMode,

    // Ingredient search
    ingredientSearch,

    // Notifications
    notifications,

    // Social features
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    publicProfile,
    sharedShoppingLists,
    groupDetail,

    // Messaging
    messages,
    chat,

    // Settings
    settings,
    settingsFamily,
    settingsMenuTaste,
    settingsAllergens,
    settingsPersonalTags,
    settingsNotifications,
    settingsAccountSecurity,
    collectionStats,
    moderatorReview,

    // Legal
    termsOfService,
    privacyPolicy,
    communityGuidelines,

    // Help
    faq,
  };

  /// All routes including aliases
  static Set<String> get allRoutesWithAliases {
    return {...allRoutes, ...aliases.keys};
  }

  /// Debug route list for development
  static String debugRouteList() {
    final buffer = StringBuffer();
    buffer.writeln('=== BUTLERY ROUTES (UNIFIED) ===');

    buffer.writeln('\nBASE ROUTES:');
    buffer.writeln('  $home');
    buffer.writeln('  $auth');

    buffer.writeln('\nRECIPE ROUTES:');
    for (final route in [
      addRecipe,
      importViaUrl,
      photoImport,
      quickCapture,
      manualEntry,
      fromSocialMedia,
      importFromArchive,
      recipeDetail,
      editRecipe,
      receiveShare,
    ]) {
      buffer.writeln('  $route');
    }

    buffer.writeln('\nSHOPPING ROUTES:');
    buffer.writeln('  $weeklyMenu');
    buffer.writeln('  $shoppingList');

    buffer.writeln('\nSOCIAL ROUTES:');
    for (final route in [
      profileEdit,
      friends,
      friendRequests,
      shared,
      collaborativeShopping,
      menuPreview,
      createSharedShopping,
      friendProfile,
      sharedShoppingLists,
    ]) {
      buffer.writeln('  $route');
    }

    buffer.writeln('\nALIASES:');
    aliases.forEach((alias, target) {
      buffer.writeln('  $alias -> $target');
    });

    return buffer.toString();
  }

  /// Validates routes from main.dart are defined
  static List<String> findMissingRoutes(List<String> routesFromMainDart) {
    final missing = <String>[];
    for (final route in routesFromMainDart) {
      if (!isValidRoute(route)) {
        missing.add(route);
      }
    }
    return missing;
  }
}

/// Animation types for routes
enum RouteAnimationType {
  fade,
  slideFromBottom,
  slideFromRight,
  scale,
}
