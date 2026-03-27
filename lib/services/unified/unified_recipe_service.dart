// lib/services/unified/unified_recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rxdart/rxdart.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

// Focused modules
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/social_recipe_module.dart';
import 'package:butlery/services/unified/modules/realtime_recipe_module.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/services/storage_service.dart';

// Legacy feature interfaces (for backward compatibility)
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/helpers/social_operations_initializer.dart';
import 'package:butlery/services/unified/helpers/recipe_content_operations.dart';
import 'package:butlery/services/unified/helpers/recipe_auth_state_handler.dart';
import 'package:butlery/services/unified/helpers/personal_recipe_crud.dart';
import 'package:butlery/services/unified/helpers/recipe_utility_operations.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';

/// Unified recipe service coordinating personal, social, and real-time recipe operations.
///
/// ## Usage
/// ```dart
/// final service = ServiceLocator.get<UnifiedRecipeService>();
///
/// // Personal recipe operations
/// final recipe = await service.personal.createRecipe(title: 'Pasta', ...);
/// await service.personal.updateRecipe(recipe.copyWith(title: 'Updated'));
///
/// // Social sharing
/// await service.social.shareRecipe(recipeId: recipe.id, userIds: [...]);
///
/// // Real-time collaboration
/// service.realtime.watchRecipe(recipe.id).listen((updated) => ...);
/// ```
///
/// Delegates to specialized modules (PersonalRecipeModule, SocialRecipeModule,
/// RealtimeRecipeModule, RecipeCacheModule) with backward-compatible legacy interfaces.
class UnifiedRecipeService
    with ErrorHandlingMixin, FirebaseServiceMixin
    implements NotificationParent, PersonalRecipeDelegate {
  final FirebaseFirestore _firestore;
  final FirebaseAuthRepository _authRepository;
  final RecipeRepository? _recipeRepository;
  final CommentsRepository? _commentsRepository;
  final RatingsRepository? _ratingsRepository;
  final NotificationsRepository? _notificationsRepository;
  final FirestoreRepository _firestoreRepository;

  // Focused modules
  late final PersonalRecipeModule _personalModule;
  late final SocialRecipeModule _socialModule;
  late final RealtimeRecipeModule _realtimeModule;
  late final RecipeCacheModule _cacheModule;
  bool _modulesInitialized = false;

  // Legacy feature interfaces (maintained for backward compatibility)
  late final PersonalRecipeOperations personal;
  late final SocialRecipeOperations social;
  late final RealtimeRecipeOperations realtime;

  // Explicit initialization tracking (replaces try-catch pattern)
  bool _socialInitialized = false;

  // Cancellable timer for social operations retry
  Timer? _socialRetryTimer;

  // Content operations helper
  late final RecipeContentOperations _contentOps;

  // Auth state handler
  late final RecipeAuthStateHandler _authHandler;

  // Personal recipe CRUD helper
  late final PersonalRecipeCrud _personalCrud;

  // Utility operations helper
  late final RecipeUtilityOperations _utilityOps;

  // Discovery service accessor
  RecipeDiscoveryService get discovery {
    // Ensure social operations are initialized before accessing
    _initializeSocialOperations();
    return social.discoveryService;
  }

  // State
  final List<Recipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  final _stateSubject =
      BehaviorSubject<RecipeServiceState>.seeded(const RecipeStateLoading());

  Stream<RecipeServiceState> get stateStream => _stateSubject.stream;
  RecipeServiceState get currentState => _stateSubject.value;

  void notifyListeners() {
    _emitState();
  }

  void _emitState() {
    if (_stateSubject.isClosed) return;
    if (!_isInitialized && _error == null) {
      _stateSubject.add(const RecipeStateLoading());
      return;
    }
    if (_error != null && _recipes.isEmpty) {
      _stateSubject.add(RecipeStateError(message: _error!));
      return;
    }
    _stateSubject.add(RecipeStateData(
      recipes: _recipes,
      error: _error,
    ));
  }

  // Auth state subscription (stored to prevent garbage collection)
  StreamSubscription<User?>? _authSubscription;

  /// CRIT-7: Stream controller for tagging failure notifications.
  /// UI can listen to this stream to show snackbars when tagging fails.
  final _taggingFailureController = StreamController<String>.broadcast();

  /// CRIT-7: Stream of recipe titles for which tagging has failed.
  /// Listen to this stream to show user-facing notifications.
  Stream<String> get taggingFailures => _taggingFailureController.stream;

  UnifiedRecipeService({
    FirebaseAuthRepository? authRepository,
    RecipeRepository? recipeRepository,
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    NotificationsRepository? notificationsRepository,
    FirestoreRepository? firestoreRepository,
  })  : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
        _firestore =
            (firestoreRepository ?? ServiceLocator.get<FirestoreRepository>())
                .firestore,
        _authRepository = authRepository ?? FirebaseAuthRepository(),
        _recipeRepository = recipeRepository,
        _commentsRepository = commentsRepository,
        _ratingsRepository = ratingsRepository,
        _notificationsRepository = notificationsRepository {
    // Initialize legacy interfaces immediately for backward compatibility
    _initializeLegacyInterfaces();

    // Delay module initialization to avoid circular dependencies
    Future.microtask(() {
      _initializeModules();
    });

    AppLogger.info(
      '✅ UnifiedRecipeService initialized with focused modules and legacy interfaces',
    );
  }
  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  /// Get recipe repository with fallback to service locator
  RecipeRepository _getRecipeRepository() {
    return _recipeRepository ?? ServiceLocator.get<RecipeRepository>();
  }

  /// Try to get TaggingService from service locator.
  /// Returns null if not registered (tagging is optional).
  TaggingService? _tryGetTaggingService() {
    try {
      return ServiceLocator.get<TaggingService>();
    } catch (_) {
      return null;
    }
  }

  /// Try to get PersonalTagService from service locator.
  /// Returns null if not registered (personal tags are optional).
  PersonalTagService? _tryGetPersonalTagService() {
    try {
      return ServiceLocator.get<PersonalTagService>();
    } catch (_) {
      return null;
    }
  }

  /// Create service adapter with all dependencies
  /// Made lazy to avoid circular dependency issues during initialization
  RecipeServiceAdapter? _serviceAdapter;
  RecipeServiceAdapter _getServiceAdapter() {
    // Lazy initialization to avoid circular dependencies
    _serviceAdapter ??= RecipeServiceAdapter(
      recipeRepository:
          _recipeRepository ?? ServiceLocator.get<RecipeRepository>(),
      commentsRepository:
          _commentsRepository ?? ServiceLocator.tryGet<CommentsRepository>(),
      ratingsRepository:
          _ratingsRepository ?? ServiceLocator.tryGet<RatingsRepository>(),
      notificationsRepository: _notificationsRepository ??
          ServiceLocator.tryGet<NotificationsRepository>(),
      storageService: ServiceLocator.tryGet<StorageService>(),
    );
    return _serviceAdapter!;
  }

  // Lazy cache helper getter
  JsonCacheHelper? _cacheHelperField;
  JsonCacheHelper get _cacheHelper {
    if (_cacheHelperField == null) {
      final offlineService = ServiceLocator.get<OfflineService>();
      _cacheHelperField = JsonCacheHelper(
        'unified_recipes_cache',
        offlineService.database.cacheDao,
      );
    }
    return _cacheHelperField!;
  }

  void _initializeModules() {
    _personalModule = PersonalRecipeModule(
      recipeRepository: _getRecipeRepository(),
      userRepository: ServiceLocator.get<UserRepository>(),
      getCacheHelper: () => _cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getServiceAdapter: () => _getServiceAdapter(),
      taggingService: _tryGetTaggingService(),
      personalTagService: _tryGetPersonalTagService(),
      // CRIT-7: Wire up tagging failure notifications to stream
      onTaggingFailed: (recipeTitle) {
        _taggingFailureController.add(recipeTitle);
      },
    );

    _socialModule = SocialRecipeModule(
      getCacheHelper: () => _cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getRecipe: (String id) async => getRecipeById(id),
      saveRecipe: saveRecipeForSocialModule,
    );

    _realtimeModule = RealtimeRecipeModule(
      firestore: _firestore,
      getCacheHelper: () => _cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getRecipe: (String id) async => getRecipeById(id),
    );

    _cacheModule = RecipeCacheModule(
      firestore: _firestore,
      cacheHelper: _cacheHelper,
      getCurrentUserId: () => currentUserId,
      setError: _setError,
      notifyListeners: notifyListeners,
      // BUG-003: On web, cache is stubbed so we update _recipes directly
      onRecipeUpdated: kIsWeb ? _handleDirectRecipeUpdate : null,
      onRecipeRemoved: kIsWeb ? _handleDirectRecipeRemoval : null,
    );

    _contentOps = RecipeContentOperations(
      personalModule: _personalModule,
      realtimeModule: _realtimeModule,
      isInRealtimeSession: (recipeId) =>
          _realtimeModule.isInRealtimeEditingSession(recipeId),
    );

    _authHandler = RecipeAuthStateHandler(
      cacheModule: _cacheModule,
      authRepository: _authRepository,
      fetchRecipesFromFirebase: (userId) =>
          _getRecipeRepository().fetchUserRecipes(userId),
      recipes: _recipes,
      setError: _setError,
      setLoading: (loading) => _isLoading = loading,
      notifyListeners: notifyListeners,
    );

    _personalCrud = PersonalRecipeCrud(
      personalModule: _personalModule,
      cacheModule: _cacheModule,
      recipes: _recipes,
      notifyListeners: notifyListeners,
    );

    _utilityOps = RecipeUtilityOperations(
      cacheModule: _cacheModule,
      authRepository: _authRepository,
      recipes: _recipes,
      getServiceAdapter: () => _getServiceAdapter(),
      getRecipeById: (id) => getRecipeById(id),
      setError: _setError,
      setLoading: (loading) => _isLoading = loading,
      notifyListeners: notifyListeners,
    );

    _modulesInitialized = true;
  }

  String? _userIdGetter() => currentUserId;
  String? _displayNameGetter() => currentUserDisplayName;
  List<Recipe> _recipesGetter() => recipes;

  SocialOpsContext get _socialContext => SocialOpsContext(
        getCurrentUserId: _userIdGetter,
        getCurrentUserDisplayName: _displayNameGetter,
        getRecipes: _recipesGetter,
        updateRecipe: updateRecipe,
        createCollaborativeRecipe: createCollaborativeRecipe,
        createPersonalRecipe: createPersonalRecipe,
      );

  void _initializeLegacyInterfaces() {
    // Initialize legacy interfaces for backward compatibility
    personal = PersonalRecipeOperations(this);
    realtime = RealtimeRecipeOperations(
      getCurrentUserId: _userIdGetter,
      getCurrentUserDisplayName: _displayNameGetter,
      getRecipes: _recipesGetter,
      notificationParent: this,
      updateRecipeContent: updateRecipeContent,
      createCollaborativeRecipe: createCollaborativeRecipe,
      createPersonalRecipe: createPersonalRecipe,
      deleteRecipe: deleteRecipe,
    );

    // SocialRecipeOperations needs repositories - try immediate initialization or defer
    final initializedSocial = SocialOperationsInitializer.tryInitialize(
      _socialContext,
      _ratingsRepository,
      _firestoreRepository,
    );

    if (initializedSocial != null) {
      social = initializedSocial;
      _socialInitialized = true;
    } else {
      // Defer initialization
      Future.microtask(() => _initializeSocialOperations());
    }
  }

  void _initializeSocialOperations() {
    // Check if already initialized using explicit flag
    if (_socialInitialized) return;

    // Try to initialize with available repositories
    final initialized = SocialOperationsInitializer.tryInitialize(
      _socialContext,
      _ratingsRepository,
      _firestoreRepository,
    );

    if (initialized != null) {
      social = initialized;
      _socialInitialized = true;
    } else {
      // Create with fallback repositories and schedule retry
      social = SocialOperationsInitializer.initializeWithFallback(
        _socialContext,
        _ratingsRepository,
        _firestoreRepository,
        _authRepository,
      );
      _socialInitialized = true;

      _socialRetryTimer = SocialOperationsInitializer.scheduleRetry(
        _socialContext,
        (operations) {
          social = operations;
          _socialInitialized = true;
        },
        const Duration(milliseconds: 500),
        onTimerCreated: (timer) => _socialRetryTimer = timer,
      );
    }
  }

  bool _areModulesInitialized() => _modulesInitialized;

  /// Fetch all user recipes using cursor-based pagination (no cap).
  @override
  Future<List<Recipe>> fetchAllUserRecipes(String userId) async {
    return await _personalModule.fetchAllUserRecipes(userId);
  }

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<Recipe> get personalRecipes =>
      recipes.where((r) => r.isPersonal).toList();
  List<Recipe> get collaborativeRecipes =>
      recipes.where((r) => r.isCollaborative).toList();

  bool get hasRecipes => _recipes.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get lastError => _error; // Legacy property

  @override
  String? get currentUserId => _authRepository.currentUserId;
  @override
  String? get currentUserDisplayName =>
      _authRepository.currentUser?.displayName ?? 'Du';
  bool get isSyncing {
    try {
      return _cacheModule.isSyncing;
    } catch (_) {
      // Module not yet initialized
      return false;
    }
  }

  bool get hasPendingWrites {
    try {
      return _cacheModule.hasPendingWrites;
    } catch (_) {
      return false;
    }
  }

  bool get isFromCache {
    try {
      return _cacheModule.isFromCache;
    } catch (_) {
      return false;
    }
  }

  /// BUG-003: Handle direct recipe updates on web (bypasses stubbed cache)
  void _handleDirectRecipeUpdate(Recipe recipe) {
    final existingIndex = _recipes.indexWhere((r) => r.id == recipe.id);
    if (existingIndex >= 0) {
      _recipes[existingIndex] = recipe;
    } else {
      _recipes.add(recipe);
    }
    AppLogger.debug('📝 [Web] Direct recipe update: ${recipe.title}');
  }

  /// BUG-003: Handle direct recipe removals on web (bypasses stubbed cache)
  void _handleDirectRecipeRemoval(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    AppLogger.debug('🗑️ [Web] Direct recipe removal: $recipeId');
  }

  /// Public getter for firestore instance (for legacy interfaces)
  @override
  FirebaseFirestore get firestore => _firestore;
  Future<void> initialize() async {
    // Early return guard to prevent double initialization
    if (_isInitialized) {
      return;
    }

    try {
      AppLogger.info(
        '🔄 [UnifiedRecipeService.initialize] Starting initialization (early return guard active)...',
      );
      _isLoading = true;
      notifyListeners();

      // Firestore settings are configured early in main.dart bootstrap
      // (before any DI modules run) to avoid microtask queue races.

      // Wait for modules to be initialized if not already
      if (!_areModulesInitialized()) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_areModulesInitialized()) {
          AppLogger.warning('Modules not initialized, initializing now...');
          _initializeModules();
        }
      }

      // Initialize cache and load cached recipes
      final cachedRecipes = await _cacheModule.initializeCache();
      _recipes.clear();
      _recipes.addAll(cachedRecipes);

      // Listen to auth state changes with error handling
      _authSubscription = _authRepository.authStateChanges().listen(
        (user) {
          try {
            AppLogger.info(
              '🔔 [UnifiedRecipeService] Auth state listener fired - User: ${user?.uid ?? "NULL"}',
            );
            _handleAuthStateChange(user?.uid);
          } catch (e) {
            AppLogger.error(
              '❌ [UnifiedRecipeService] Auth state listener error: $e',
            );
          }
        },
        onError: (error) {
          AppLogger.error(
            '❌ [UnifiedRecipeService] Auth state stream error: $error',
          );
        },
      );
      AppLogger.success(
        '✅ [UnifiedRecipeService] Auth state listener registered',
      );

      // Start Firebase sync if authenticated
      if (_authRepository.currentUser != null) {
        await _cacheModule.startFirebaseSync();

        // BUG-003 FIX: On web, cache is stubbed so we load directly from Firebase
        if (kIsWeb) {
          final userId = _authRepository.currentUserId;
          if (userId != null) {
            final firebaseRecipes =
                await _getRecipeRepository().fetchUserRecipes(userId);
            _recipes.clear();
            _recipes.addAll(firebaseRecipes);
            AppLogger.info(
              '📦 [Web] Loaded ${firebaseRecipes.length} recipes directly from Firebase',
            );
          }
        } else {
          // BUT-198: startFirebaseSync returns immediately (listeners + background fetch).
          // Cache was already loaded earlier in initialize(), real-time listeners
          // will push updates as they arrive — no blocking reload needed.
          AppLogger.info(
            '📦 Firebase sync started, serving ${_recipes.length} cached recipes',
          );
        }
      }

      _isInitialized = true;
      _isLoading = false;
      AppLogger.success('✅ UnifiedRecipeService initialized');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [UnifiedRecipeService] Initialization failed: $e\n$stackTrace',
      );
      _setError(AppLocale.current.errorCouldNotLoadRecipes);
      _isLoading = false;
      notifyListeners();
      rethrow; // CRITICAL: Propagate failure to bootstrap system
    }
  }

  Future<String?> createPersonalRecipe({
    required String title,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async =>
      _personalCrud.createPersonalRecipe(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        imageUrls: imageUrls,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
      );

  @override
  Future<void> saveRecipeRaw(Recipe recipe) async =>
      _personalCrud.saveRecipeRaw(recipe);

  @override
  Future<bool> updateRecipe(Recipe updatedRecipe) async =>
      _personalCrud.updateRecipe(updatedRecipe);

  @override
  Future<bool> deleteRecipe(String recipeId) async =>
      _personalCrud.deleteRecipe(recipeId);

  @override
  Future<bool> markAsCooked(String recipeId) async =>
      _personalCrud.markAsCooked(recipeId);

  /// Save a recipe from the social module - handles both personal and collaborative types.
  /// Unlike [updateRecipe], this does not reject collaborative recipes.
  Future<bool> saveRecipeForSocialModule(Recipe recipe) async =>
      _utilityOps.saveRecipeForSocialModule(recipe);
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> memberIds,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    final recipeId = await _socialModule.createCollaborativeRecipe(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      initialMembers: memberIds,
      description: description,
      portions: portions,
      cookingTime: timeMinutes,
      personalTagIds: personalTagIds,
    );

    // Note: Recipe is already added to _recipes in saveRecipeForSocialModule
    // No need to add it again here

    return recipeId;
  }

  Future<bool> addMemberToRecipe(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async {
    return await _socialModule.addMemberToRecipe(recipeId, userId, permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _socialModule.removeMemberFromRecipe(recipeId, userId);
  }

  /// Remove all sharing from a recipe (revoke all members, mark non-collaborative)
  Future<bool> unshareRecipe(String recipeId) async {
    return await _socialModule.unshareRecipe(recipeId);
  }

  Future<bool> updateMemberPermission(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async {
    return await _socialModule.updateMemberPermission(
      recipeId,
      userId,
      permission,
    );
  }

  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _realtimeModule.startRealtimeEditing(recipeId);
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _realtimeModule.stopRealtimeEditing(recipeId);
  }

  Future<bool> makeRealtimeEdit(
    String recipeId,
    Map<String, dynamic> changes,
  ) async {
    return await _realtimeModule.makeRealtimeEdit(recipeId, changes);
  }

  bool isInRealtimeEditingSession(String recipeId) {
    return _realtimeModule.isInRealtimeEditingSession(recipeId);
  }

  @override
  Future<bool> updateRecipeContent({
    required String recipeId,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async =>
      _utilityOps.updateRecipeContent(
        recipeId: recipeId,
        currentUserId: currentUserId,
        currentUserDisplayName: currentUserDisplayName,
        updateRecipe: updateRecipe,
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        imageUrls: imageUrls,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
      );

  // Ingredient operations (delegated to content helper)
  @override
  Future<bool> addIngredient(String recipeId, String ingredient) async =>
      _contentOps.addIngredient(recipeId, ingredient);

  @override
  Future<bool> updateIngredient(
    String recipeId,
    int index,
    String newIngredient,
  ) async =>
      _contentOps.updateIngredient(recipeId, index, newIngredient);

  @override
  Future<bool> removeIngredient(String recipeId, int index) async =>
      _contentOps.removeIngredient(recipeId, index);

  // Instruction operations (delegated to content helper)
  @override
  Future<bool> addInstruction(String recipeId, String instruction) async =>
      _contentOps.addInstruction(recipeId, instruction);

  @override
  Future<bool> updateInstruction(
    String recipeId,
    int index,
    String newInstruction,
  ) async =>
      _contentOps.updateInstruction(recipeId, index, newInstruction);

  @override
  Future<bool> removeInstruction(String recipeId, int index) async =>
      _contentOps.removeInstruction(recipeId, index);

  Future<bool> markRecipeAsCooked(String recipeId) async {
    return await _personalModule.markRecipeAsCooked(recipeId);
  }

  /// Toggle favorite status for a recipe.
  /// Performs optimistic update via copyWith + updateRecipe.
  Future<bool> toggleFavorite(String recipeId, bool isFavorite) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    final updated = recipe.copyWith(isFavorite: isFavorite);
    return await updateRecipe(updated);
  }

  /// Legacy createRecipe method
  @override
  Future<String?> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> imageUrls,
    required String mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    return await createPersonalRecipe(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
  }

  /// Legacy deleteRecipeById method
  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    final success = await deleteRecipe(id);
    if (success) {
      return RecipeOperationResult.success();
    } else {
      return RecipeOperationResult.failure(
        _error ?? AppLocale.current.errorCouldNotDeleteRecipe,
      );
    }
  }

  /// Legacy refresh method (delegated to utility helper)
  Future<void> refresh() async => _utilityOps.refresh();
  Recipe? getRecipeById(String id) {
    return _recipes.where((r) => r.id == id).firstOrNull;
  }

  // Optimistic local-only list mutations for undo delete support
  void optimisticRemove(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    notifyListeners();
  }

  /// Remove recipe and return its original index for position-aware restore.
  int optimisticRemoveWithIndex(String recipeId) {
    final index = _recipes.indexWhere((r) => r.id == recipeId);
    if (index >= 0) {
      _recipes.removeAt(index);
      notifyListeners();
    }
    return index;
  }

  void optimisticRestore(Recipe recipe) {
    _recipes.add(recipe);
    notifyListeners();
  }

  /// Replace a recipe in the in-memory list without persisting.
  /// Used for optimistic UI updates with rollback on failure.
  void optimisticUpdate(Recipe updated) {
    final index = _recipes.indexWhere((r) => r.id == updated.id);
    if (index >= 0) {
      _recipes[index] = updated;
      notifyListeners();
    }
  }

  /// Insert recipe at a specific position for ordered restore after undo.
  void optimisticRestoreAt(Recipe recipe, int index) {
    if (index >= 0 && index <= _recipes.length) {
      _recipes.insert(index, recipe);
    } else {
      _recipes.add(recipe);
    }
    notifyListeners();
  }

  /// Find recipes by source URL for duplicate detection during import.
  Future<List<Recipe>> findBySourceUrl(String url) async {
    return await _getRecipeRepository().findBySourceUrl(url);
  }

  /// Find recipes by title for duplicate detection during import.
  Future<List<Recipe>> findByTitle(String title) async {
    return await _getRecipeRepository().findByTitle(title);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _handleAuthStateChange(String? userId) {
    _authHandler.handleAuthStateChange(userId);
  }

  void _setError(String message) {
    _error = message.isEmpty ? null : message;
    notifyListeners();
  }

  /// Get service status for debugging
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'loading': _isLoading,
      'error': _error,
      'recipeCount': _recipes.length,
      'personalCount': personalRecipes.length,
      'collaborativeCount': collaborativeRecipes.length,
      'cacheStatus': _areModulesInitialized()
          ? _cacheModule.getSyncStatus()
          : 'not initialized',
      'realtimeStatus': _areModulesInitialized()
          ? _realtimeModule.getRealtimeStatus()
          : 'not initialized',
    };
  }

  /// Reset state for logout. Allows re-initialization for a new user session.
  /// Safe to call mid-operation — cancels subscriptions/timers first, then clears state.
  void resetForLogout() {
    // Cancel subscriptions first to prevent callbacks during reset
    _authSubscription?.cancel();
    _authSubscription = null;
    _socialRetryTimer?.cancel();
    _socialRetryTimer = null;

    // Note: _taggingFailureController kept open — broadcast stream, new listeners after re-login OK

    // Clear recipe state
    _recipes.clear();
    _isInitialized = false;
    _isLoading = false;
    _error = null;
    _socialInitialized = false;
    _serviceAdapter = null;

    if (_areModulesInitialized()) {
      _personalModule.cancelPendingRetries();
      _cacheModule.dispose();
      _realtimeModule.dispose();
      _modulesInitialized = false;
    }

    _stateSubject.add(const RecipeStateLoading());
    AppLogger.info('UnifiedRecipeService reset for logout');
  }

  void dispose() {
    _authSubscription?.cancel();
    _socialRetryTimer?.cancel();
    _taggingFailureController.close();
    _stateSubject.close();

    if (_areModulesInitialized()) {
      _personalModule.cancelPendingRetries();
      _cacheModule.dispose();
      _realtimeModule.dispose();
    }
  }
}
