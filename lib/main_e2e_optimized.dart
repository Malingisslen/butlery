/// Butlery E2E Optimized Application
///
/// INDUSTRY STANDARD E2E SOLUTION:
/// - Preserves REAL UI components (AuthView, MinaReceptView, etc.)
/// - Skips problematic Firebase/SharedPreferences initialization
/// - Enables fast, reliable E2E testing with authentic user journeys
///
/// PERFORMANCE TARGET: <1 second initialization (vs 15+ seconds for full app)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

// Import REAL UI components for authentic testing
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/mina_recept_view.dart';

// Import theme system for consistent styling
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Import routing for navigation testing
import 'package:butlery/core/router/app_router.dart';

// Import DI system for mocking services that AuthView needs
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';

// Import minimal service dependencies  
import 'package:butlery/services/auth_service.dart';

// Import required models 
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';

// Import Recipe Lifecycle services and models (verified against production code)
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/offline_service.dart' as offline_service;
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// **INDUSTRY STANDARD E2E APP**
///
/// This app variant enables comprehensive E2E testing by:
/// 1. Using REAL UI components from production app
/// 2. Skipping Firebase initialization that hangs in test environments
/// 3. Providing mocked authentication state for testing different scenarios
/// 4. Maintaining identical look/feel to production app
/// 5. Enabling fast test execution (<1 second vs 15+ seconds)
class ButleryE2EApp extends StatefulWidget {
  /// E2E testing mode configuration
  final E2EMode mode;

  /// Mock authentication state for testing
  final bool mockUserAuthenticated;

  /// Mock user data for testing
  final String mockUserEmail;

  const ButleryE2EApp({
    super.key,
    this.mode = E2EMode.mockTier,
    this.mockUserAuthenticated = false,
    this.mockUserEmail = 'test@butlery.se',
  });

  @override
  State<ButleryE2EApp> createState() => _ButleryE2EAppState();
}

class _ButleryE2EAppState extends State<ButleryE2EApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeE2EServices();
  }

  /// Initialize minimal ServiceLocator with mocked services for E2E testing
  ///
  /// RESILIENT APPROACH: Ensure ServiceLocator always initializes successfully
  Future<void> _initializeE2EServices() async {
    if (kDebugMode) {
      debugPrint(
          '🔧 E2E: Using resilient mock ServiceLocator initialization');
    }

    try {
      // Initialize Firebase for E2E testing to resolve Firebase dependencies
      if (!Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'mock-api-key',
            appId: 'mock-app-id', 
            messagingSenderId: 'mock-sender-id',
            projectId: 'mock-project-id',
          ),
        );
        if (kDebugMode) {
          debugPrint('✅ E2E Firebase mock initialization successful');
        }
      }
      
      // Reset ServiceLocator to ensure clean state
      ServiceLocator.reset();

      // Create real DIContainer but register services directly without complex initialization
      final container = DIContainer();

      // ALWAYS initialize ServiceLocator first, even with empty container
      ServiceLocator.initialize(container);
      
      if (kDebugMode) {
        debugPrint('✅ E2E ServiceLocator base initialization successful');
      }

      // Register mocked services directly with DIContainer's GetIt instance
      // This can fail, but ServiceLocator is already initialized
      await _registerE2EMockServicesDirect(container);

      if (kDebugMode) {
        debugPrint('✅ E2E Mock services registered successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ E2E Service registration error: $e');
        debugPrint('   ServiceLocator base initialization still successful');
      }
    }
    
    // ALWAYS mark as initialized - ServiceLocator itself is working
    setState(() {
      _isInitialized = true;
    });
  }

  /// Register mocked services needed by UI components directly with DIContainer
  /// RESILIENT APPROACH: Register each service safely, continue if some fail
  Future<void> _registerE2EMockServicesDirect(DIContainer container) async {
    final getIt = container.container;
    int successCount = 0;
    
    // 🔐 Authentication Services
    try {
      final mockAuthService = _MockAuthService();
      getIt.registerSingleton<AuthService>(mockAuthService);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register AuthService: $e');
    }
    
    try {
      final mockAuthViewModel = _MockAuthViewModel();
      getIt.registerSingleton<AuthViewModel>(mockAuthViewModel);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register AuthViewModel: $e');
    }
    
    // 🍳 Recipe Management Services (for Recipe Lifecycle E2E)
    try {
      final mockRecipeListViewModel = _E2EStubFactory.createRecipeListViewModel();
      getIt.registerSingleton<RecipeListViewModel>(mockRecipeListViewModel);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register RecipeListViewModel: $e');
    }
      
    try {
      final mockUserService = _E2EStubFactory.createUserService();
      getIt.registerSingleton<UserService>(mockUserService);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register UserService: $e');
    }
      
    try {
      final mockFriendsViewModel = _E2EStubFactory.createFriendsViewModel();
      getIt.registerSingleton<FriendsViewModel>(mockFriendsViewModel);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register FriendsViewModel: $e');
    }
      
    try {
      final mockSharedContentViewModel = _E2EStubFactory.createSharedContentViewModel();
      getIt.registerSingleton<SharedContentViewModel>(mockSharedContentViewModel);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register SharedContentViewModel: $e');
    }
      
    try {
      final mockOfflineService = _E2EStubFactory.createOfflineService();
      getIt.registerSingleton<offline_service.OfflineService>(mockOfflineService);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register OfflineService: $e');
    }
      
    try {
      final mockUnifiedRecipeService = _E2EStubFactory.createUnifiedRecipeService();
      getIt.registerSingleton<UnifiedRecipeService>(mockUnifiedRecipeService);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register UnifiedRecipeService: $e');
    }
      
    try {
      final mockAnalyticsService = _E2EStubFactory.createAnalyticsService();
      getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);
      successCount++;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to register AnalyticsService: $e');
    }
    
    if (kDebugMode) {
      debugPrint('🔧 E2E: Successfully registered $successCount/9 mock services');
      debugPrint('   📊 Service registration resilience test completed');
    }
  }
  

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'Butlery E2E Initializing',
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          backgroundColor: AppColors.backgroundBeige,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryBlue),
                SizedBox(height: AppDimensions.spacingL),
                Text(
                  'Initializing E2E Environment...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Butlery E2E Test',

      // Use REAL production theme for authentic testing
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // Use production routing for navigation testing
      onUnknownRoute: AppRouter.handleUnknownRoute,
      onGenerateRoute: AppRouter.generateRoute,

      // Determine initial screen based on mock auth state
      home: _buildInitialScreen(),
    );
  }

  /// Build initial screen based on mock authentication state
  Widget _buildInitialScreen() {
    if (widget.mockUserAuthenticated) {
      // Show main app (authenticated state)
      return _buildMainAppScreen();
    } else {
      // Show authentication screen (unauthenticated state)
      return const AuthView();
    }
  }

  /// Build main app screen for authenticated testing
  Widget _buildMainAppScreen() {
    // For E2E testing, we can mock the main recipe view
    // This allows testing of authenticated user workflows
    return const MinaReceptView(key: ValueKey('e2e_main_app'));
  }
}

