// lib/services/unified/unified_recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

// Focused modules
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/social_recipe_module.dart';
import 'package:butlery/services/unified/modules/realtime_recipe_module.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';

// Legacy feature interfaces (for backward compatibility)
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Comprehensive unified recipe service providing coordinated access to personal, social, and real-time recipe functionality.
///
/// This service implements a sophisticated recipe management system using modular architecture with focused components
/// for personal recipe operations, social recipe sharing, real-time collaborative editing, and intelligent caching.
/// It provides a unified API surface that coordinates between specialized modules while maintaining backward compatibility
/// and clean separation of concerns for maintainable and scalable recipe management across all application features.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with recipe state changes across all modules
/// - Uses [ErrorHandlingMixin] for comprehensive error management and graceful degradation strategies
/// - Implements [FirebaseServiceMixin] for Firebase integration and authentication-aware operations
/// - Coordinates specialized modules following Single Responsibility Principle for maintainable architecture
///
/// **Modular Coordination Architecture:**
/// This service coordinates between focused modules with clear responsibilities:
/// - **[PersonalRecipeModule]**: Personal recipe CRUD operations, local storage, and user-specific management
/// - **[SocialRecipeModule]**: Social recipe sharing, community features, and friend-based recipe discovery
/// - **[RealtimeRecipeModule]**: Real-time collaborative editing, live synchronization, and conflict resolution
/// - **[RecipeCacheModule]**: Intelligent caching, offline support, and performance optimization strategies
///
/// **Unified API Benefits:**
/// - **Single Entry Point**: Unified interface for all recipe operations reducing complexity for ViewModels
/// - **Coordinated Operations**: Seamless integration between personal, social, and real-time recipe features
/// - **Backward Compatibility**: Legacy operation interfaces maintained for smooth migration and existing code support
/// - **Clean Separation**: Each module handles specific concerns without cross-module business logic contamination
/// - **Reactive Updates**: Comprehensive state management with automatic UI updates across all recipe operations
///
/// **What This Service Does NOT Contain:**
/// - Business logic implementation (delegated to specialized modules for focused responsibility)
/// - Direct Firebase operations (handled by modules and repository layers for proper abstraction)
/// - Caching logic implementation (managed by RecipeCacheModule for performance optimization)
/// - Authentication management (handled by FirebaseAuthRepository and authentication mixins)
///
/// **Usage Examples:**
/// ```dart
/// final recipeService = UnifiedRecipeService(firestore, authRepository);
/// await recipeService.initialize();
///
/// // Personal recipe operations
/// final personalRecipes = await recipeService.personal.getAllRecipes();
/// await recipeService.personal.createRecipe(title: 'Köttbullar');
///
/// // Social recipe sharing
/// await recipeService.social.shareRecipeWithFriend(recipeId, friendId);
/// final sharedRecipes = await recipeService.social.getSharedRecipes();
///
/// // Real-time collaborative editing
/// final realtimeRecipe = await recipeService.realtime.startCollaborativeSession(recipeId);
/// recipeService.realtime.watchRecipeChanges(recipeId).listen(updateUI);
/// ```
class UnifiedRecipeService extends ChangeNotifier
    with ErrorHandlingMixin, FirebaseServiceMixin
    implements NotificationParent {
  final FirebaseFirestore _firestore;
  final FirebaseAuthRepository _authRepository;
  final RecipeRepository? _recipeRepository;
  final CommentsRepository? _commentsRepository;
  final RatingsRepository? _ratingsRepository;
  final NotificationsRepository? _notificationsRepository;
  final FirestoreRepository? _firestoreRepository;

  // Focused modules
  late final PersonalRecipeModule _personalModule;
  late final SocialRecipeModule _socialModule;
  late final RealtimeRecipeModule _realtimeModule;
  late final RecipeCacheModule _cacheModule;

  // Legacy feature interfaces (maintained for backward compatibility)
  late final PersonalRecipeOperations personal;
  late final SocialRecipeOperations social;
  late final RealtimeRecipeOperations realtime;

  // Discovery service accessor
  RecipeDiscoveryService get discovery => social.discoveryService;

  // State
  final List<Recipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  UnifiedRecipeService({
    FirebaseFirestore? firestore,
    FirebaseAuthRepository? authRepository,
    RecipeRepository? recipeRepository,
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    NotificationsRepository? notificationsRepository,
    FirestoreRepository? firestoreRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository(),
        _recipeRepository = recipeRepository,
        _commentsRepository = commentsRepository,
        _ratingsRepository = ratingsRepository,
        _notificationsRepository = notificationsRepository,
        _firestoreRepository = firestoreRepository {
    // Initialize both modules and legacy interfaces
    _initializeModules();
    _initializeLegacyInterfaces();

    AppLogger.info(
        '✅ UnifiedRecipeService initialized with focused modules and legacy interfaces');
  }

  // ===== DEPENDENCY HELPERS =====

  /// Get recipe repository with fallback to service locator
  RecipeRepository _getRecipeRepository() {
    return _recipeRepository ?? ServiceLocator.get<RecipeRepository>();
  }

  /// Create service adapter with all dependencies
  RecipeServiceAdapter _createServiceAdapter() {
    return RecipeServiceAdapter(
      recipeRepository:
          _recipeRepository ?? ServiceLocator.get<RecipeRepository>(),
      commentsRepository:
          _commentsRepository ?? ServiceLocator.get<CommentsRepository>(),
      ratingsRepository:
          _ratingsRepository ?? ServiceLocator.get<RatingsRepository>(),
      notificationsRepository: _notificationsRepository ??
          ServiceLocator.get<NotificationsRepository>(),
    );
  }

  // ===== MODULE INITIALIZATION =====

  void _initializeModules() {
    final cacheHelper = JsonCacheFactory.recipeCache();

    _personalModule = PersonalRecipeModule(
      recipeRepository: _getRecipeRepository(),
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      serviceAdapter: _createServiceAdapter(),
    );

    _socialModule = SocialRecipeModule(
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getRecipe: (String id) async => getRecipeById(id),
      saveRecipe: _saveRecipeForSocialModule,
    );

    _realtimeModule = RealtimeRecipeModule(
      firestore: _firestore,
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getRecipe: (String id) async => getRecipeById(id),
    );

    _cacheModule = RecipeCacheModule(
      firestore: _firestore,
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      setError: _setError,
      notifyListeners: notifyListeners,
    );
  }

  void _initializeLegacyInterfaces() {
    // Initialize legacy interfaces for backward compatibility
    personal = PersonalRecipeOperations(this);
    social = SocialRecipeOperations(
      this,
      ratingsRepository:
          _ratingsRepository ?? ServiceLocator.get<RatingsRepository>(),
      firestoreRepository:
          _firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
    );
    realtime = RealtimeRecipeOperations(this);
  }

  // ===== GETTERS =====

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
  bool get isSyncing => _cacheModule.isSyncing;

  /// Public getter for firestore instance (for legacy interfaces)
  @override
  FirebaseFirestore get firestore => _firestore;

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initializing UnifiedRecipeService...');
      _isLoading = true;
      notifyListeners();

      // Configure Firestore settings
      if (kDebugMode) {
        try {
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings already configured');
        }
      }

      // Initialize cache and load cached recipes
      final cachedRecipes = await _cacheModule.initializeCache();
      _recipes.clear();
      _recipes.addAll(cachedRecipes);

      // Listen to auth state changes
      _authRepository.authStateChanges().listen((user) {
        _handleAuthStateChange(user?.uid);
      });

      // Start Firebase sync if authenticated
      if (_authRepository.currentUser != null) {
        await _cacheModule.startFirebaseSync();
      }

      _isInitialized = true;
      _isLoading = false;
      AppLogger.success('✅ UnifiedRecipeService initialized');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Initialization error: $e');
      _setError('Kunde inte ladda recept: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== PERSONAL RECIPE OPERATIONS (DELEGATE TO PERSONAL MODULE) =====

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
    List<String>? tags,
    String? sourceUrl,
  }) async {
    final recipeId = await _personalModule.createPersonalRecipe(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
    );

    if (recipeId != null) {
      // Add to local list
      final recipe = await _cacheModule.loadRecipeFromCache(recipeId);
      if (recipe != null) {
        _recipes.add(recipe);
        notifyListeners();
      }
    }

    return recipeId;
  }

  Future<bool> updateRecipe(Recipe updatedRecipe) async {
    final success = await _personalModule.updatePersonalRecipe(updatedRecipe);

    if (success) {
      // Update local list
      final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
      if (index != -1) {
        _recipes[index] = updatedRecipe;
        notifyListeners();
      }
    }

    return success;
  }

  Future<bool> deleteRecipe(String recipeId) async {
    final success = await _personalModule.deletePersonalRecipe(recipeId);

    if (success) {
      // Remove from local list
      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();
    }

    return success;
  }

  Future<bool> markAsCooked(String recipeId) async {
    return await _personalModule.markRecipeAsCooked(recipeId);
  }

  // ===== INTERNAL SAVE METHOD FOR SOCIAL MODULE =====

  /// Save a recipe from the social module (handles both create and update)
  /// This method determines whether to create a new recipe or update an existing one
  Future<bool> _saveRecipeForSocialModule(Recipe recipe) async {
    try {
      final serviceAdapter = _createServiceAdapter();

      // Check if this recipe already exists in our list
      final existingRecipe = getRecipeById(recipe.id);

      if (existingRecipe != null) {
        // Update existing recipe
        final success = await serviceAdapter.updateRecipe(recipe);
        if (success) {
          // Update local cache
          final index = _recipes.indexWhere((r) => r.id == recipe.id);
          if (index != -1) {
            _recipes[index] = recipe;
            notifyListeners();
          }
        }
        return success;
      } else {
        // Create new recipe
        final createdId = await serviceAdapter.createRecipe(recipe);
        if (createdId != null) {
          // Add to local cache
          _recipes.add(recipe);
          notifyListeners();
          return true;
        }
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Failed to save recipe from social module: $e');
      return false;
    }
  }

  // ===== COLLABORATIVE RECIPE OPERATIONS (DELEGATE TO SOCIAL MODULE) =====

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
    List<String>? tags,
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
      tags: tags,
    );

    // Note: Recipe is already added to _recipes in _saveRecipeForSocialModule
    // No need to add it again here

    return recipeId;
  }

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _socialModule.addMemberToRecipe(recipeId, userId, permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _socialModule.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _socialModule.updateMemberPermission(
        recipeId, userId, permission);
  }

  // ===== REAL-TIME EDITING OPERATIONS (DELEGATE TO REALTIME MODULE) =====

  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _realtimeModule.startRealtimeEditing(recipeId);
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _realtimeModule.stopRealtimeEditing(recipeId);
  }

  Future<bool> makeRealtimeEdit(
      String recipeId, Map<String, dynamic> changes) async {
    return await _realtimeModule.makeRealtimeEdit(recipeId, changes);
  }

  bool isInRealtimeEditingSession(String recipeId) {
    return _realtimeModule.isInRealtimeEditingSession(recipeId);
  }

  // ===== CONTENT OPERATIONS =====

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
    List<String>? tags,
    String? sourceUrl,
  }) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) {
      _setError('Recept hittades inte');
      return false;
    }

    final updatedRecipe = recipe.copyWith(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      lastEditedByUserId: currentUserId,
      lastEditedByDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  // Ingredient operations
  Future<bool> addIngredient(String recipeId, String ingredient) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.addIngredientRealtime(
          recipeId, ingredient, null);
    } else {
      return await _personalModule.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String newIngredient) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.updateIngredientRealtime(
          recipeId, index, newIngredient);
    } else {
      return await _personalModule.updateIngredient(
          recipeId, index, newIngredient);
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.removeIngredientRealtime(recipeId, index);
    } else {
      return await _personalModule.removeIngredient(recipeId, index);
    }
  }

  // Instruction operations
  Future<bool> addInstruction(String recipeId, String instruction) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.addInstructionRealtime(
          recipeId, instruction, null);
    } else {
      return await _personalModule.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String newInstruction) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.updateInstructionRealtime(
          recipeId, index, newInstruction);
    } else {
      return await _personalModule.updateInstruction(
          recipeId, index, newInstruction);
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.removeInstructionRealtime(recipeId, index);
    } else {
      return await _personalModule.removeInstruction(recipeId, index);
    }
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    return await _personalModule.markRecipeAsCooked(recipeId);
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Legacy createRecipe method
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
    List<String>? tags,
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
      tags: tags,
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
          _error ?? 'Kunde inte ta bort recept');
    }
  }

  /// Legacy refresh method
  Future<void> refresh() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Clear local data
      _recipes.clear();

      // Reload from cache
      final cachedRecipes = await _cacheModule.initializeCache();
      _recipes.addAll(cachedRecipes);

      // Restart Firebase sync
      await _cacheModule.stopFirebaseSync();
      if (_authRepository.currentUser != null) {
        await _cacheModule.startFirebaseSync();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Kunde inte uppdatera recept: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  Recipe? getRecipeById(String id) {
    return _recipes.where((r) => r.id == id).firstOrNull;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== AUTH STATE HANDLING =====

  void _handleAuthStateChange(String? userId) {
    _cacheModule.onAuthStateChanged(userId);
    if (userId == null) {
      _clearAll();
    }
  }

  void _clearAll() {
    _recipes.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  // ===== DIAGNOSTICS =====

  /// Get service status for debugging
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'loading': _isLoading,
      'error': _error,
      'recipeCount': _recipes.length,
      'personalCount': personalRecipes.length,
      'collaborativeCount': collaborativeRecipes.length,
      'cacheStatus': _cacheModule.getSyncStatus(),
      'realtimeStatus': _realtimeModule.getRealtimeStatus(),
    };
  }

  @override
  void dispose() {
    _cacheModule.dispose();
    _realtimeModule.dispose();
    super.dispose();
  }
}
