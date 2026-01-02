/// Testable ViewModel variants for deterministic view testing.
///
/// This module extends the existing widget_mocks.dart infrastructure with
/// enhanced state control specifically designed for view-level testing.
/// It provides testable ViewModels that allow precise state manipulation
/// for testing complex view interactions and state transitions.
///
/// **Key Features:**
/// - **Deterministic State Control**: Precise state manipulation for predictable testing
/// - **Collaborative State Simulation**: Real-time editing conflicts and resolution testing
/// - **Error State Management**: Controlled error injection and recovery testing
/// - **Performance Monitoring**: State transition timing and memory leak detection
/// - **Swedish Context Support**: Localized error messages and user feedback
///
/// **Architecture Integration:**
/// These testable ViewModels maintain the same interfaces as production ViewModels
/// while providing enhanced state control capabilities. They integrate seamlessly
/// with the existing TestServiceLocator and provider infrastructure.
///
/// **Usage Example:**
/// ```dart
/// testWidgets('should handle collaborative conflict resolution', (tester) async {
///   final viewModel = TestableRecipeFormViewModel();
///
///   // Configure collaborative conflict scenario
///   viewModel.simulateCollaborativeConflict(
///     conflictingUser: 'Anna Andersson',
///     conflictType: ConflictType.simultaneousEdit,
///   );
///
///   await tester.pumpWidget(createTestView(viewModel));
///
///   // Verify conflict UI is displayed
///   expect(find.text('Anna Andersson redigerar detta recept'), findsOneWidget);
///   expect(find.text('Skapa kopia'), findsOneWidget);
/// });
/// ```
library;

// Import existing mock infrastructure
import '../../infrastructure/mocks/widget_mocks.dart';

// Import production ViewModels for interface compatibility
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
// import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart'; // Interface not formally implemented
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';

// Import models for state management
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

// ==================== CORE TESTABLE VIEWMODEL BASE ====================

/// Enhanced base class for testable ViewModels with advanced state control.
///
/// Extends the existing MockBaseViewModel with view-testing specific capabilities
/// including state transition monitoring, memory leak detection, and performance tracking.
class TestableViewModelBase extends MockBaseViewModel {
  // State tracking for testing
  final List<String> _stateTransitions = [];
  final Map<String, DateTime> _stateTimestamps = {};
  bool _disposed = false;

  // Performance tracking
  final Stopwatch _stateTransitionStopwatch = Stopwatch();
  Duration? _lastTransitionDuration;

  // Error injection capabilities
  String? _injectedError;
  bool _shouldFailNextOperation = false;

  // ==================== STATE TRANSITION MONITORING ====================

  /// Record state transition for testing verification.
  void _recordStateTransition(String newState) {
    if (_disposed) return;

    _stateTransitionStopwatch.stop();
    _lastTransitionDuration = _stateTransitionStopwatch.elapsed;
    _stateTransitionStopwatch.reset();

    _stateTransitions.add(newState);
    _stateTimestamps[newState] = DateTime.now();
    _stateTransitionStopwatch.start();
  }

  /// Get recorded state transitions for test verification.
  List<String> getStateTransitions() => List.from(_stateTransitions);

  /// Get duration of last state transition.
  Duration? getLastTransitionDuration() => _lastTransitionDuration;

  /// Clear state transition history.
  void clearStateHistory() {
    _stateTransitions.clear();
    _stateTimestamps.clear();
  }

  // ==================== ERROR INJECTION UTILITIES ====================

  /// Inject error for next operation to test error handling.
  void injectError(String errorMessage) {
    _injectedError = errorMessage;
  }

  /// Configure next operation to fail for testing.
  void failNextOperation() {
    _shouldFailNextOperation = true;
  }

  /// Check if error should be injected and consume it.
  String? _consumeInjectedError() {
    final error = _injectedError;
    _injectedError = null;
    return error;
  }

  /// Check if operation should fail and consume flag.
  bool _consumeFailureFlag() {
    final shouldFail = _shouldFailNextOperation;
    _shouldFailNextOperation = false;
    return shouldFail;
  }

  // ==================== PERFORMANCE UTILITIES ====================