/// E2E Testing Mode Configuration
enum E2EMode {
  /// Mock tier - fastest testing with mocked services
  mockTier,

  /// Emulator tier - Firebase emulator integration (when available)
  emulatorTier,

  /// Staging tier - staging environment testing (production-like)
  stagingTier,
}

/// E2E Test Helper Functions
class E2ETestHelper {
  /// Create authenticated E2E app for testing main app flows
  static Widget createAuthenticatedApp({
    E2EMode mode = E2EMode.mockTier,
    String userEmail = 'test@butlery.se',
  }) {
    return ButleryE2EApp(
      mode: mode,
      mockUserAuthenticated: true,
      mockUserEmail: userEmail,
    );
  }

  /// Create unauthenticated E2E app for testing auth flows
  static Widget createUnauthenticatedApp({
    E2EMode mode = E2EMode.mockTier,
  }) {
    return ButleryE2EApp(
      mode: mode,
      mockUserAuthenticated: false,
    );
  }

  /// Create E2E app for specific recipe testing
  static Widget createRecipeTestingApp({
    E2EMode mode = E2EMode.mockTier,
  }) {
    return ButleryE2EApp(
      mode: mode,
      mockUserAuthenticated: true,
      mockUserEmail: 'chef@butlery.se',
    );
  }
}

/// Mock User Profile for E2E Testing
class E2EMockUser {
  static const String testUserId = 'e2e_test_user_123';
  static const String testUserName = 'E2E Test User';
  static const String testUserEmail = 'test@butlery.se';

  static const String chefUserId = 'e2e_chef_user_456';
  static const String chefUserName = 'E2E Chef User';
  static const String chefUserEmail = 'chef@butlery.se';
}


