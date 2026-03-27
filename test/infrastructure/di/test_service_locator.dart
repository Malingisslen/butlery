/// Test Service Locator matching production DI patterns
///
/// This service locator mimics the production ServiceLocator.get() pattern
/// while providing test-specific mock registration and management.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../factories/mock_factory.dart';
import '../mocks/production_mocks.dart';
import '../mocks/service_mocks.dart';
import '../mocks/fallback_values.dart';
import '../mocks/firestore_singleton.dart';

// Repository interfaces
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';

// Service interfaces
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';

// ViewModel imports
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';

// Service imports for Phase 4
// (ActivityService removed - dead code)

// View testing specific imports (mock_view_models.dart not wired up)

// Core interfaces - production ServiceLocator integration removed for E2E simplification

/// Test service locator that matches production patterns
///
/// Usage:
/// ```dart
/// final authService = ServiceLocator.get<AuthService>();
/// ```
class ServiceLocator {
  /// GetIt instance for dependency injection
  static final GetIt _getIt = GetIt.instance;

  /// Whether the service locator has been initialized
  static bool _initialized = false;

  /// Get a service matching production pattern
  ///
  /// This matches the production pattern:
  /// `ServiceLocator.get<T>()`
  static T get<T extends Object>() {
    if (!_initialized) {
      throw StateError(
        'TestServiceLocator not initialized. Call TestServiceLocator.initialize() first.',
      );
    }
    return _getIt.get<T>();
  }

  /// Check if a service is registered
  static bool isRegistered<T extends Object>() {
    return _initialized && _getIt.isRegistered<T>();
  }
}

/// Test service locator initialization and management
class TestServiceLocator {
  /// Private constructor to prevent instantiation
  TestServiceLocator._();

  /// Initialize the test service locator with mocks
  static Future<void> initialize() async {
    if (ServiceLocator._initialized) {
      await reset();
    }

    // Register all fallback values for Mocktail's any() matcher
    registerAllFallbackValues();

    // Register all mocks matching production services
    await _registerRepositories();
    await _registerServices();
    await _registerViewModels();
    await _registerUtilities();

    ServiceLocator._initialized = true;

    // Skip production ServiceLocator initialization for E2E tests to avoid circular dependencies
    if (kDebugMode) {
      debugPrint(
          '✅ TestServiceLocator initialized - skipping production ServiceLocator for E2E testing');
    }
  }

  /// Clear state without resetting registrations
  static Future<void> clearState() async {
    // Clear Firestore data aggressively
    await FirestoreSingleton.clearData();

    // Reset mock states if they have state
    try {
      // Get all registered mocks and reset their states
      if (ServiceLocator._getIt.isRegistered<AuthRepository>()) {
        final authRepo = ServiceLocator._getIt.get<AuthRepository>();
        if (authRepo is MockAuthRepository) {
          authRepo.setAuthState(userId: null, user: null);
        }
      }
    } catch (e) {
      // Services might not be registered, continue
      debugPrint('Error clearing state: $e');
    }
  }

  /// Complete reset of service locator with aggressive cleanup
  static Future<void> reset() async {
    // Reset GetIt instance completely
    if (ServiceLocator._initialized) {
      try {
        // First clear all states
        await clearState();

        // Unregister all services explicitly
        await _unregisterAll();

        // Reset GetIt with dispose flag
        await ServiceLocator._getIt.reset(dispose: true);
        ServiceLocator._initialized = false;

        // Small delay for garbage collection
        await Future.delayed(Duration(milliseconds: 5));
      } catch (e) {
        debugPrint('Error during service locator reset: $e');
        // Force reset on error by creating new instance
        try {
          await ServiceLocator._getIt.reset(dispose: true);
        } catch (_) {
          // Ignore secondary error
        }
        ServiceLocator._initialized = false;
      }
    }

    // Production ServiceLocator integration removed for E2E testing simplification

    // Force Firestore hard reset
    await FirestoreSingleton.hardReset();
  }

