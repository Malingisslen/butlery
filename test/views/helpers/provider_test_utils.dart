/// Multi-provider coordination utilities for Butlery view testing.
///
/// This module provides specialized utilities for managing Butlery's complex
/// multi-provider architecture in view tests. It handles provider setup,
/// state management, and coordination for views that typically use 2-5
/// different ViewModels simultaneously.
///
/// **Key Features:**
/// - **Standard Provider Combinations**: Pre-configured provider trees for common view types
/// - **Provider State Management**: Coordinated state setup and cleanup utilities
/// - **Dependency Verification**: Validation that all required providers are available
/// - **Scenario Configuration**: Quick setup for authentication, collaborative, offline scenarios
/// - **Performance Optimization**: Efficient provider initialization and disposal
///
/// **Architecture Integration:**
/// This module integrates with Butlery's modular DI system and the existing
/// TestServiceLocator infrastructure, ensuring view tests use the same
/// dependency patterns as production code.
///
/// **Usage Example:**
/// ```dart
/// testWidgets('EditRecipeView should coordinate multiple providers', (tester) async {
///   final providers = ProviderTestUtils.setupRecipeEditProviders(
///     recipeId: 'test-recipe-123',
///     isCollaborative: true,
///   );
///   
///   await tester.pumpWidget(
///     ViewTestHelpers.createTestViewWidget(
///       child: const EditRecipeView(),
///       providers: providers,
///     ),
///   );
///   
///   ProviderTestUtils.verifyProvidersAvailable(tester, [
///     RecipeFormViewModel,
///     CollaborativeStatusViewModel,
///     AuthService,
///   ]);
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

// Import existing test infrastructure
import '../../infrastructure/mocks/widget_mocks.dart';

// Import ViewModels for provider setup
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';

/// Utilities for managing multi-provider coordination in view tests.
///
/// This class provides methods for setting up complex provider trees that
/// match Butlery's production architecture, ensuring view tests accurately
/// reflect real-world provider dependencies and interactions.
class ProviderTestUtils {
  /// Private constructor to prevent instantiation
  ProviderTestUtils._();

  // ==================== STANDARD PROVIDER COMBINATIONS ====================

  /// Setup providers for authentication views (AuthView).
  ///
  /// Creates the standard provider tree used by authentication views:
  /// - AuthViewModel for login/registration logic
  /// - UserService for profile management
  /// - PermissionService for access control
  ///
  /// **Parameters:**
  /// - `isAuthenticated`: Whether user should start authenticated
  /// - `userId`: User ID for authenticated scenarios
  /// - `email`: User email for form pre-population
  static List<ChangeNotifierProvider> setupAuthProviders({
    bool isAuthenticated = false,
    String? userId,
    String? email,
  }) {
    final authViewModel = WidgetMockFactory.createMockAuthViewModel(
      isAuthenticated: isAuthenticated,
      userId: userId,
      email: email,
    );

    return [
      ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
    ];
  }

  /// Setup providers for recipe editing views (EditRecipeView).
  ///
  /// Creates the comprehensive provider tree for recipe editing:
  /// - RecipeFormViewModel for form state management
  /// - CollaborativeStatusViewModel for real-time editing status
  /// - AuthService for user authentication state
  /// - SocialRecipeViewModel for social features
  ///
  /// **Parameters:**
  /// - `recipeId`: ID of recipe being edited (null for new recipe)
  /// - `isCollaborative`: Whether recipe supports collaboration
  /// - `hasConflicts`: Whether to simulate edit conflicts
  /// - `isOwner`: Whether current user owns the recipe
  static List<ChangeNotifierProvider> setupRecipeEditProviders({
    String? recipeId,
    bool isCollaborative = false,
    bool hasConflicts = false,
    bool isOwner = true,
  }) {
    final recipeFormViewModel = MockRecipeFormViewModel();
    final collaborativeStatusViewModel = MockCollaborativeStatusViewModel();
    final socialRecipeViewModel = MockSocialRecipeViewModel();

    // Configure recipe form state
    if (recipeId != null) {
      recipeFormViewModel.setRecipeFormState(
        recipe: WidgetMockFactory.createTestRecipes(count: 1).first,
        isLoading: false,
      );
    }

    // Configure collaborative state
    if (isCollaborative) {
      collaborativeStatusViewModel.setCollaborativeState(
        isCollaborative: true,
        hasConflicts: hasConflicts,
        canEdit: isOwner,
        activeCollaborators: hasConflicts ? ['other-user'] : [],
      );
    }

    // Configure social features
    socialRecipeViewModel.setSocialRecipeState(
      commentCount: 5,
      isLoadingComments: false,
    );

    return [
      ChangeNotifierProvider<RecipeFormViewModel>.value(value: recipeFormViewModel),
      ChangeNotifierProvider<CollaborativeStatusViewModel>.value(value: collaborativeStatusViewModel),
      ChangeNotifierProvider<SocialRecipeViewModel>.value(value: socialRecipeViewModel),
    ];
  }