/// Mock AuthService for E2E testing
///
/// Provides minimal mock implementation that AuthViewModel depends on
class _MockAuthService extends AuthService {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<bool> signInWithEmail(
      {required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;

    // Mock delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock success/error logic for E2E testing
    if (email.contains('error')) {
      _errorMessage = 'E2E Mock: Invalid credentials';
      _isLoading = false;
      return false;
    }

    _isLoading = false;

    if (kDebugMode) {
      debugPrint('✅ E2E Mock AuthService: User signed in - $email');
    }
    return true;
  }

  @override
  Future<bool> registerWithEmail(
      {required String email,
      required String password,
      required String displayName}) async {
    _isLoading = true;
    _errorMessage = null;

    // Mock delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock success/error logic
    if (email.contains('taken')) {
      _errorMessage = 'E2E Mock: Email already taken';
      _isLoading = false;
      return false;
    }

    _isLoading = false;

    if (kDebugMode) {
      debugPrint(
          '✅ E2E Mock AuthService: User registered - $displayName ($email)');
    }
    return true;
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;

    if (kDebugMode) {
      debugPrint('✅ E2E Mock AuthService: Password reset sent to $email');
    }
    return true;
  }

  @override
  void clearError() {
    _errorMessage = null;
  }
}

/// Mock AuthViewModel for E2E testing
///
/// Provides minimal mock implementation that AuthView expects
class _MockAuthViewModel extends AuthViewModel {
  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  String? _validationError;

  @override
  bool get isLoginMode => _isLoginMode;

  @override
  bool get isPasswordVisible => _isPasswordVisible;

  @override
  bool get isLoading => false; // Override to avoid accessing AuthService

  @override
  String? get errorMessage => _validationError;

  @override
  void toggleAuthMode() {
    _isLoginMode = !_isLoginMode;
    notifyListeners();
  }

  @override
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  @override
  void clearError() {
    _validationError = null;
    notifyListeners();
  }

  @override
  Future<bool> signIn({required String email, required String password}) async {
    _validationError = null;
    notifyListeners();

    // For E2E testing, simulate different scenarios
    if (email.contains('error')) {
      _validationError = 'E2E Mock: Invalid credentials';
      notifyListeners();
      return false;
    }

    if (kDebugMode) {
      debugPrint('✅ E2E Mock AuthViewModel: User signed in - $email');
    }
    return true;
  }

  @override
  Future<bool> register(
      {required String email,
      required String password,
      required String displayName}) async {
    _validationError = null;
    notifyListeners();

    // For E2E testing, simulate different scenarios
    if (email.contains('taken')) {
      _validationError = 'E2E Mock: Email already taken';
      notifyListeners();
      return false;
    }

    if (kDebugMode) {
      debugPrint(
          '✅ E2E Mock AuthViewModel: User registered - $displayName ($email)');
    }
    return true;
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    if (kDebugMode) {
      debugPrint('✅ E2E Mock AuthViewModel: Password reset sent to $email');
    }
    return true;
  }
}

// =============================================================================
// ULTRA-SIMPLE E2E TEST - Focus on Basic App Loading
// =============================================================================
// 
// GOLD STANDARD APPROACH: Test incrementally, don't over-engineer
// 1. First get the app to load without crashing
// 2. Then add functionality as needed
// 3. Don't implement complex Firebase interfaces unnecessarily

/// GOLD STANDARD: Centralized factory for all E2E stub services
/// Focus: Manage complex dependencies in one place, enable workflow testing
class _E2EStubFactory {
  
  /// Create RecipeListViewModel stub - handles all constructor dependencies
  static RecipeListViewModel createRecipeListViewModel() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating RecipeListViewModel stub');
    }
    // Return basic instance that won't crash UI - let production class handle defaults
    return RecipeListViewModel();
  }
  
  /// Create UserService stub - simplified mock approach
  static dynamic createUserService() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified UserService mock');
    }
    // Create a simplified mock that provides basic functionality without Firebase complexity
    return _E2EUserServiceMock();
  }
  
  /// Create FriendsViewModel stub - simplified mock approach
  static dynamic createFriendsViewModel() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified FriendsViewModel mock');
    }
    // Create a simplified mock that provides basic functionality without complex dependencies
    return _E2EFriendsViewModelMock();
  }
  
  /// Create SharedContentViewModel stub - simplified mock approach
  static dynamic createSharedContentViewModel() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified SharedContentViewModel mock');  
    }
    // Create a simplified mock that provides basic functionality without complex dependencies
    return _E2ESharedContentViewModelMock();
  }
  
  /// Create OfflineService stub - simplified mock approach
  static dynamic createOfflineService() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified OfflineService mock');
    }
    // Create a simplified mock that provides basic functionality
    return _E2EOfflineServiceMock();
  }
  
  /// Create UnifiedRecipeService stub - simplified mock approach
  static dynamic createUnifiedRecipeService() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified UnifiedRecipeService mock');
    }
    // Create a simplified mock that provides basic functionality
    return _E2EUnifiedRecipeServiceMock();
  }
  
  /// Create AnalyticsService stub - simplified mock approach
  static dynamic createAnalyticsService() {
    if (kDebugMode) {
      debugPrint('✅ E2E Factory: Creating simplified AnalyticsService mock');
    }
    // Create a simplified mock that provides basic functionality
    return _E2EAnalyticsServiceMock();
  }
}