  /// Unregister all services explicitly
  static Future<void> _unregisterAll() async {
    final getIt = ServiceLocator._getIt;

    // Get all registered types - comprehensive list
    final repositoryTypes = <Type>[
      AuthRepository,
      RecipeRepository,
      UserRepository,
      ShoppingRepository,
      FirestoreRepository,
      CommentsRepository,
      RatingsRepository,
      NotificationsRepository,
      MessagingRepository,
      FriendsRepository,
      AnalyticsRepository,
      CollaborativeRecipeRepository,
    ];

    final serviceTypes = <Type>[
      AuthService,
      UserService,
      PermissionService,
      AnalyticsService,
      ConnectivityMonitoringService,
      StorageService,
      ImagePickerService,
    ];

    // Unregister repositories
    for (final type in repositoryTypes) {
      try {
        if (getIt.isRegistered(instance: type)) {
          await getIt.unregister(instance: type);
        }
      } catch (e) {
        // Type might not be registered, continue
      }
    }

    // Unregister services
    for (final type in serviceTypes) {
      try {
        if (getIt.isRegistered(instance: type)) {
          await getIt.unregister(instance: type);
        }
      } catch (e) {
        // Type might not be registered, continue
      }
    }

    // Also try to unregister any remaining registrations
    try {
      // This will unregister anything we might have missed
      final allFactories = getIt.getAll<Object>();
      for (final _ in allFactories) {
        // Just iterate to clear references
      }
    } catch (e) {
      // Ignore errors here
    }
  }

  /// Register a custom mock (for test-specific overrides)
  static void registerMock<T extends Object>(T mock) {
    if (ServiceLocator._getIt.isRegistered<T>()) {
      ServiceLocator._getIt.unregister<T>();
    }
    ServiceLocator._getIt.registerSingleton<T>(mock);
  }

  /// Register a factory mock
  static void registerFactory<T extends Object>(T Function() factory) {
    if (ServiceLocator._getIt.isRegistered<T>()) {
      ServiceLocator._getIt.unregister<T>();
    }
    ServiceLocator._getIt.registerFactory<T>(factory);
  }

  /// Register a singleton mock (alias for registerMock)
  static void registerSingleton<T extends Object>(T mock) {
    registerMock<T>(mock);
  }

  /// Get a service from the service locator
  static T get<T extends Object>() {
    return ServiceLocator.get<T>();
  }

  /// Check if a service is registered
  static bool isRegistered<T extends Object>() {
    return ServiceLocator.isRegistered<T>();
  }

  /// Register all repository mocks
  static Future<void> _registerRepositories() async {
    final getIt = ServiceLocator._getIt;

    // Auth Repository
    getIt.registerSingleton<AuthRepository>(
      MockFactory.createAuthRepository(isAuthenticated: false),
    );

    // Recipe Repository
    getIt.registerSingleton<RecipeRepository>(
      MockFactory.createRecipeRepository(),
    );

    // User Repository
    getIt.registerSingleton<UserRepository>(
      MockFactory.createUserRepository(),
    );

    // Shopping Repository
    getIt.registerSingleton<ShoppingRepository>(
      MockFactory.createShoppingRepository(),
    );

    // Firestore Repository
    getIt.registerSingleton<FirestoreRepository>(
      MockFactory.createFirestoreRepository(),
    );

    // Comments Repository
    getIt.registerSingleton<CommentsRepository>(
      MockFactory.createCommentsRepository(),
    );

    // Ratings Repository
    getIt.registerSingleton<RatingsRepository>(
      MockFactory.createRatingsRepository(),
    );

    // Notifications Repository
    getIt.registerSingleton<NotificationsRepository>(
      MockFactory.createNotificationsRepository(),
    );

    // Messages Repository
    getIt.registerSingleton<MessagingRepository>(
      MockFactory.createMessagesRepository(),
    );

    // Friends Repository
    getIt.registerSingleton<FriendsRepository>(
      MockFactory.createFriendsRepository(),
    );

    // Groups Repository (no interface exists, register as concrete type)
    getIt.registerSingleton(
      MockFactory.createGroupsRepository(),
    );

    // Analytics Repository
    getIt.registerSingleton<AnalyticsRepository>(
      MockFactory.createAnalyticsRepository(),
    );

    // Collaborative Recipe Repository
    getIt.registerSingleton<CollaborativeRecipeRepository>(
      MockFactory.createCollaborativeRecipeRepository(),
    );
  }

