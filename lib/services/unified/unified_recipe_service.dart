// lib/services/unified/unified_recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
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

// Legacy feature interfaces (for backward compatibility)
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe_operations.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Unified Recipe Service - Clean coordinator with focused module delegation
///
/// This service provides a clean API that coordinates between focused modules:
/// - PersonalRecipeModule: Personal recipe CRUD operations
/// - SocialRecipeModule: Social recipe sharing and collaboration
/// - RealtimeRecipeModule: Real-time collaborative editing
/// - RecipeCacheModule: Caching and sync management
///
/// ❌ DOES NOT CONTAIN: Business logic implementation, Firebase operations, caching logic
class UnifiedRecipeService extends ChangeNotifier with ErrorHandlingMixin, FirebaseServiceMixin {
  final FirebaseFirestore _firestore;
  final FirebaseAuthRepository _authRepository;

  // Focused modules
  late final PersonalRecipeModule _personalModule;
  late final SocialRecipeModule _socialModule;
  late final RealtimeRecipeModule _realtimeModule;
  late final RecipeCacheModule _cacheModule;

  // Legacy feature interfaces (maintained for backward compatibility)
  late final PersonalRecipeOperations personal;
  late final SocialRecipeOperations social;
  late final RealtimeRecipeOperations realtime;

  // State
  final List<Recipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  UnifiedRecipeService({
    FirebaseFirestore? firestore,
    FirebaseAuthRepository? authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository() {
    
    // Initialize both modules and legacy interfaces
    _initializeModules();
    _initializeLegacyInterfaces();
    
    AppLogger.info('✅ UnifiedRecipeService initialized with focused modules and legacy interfaces');
  }

  // ===== MODULE INITIALIZATION =====

  void _initializeModules() {
    final cacheHelper = JsonCacheFactory.recipeCache();
    
    _personalModule = PersonalRecipeModule(
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
    );

    _socialModule = SocialRecipeModule(
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      notifyListeners: notifyListeners,
      getRecipe: (String id) async => getRecipeById(id),
      saveRecipe: updateRecipe,
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
      cacheHelper: cacheHelper,
      getCurrentUserId: () => currentUserId,
      setError: _setError,
      notifyListeners: notifyListeners,
    );
  }

  void _initializeLegacyInterfaces() {
    // Initialize legacy interfaces for backward compatibility
    personal = PersonalRecipeOperations(this);
    social = SocialRecipeOperations(this);
    realtime = RealtimeRecipeOperations(this);
  }

  // ===== GETTERS =====

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<Recipe> get personalRecipes => recipes.where((r) => r.isPersonal).toList();
  List<Recipe> get collaborativeRecipes => recipes.where((r) => r.isCollaborative).toList();

  bool get hasRecipes => _recipes.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get lastError => _error; // Legacy property

  String? get currentUserId => _authRepository.currentUserId;
  String? get currentUserDisplayName => _authRepository.currentUser?.displayName ?? 'Du';
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

  Future<bool> addMemberToRecipe(String recipeId, String userId, ResourcePermission permission) async {
    return await _socialModule.addMemberToRecipe(recipeId, userId, permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _socialModule.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(String recipeId, String userId, ResourcePermission permission) async {
    return await _socialModule.updateMemberPermission(recipeId, userId, permission);
  }

  // ===== REAL-TIME EDITING OPERATIONS (DELEGATE TO REALTIME MODULE) =====

  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _realtimeModule.startRealtimeEditing(recipeId);
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _realtimeModule.stopRealtimeEditing(recipeId);
  }

  Future<bool> makeRealtimeEdit(String recipeId, Map<String, dynamic> changes) async {
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
      return await _realtimeModule.addIngredientRealtime(recipeId, ingredient, null);
    } else {
      return await _personalModule.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.updateIngredientRealtime(recipeId, index, newIngredient);
    } else {
      return await _personalModule.updateIngredient(recipeId, index, newIngredient);
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
      return await _realtimeModule.addInstructionRealtime(recipeId, instruction, null);
    } else {
      return await _personalModule.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    if (isInRealtimeEditingSession(recipeId)) {
      return await _realtimeModule.updateInstructionRealtime(recipeId, index, newInstruction);
    } else {
      return await _personalModule.updateInstruction(recipeId, index, newInstruction);
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
      return RecipeOperationResult.failure(_error ?? 'Kunde inte ta bort recept');
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