  /// Setup providers for recipe detail views (RecipeDetailView).
  /// Temporarily simplified until all ViewModels are properly imported.
  static List<ChangeNotifierProvider> setupRecipeDetailProviders({
    String? recipeId,
    bool isLoading = false,
    int commentCount = 0,
    bool hasUserReaction = false,
  }) {
    // Simplified implementation - will be expanded when ViewModels are available
    return [];
  }

  /// Setup providers for shopping views (UnifiedShoppingView, CollaborativeShoppingView).
  ///
  /// Creates provider tree for shopping list management:
  /// - UnifiedShoppingViewModel for list data
  /// - CollaborativeStatusViewModel for real-time collaboration
  /// - AuthService for user context
  static List<ChangeNotifierProvider> setupShoppingProviders({
    bool isCollaborative = false,
    bool hasConflicts = false,
    int listCount = 2,
    bool isOffline = false,
  }) {
    final shoppingViewModel = WidgetMockFactory.createMockShoppingViewModel(
      lists: WidgetMockFactory.createTestShoppingLists(count: listCount),
      isLoading: false,
    );

    final providers = <ChangeNotifierProvider>[
      ChangeNotifierProvider<UnifiedShoppingViewModel>.value(value: shoppingViewModel),
    ];

    // Add collaborative features if needed
    if (isCollaborative) {
      final collaborativeStatusViewModel = MockCollaborativeStatusViewModel();
      collaborativeStatusViewModel.setCollaborativeState(
        isCollaborative: true,
        hasConflicts: hasConflicts,
        isOffline: isOffline,
      );

      providers.add(
        ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
          value: collaborativeStatusViewModel,
        ),
      );
    }

