/// Comprehensive route management system providing unified navigation constants for the Butlery cooking application.
///
/// This route management system implements a sophisticated navigation architecture that organizes all application
/// routes with clear categorization, authentication requirements, animation types, and Swedish-friendly naming
/// conventions. It provides a centralized navigation structure that supports the cooking application's complex
/// workflow requirements while maintaining consistent user experience patterns throughout the Swedish cooking interface.
///
/// **Architecture Integration:**
/// - Provides centralized route definitions eliminating scattered navigation strings throughout codebase
/// - Integrates with authentication system to enforce access control on protected routes
/// - Supports animation system with route-specific transition types for enhanced user experience
/// - Enables route aliasing for backward compatibility and user-friendly URL structures
/// - Implements comprehensive route validation preventing navigation errors and broken links
///
/// **Route Categories:**
/// - **Base Routes**: Fundamental application entry points (home, authentication)
/// - **Recipe Routes**: Complete recipe management workflow including creation, editing, and import methods
/// - **Menu & Shopping Routes**: Weekly menu planning and unified shopping list management
/// - **Social Routes**: Friend management, sharing, collaboration, and community features
/// - **Messaging Routes**: Real-time communication and conversation management
/// - **Route Aliases**: User-friendly alternative paths for common navigation patterns
///
/// **Navigation Features:**
/// The route system supports complex cooking application workflows with specialized paths for recipe import,
/// collaborative shopping, social sharing, and real-time messaging that reflect the natural flow of Swedish
/// cooking preparation and meal planning activities.
///
/// **Key Features:**
/// - Swedish-friendly route naming reflecting cooking terminology and cultural preferences
/// - Authentication-aware routing with automatic access control enforcement
/// - Animation type assignment for consistent and delightful navigation transitions
/// - Route validation system preventing broken navigation and error states
/// - Alias support enabling multiple paths to common destinations for improved usability
/// - Debug utilities providing comprehensive route analysis and validation tools
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to recipe creation
/// Navigator.pushNamed(context, Routes.laggTill);
/// 
/// // Check authentication requirements
/// if (Routes.requiresAuth(routeName)) {
///   // Redirect to authentication
///   Navigator.pushReplacementNamed(context, Routes.auth);
/// }
/// 
/// // Get appropriate animation for route
/// final animationType = Routes.getAnimationType(Routes.receptDetalj);
/// 
/// // Validate route before navigation
/// if (Routes.isValidRoute(userProvidedRoute)) {
///   Navigator.pushNamed(context, userProvidedRoute);
/// }
/// 
/// // Use aliases for user-friendly URLs
/// Navigator.pushNamed(context, '/shopping'); // Resolves to Routes.inkopslista
/// ```

/// Comprehensive route management system implementing unified navigation constants for cooking-focused user interface design.
///
/// This class serves as the authoritative source for all navigation routes throughout the Butlery application,
/// providing organized route categorization, authentication integration, animation type management, and
/// validation utilities. It ensures consistent navigation patterns while supporting the complex workflow
/// requirements of Swedish cooking applications with appropriate terminology and user experience considerations.
///
/// **Route Architecture:**
/// - **Centralized Definition**: Single source of truth for all navigation paths preventing route duplication
/// - **Category Organization**: Logical grouping of routes by application domain and functionality
/// - **Authentication Integration**: Automatic access control enforcement based on route requirements
/// - **Animation Management**: Route-specific transition types for enhanced navigation experience
/// - **Validation Framework**: Comprehensive route validation and error prevention mechanisms
///
/// **Design Principles:**
/// The route system reflects the logical flow of cooking activities with intuitive navigation paths,
/// Swedish terminology that feels natural to users, and organized structure that supports complex
/// cooking workflows while maintaining simplicity and clarity in navigation patterns.
class Routes {
  // ===== BASE ROUTES =====
  
  /// Home route - primary application entry point displaying user's main recipe collection
  static const String home = '/';
  
  /// Authentication route - user login and registration interface
  static const String auth = '/auth';

  // ===== RECIPE ROUTES =====
  
  /// Add recipe route - main recipe creation interface with import method selection
  static const String laggTill = '/laggTill';
  
  /// URL import route - recipe import from web URLs with intelligent parsing
  static const String importViaUrl = '/importViaUrl';
  
  /// Photo import route - OCR-based recipe extraction from images
  static const String photoImport = '/photoImport';
  
  /// Manual recipe creation route - free-form recipe writing interface
  static const String skrivSjalv = '/skrivSjalv';
  
  /// Social media import route - recipe extraction from social media posts
  static const String franSocialaMedier = '/franSocialaMedier';
  
  /// Archive import route - recipe selection from community archive
  static const String importFranArkiv = '/importFranArkiv';
  
  /// Recipe detail route - comprehensive recipe display with social features
  static const String receptDetalj = '/receptDetalj';
  
  /// Recipe editing route - full recipe modification interface
  static const String redigeraRecept = '/redigeraRecept';
  
  /// Shared recipe reception route - interface for receiving shared recipes
  static const String receiveShare = '/receiveShare';

  // ===== MENU & SHOPPING ROUTES =====
  
  /// Weekly menu route - comprehensive meal planning and menu generation interface
  static const String veckomeny = '/veckomeny';
  
  /// Unified shopping list route - comprehensive shopping list management with collaboration
  static const String inkopslista = '/inkopslista'; // ✅ UNIFIED SHOPPING SYSTEM

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

  // ===== MESSAGING ROUTES =====
  static const String messages = '/messages';
  static const String chat = '/chat';

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
    messages,
    chat,
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
    messages,
    chat,
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

    // Messaging
    messages,
    chat,
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
