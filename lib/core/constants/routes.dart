// lib/core/constants/routes.dart

/// Centraliserade route-konstanter för Butlery
/// Baserat på faktiska rutter från main.dart
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
  static const String inkopslista = '/inkopslista';

  // ===== SOCIAL ROUTES (befintliga) =====
  static const String profileEdit = '/profile/edit';
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String shared = '/shared';
  static const String collaborativeShopping = '/collaborative-shopping';
  static const String menuPreview = '/menu-preview';
  static const String createSharedShopping = '/create-shared-shopping';
  static const String sharedShoppingLists = '/shared-shopping-lists';

  // ===== NYA ROUTES (som vi behöver lägga till) =====
  static const String friendProfile = '/friend-profile';

  // ===== UTILITY METHODS =====

  /// Kontrollera om route finns i main.dart
  static bool isValidRoute(String route) {
    const existingRoutes = {
      home,
      auth,
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
      sharedShoppingLists,
    };
    return existingRoutes.contains(route);
  }

  /// Nya routes som behöver läggas till i main.dart
  static const Set<String> newRoutes = {
    friendProfile,
  };

  /// Alla routes som ska finnas
  static const Set<String> allRoutes = {
    // Befintliga från main.dart
    home,
    auth,
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
    sharedShoppingLists,
    // Nya som behöver läggas till
    friendProfile,
  };
}
