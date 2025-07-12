// lib/core/constants/routes.dart

class Routes {
  // ===== BASE ROUTES =====
  static const String home = '/';
  static const String auth = '/auth';

  // ===== RECIPE ROUTES =====
  static const String laggTill = '/laggTill';
  static const String importViaUrl = '/importViaUrl';
  static const String photoImport = '/photoImport';
  static const String skrivSjalv = '/skrivSjalv';
  static const String franSocialaMedier = '/franSocialaMedier';
  static const String importFranArkiv = '/importFranArkiv';
  static const String receptDetalj = '/receptDetalj';
  static const String redigeraRecept = '/redigeraRecept';
  static const String receiveShare = '/receiveShare';

  // ===== MENU & SHOPPING ROUTES =====
  static const String veckomeny = '/veckomeny';
  static const String inkopslista = '/inkopslista'; // ✅ NYA UNIFIED SHOPPING

  // ===== SOCIAL ROUTES =====
  static const String profileEdit = '/profile/edit';
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String shared = '/shared';
  static const String collaborativeShopping = '/collaborative-shopping';
  static const String menuPreview = '/menu-preview';
  static const String createSharedShopping = '/create-shared-shopping';
  static const String friendProfile = '/friend-profile';
  static const String sharedShoppingLists = '/shared-shopping-lists';

  // ===== ROUTE ALIASES =====
  static const Map<String, String> aliases = {
    '/home': home, // Explicit hem-alias
    '/shopping': inkopslista, // Alias för unified shopping
  };

  // ===== ROUTE KATEGORIER =====
  /// Routes som kräver autentisering
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
    inkopslista,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,
  };

  /// Routes som använder slide-from-bottom animation
  static const Set<String> bottomSlideRoutes = {
    laggTill,
    importViaUrl,
    photoImport,
    skrivSjalv,
    franSocialaMedier,
    importFranArkiv,
    receiveShare,
  };

  /// Routes som använder slide-from-right animation
  static const Set<String> rightSlideRoutes = {
    inkopslista,
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,
  };

  /// Routes som använder fade animation
  static const Set<String> fadeRoutes = {
    home,
    auth,
  };

  // ===== UTILITY METHODS =====

  /// Löser upp route-alias till huvudroute
  static String resolveRoute(String route) {
    return aliases[route] ?? route;
  }

  /// Kontrollerar om en route är giltig (inklusive aliases)
  static bool isValidRoute(String route) {
    final resolvedRoute = resolveRoute(route);
    return allRoutes.contains(resolvedRoute);
  }

  /// Kontrollerar om route kräver autentisering
  static bool requiresAuth(String route) {
    final resolvedRoute = resolveRoute(route);
    return authenticatedRoutes.contains(resolvedRoute);
  }

  /// Får animation-typ för en route
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

  /// Alla giltiga routes (utan aliases)
  static const Set<String> allRoutes = {
    // Base
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

    // Menu & Shopping - ENDAST UNIFIED
    veckomeny,
    inkopslista, // ✅ UNIFIED SHOPPING

    // Social features
    profileEdit,
    friends,
    friendRequests,
    shared,
    collaborativeShopping,
    menuPreview,
    createSharedShopping,
    friendProfile,
    sharedShoppingLists,
  };

  /// Alla routes inklusive aliases (för debug-syfte)
  static Set<String> get allRoutesWithAliases {
    return {...allRoutes, ...aliases.keys};
  }

  // ===== DEBUG & DEVELOPMENT =====

  /// Visar alla routes i en läsbar format (för utveckling)
  static String debugRouteList() {
    final buffer = StringBuffer();
    buffer.writeln('=== BUTLERY ROUTES (UNIFIED) ===');

    buffer.writeln('\n📱 BASE ROUTES:');
    buffer.writeln('  $home');
    buffer.writeln('  $auth');

    buffer.writeln('\n🍳 RECIPE ROUTES:');
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

    buffer.writeln('\n🛒 SHOPPING ROUTES:');
    buffer.writeln('  $veckomeny');
    buffer.writeln('  $inkopslista ✅ (UNIFIED SHOPPING)');

    buffer.writeln('\n👥 SOCIAL ROUTES:');
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

    buffer.writeln('\n🔄 ALIASES:');
    aliases.forEach((alias, target) {
      buffer.writeln('  $alias -> $target');
    });

    return buffer.toString();
  }

  /// Validerar att alla routes från main.dart finns definierade
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

/// Enum för animation-typer (används av RouteAnimations)
enum RouteAnimationType {
  fade,
  slideFromBottom,
  slideFromRight,
  scale, // För error routes
}