// =============================================================================
// ULTRA-SIMPLE E2E MOCK IMPLEMENTATIONS - Gold Standard Minimal Dependencies
// =============================================================================

/// Simplified UserService mock that provides basic functionality
class _E2EUserServiceMock extends ChangeNotifier {
  final UserProfile _currentProfile = UserProfile(
    uid: 'e2e_test_user_123',
    displayName: 'E2E Test User',
    email: 'test@butlery.se',
    isSearchable: true,
    allowEmailSearch: false,
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
  );
  
  UserProfile get currentUserProfile => _currentProfile;
  bool get isLoading => false;
  String? get error => null;
  bool get hasError => false;
  
  Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    final now = DateTime.now();
    return userIds.map((id) => UserProfile(
      uid: id,
      displayName: 'E2E User $id',
      email: 'user$id@butlery.se',
      isSearchable: true,
      allowEmailSearch: false,
      joinedAt: now,
      lastActiveAt: now,
    )).toList();
  }
  
  void clearError() {}
}

/// Simplified FriendsViewModel mock that provides basic social functionality
class _E2EFriendsViewModelMock extends ChangeNotifier {
  List<UserProfile> get friends => [];
  List<FriendRequest> get incomingRequests => [];
  List<FriendRequest> get sentRequests => [];
  int get friendsCount => 0;
  int get pendingRequestsCount => 0;
  bool get isLoading => false;
  String? get error => null;
  bool get hasError => false;
  
  Future<void> refresh() async {}
  void clearError() {}
}

/// Simplified SharedContentViewModel mock that provides basic shared content functionality
class _E2ESharedContentViewModelMock extends ChangeNotifier {
  String get searchQuery => '';
  int get currentTabIndex => 0;
  bool get isLoading => false;
  String? get error => null;
  bool get hasError => false;
  bool get isImporting => false;
  
  List<SharedRecipe> get visibleSharedRecipes => [];
  List<SharedMenu> get visibleSharedMenus => [];
  bool get hasSharedContent => false;
  bool get hasFilteredContent => false;
  List<SharedRecipe> get filteredSharedRecipes => [];
  List<SharedMenu> get filteredSharedMenus => [];
  
  int get totalSharedRecipes => 0;
  int get totalSharedMenus => 0;
  int get unreadRecipesCount => 0;
  int get unreadMenusCount => 0;
  int get totalUnreadCount => 0;
  
  void updateSearchQuery(String query) {}
  void clearSearch() {}
  void setTabIndex(int index) {}
  void clearError() {}
}

/// Simplified OfflineService mock that provides basic offline functionality
class _E2EOfflineServiceMock extends ChangeNotifier {
  bool get isOnline => true;
  bool get isOffline => false;
  bool get isSyncing => false;
  String? get syncStatus => 'online';
  
  Future<void> syncNow() async {}
}

/// Simplified UnifiedRecipeService mock that provides basic recipe functionality
class _E2EUnifiedRecipeServiceMock extends ChangeNotifier {
  List<dynamic> get recipes => [];
  List<dynamic> get personalRecipes => [];
  List<dynamic> get collaborativeRecipes => [];
  
  bool get hasRecipes => false;
  bool get isInitialized => true;
  bool get isLoading => false;
  String? get error => null;
  bool get hasError => false;
  bool get isSyncing => false;
  
  String? get currentUserId => 'e2e_test_user_123';
  String? get currentUserDisplayName => 'E2E Test User';
  
  Future<void> initialize() async {}
  void clearError() {}
  dynamic getRecipeById(String id) => null;
}

/// Simplified AnalyticsService mock that provides basic analytics functionality
class _E2EAnalyticsServiceMock extends ChangeNotifier {
  Future<void> logEvent(String name, Map<String, dynamic> parameters) async {}
  Future<void> setUserId(String userId) async {}
  Future<void> setUserProperty(String name, String value) async {}
}