  /// Register all service mocks
  static Future<void> _registerServices() async {
    final getIt = ServiceLocator._getIt;

    // Auth Service
    getIt.registerSingleton<AuthService>(
      MockFactory.createAuthService(isAuthenticated: false),
    );

    // User Service
    getIt.registerSingleton<UserService>(
      MockFactory.createUserService(),
    );

    // Permission Service
    getIt.registerSingleton<PermissionService>(
      MockFactory.createPermissionService(),
    );

    // Unified Recipe Service
    getIt.registerSingleton<UnifiedRecipeService>(
      MockFactory.createUnifiedRecipeService(),
    );

    // Unified Shopping Service
    getIt.registerSingleton<UnifiedShoppingService>(
      MockFactory.createUnifiedShoppingService(),
    );

    // Unified Friends Service
    getIt.registerSingleton<UnifiedFriendsService>(
      MockFactory.createUnifiedFriendsService(),
    );

    // Messaging Service
    getIt.registerSingleton(
      MockFactory.createMessagingService(),
    );

    // Notification Service
    getIt.registerSingleton(
      MockFactory.createNotificationService(),
    );

    // Menu Service
    getIt.registerSingleton(
      MockFactory.createMenuService(),
    );

    // Import Manager
    getIt.registerSingleton(
      MockFactory.createImportManager(),
    );

    // Search Service
    getIt.registerSingleton(
      MockFactory.createSearchService(),
    );

    // Recipe Discovery Service
    getIt.registerSingleton(
      MockFactory.createRecipeDiscoveryService(),
    );

    // Analytics Service
    getIt.registerSingleton<AnalyticsService>(
      MockFactory.createAnalyticsService(),
    );

    // Storage Service
    getIt.registerSingleton<StorageService>(
      MockFactory.createStorageService(),
    );

    // Image Picker Service
    getIt.registerSingleton<ImagePickerService>(
      MockFactory.createImagePickerService(),
    );

    // Dialog Service
    getIt.registerSingleton(
      MockFactory.createDialogService(),
    );

    // Connectivity Service
    getIt.registerSingleton(
      MockFactory.createConnectivityService(),
    );

    // Connectivity Monitoring Service
    getIt.registerSingleton<ConnectivityMonitoringService>(
      MockFactory.createConnectivityMonitoringService(),
    );

    // Social Menu Operations (needed by MenuViewModel)
    getIt.registerSingleton<SocialMenuOperations>(
      MockSocialMenuOperations(),
    );
  }

