/// Helper utilities for configuring mocks in tests
///
/// Provides convenient methods to configure commonly used mocks
/// following the configuration pattern instead of stubbing getters.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import '../infrastructure/mocks/production_mocks.dart';
import '../infrastructure/factories/mock_factory.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/permission_service.dart';

/// Helper class for configuring mocks consistently across tests
class MockConfigurator {
  /// Configure authentication state for auth repository mock
  static void configureAuth({
    required MockAuthRepository mock,
    String? userId,
    User? user,
    bool isAuthenticated = false,
  }) {
    mock.setAuthState(
      userId: userId,
      user: user,
      isAuthenticated: isAuthenticated,
    );
  }

  /// Configure authenticated user state
  static void configureAuthenticatedUser({
    required MockAuthRepository mock,
    String userId = 'test_user_123',
    String email = 'test@example.com',
    String displayName = 'Test User',
  }) {
    final user = MockFactory.createMockUser(
      uid: userId,
      email: email,
      displayName: displayName,
    );

    mock.setAuthState(
      user: user,
      userId: userId,
      isAuthenticated: true,
    );
  }

  /// Configure unauthenticated state
  static void configureUnauthenticated(MockAuthRepository mock) {
    mock.setAuthState(
      user: null,
      userId: null,
      isAuthenticated: false,
    );
  }

  /// Configure recipe repository with recipes
  static void configureRecipes({
    required MockRecipeRepository mock,
    List<Recipe>? recipes,
    String? userId,
  }) {
    if (recipes != null) {
      mock.setRecipes(recipes);
    }
    if (userId != null) {
      mock.setRecipeRepositoryState(currentUserId: userId);
    }
  }

  /// Configure user repository with profiles
  static void configureUserProfiles({
    required MockUserRepository mock,
    Map<String, UserProfile>? profiles,
    String? currentUserId,
  }) {
    mock.setUserRepositoryState(
      profiles: profiles,
      currentUserId: currentUserId,
    );
  }

  /// Configure permission service mock
  static void configurePermissionService({
    required PermissionService service,
    required MockAuthRepository authMock,
    String? userId,
    String? displayName,
  }) {
    if (userId != null) {
      final user = MockFactory.createMockUser(
        uid: userId,
        email: 'test@example.com',
        displayName: displayName ?? 'Test User',
      );

      authMock.setAuthState(
        user: user,
        userId: userId,
        isAuthenticated: true,
      );
    }
  }

  /// Configure Firebase Auth mock (for low-level repository tests)
  static void configureFirebaseAuth({
    required dynamic mockFirebaseAuth,
    User? currentUser,
  }) {
    // For Firebase Auth mocks, we need to use when() since it's a third-party interface
    // But we should minimize this usage and prefer using our own auth repository mocks
    if (mockFirebaseAuth != null) {
      when(() => mockFirebaseAuth.currentUser).thenReturn(currentUser);
    }
  }

  /// Configure mock for async auth state changes stream
  static void configureAuthStateStream({
    required MockAuthRepository mock,
    User? user,
  }) {
    when(() => mock.authStateChanges()).thenAnswer(
      (_) => Stream.value(user),
    );
  }

  /// Configure mock for successful async operations
  static void configureAsyncSuccess<T>({
    required Mock mock,
    required String methodName,
    required T returnValue,
  }) {
    // This is a helper for common async stubbing patterns
    // Usage should be documented per mock type
  }

  /// Reset all mock states to defaults
  static void resetAllMocks(List<Mock> mocks) {
    for (final mock in mocks) {
      if (mock is MockAuthRepository) {
        configureUnauthenticated(mock);
      } else if (mock is MockRecipeRepository) {
        mock.setRecipes([]);
      } else if (mock is MockUserRepository) {
        mock.setUserRepositoryState(
          profiles: {},
          currentUserId: null,
        );
      }
    }
  }
}

/// Extension methods for convenient mock configuration
extension MockAuthRepositoryExtensions on MockAuthRepository {
  /// Quick configure as authenticated
  void asAuthenticated({
    String userId = 'test_user_123',
    String email = 'test@example.com',
    String displayName = 'Test User',
  }) {
    MockConfigurator.configureAuthenticatedUser(
      mock: this,
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }

  /// Quick configure as unauthenticated
  void asUnauthenticated() {
    MockConfigurator.configureUnauthenticated(this);
  }
}

extension MockRecipeRepositoryExtensions on MockRecipeRepository {
  /// Quick configure with test recipes
  void withRecipes(List<Recipe> recipes) {
    MockConfigurator.configureRecipes(
      mock: this,
      recipes: recipes,
    );
  }

  /// Quick configure with empty recipes
  void withNoRecipes() {
    MockConfigurator.configureRecipes(
      mock: this,
      recipes: [],
    );
  }
}