  /// Measure time for state change operations.
  Future<T> _measureStateChange<T>(
      String operation, Future<T> Function() fn) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await fn();
      stopwatch.stop();
      _recordStateTransition('$operation (${stopwatch.elapsedMilliseconds}ms)');
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordStateTransition(
          '$operation failed (${stopwatch.elapsedMilliseconds}ms)');
      rethrow;
    }
  }

  // ==================== MEMORY LEAK DETECTION ====================

  @override
  void dispose() {
    _disposed = true;
    _stateTransitions.clear();
    _stateTimestamps.clear();
    _stateTransitionStopwatch.stop();
    super.dispose();
  }

  /// Verify ViewModel has been properly disposed.
  bool get isProperlyDisposed => _disposed;
}

// ==================== AUTHENTICATION VIEWMODEL ====================

/// Testable AuthViewModel with enhanced authentication state control.
class TestableAuthViewModel extends TestableViewModelBase
    implements AuthViewModel {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _currentUserId;
  String? _userEmail;
  String? _userDisplayName;
  String? _lastError;

  // Authentication flow states
  bool _isRegistrationMode = false;
  bool _isPasswordResetMode = false;
  bool _rememberMe = false;

  // ==================== AUTHENTICATION STATE ====================

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isLoading => _isLoading;

  String? get currentUserId => _currentUserId;
  String? get userEmail => _userEmail;
  String? get userDisplayName => _userDisplayName;
  String? get lastError => _lastError;
  bool get isRegistrationMode => _isRegistrationMode;
  bool get isPasswordResetMode => _isPasswordResetMode;
  bool get rememberMe => _rememberMe;

  /// Set authentication state for testing scenarios.
  void setAuthenticationState({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? email,
    String? displayName,
    String? error,
  }) {
    if (isAuthenticated != null) {
      _isAuthenticated = isAuthenticated;
      _recordStateTransition(
          'auth_state_${isAuthenticated ? 'authenticated' : 'unauthenticated'}');
    }
    if (isLoading != null) {
      _isLoading = isLoading;
      _recordStateTransition('loading_$isLoading');
    }
    if (userId != null) _currentUserId = userId;
    if (email != null) _userEmail = email;
    if (displayName != null) _userDisplayName = displayName;
    if (error != null) {
      _lastError = error;
      _recordStateTransition('error_set');
    }
    notifyListeners();
  }

  /// Simulate authentication flow states.
  void setAuthenticationFlowState({
    bool? isRegistrationMode,
    bool? isPasswordResetMode,
    bool? rememberMe,
  }) {
    if (isRegistrationMode != null) {
      _isRegistrationMode = isRegistrationMode;
      _recordStateTransition('registration_mode_$isRegistrationMode');
    }
    if (isPasswordResetMode != null) {
      _isPasswordResetMode = isPasswordResetMode;
      _recordStateTransition('password_reset_mode_$isPasswordResetMode');
    }
    if (rememberMe != null) {
      _rememberMe = rememberMe;
    }
    notifyListeners();
  }

  /// Simulate login process with controlled timing.
  Future<void> simulateLogin(
    String email,
    String password, {
    Duration delay = const Duration(milliseconds: 500),
    bool shouldSucceed = true,
  }) async {
    return _measureStateChange('login', () async {
      setAuthenticationState(isLoading: true);

      await Future.delayed(delay);

      final injectedError = _consumeInjectedError();
      final shouldFail = _consumeFailureFlag() || !shouldSucceed;

      if (injectedError != null) {
        setAuthenticationState(
          isLoading: false,
          error: injectedError,
        );
        throw Exception(injectedError);
      } else if (shouldFail) {
        final error = 'Felaktiga inloggningsuppgifter';
        setAuthenticationState(
          isLoading: false,
          error: error,
        );
        throw Exception(error);
      } else {
        setAuthenticationState(
          isAuthenticated: true,
          isLoading: false,
          userId: 'test_user_123',
          email: email,
          displayName: 'Test Användare',
          error: null,
        );
      }
    });
  }

  /// Simulate registration process.
  Future<void> simulateRegistration(
    String name,
    String email,
    String password, {
    Duration delay = const Duration(milliseconds: 800),
    bool shouldSucceed = true,
  }) async {
    return _measureStateChange('registration', () async {
      setAuthenticationState(isLoading: true);

      await Future.delayed(delay);

      if (!shouldSucceed) {
        setAuthenticationState(
          isLoading: false,
          error: 'E-postadressen används redan',
        );
        throw Exception('Registration failed');
      } else {
        setAuthenticationState(
          isAuthenticated: true,
          isLoading: false,
          userId: 'new_user_123',
          email: email,
          displayName: name,
          error: null,
        );
      }
    });
  }

  /// Simulate password reset flow.
  Future<void> simulatePasswordReset(
    String email, {
    Duration delay = const Duration(milliseconds: 600),
    bool shouldSucceed = true,
  }) async {
    return _measureStateChange('password_reset', () async {
      setAuthenticationState(isLoading: true);

      await Future.delayed(delay);

      if (!shouldSucceed) {
        setAuthenticationState(
          isLoading: false,
          error: 'E-postadressen hittades inte',
        );
        throw Exception('Password reset failed');
      } else {
        setAuthenticationState(
          isLoading: false,
          error: null,
        );
        _recordStateTransition('password_reset_sent');
      }
    });
  }

  /// Simulate logout process.
  Future<void> simulateLogout({
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    return _measureStateChange('logout', () async {
      setAuthenticationState(isLoading: true);

      await Future.delayed(delay);

      setAuthenticationState(
        isAuthenticated: false,
        isLoading: false,
        userId: null,
        email: null,
        displayName: null,
        error: null,
      );
    });
  }
}

// ==================== RECIPE FORM VIEWMODEL ====================

/// Testable RecipeFormViewModel with collaborative editing simulation.
class TestableRecipeFormViewModel extends TestableViewModelBase
    implements RecipeFormViewModel {
  Recipe? _recipe;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isCollaborativeMode = false;

  // Collaborative editing state
  bool _hasEditConflict = false;
  String? _conflictingUserName;
  ConflictType? _conflictType;
  bool _canForceEdit = false;

  // Form validation state
  Map<String, String?> _validationErrors = {};
  bool _isFormValid = true;

  // ==================== RECIPE STATE ====================

  @override
  Recipe? get recipe => _recipe;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isCollaborativeMode => _isCollaborativeMode;
  bool get hasEditConflict => _hasEditConflict;
  String? get conflictingUserName => _conflictingUserName;
  ConflictType? get conflictType => _conflictType;
  bool get canForceEdit => _canForceEdit;
  Map<String, String?> get validationErrors => Map.from(_validationErrors);
  bool get isFormValid => _isFormValid;

  /// Set recipe form state for testing.
  void setRecipeFormState({
    Recipe? recipe,
    bool? isLoading,
    bool? hasUnsavedChanges,
    bool? isCollaborativeMode,
  }) {
    if (recipe != null) {
      _recipe = recipe;
      _recordStateTransition('recipe_loaded');
    }
    if (isLoading != null) {
      _isLoading = isLoading;
      _recordStateTransition('loading_$isLoading');
    }
    if (hasUnsavedChanges != null) {
      _hasUnsavedChanges = hasUnsavedChanges;
      _recordStateTransition('unsaved_changes_$hasUnsavedChanges');
    }
    if (isCollaborativeMode != null) {
      _isCollaborativeMode = isCollaborativeMode;
      _recordStateTransition('collaborative_mode_$isCollaborativeMode');
    }
    notifyListeners();
  }

  /// Simulate collaborative editing conflict.
  void simulateCollaborativeConflict({
    required String conflictingUser,
    required ConflictType conflictType,
    bool canForceEdit = false,
  }) {
    _hasEditConflict = true;
    _conflictingUserName = conflictingUser;
    _conflictType = conflictType;
    _canForceEdit = canForceEdit;
    _recordStateTransition('collaborative_conflict_${conflictType.name}');
    notifyListeners();
  }

  /// Resolve collaborative conflict.
  void resolveCollaborativeConflict() {
    _hasEditConflict = false;
    _conflictingUserName = null;
    _conflictType = null;
    _canForceEdit = false;
    _recordStateTransition('collaborative_conflict_resolved');
    notifyListeners();
  }

  /// Simulate form validation with Swedish error messages.
  void simulateFormValidation({
    Map<String, String?>? validationErrors,
    bool? isValid,
  }) {
    if (validationErrors != null) {
      _validationErrors = Map.from(validationErrors);
    }
    if (isValid != null) {
      _isFormValid = isValid;
    }
    _recordStateTransition(
        'form_validation_${_isFormValid ? 'passed' : 'failed'}');
    notifyListeners();
  }

  /// Simulate save operation.
  Future<void> simulateSave({
    Duration delay = const Duration(milliseconds: 1000),
    bool shouldSucceed = true,
  }) async {
    return _measureStateChange('save_recipe', () async {
      setRecipeFormState(isLoading: true);

      await Future.delayed(delay);

      final injectedError = _consumeInjectedError();
      final shouldFail = _consumeFailureFlag() || !shouldSucceed;

      if (injectedError != null) {
        setError(injectedError);
        setRecipeFormState(isLoading: false);
        throw Exception(injectedError);
      } else if (shouldFail) {
        setError(
            'Kunde inte spara recept. Kontrollera din internetanslutning.');
        setRecipeFormState(isLoading: false);
        throw Exception('Save failed');
      } else {
        setRecipeFormState(
          isLoading: false,
          hasUnsavedChanges: false,
        );
        _recordStateTransition('recipe_saved');
      }
    });
  }

  /// Simulate fork operation (create copy from collaborative conflict).
  Future<void> simulateFork({
    Duration delay = const Duration(milliseconds: 800),
  }) async {
    return _measureStateChange('fork_recipe', () async {
      setRecipeFormState(isLoading: true);

      await Future.delayed(delay);

      // Create new recipe copy
      final forkedRecipe = Recipe(
        core: RecipeCore(
          title: '${_recipe?.title ?? 'Recept'} (Kopia)',
          description: _recipe?.description ?? '',
          ingredients: _recipe?.ingredients ?? [],
          instructions: _recipe?.instructions ?? [],
          mealType: _recipe?.mealType ?? 'Lunch',
        ),
        type: RecipeType.personal,
      );

      setRecipeFormState(
        recipe: forkedRecipe,
        isLoading: false,
        hasUnsavedChanges: false,
      );

      // Clear conflict state
      resolveCollaborativeConflict();
    });
  }
}

// ==================== SHOPPING VIEWMODEL ====================

/// Testable UnifiedShoppingViewModel with collaborative shopping simulation.
class TestableUnifiedShoppingViewModel extends TestableViewModelBase
    implements UnifiedShoppingViewModel {
  List<UnifiedShoppingList> _shoppingLists = [];
  UnifiedShoppingList? _activeList;
  bool _isLoading = false;
  bool _isSyncing = false;

  // Collaborative state
  final Map<String, List<String>> _activeCollaborators = {};
  bool _hasConflicts = false;
  int _pendingChanges = 0;

  // ==================== SHOPPING STATE ====================

  @override
  List<UnifiedShoppingList> get lists => List.from(_shoppingLists);

  @override
  UnifiedShoppingList? get activeList => _activeList;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isSyncing => _isSyncing;
  bool get hasConflicts => _hasConflicts;
  int get pendingChanges => _pendingChanges;

  /// Set shopping state for testing.
  void setShoppingState({
    List<UnifiedShoppingList>? lists,
    UnifiedShoppingList? activeList,
    bool? isLoading,
    bool? isSyncing,
  }) {
    if (lists != null) {
      _shoppingLists = lists;
      _recordStateTransition('lists_loaded_${lists.length}');
    }
    if (activeList != null) {
      _activeList = activeList;
      _recordStateTransition('active_list_changed');
    }
    if (isLoading != null) {
      _isLoading = isLoading;
      _recordStateTransition('loading_$isLoading');
    }
    if (isSyncing != null) {
      _isSyncing = isSyncing;
      _recordStateTransition('syncing_$isSyncing');
    }
    notifyListeners();
  }

  /// Simulate collaborative shopping scenario.
  void simulateCollaborativeEditing({
    required String listId,
    required List<String> collaborators,
    bool hasConflicts = false,
    int pendingChanges = 0,
  }) {
    _activeCollaborators[listId] = collaborators;
    _hasConflicts = hasConflicts;
    _pendingChanges = pendingChanges;
    _recordStateTransition(
        'collaborative_editing_${collaborators.length}_users');
    notifyListeners();
  }

  /// Simulate sync operation.
  Future<void> simulateSync({
    Duration delay = const Duration(milliseconds: 600),
    bool shouldSucceed = true,
  }) async {
    return _measureStateChange('sync_shopping_lists', () async {
      setShoppingState(isSyncing: true);

      await Future.delayed(delay);

      if (!shouldSucceed) {
        setError('Synkronisering misslyckades');
        setShoppingState(isSyncing: false);
        throw Exception('Sync failed');
      } else {
        _pendingChanges = 0;
        _hasConflicts = false;
        setShoppingState(isSyncing: false);
        _recordStateTransition('sync_completed');
      }
    });
  }
}

// ==================== COLLABORATIVE SHOPPING VIEWMODEL ====================

/// Testable CollaborativeShoppingViewModel with enhanced collaborative state control.
/// Note: Does not formally implement CollaborativeShoppingViewModel due to inheritance conflicts
/// but provides all required methods for testing.
class TestableCollaborativeShoppingViewModel extends MockBaseViewModel {
  // State tracking for testing (simplified version from TestableViewModelBase)
  final List<String> _stateTransitions = [];

  void _recordStateTransition(String newState) {
    _stateTransitions.add(newState);
  }

  List<String> getStateTransitions() => List.from(_stateTransitions);

  // Measure state changes for testing
  Future<T> _measureStateChange<T>(
      String operation, Future<T> Function() fn) async {
    final result = await fn();
    _recordStateTransition('$operation completed');
    return result;
  }

  /// Verify ViewModel has been properly disposed (for test compatibility).
  bool get isProperlyDisposed => isDisposed;

  // Error injection capabilities (from TestableViewModelBase)
  String? _injectedError;
  bool _shouldFailNextOperation = false;

  /// Inject error for next operation to test error handling.
  void injectError(String errorMessage) {
    _injectedError = errorMessage;
  }

  /// Configure next operation to fail for testing.
  void failNextOperation() {
    _shouldFailNextOperation = true;
  }

  /// Check if error should be injected and consume it.
  String? _consumeInjectedError() {
    final error = _injectedError;
    _injectedError = null;
    return error;
  }

  /// Check if operation should fail and consume flag.
  bool _consumeFailureFlag() {
    final shouldFail = _shouldFailNextOperation;
    _shouldFailNextOperation = false;
    return shouldFail;
  }

  String _listId = '';
  UnifiedShoppingList? _currentList;
  bool _isLoading = false;
  bool _isAddingItem = false;
  String _lastActivity = '';
  DateTime _lastActivityTime = DateTime.now();

  // Collaborative state
  final Map<String, String> _participants = {};
  bool _hasConflicts = false;
  bool _canEdit = true;
  bool _canView = true;
  int _totalItems = 0;
  int _completedItems = 0;

  // ==================== COLLABORATIVE SHOPPING STATE ====================

  String get listId => _listId;

  UnifiedShoppingList? get currentList => _currentList;

  @override
  bool get isLoading => _isLoading;

  bool get isAddingItem => _isAddingItem;

  bool get hasData => _currentList != null;

  String get listTitle => _currentList?.name ?? 'Laddar...';

  String get listDescription => _currentList?.description ?? '';

  bool get hasDescription => listDescription.isNotEmpty;

  bool get canEdit => _canEdit;

  bool get canView => _canView;

  int get totalItems => _totalItems;

  int get completedItems => _completedItems;

  String get lastActivity => _lastActivity;
  DateTime get lastActivityTime => _lastActivityTime;
  bool get hasConflicts => _hasConflicts;
  Map<String, String> get participants => Map.from(_participants);

  /// Set collaborative shopping state for testing.
  void setCollaborativeShoppingState({
    String? listId,
    UnifiedShoppingList? currentList,
    bool? isLoading,
    bool? isAddingItem,
    bool? canEdit,
    bool? canView,
    int? totalItems,
    int? completedItems,
    String? lastActivity,
  }) {
    if (listId != null) {
      _listId = listId;
      _recordStateTransition('list_id_set_$listId');
    }
    if (currentList != null) {
      _currentList = currentList;
      _recordStateTransition('current_list_loaded');
    }
    if (isLoading != null) {
      _isLoading = isLoading;
      _recordStateTransition('loading_$isLoading');
    }
    if (isAddingItem != null) {
      _isAddingItem = isAddingItem;
      _recordStateTransition('adding_item_$isAddingItem');
    }
    if (canEdit != null) {
      _canEdit = canEdit;
      _recordStateTransition('can_edit_$canEdit');
    }
    if (canView != null) {
      _canView = canView;
      _recordStateTransition('can_view_$canView');
    }
    if (totalItems != null) {
      _totalItems = totalItems;
      _recordStateTransition('total_items_$totalItems');
    }
    if (completedItems != null) {
      _completedItems = completedItems;
      _recordStateTransition('completed_items_$completedItems');
    }
    if (lastActivity != null) {
      _lastActivity = lastActivity;
      _lastActivityTime = DateTime.now();
      _recordStateTransition('activity_updated');
    }
    notifyListeners();
  }

  /// Simulate collaborative participant management.
  void simulateParticipants({
    required Map<String, String> participants,
    bool hasConflicts = false,
  }) {
    _participants.clear();
    _participants.addAll(participants);
    _hasConflicts = hasConflicts;
    _recordStateTransition('participants_updated_${participants.length}');
    notifyListeners();
  }

  /// Simulate add item operation.
  Future<bool> addItem(String itemName) async {
    return _measureStateChange('add_item', () async {
      setCollaborativeShoppingState(isAddingItem: true);

      await Future.delayed(const Duration(milliseconds: 500));

      final injectedError = _consumeInjectedError();
      final shouldFail = _consumeFailureFlag();

      if (injectedError != null) {
        setError(injectedError);
        setCollaborativeShoppingState(isAddingItem: false);
        return false;
      } else if (shouldFail) {
        setError('Kunde inte lägga till vara');
        setCollaborativeShoppingState(isAddingItem: false);
        return false;
      } else {
        setCollaborativeShoppingState(
          isAddingItem: false,
          totalItems: _totalItems + 1,
          lastActivity: 'Lade till "$itemName"',
        );
        _recordStateTransition('item_added');
        return true;
      }
    });
  }

  /// Simulate toggle item completion.
  Future<bool> toggleItemCompletion(String itemId) async {
    return _measureStateChange('toggle_item', () async {
      await Future.delayed(const Duration(milliseconds: 300));

      final shouldFail = _consumeFailureFlag();

      if (shouldFail) {
        setError('Kunde inte uppdatera vara');
        return false;
      } else {
        // Toggle completion count
        final isCompleting = _completedItems < _totalItems;
        setCollaborativeShoppingState(
          completedItems:
              isCompleting ? _completedItems + 1 : _completedItems - 1,
          lastActivity:
              isCompleting ? 'Markerade vara som köpt' : 'Avmarkerade vara',
        );
        _recordStateTransition('item_toggled');
        return true;
      }
    });
  }

  /// Simulate refresh operation.
  Future<void> refresh() async {
    return _measureStateChange('refresh', () async {
      setCollaborativeShoppingState(isLoading: true);

      await Future.delayed(const Duration(milliseconds: 800));

      final shouldFail = _consumeFailureFlag();

      if (shouldFail) {
        setError('Kunde inte uppdatera lista');
        setCollaborativeShoppingState(isLoading: false);
      } else {
        setCollaborativeShoppingState(
          isLoading: false,
          lastActivity: 'Lista uppdaterad',
        );
        _recordStateTransition('refreshed');
      }
    });
  }

  // ==================== REQUIRED INTERFACE METHODS ====================

  bool canEditShoppingList(String listId) => _canEdit;

  bool canViewShoppingList(String listId) => _canView;

  // Additional methods that may be required by the interface
  // These would be implemented based on the actual CollaborativeShoppingViewModel interface
}

// ==================== DISCOVERY DASHBOARD VIEWMODEL ====================

/// Testable DiscoveryDashboardViewModel with tab and scroll controller simulation.
class TestableDiscoveryDashboardViewModel extends TestableViewModelBase
    implements DiscoveryDashboardViewModel {
  int _activeTabIndex = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreContent = true;

  // Tab-specific content
  final Map<int, List<dynamic>> _tabContent = {
    0: [], // Recommendations
    1: [], // Friends Activity
    2: [], // Trending
  };

  // Scroll state
  bool _isScrolledToTop = true;
  double _scrollOffset = 0.0;

  // ==================== DASHBOARD STATE ====================

  int get activeTabIndex => _activeTabIndex;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isLoadingMore => _isLoadingMore;

  @override
  bool get hasMoreContent => _hasMoreContent;
  bool get isScrolledToTop => _isScrolledToTop;
  double get scrollOffset => _scrollOffset;

  /// Set dashboard state for testing.
  void setDashboardState({
    int? activeTabIndex,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreContent,
  }) {
    if (activeTabIndex != null) {
      _activeTabIndex = activeTabIndex;
      _recordStateTransition('tab_changed_$activeTabIndex');
    }
    if (isLoading != null) {
      _isLoading = isLoading;
      _recordStateTransition('loading_$isLoading');
    }
    if (isLoadingMore != null) {
      _isLoadingMore = isLoadingMore;
      _recordStateTransition('loading_more_$isLoadingMore');
    }
    if (hasMoreContent != null) {
      _hasMoreContent = hasMoreContent;
    }
    notifyListeners();
  }

  /// Simulate tab controller initialization and synchronization.
  void simulateTabControllerSync({
    required int tabCount,
    int initialTab = 0,
  }) {
    _activeTabIndex = initialTab;

    // Initialize tab content
    for (int i = 0; i < tabCount; i++) {
      _tabContent[i] = [];
    }

    _recordStateTransition('tab_controller_initialized_${tabCount}_tabs');
    notifyListeners();
  }

  /// Simulate scroll controller setup and infinite loading.
  void simulateScrollControllerSetup() {
    _isScrolledToTop = true;
    _scrollOffset = 0.0;
    _recordStateTransition('scroll_controller_initialized');
    notifyListeners();
  }

  /// Simulate infinite scroll loading.
  Future<void> simulateLoadMore({
    Duration delay = const Duration(milliseconds: 800),
    bool hasMoreAfterLoad = true,
  }) async {
    return _measureStateChange('load_more_content', () async {
      setDashboardState(isLoadingMore: true);

      await Future.delayed(delay);

      // Add mock content to active tab
      final currentContent = _tabContent[_activeTabIndex] ?? [];
      _tabContent[_activeTabIndex] = [
        ...currentContent,
        ...List.generate(10, (i) => 'Content ${currentContent.length + i}')
      ];

      setDashboardState(
        isLoadingMore: false,
        hasMoreContent: hasMoreAfterLoad,
      );
    });
  }

  /// Simulate scroll position changes.
  void simulateScrollChange(double offset) {
    _scrollOffset = offset;
    _isScrolledToTop = offset <= 0;
    _recordStateTransition('scroll_offset_${offset.toInt()}');
    notifyListeners();
  }
}

// ==================== COLLABORATIVE CONFLICT TYPES ====================

/// Types of collaborative editing conflicts for testing scenarios.
enum ConflictType {
  simultaneousEdit,
  permissionChanged,
  recipeDeleted,
  networkConflict,
}

extension ConflictTypeExtension on ConflictType {
  String get swedishDescription {
    switch (this) {
      case ConflictType.simultaneousEdit:
        return 'En annan användare redigerar detta recept';
      case ConflictType.permissionChanged:
        return 'Dina behörigheter för detta recept har ändrats';
      case ConflictType.recipeDeleted:
        return 'Detta recept har tagits bort av ägaren';
      case ConflictType.networkConflict:
        return 'Nätverkskonflikt upptäckt vid synkronisering';
    }
  }
}

// ==================== FACTORY METHODS ====================

/// Factory methods for creating pre-configured testable ViewModels.
class TestableViewModelFactory {
  /// Create testable AuthViewModel for authentication tests.
  static TestableAuthViewModel createAuthViewModel({
    bool isAuthenticated = false,
    bool isLoading = false,
    String? userId,
    String? email,
  }) {
    final viewModel = TestableAuthViewModel();
    viewModel.setAuthenticationState(
      isAuthenticated: isAuthenticated,
      isLoading: isLoading,
      userId: userId,
      email: email,
    );
    return viewModel;
  }

  /// Create testable RecipeFormViewModel for recipe editing tests.
  static TestableRecipeFormViewModel createRecipeFormViewModel({
    Recipe? recipe,
    bool isCollaborative = false,
    bool hasConflicts = false,
  }) {
    final viewModel = TestableRecipeFormViewModel();
    viewModel.setRecipeFormState(
      recipe: recipe,
      isCollaborativeMode: isCollaborative,
    );

    if (hasConflicts) {
      viewModel.simulateCollaborativeConflict(
        conflictingUser: 'Anna Andersson',
        conflictType: ConflictType.simultaneousEdit,
      );
    }

    return viewModel;
  }

  /// Create testable UnifiedShoppingViewModel for shopping tests.
  static TestableUnifiedShoppingViewModel createShoppingViewModel({
    List<UnifiedShoppingList>? lists,
    bool isCollaborative = false,
  }) {
    final viewModel = TestableUnifiedShoppingViewModel();
    viewModel.setShoppingState(
      lists: lists ?? [],
      isLoading: false,
    );

    if (isCollaborative) {
      viewModel.simulateCollaborativeEditing(
        listId: 'test-list',
        collaborators: ['Anna', 'Erik'],
      );
    }

    return viewModel;
  }

  /// Create testable CollaborativeShoppingViewModel for collaborative shopping tests.
  static TestableCollaborativeShoppingViewModel
      createCollaborativeShoppingViewModel({
    String? listId,
    UnifiedShoppingList? currentList,
    bool hasData = true,
    bool isLoading = false,
    bool canEdit = true,
    bool canView = true,
    int totalItems = 3,
    int completedItems = 1,
    Map<String, String>? participants,
    bool hasConflicts = false,
  }) {
    final viewModel = TestableCollaborativeShoppingViewModel();

    // Set up basic state
    viewModel.setCollaborativeShoppingState(
      listId: listId ?? 'test-collaborative-list-123',
      currentList: hasData ? (currentList ?? _createTestShoppingList()) : null,
      isLoading: isLoading,
      canEdit: canEdit,
      canView: canView,
      totalItems: totalItems,
      completedItems: completedItems,
      lastActivity: 'Lista skapad',
    );

    // Set up collaborative features
    if (participants != null) {
      viewModel.simulateParticipants(
        participants: participants,
        hasConflicts: hasConflicts,
      );
    }

    return viewModel;
  }

  /// Create testable DiscoveryDashboardViewModel for dashboard tests.
  static TestableDiscoveryDashboardViewModel createDiscoveryDashboardViewModel({
    int tabCount = 3,
    int initialTab = 0,
  }) {
    final viewModel = TestableDiscoveryDashboardViewModel();
    viewModel.simulateTabControllerSync(
      tabCount: tabCount,
      initialTab: initialTab,
    );
    viewModel.simulateScrollControllerSetup();
    return viewModel;
  }

  /// Create a test shopping list with Swedish defaults.
  static UnifiedShoppingList _createTestShoppingList() {
    return UnifiedShoppingList(
      id: 'test-collaborative-list-123',
      name: 'Gemensam handlingslista',
      description: 'Delad lista för familjen',
      ownerId: 'test-user-123',
      ownerDisplayName: 'Test Användare',
      type: ListType.collaborative,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      items: [],
      memberPermissions: {
        'test-user-123': SharedListPermission.admin,
        'test-user-456': SharedListPermission.edit,
      },
    );
  }
}
