/// Test Service Locator matching production DI patterns
/// 
/// This service locator mimics the production ServiceLocator.get() pattern
/// while providing test-specific mock registration and management.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../factories/mock_factory.dart';
import '../mocks/production_mocks.dart';
import '../mocks/fallback_values.dart';

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
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';

// Service interfaces
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';

// Core interfaces
import 'package:butlery/core/providers/application_provider.dart' as prod;

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
  
  /// Tracks if production ServiceLocator was initialized for cleanup
  static bool _productionInitialized = false;
  
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
    
    // Also initialize production ServiceLocator if needed
    await _initializeProductionServiceLocator();
  }
  
  /// Initialize production ServiceLocator with test mocks
  /// This prevents tests from needing to directly manipulate prod.ServiceLocator
  static Future<void> _initializeProductionServiceLocator() async {
    try {
      // Reset production ServiceLocator first if needed
      prod.ServiceLocator.reset();
      
      // Initialize with mock DIContainer for tests that need it
      // This is specifically for ViewModels that use production ServiceLocator
      prod.ServiceLocator.initialize(MockDIContainer());
      _productionInitialized = true;
    } catch (e) {
      // Production ServiceLocator might not be needed for this test
      // This is expected for tests that don't use ViewModels
    }
  }
  
  /// Clear state without resetting registrations
  static Future<void> clearState() async {
    // This would clear any stateful mocks without unregistering them
    // Useful for test isolation without the overhead of re-registration
  }
  
  /// Complete reset of service locator
  static Future<void> reset() async {
    if (ServiceLocator._initialized) {
      await ServiceLocator._getIt.reset();
      ServiceLocator._initialized = false;
    }
    
    // Also reset production ServiceLocator if it was initialized
    if (_productionInitialized) {
      try {
        _resetProductionServiceLocator();
      } catch (e) {
        debugPrint('Production ServiceLocator reset skipped: $e');
      }
      _productionInitialized = false;
    }
  }
  
  /// Reset production ServiceLocator
  static void _resetProductionServiceLocator() {
    // Reset the production ServiceLocator
    prod.ServiceLocator.reset();
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
    
    // Social Recipe Repository
    getIt.registerSingleton<SocialRecipeRepository>(
      MockFactory.createSocialRecipeRepository(),
    );
    
    // Analytics Repository
    getIt.registerSingleton<AnalyticsRepository>(
      MockFactory.createAnalyticsRepository(),
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
    getIt.registerSingleton(
      MockFactory.createUnifiedRecipeService(),
    );
    
    // Unified Shopping Service
    getIt.registerSingleton(
      MockFactory.createUnifiedShoppingService(),
    );
    
    // Unified Friends Service
    getIt.registerSingleton(
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
    getIt.registerSingleton(
      MockFactory.createAnalyticsService(),
    );
    
    // Storage Service
    getIt.registerSingleton(
      MockFactory.createStorageService(),
    );
    
    // Dialog Service
    getIt.registerSingleton(
      MockFactory.createDialogService(),
    );
    
    // Connectivity Service
    getIt.registerSingleton(
      MockFactory.createConnectivityService(),
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
    getIt.registerFactory(
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
    }
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
}

/// Extension to make test context aware of service locator
extension TestServiceLocatorContext on Object {
  /// Get a service from the test container
  T getService<T extends Object>() => ServiceLocator.get<T>();
  
  /// Check if a service is registered
  bool isServiceRegistered<T extends Object>() => ServiceLocator.isRegistered<T>();
}