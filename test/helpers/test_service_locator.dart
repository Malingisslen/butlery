/// Comprehensive test service locator providing proper dependency injection for Flutter testing.
///
/// This module implements a complete test service locator system matching the application's
/// ServiceLocator pattern with proper mock implementations for all services and repositories.
/// It provides comprehensive test infrastructure for unit testing, widget testing, and integration
/// testing with proper isolation, setup, and teardown functionality for reliable test execution.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';

// Services
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

// Repositories
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

// ===== MOCK SERVICE IMPLEMENTATIONS =====

/// Mock UnifiedRecipeService for comprehensive recipe testing
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

/// Mock AuthService for authentication testing
class MockAuthService extends Mock implements AuthService {}

/// Mock MessagingService for chat and messaging testing
class MockMessagingService extends Mock implements MessagingService {}

/// Mock AnalyticsService for analytics testing
class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Mock UserService for user management testing
class MockUserService extends Mock implements UserService {}

/// Mock PermissionService for permission system testing
class MockPermissionService extends Mock implements PermissionService {}

/// Mock StorageService for file storage testing
class MockStorageService extends Mock implements StorageService {}

/// Mock UnifiedShoppingService for shopping list testing
class MockUnifiedShoppingService extends Mock
    implements UnifiedShoppingService {}

/// Mock UnifiedFriendsService for social features testing
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {}

// ===== MOCK REPOSITORY IMPLEMENTATIONS =====

/// Mock FirebaseAuthRepository for auth repository testing
class MockFirebaseAuthRepository extends Mock
    implements FirebaseAuthRepository {}

/// Mock FirebaseRecipeRepository for recipe repository testing
class MockFirebaseRecipeRepository extends Mock
    implements FirebaseRecipeRepository {}

/// Mock FirebaseMessagingRepository for messaging repository testing
class MockFirebaseMessagingRepository extends Mock
    implements FirebaseMessagingRepository {}

/// Mock FirebaseShoppingRepository for shopping repository testing
class MockFirebaseShoppingRepository extends Mock
    implements FirebaseShoppingRepository {}

/// Mock FirebaseUserRepository for user repository testing
class MockFirebaseUserRepository extends Mock
    implements FirebaseUserRepository {}

/// Mock FirebaseFriendsRepository for friends repository testing
class MockFirebaseFriendsRepository extends Mock
    implements FirebaseFriendsRepository {}

/// Mock CommentsRepository for comments testing
class MockCommentsRepository extends Mock implements CommentsRepository {}

/// Mock RatingsRepository for ratings testing
class MockRatingsRepository extends Mock implements RatingsRepository {}

/// Mock NotificationsRepository for notifications testing
class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

/// Mock FirestoreRepository for general Firestore operations
class MockFirestoreRepository extends Mock implements FirestoreRepository {}

/// Mock DIContainer for dependency injection testing
class MockDIContainer extends Mock implements DIContainer {}

/// Mock ApplicationBootstrap for testing
class MockApplicationBootstrap extends Mock implements ApplicationBootstrap {
  @override
  bool get isInitialized => true;
}

// ===== TEST SERVICE LOCATOR =====

/// Comprehensive test service locator providing complete mock infrastructure for testing.
///
/// This service locator provides proper mock implementations for all application services
/// and repositories, enabling comprehensive unit testing, widget testing, and integration
/// testing with proper isolation and predictable behavior for reliable test execution.
class TestServiceLocator {
  static MockDIContainer? _mockContainer;

  // Services
  static late MockUnifiedRecipeService mockRecipeService;
  static late MockAuthService mockAuthService;
  static late MockMessagingService mockMessagingService;
  static late MockAnalyticsService mockAnalyticsService;
  static late MockUserService mockUserService;
  static late MockPermissionService mockPermissionService;
  static late MockStorageService mockStorageService;
  static late MockUnifiedShoppingService mockShoppingService;
  static late MockUnifiedFriendsService mockFriendsService;

  // Repositories
  static late MockFirebaseAuthRepository mockAuthRepository;
  static late MockFirebaseRecipeRepository mockRecipeRepository;
  static late MockFirebaseMessagingRepository mockMessagingRepository;
  static late MockFirebaseShoppingRepository mockShoppingRepository;
  static late MockFirebaseUserRepository mockUserRepository;
  static late MockFirebaseFriendsRepository mockFriendsRepository;
  static late MockCommentsRepository mockCommentsRepository;
  static late MockRatingsRepository mockRatingsRepository;
  static late MockNotificationsRepository mockNotificationsRepository;
  static late MockFirestoreRepository mockFirestoreRepository;

