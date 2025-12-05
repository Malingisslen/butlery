/// Route management system for unified navigation constants.

/// Central source for all navigation routes in the Butlery application.
class Routes {
  /// Home route
  static const String home = '/';
  
  /// Authentication route
  static const String auth = '/auth';

  /// Add recipe route
  static const String laggTill = '/laggTill';
  
  /// URL import route
  static const String importViaUrl = '/importViaUrl';
  
  /// Photo import route
  static const String photoImport = '/photoImport';
  
  /// Manual recipe creation route
  static const String skrivSjalv = '/skrivSjalv';
  
  /// Social media import route
  static const String franSocialaMedier = '/franSocialaMedier';
  
  /// Archive import route
  static const String importFranArkiv = '/importFranArkiv';
  
  /// File import route (CSV/Excel)
  static const String fileImport = '/fileImport';
  
  /// Recipe detail route
  static const String receptDetalj = '/receptDetalj';
  
  /// Recipe editing route
  static const String redigeraRecept = '/redigeraRecept';
  
  /// Shared recipe reception route
  static const String receiveShare = '/receiveShare';

  /// Weekly menu route
  static const String veckomeny = '/veckomeny';

  /// Collaborative realtime menu route
  static const String realtimeMenu = '/realtime-menu';

  /// Unified shopping list route
  static const String inkopslista = '/inkopslista';

  // Social routes
  static const String discovery = '/discovery';
  static const String profileEdit = '/profile/edit';
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String shared = '/shared';
  static const String collaborativeShopping = '/collaborative-shopping';
  static const String menuPreview = '/menu-preview';
  static const String createSharedShopping = '/create-shared-shopping';
  static const String friendProfile = '/friend-profile';
  static const String sharedShoppingLists = '/shared-shopping-lists';

  // Messaging routes
  static const String messages = '/messages';
  static const String chat = '/chat';

  // Route aliases
  static const Map<String, String> aliases = {
    '/home': home, // Explicit hem-alias
    '/shopping': inkopslista, // Alias för unified shopping
  };

  /// Routes requiring authentication
  static const Set<String> authenticatedRoutes = {
    laggTill,
    importViaUrl,
    photoImport,
    skrivSjalv,
    franSocialaMedier,
    importFranArkiv,
    receptDetalj,
    redigeraRecept,
    receiveShare,
    veckomeny,
    realtimeMenu,
    inkopslista,
    discovery,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,
    messages,
    chat,
  };

  /// Routes using slide-from-bottom animation
  static const Set<String> bottomSlideRoutes = {
    laggTill,
    importViaUrl,
    photoImport,
    skrivSjalv,
    franSocialaMedier,
    importFranArkiv,
    receiveShare,
  };

  /// Routes using slide-from-right animation
  static const Set<String> rightSlideRoutes = {
    inkopslista,
    discovery,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,
    messages,
    chat,
  };

  /// Routes using fade animation
  static const Set<String> fadeRoutes = {
    home,
    auth,
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

    // Recipe management
    laggTill,
    importViaUrl,
    photoImport,
    skrivSjalv,
    franSocialaMedier,
    importFranArkiv,
    receptDetalj,
    redigeraRecept,
    receiveShare,

    // Menu & Shopping
    veckomeny,
    realtimeMenu,
    inkopslista,

    // Social features
    discovery,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,

    // Messaging
    messages,
    chat,
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
      laggTill,
      importViaUrl,
      photoImport,
      skrivSjalv,
      franSocialaMedier,
      importFranArkiv,
      receptDetalj,
      redigeraRecept,
      receiveShare
    ]) {
      buffer.writeln('  $route');
    }

    buffer.writeln('\nSHOPPING ROUTES:');
    buffer.writeln('  $veckomeny');
    buffer.writeln('  $inkopslista');

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
      sharedShoppingLists
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