  /// Register all ViewModel mocks
  static Future<void> _registerViewModels() async {
    final getIt = ServiceLocator._getIt;

    // Auth ViewModel
    getIt.registerFactory(
      () => MockFactory.createAuthViewModel(),
    );

    // Recipe Form ViewModel
    getIt.registerFactory(
      () => MockFactory.createRecipeFormViewModel(),
    );

    // Recipe List ViewModel
    getIt.registerFactory(
      () => MockFactory.createRecipeListViewModel(),
    );

    // Shopping ViewModel
    getIt.registerFactory<MockShoppingViewModel>(
      () => MockFactory.createShoppingViewModel(),
    );

    // Menu ViewModel
    getIt.registerFactory(
      () => MockFactory.createMenuViewModel(),
    );

    // Friends ViewModel
    getIt.registerFactory(
      () => MockFactory.createFriendsViewModel(),
    );

    // Profile ViewModel
    getIt.registerFactory(
      () => MockFactory.createProfileViewModel(),
    );

    // Settings ViewModel
    getIt.registerFactory(
      () => MockFactory.createSettingsViewModel(),
    );

    // URL Import ViewModel
    getIt.registerFactory<UrlImportViewModel>(
      () => MockFactory.createUrlImportViewModel(),
    );

    // Photo Import ViewModel
    getIt.registerFactory<PhotoImportViewModel>(
      () => MockFactory.createPhotoImportViewModel(),
    );

    // Shared Content Coordinator ViewModel
    getIt.registerFactory<SharedContentCoordinatorViewModel>(
      () => MockFactory.createSharedContentCoordinatorViewModel(),
    );

    // Activity Service removed - dead code
  }

  /// Register utility services
  static Future<void> _registerUtilities() async {
    final getIt = ServiceLocator._getIt;

    // Logger
    getIt.registerSingleton(
      MockFactory.createLogger(),
    );

    // Error Handler
    getIt.registerSingleton(
      MockFactory.createErrorHandler(),
    );

    // Cache Manager
    getIt.registerSingleton(
      MockFactory.createCacheManager(),
    );

    // Network Manager
    getIt.registerSingleton(
      MockFactory.createNetworkManager(),
    );
  }

  /// Configure for specific test scenarios
  static void configureForScenario(TestScenario scenario) {
    switch (scenario) {
      case TestScenario.authenticated:
        _configureAuthenticated();
        break;
      case TestScenario.unauthenticated:
        _configureUnauthenticated();
        break;
      case TestScenario.offline:
        _configureOffline();
        break;
      case TestScenario.error:
        _configureError();
        break;
      case TestScenario.collaborative:
        _configureCollaborative();
        break;
      case TestScenario.viewTesting:
        _configureViewTesting();
        break;
    }
  }

  // ==================== VIEW TESTING SPECIFIC CONFIGURATION ====================

  /// Configure for view testing with enhanced mock capabilities
  static void _configureViewTesting() {
    // ViewModel registrations not yet wired (mock_view_models.dart)
  }

  /// Configure for collaborative view testing scenarios
  static void _configureCollaborative() {
    _configureAuthenticated(); // Base authenticated state
    // Collaborative ViewModel registrations not yet wired (mock_view_models.dart)
  }

  /// Register view-specific mock services
  static Future<void> registerViewTestingServices() async {
    final getIt = ServiceLocator._getIt;

    // Register mock collaborative status service
    getIt.registerSingleton<MockCollaborativeStatusService>(
      MockCollaborativeStatusService(),
    );

    // Register mock view navigation service
    getIt.registerSingleton<MockViewNavigationService>(
      MockViewNavigationService(),
    );

    // Register Swedish localization service
    getIt.registerSingleton<MockSwedishLocalizationService>(
      MockSwedishLocalizationService(),
    );
  }

  /// Quick setup for specific view types
  static Future<void> configureForViewType(ViewType viewType) async {
    switch (viewType) {
      case ViewType.authentication:
        configureForScenario(TestScenario.unauthenticated);
        break;
      case ViewType.recipeEdit:
        configureForScenario(TestScenario.authenticated);
        _configureViewTesting();
        break;
      case ViewType.collaborativeRecipeEdit:
        configureForScenario(TestScenario.collaborative);
        break;
      case ViewType.shopping:
        configureForScenario(TestScenario.authenticated);
        _configureViewTesting();
        break;
      case ViewType.social:
        configureForScenario(TestScenario.authenticated);
        _configureViewTesting();
        break;
      case ViewType.messaging:
        configureForScenario(TestScenario.authenticated);
        _configureViewTesting();
        break;
    }

    await registerViewTestingServices();
  }