  // Firebase mocks
  static late FakeFirebaseFirestore fakeFirestore;
  static late MockUser mockFirebaseUser;

  /// Initialize test service locator with comprehensive mock setup.
  ///
  /// Sets up all mock services and repositories with proper fallback values
  /// and default behaviors for reliable testing infrastructure.
  static void initialize() {
    // Initialize Hive for testing
    _initializeTestHive();
    // Initialize Firebase mocks
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseUser = MockUser(
      uid: 'test_user_123',
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: 'https://example.com/photo.jpg',
    );

    // Initialize service mocks
    mockRecipeService = MockUnifiedRecipeService();
    mockAuthService = MockAuthService();
    mockMessagingService = MockMessagingService();
    mockAnalyticsService = MockAnalyticsService();
    mockUserService = MockUserService();
    mockPermissionService = MockPermissionService();
    mockStorageService = MockStorageService();
    mockShoppingService = MockUnifiedShoppingService();
    mockFriendsService = MockUnifiedFriendsService();

    // Initialize repository mocks
    mockAuthRepository = MockFirebaseAuthRepository();
    mockRecipeRepository = MockFirebaseRecipeRepository();
    mockMessagingRepository = MockFirebaseMessagingRepository();
    mockShoppingRepository = MockFirebaseShoppingRepository();
    mockUserRepository = MockFirebaseUserRepository();
    mockFriendsRepository = MockFirebaseFriendsRepository();
    mockCommentsRepository = MockCommentsRepository();
    mockRatingsRepository = MockRatingsRepository();
    mockNotificationsRepository = MockNotificationsRepository();
    mockFirestoreRepository = MockFirestoreRepository();

    // Initialize mock container
    _mockContainer = MockDIContainer();

    _setupDefaultBehaviors();
    _registerFallbackValues();
    _setupServiceLocator();
  }

  /// Setup default mock behaviors for common operations.
  static void _setupDefaultBehaviors() {
    // RecipeService defaults
    when(() => mockRecipeService.recipes).thenReturn([]);
    when(() => mockRecipeService.personalRecipes).thenReturn([]);
    when(() => mockRecipeService.collaborativeRecipes).thenReturn([]);
    when(() => mockRecipeService.isLoading).thenReturn(false);
    when(() => mockRecipeService.isInitialized).thenReturn(true);
    when(() => mockRecipeService.hasError).thenReturn(false);
    when(() => mockRecipeService.error).thenReturn(null);
    when(() => mockRecipeService.currentUserId).thenReturn('test_user_123');
    when(() => mockRecipeService.currentUserDisplayName)
        .thenReturn('Test User');
    when(() => mockRecipeService.initialize()).thenAnswer((_) async {});

    // AuthService defaults
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUserId).thenReturn('test_user_123');

    // Container defaults
    when(() => _mockContainer!.get<UnifiedRecipeService>())
        .thenReturn(mockRecipeService);
    when(() => _mockContainer!.get<AuthService>()).thenReturn(mockAuthService);
    when(() => _mockContainer!.get<MessagingService>())
        .thenReturn(mockMessagingService);
    when(() => _mockContainer!.get<AnalyticsService>())
        .thenReturn(mockAnalyticsService);
    when(() => _mockContainer!.get<UserService>()).thenReturn(mockUserService);
    when(() => _mockContainer!.get<PermissionService>())
        .thenReturn(mockPermissionService);
    when(() => _mockContainer!.get<StorageService>())
        .thenReturn(mockStorageService);
    when(() => _mockContainer!.get<UnifiedShoppingService>())
        .thenReturn(mockShoppingService);
    when(() => _mockContainer!.get<UnifiedFriendsService>())
        .thenReturn(mockFriendsService);

    when(() => _mockContainer!.get<FirebaseAuthRepository>())
        .thenReturn(mockAuthRepository);
    when(() => _mockContainer!.get<FirebaseRecipeRepository>())
        .thenReturn(mockRecipeRepository);
    when(() => _mockContainer!.get<RecipeRepository>())
        .thenReturn(mockRecipeRepository);
    when(() => _mockContainer!.get<FirebaseMessagingRepository>())
        .thenReturn(mockMessagingRepository);
    when(() => _mockContainer!.get<FirebaseShoppingRepository>())
        .thenReturn(mockShoppingRepository);
    when(() => _mockContainer!.get<FirebaseUserRepository>())
        .thenReturn(mockUserRepository);
    when(() => _mockContainer!.get<FirebaseFriendsRepository>())
        .thenReturn(mockFriendsRepository);
    when(() => _mockContainer!.get<CommentsRepository>())
        .thenReturn(mockCommentsRepository);
    when(() => _mockContainer!.get<RatingsRepository>())
        .thenReturn(mockRatingsRepository);
    when(() => _mockContainer!.get<NotificationsRepository>())
        .thenReturn(mockNotificationsRepository);
    when(() => _mockContainer!.get<FirestoreRepository>())
        .thenReturn(mockFirestoreRepository);