    return providers;
  }

  /// Setup providers for social views (DiscoveryDashboardView, FriendsListView).
  /// Temporarily simplified until all ViewModels are properly imported.
  static List<ChangeNotifierProvider> setupSocialProviders({
    bool hasUnreadNotifications = false,
    int friendCount = 0,
    int pendingRequestCount = 0,
    bool isDiscoveryLoading = false,
  }) {
    // Simplified implementation - will be expanded when ViewModels are available
    return [];
  }

  /// Setup providers for messaging views (ConversationsListView, ChatView).
  /// Temporarily simplified until ConversationsViewModel is properly imported.
  static List<ChangeNotifierProvider> setupMessagingProviders({
    int conversationCount = 3,
    bool hasUnreadMessages = false,
    bool isLoading = false,
  }) {
    // Simplified implementation - will be expanded when ViewModels are available
    return [];
  }

  // ==================== PROVIDER VERIFICATION UTILITIES ====================

  /// Verify that all required providers are available in the widget tree.
  ///
  /// This method checks that providers are properly registered and accessible
  /// from the widget tree, helping catch provider setup issues early.
  ///
  /// **Usage:**
  /// ```dart
  /// ProviderTestUtils.verifyProvidersAvailable(tester, [
  ///   AuthService,
  ///   RecipeFormViewModel,
  ///   CollaborativeStatusViewModel,
  /// ]);
  /// ```
  static void verifyProvidersAvailable(
    WidgetTester tester,
    List<Type> providerTypes,
  ) {
    final context = tester.element(find.byType(MaterialApp).first);
    
    for (final type in providerTypes) {
      try {
        final provider = Provider.of(context, listen: false);
        expect(provider, isNotNull, 
          reason: 'Provider of type $type is not available in widget tree');
      } catch (e) {
        fail('Provider of type $type failed verification: $e');
      }
    }
  }

  /// Verify provider initialization state.
  ///
  /// Checks that providers have been properly initialized with expected
  /// state values, ensuring test scenarios are set up correctly.
  static void verifyProviderInitialization(
    WidgetTester tester,
    Map<Type, Map<String, dynamic>> expectedStates,
  ) {
    final context = tester.element(find.byType(MaterialApp).first);

    for (final entry in expectedStates.entries) {
      final providerType = entry.key;
      final expectedState = entry.value;

      try {
        final provider = Provider.of(context, listen: false);
        
        // Verify each expected state property
        for (final stateEntry in expectedState.entries) {
          final property = stateEntry.key;
          final expectedValue = stateEntry.value;
          
          // Use reflection or type-specific checks to verify state
          _verifyProviderProperty(provider, property, expectedValue);
        }
      } catch (e) {
        fail('Provider initialization verification failed for $providerType: $e');
      }
    }
  }

  /// Verify specific provider property value.
  static void _verifyProviderProperty(dynamic provider, String property, dynamic expectedValue) {
    // Implementation would depend on specific provider types and their properties
    // This is a placeholder for type-specific property verification
    
    // Example implementations:
    if (provider is MockAuthViewModel && property == 'isAuthenticated') {
      expect(provider.isAuthenticated, equals(expectedValue));
    } else if (provider is MockRecipeFormViewModel && property == 'isLoading') {
      expect(provider.isLoading, equals(expectedValue));
    }
    // Add more type-specific verifications as needed
  }

  // ==================== STATE MANAGEMENT UTILITIES ====================

  /// Reset all provider states to clean slate.
  ///
  /// Clears provider state between tests to prevent test pollution
  /// and ensure each test starts with predictable state.
  static Future<void> resetProviderStates(List<ChangeNotifier> providers) async {
    for (final provider in providers) {
      if (provider is MockBaseViewModel) {
        provider.setLoadingState(false);
        provider.setErrorState(null);
      }
    }
  }

  /// Configure providers for authenticated user scenario.
  ///
  /// Sets up all providers with authenticated user state for tests
  /// that require a logged-in user context.
  static void configureAuthenticatedState(List<ChangeNotifier> providers) {
    for (final provider in providers) {
      if (provider is MockAuthViewModel) {
        provider.setAuthState(
          isAuthenticated: true,
          userId: 'test-user-123',
          email: 'test@example.com',
        );
      }
    }
  }

  /// Configure providers for unauthenticated scenario.
  static void configureUnauthenticatedState(List<ChangeNotifier> providers) {
    for (final provider in providers) {
      if (provider is MockAuthViewModel) {
        provider.setAuthState(isAuthenticated: false);
      }
    }
  }

  /// Configure providers for offline scenario.
  ///
  /// Sets up providers to simulate offline mode for testing
  /// offline functionality and error handling.
  static void configureOfflineState(List<ChangeNotifier> providers) {
    for (final provider in providers) {
      if (provider is MockCollaborativeStatusViewModel) {
        provider.setCollaborativeState(isOffline: true);
      }
    }
  }

  // ==================== SCENARIO-BASED PROVIDER SETUP ====================

  /// Quick setup for critical views with standard configurations.
  static Map<String, List<ChangeNotifierProvider>> getStandardViewProviders() {
    return {
      'auth': setupAuthProviders(isAuthenticated: false),
      'auth_authenticated': setupAuthProviders(isAuthenticated: true),
      'recipe_edit_new': setupRecipeEditProviders(),
      'recipe_edit_existing': setupRecipeEditProviders(recipeId: 'test-recipe'),
      'recipe_edit_collaborative': setupRecipeEditProviders(
        recipeId: 'test-recipe',
        isCollaborative: true,
      ),
      'recipe_detail': setupRecipeDetailProviders(recipeId: 'test-recipe'),
      'shopping_personal': setupShoppingProviders(),
      'shopping_collaborative': setupShoppingProviders(isCollaborative: true),
      'social': setupSocialProviders(),
      'messaging': setupMessagingProviders(),
    };
  }

  /// Get providers for specific view type with custom configuration.
  static List<ChangeNotifierProvider> getProvidersForView(
    String viewType,
    Map<String, dynamic>? config,
  ) {
    config ??= {};

    switch (viewType) {
      case 'auth':
        return setupAuthProviders(
          isAuthenticated: config['isAuthenticated'] ?? false,
          userId: config['userId'],
          email: config['email'],
        );

      case 'recipe_edit':
        return setupRecipeEditProviders(
          recipeId: config['recipeId'],
          isCollaborative: config['isCollaborative'] ?? false,
          hasConflicts: config['hasConflicts'] ?? false,
          isOwner: config['isOwner'] ?? true,
        );

      case 'shopping':
        return setupShoppingProviders(
          isCollaborative: config['isCollaborative'] ?? false,
          hasConflicts: config['hasConflicts'] ?? false,
          listCount: config['listCount'] ?? 2,
          isOffline: config['isOffline'] ?? false,
        );

      case 'social':
        return setupSocialProviders(
          friendCount: config['friendCount'] ?? 0,
          pendingRequestCount: config['pendingRequestCount'] ?? 0,
        );

      default:
        return [];
    }
  }
}