  /// Configure for authenticated user scenario
  static void _configureAuthenticated() {
    final authService = MockFactory.createAuthService(
      isAuthenticated: true,
      userId: 'test_user_123',
    );
    registerMock(authService);

    final userService = MockFactory.createUserService();
    registerMock(userService);
  }

  /// Configure for unauthenticated scenario
  static void _configureUnauthenticated() {
    final authService = MockFactory.createAuthService(
      isAuthenticated: false,
    );
    registerMock(authService);
  }

  /// Configure for offline scenario
  static void _configureOffline() {
    final connectivityService = MockFactory.createConnectivityService();
    registerMock(connectivityService);
  }

  /// Configure for error scenario
  static void _configureError() {
    // Configure services to throw errors for testing error handling
  }
}

/// Test scenarios for quick configuration
enum TestScenario {
  authenticated,
  unauthenticated,
  offline,
  error,
  collaborative,
  viewTesting,
}

/// View types for specialized configuration
enum ViewType {
  authentication,
  recipeEdit,
  collaborativeRecipeEdit,
  shopping,
  social,
  messaging,
}

/// Extension to make test context aware of service locator
extension TestServiceLocatorContext on Object {
  /// Get a service from the test container
  T getService<T extends Object>() => ServiceLocator.get<T>();

  /// Check if a service is registered
  bool isServiceRegistered<T extends Object>() =>
      ServiceLocator.isRegistered<T>();
}

// ==================== VIEW TESTING MOCK SERVICES ====================

/// Mock collaborative status service for view testing.
class MockCollaborativeStatusService {
  bool _isCollaborative = false;
  bool _hasConflicts = false;
  List<String> _activeCollaborators = [];

  bool get isCollaborative => _isCollaborative;
  bool get hasConflicts => _hasConflicts;
  List<String> get activeCollaborators => List.from(_activeCollaborators);

  void setCollaborativeState({
    bool? isCollaborative,
    bool? hasConflicts,
    List<String>? collaborators,
  }) {
    if (isCollaborative != null) _isCollaborative = isCollaborative;
    if (hasConflicts != null) _hasConflicts = hasConflicts;
    if (collaborators != null) _activeCollaborators = collaborators;
  }

  Future<void> resolveConflict() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _hasConflicts = false;
  }
}

/// Mock view navigation service for testing navigation in views.
class MockViewNavigationService {
  final List<String> _navigationHistory = [];
  String? _currentRoute;

  List<String> get navigationHistory => List.from(_navigationHistory);
  String? get currentRoute => _currentRoute;

  Future<void> navigateTo(String route,
      {Map<String, dynamic>? arguments}) async {
    _navigationHistory.add(route);
    _currentRoute = route;
  }

  Future<void> goBack() async {
    if (_navigationHistory.isNotEmpty) {
      _navigationHistory.removeLast();
      _currentRoute =
          _navigationHistory.isNotEmpty ? _navigationHistory.last : null;
    }
  }

  void clearHistory() {
    _navigationHistory.clear();
    _currentRoute = null;
  }
}

/// Mock Swedish localization service for testing Swedish UI.
class MockSwedishLocalizationService {
  final Map<String, String> _swedishTranslations = {
    'login': 'Logga in',
    'register': 'Registrera',
    'email': 'E-post',
    'password': 'Lösenord',
    'save': 'Spara',
    'cancel': 'Avbryt',
    'error': 'Fel',
    'loading': 'Laddar',
    'recipe': 'Recept',
    'ingredients': 'Ingredienser',
    'instructions': 'Instruktioner',
    'portions': 'Portioner',
    'shopping_list': 'Inköpslista',
    'add_item': 'Lägg till vara',
    'friends': 'Vänner',
    'share': 'Dela',
  };

  String translate(String key) {
    return _swedishTranslations[key] ?? key;
  }

  String get currentLocale => 'sv_SE';

  bool get isSwedish => true;

  void addTranslation(String key, String translation) {
    _swedishTranslations[key] = translation;
  }
}