    when(() => _mockContainer!.isRegistered<UnifiedRecipeService>())
        .thenReturn(true);
    when(() => _mockContainer!.isRegistered<AuthService>()).thenReturn(true);
    when(() => _mockContainer!.isInitialized).thenReturn(true);
  }

  /// Register fallback values for Mocktail to handle parameter matching.
  static void _registerFallbackValues() {
    // Register custom fallback values for complex types
    registerFallbackValue(createTestRecipe());
    registerFallbackValue(createTestUser());
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(RecipeOperationResult.success('Success'));
    registerFallbackValue(Uri.parse('https://example.com'));
    // Register Firebase User fallback
    registerFallbackValue(mockFirebaseUser);
  }

  /// Setup ServiceLocator with mock container for global service access.
  static void _setupServiceLocator() {
    ServiceLocator.initialize(_mockContainer!);
  }

  /// Get the mock container for direct access in tests.
  static MockDIContainer get container => _mockContainer!;

  /// Reset all mocks to clean state for test isolation.
  static void reset() {
    // Reset all service mocks using mocktail reset function
    resetMocktailState();

    // Reinitialize with defaults
    if (_mockContainer != null) {
      _setupDefaultBehaviors();
    }
  }

  /// Dispose and clean up test service locator.
  static void dispose() {
    ServiceLocator.reset();
    _mockContainer = null;
    // Clean up test Hive
    _tearDownTestHive();
  }

  /// Create a test recipe for testing purposes.
  static Recipe createTestRecipe({
    String? id,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
  }) {
    return RecipeFactory.createPersonal(
      title: title ?? 'Test Recipe',
      description: description ?? 'Test description',
      ingredients: ingredients ?? ['Test ingredient 1', 'Test ingredient 2'],
      instructions:
          instructions ?? ['Test instruction 1', 'Test instruction 2'],
      mealType: 'Middag',
      createdBy: 'test_user_123',
    );
  }

  /// Create a test user profile for testing purposes.
  static UserProfile createTestUser({
    String? uid,
    String? displayName,
    String? email,
  }) {
    return UserProfile(
      uid: uid ?? 'test_user_123',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  /// Configure recipe service for specific test scenarios.
  static void configureRecipeService({
    List<Recipe>? recipes,
    List<Recipe>? personalRecipes,
    List<Recipe>? collaborativeRecipes,
    bool isLoading = false,
    bool hasError = false,
    String? error,
  }) {
    when(() => mockRecipeService.recipes).thenReturn(recipes ?? []);
    when(() => mockRecipeService.personalRecipes)
        .thenReturn(personalRecipes ?? []);
    when(() => mockRecipeService.collaborativeRecipes)
        .thenReturn(collaborativeRecipes ?? []);
    when(() => mockRecipeService.isLoading).thenReturn(isLoading);
    when(() => mockRecipeService.hasError).thenReturn(hasError);
    when(() => mockRecipeService.error).thenReturn(error);
  }

  /// Configure auth service for specific test scenarios.
  static void configureAuthService({
    bool isAuthenticated = true,
    String? userId,
  }) {
    when(() => mockAuthService.isAuthenticated).thenReturn(isAuthenticated);
    when(() => mockAuthService.currentUserId)
        .thenReturn(userId ?? 'test_user_123');
  }

  /// Initialize Hive for testing
  static void _initializeTestHive() {
    try {
      final tempDir = Directory.systemTemp.createTempSync('hive_test');
      Hive.init(tempDir.path);
    } catch (e) {
      // Hive is already initialized, continue
    }
  }

  /// Clean up Hive after testing
  static void _tearDownTestHive() {
    try {
      Hive.close();
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

/// Test helper for creating testable widgets with proper service provider setup.
///
/// Creates a test environment with ApplicationProvider configured with mock services
/// for widget testing scenarios that require service access.
class TestWidgetHelper {
  /// Create testable widget with mock application provider.
  static Widget createTestableWidgetWithProvider(Widget child) {
    TestServiceLocator.initialize();

    return ApplicationProvider(
      container: TestServiceLocator.container,
      bootstrap: MockApplicationBootstrap(),
      child: child,
    );
  }
}