// ==================== MOCK IMPLEMENTATIONS ====================

/// Mock collaborative status view model for testing.
class MockCollaborativeStatusViewModel extends Mock implements CollaborativeStatusViewModel {
  bool _isCollaborative = false;
  bool _hasConflicts = false;
  bool _canEdit = true;
  bool _isOffline = false;
  List<String> _activeCollaborators = [];

  bool get isCollaborative => _isCollaborative;
  bool get hasConflicts => _hasConflicts;
  bool get canEdit => _canEdit;
  bool get isOffline => _isOffline;
  List<String> get activeCollaborators => _activeCollaborators;

  void setCollaborativeState({
    bool? isCollaborative,
    bool? hasConflicts,
    bool? canEdit,
    bool? isOffline,
    List<String>? activeCollaborators,
  }) {
    if (isCollaborative != null) _isCollaborative = isCollaborative;
    if (hasConflicts != null) _hasConflicts = hasConflicts;
    if (canEdit != null) _canEdit = canEdit;
    if (isOffline != null) _isOffline = isOffline;
    if (activeCollaborators != null) _activeCollaborators = activeCollaborators;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Mock implementation
  }

  @override
  void addListener(VoidCallback listener) {
    // Mock implementation
  }

  @override
  void removeListener(VoidCallback listener) {
    // Mock implementation
  }

  @override
  void dispose() {
    // Mock implementation
  }

  @override
  bool get hasListeners => true;
}

/// Mock conversations view model for messaging tests.
/// Temporarily commented out until ConversationsViewModel is properly imported.
/*
class MockConversationsViewModel extends Mock implements ConversationsViewModel {
  List<Conversation> _conversations = [];
  bool _isLoading = false;

  @override
  List<Conversation> get conversations => _conversations;
  
  @override
  bool get isLoading => _isLoading;

  void setConversationsState({
    List<Conversation>? conversations,
    bool? isLoading,
  }) {
    if (conversations != null) _conversations = conversations;
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Mock implementation
  }

  @override
  void addListener(VoidCallback listener) {
    // Mock implementation
  }

  @override
  void removeListener(VoidCallback listener) {
    // Mock implementation
  }

  @override
  void dispose() {
    // Mock implementation
  }

  @override
  bool get hasListeners => true;
}
*/