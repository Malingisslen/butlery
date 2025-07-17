/// 🔍 AI INFO BLOCK:
/// Component: Unified Recipe Service - Consolidated service with feature interfaces
/// File: lib/services/unified/unified_recipe_service.dart
/// Quick Guide: Main recipe service with separated feature interfaces for personal, social, and realtime operations
/// Dependencies IN: Firebase, Hive, UnifiedRecipe model, Feature operations
/// Dependencies OUT: Used by all recipe ViewModels through feature interfaces
/// Data flow: ViewModels -> Feature Interfaces -> UnifiedRecipeService -> Firebase/Cache
/// State management: ChangeNotifier with optimistic updates and offline sync
/// Purpose: Single consolidated service for all recipe operations with clean separation
/// Common issues: Offline/online sync, permission validation, conflict resolution
/// Test coverage: Unit tests for all operations and feature interfaces
/// Performance: Optimistic updates with debounced Firebase sync
/// Analytics: Recipe operations, collaboration events, import/export usage
/// Code smells: Large file - separated into feature interfaces for maintainability
/// Connected to: All recipe ViewModels, Import strategies, Social features
/// Used in phases: Phase 5 - Service Consolidation

// lib/services/unified/unified_recipe_service.dart
// ✅ ENHANCED VERSION: Feature interface separation for Phase 5 consolidation

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import '../../core/cache/json_cache_helper.dart';
import '../../models/unified/unified_recipe.dart';
import '../../models/recipe.dart'; // För backwards compatibility
import '../../core/utils/logger.dart';
import '../../core/mixins/firebase_sync_mixin.dart';

// Feature interfaces
import 'operations/personal_recipe_operations.dart';
import 'operations/social_recipe_operations.dart';
import 'operations/realtime_recipe_operations.dart';
import 'types/recipe_types.dart';
import '../permission_service.dart';
import '../../core/injection.dart';

class UnifiedRecipeService extends ChangeNotifier with FirebaseSyncMixin<UnifiedRecipe> {
  final FirebaseFirestore _firestore;
  final FirebaseAuthRepository _authRepository;
  
  /// JSON cache helper for recipe data
  late final JsonCacheHelper _cacheHelper;

  // ===== FEATURE INTERFACES - Phase 5 Enhancement =====
  
  /// Personal recipe operations - handles personal recipe CRUD, import/export
  late final PersonalRecipeOperations personal;
  
  /// Social recipe operations - handles sharing, collaboration, member management
  late final SocialRecipeOperations social;
  
  /// Realtime recipe operations - handles real-time collaborative editing
  late final RealtimeRecipeOperations realtime;

  UnifiedRecipeService({
    FirebaseFirestore? firestore,
    FirebaseAuthRepository? authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository() {
    
    // Initialize feature interfaces
    personal = PersonalRecipeOperations(this);
    social = SocialRecipeOperations(this);
    realtime = RealtimeRecipeOperations(this);
    
    AppLogger.info('✅ UnifiedRecipeService initialized with feature interfaces');
  }


  // State
  final List<UnifiedRecipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ===== GETTERS - Same API as your existing RecipeService =====

  List<UnifiedRecipe> get recipes => List.unmodifiable(_recipes);
  List<UnifiedRecipe> get personalRecipes =>
      recipes.where((r) => r.isPersonal).toList();
  List<UnifiedRecipe> get collaborativeRecipes =>
      recipes.where((r) => r.isCollaborative).toList();

  bool get hasRecipes => _recipes.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  
  @override
  String? get currentUserId => sl<PermissionService>().currentUserId;
  
  @override
  FirebaseFirestore get firestore => _firestore;
  String? get currentUserDisplayName =>
      _authRepository.currentUser?.displayName ?? 'Du';


  // ===== BACKWARDS COMPATIBILITY - för befintlig kod =====

  /// Legacy getter för befintlig kod
  List<Recipe> get legacyRecipes =>
      _recipes.map((r) => r.toLegacyRecipe()).toList();

  /// Legacy method för befintlig kod
  Recipe? getRecipeById(String id) {
    final unifiedRecipe = _recipes.where((r) => r.id == id).firstOrNull;
    return unifiedRecipe?.toLegacyRecipe();
  }

  /// Legacy property för befintlig kod
  String? get lastError => _error;

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initialiserar UnifiedRecipeService...');

      // Firestore configuration för emulator
      if (kDebugMode) {
        try {
          firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings redan satta');
        }
      }

      // Initialize cache helper
      _cacheHelper = JsonCacheFactory.recipeCache();
      _cacheHelper.setCurrentUser(currentUserId);

      // Ladda cached data först (offline-first)
      await _loadCachedRecipes();

      // Lyssna på auth changes using mixin
      _authRepository.authStateChanges().listen((user) {
        onAuthStateChanged(user?.uid);
        _cacheHelper.setCurrentUser(user?.uid);
        if (user == null) {
          _clearAll();
        }
      });

      // Starta Firebase sync om inloggad using mixin
      if (_authRepository.currentUser != null) {
        startFirebaseSync();
      }

      _isInitialized = true;
      AppLogger.success('✅ UnifiedRecipeService initialiserad');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Fel vid initialisering: $e');
      _setError('Kunde inte ladda recept: $e');
    }
  }

  // ===== RECIPE MANAGEMENT =====

  Future<String?> createPersonalRecipe({
    required String name,
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
    if (!sl<PermissionService>().isAuthenticated) {
      _setError('Du måste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Receptnamn kan inte vara tomt');
      return null;
    }

    try {
      final newRecipe = UnifiedRecipe.personal(
        name: name.trim(),
        ownerId: currentUserId!,
        ownerDisplayName: currentUserDisplayName!,
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

      // Lägg till lokalt (optimistic update)
      _recipes.add(newRecipe);
      notifyListeners();

      // Spara till cache
      await _saveToCache(newRecipe);

      // Synka till Firebase
      _scheduleSyncForRecipe(newRecipe.id);

      AppLogger.success('✅ Personligt recept "$name" skapat');
      return newRecipe.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa personligt recept: $e');
      _setError('Kunde inte skapa recept: $e');
      return null;
    }
  }

  Future<String?> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
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
    String? descriptionCollaborative, // ✅ ÄNDRAT
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    if (!sl<PermissionService>().isAuthenticated) {
      _setError('Du måste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Receptnamn kan inte vara tomt');
      return null;
    }

    try {
      // Skapa member permissions
      final memberPermissions = <String, RecipePermission>{};
      for (final memberId in memberIds) {
        memberPermissions[memberId] = RecipePermission.edit;
      }

      final newRecipe = UnifiedRecipe.collaborative(
        name: name.trim(),
        ownerId: currentUserId!,
        ownerDisplayName: currentUserDisplayName!,
        memberPermissions: memberPermissions,
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
        descriptionCollaborative: descriptionCollaborative, // ✅ ÄNDRAT
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      );

      // Lägg till lokalt (optimistic update)
      _recipes.add(newRecipe);
      notifyListeners();

      // Spara till cache
      await _saveToCache(newRecipe);

      // Synka till Firebase (collaborative recipes använder annan collection)
      _scheduleSyncForRecipe(newRecipe.id);

      AppLogger.success(
          '✅ Kollaborativt recept "$name" skapat med ${memberIds.length} medlemmar');
      return newRecipe.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa kollaborativt recept: $e');
      _setError('Kunde inte skapa kollaborativt recept: $e');
      return null;
    }
  }

  Future<bool> updateRecipe(UnifiedRecipe updatedRecipe) async {
    try {
      final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
      if (index == -1) {
        _setError('Recept hittades inte');
        return false;
      }

      // Uppdatera lokalt (optimistic update)
      _recipes[index] = updatedRecipe.copyWith(
        updatedAt: DateTime.now(),
        lastEditedByUserId: currentUserId,
        lastEditedByDisplayName: currentUserDisplayName,
      );
      notifyListeners();

      // Spara till cache
      await _saveToCache(_recipes[index]);

      // Schemalägg synk (debounced)
      _scheduleSyncForRecipe(updatedRecipe.id);

      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte uppdatera recept: $e');
      _setError('Kunde inte uppdatera recept: $e');
      return false;
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    try {
      final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        _setError('Recept hittades inte');
        return false;
      }

      // Ta bort lokalt
      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      // Ta bort från cache
      await _removeFromCache(recipeId);

      // Ta bort från Firebase
      _scheduleDeleteForRecipe(recipeId, recipe.isCollaborative);

      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort recept: $e');
      _setError('Kunde inte ta bort recept: $e');
      return false;
    }
  }

  // ===== COLLABORATIVE EDITING METHODS =====

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? name,
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
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) {
      _setError('Recept hittades inte');
      return false;
    }

    // Check permissions for collaborative recipes
    if (recipe.isCollaborative) {
      if (!sl<PermissionService>().canEditRecipe(recipe.id)) {
        _setError('Du har inte behörighet att redigera detta recept');
        return false;
      }
    }

    final updatedRecipe = recipe.copyWith(
      name: name,
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
      updatedAt: DateTime.now(),
      lastEditedByUserId: currentUserId,
      lastEditedByDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.addIngredient(
      ingredient,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String newIngredient) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.updateIngredient(
      index,
      newIngredient,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.removeIngredient(
      index,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.addInstruction(
      instruction,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String newInstruction) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.updateInstruction(
      index,
      newInstruction,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.removeInstruction(
      index,
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final updatedRecipe = recipe.markAsCooked(
      userId: currentUserId,
      userDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }

  // ===== COLLABORATIVE MEMBER MANAGEMENT =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, RecipePermission permission) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null || recipe.isPersonal) return false;

    // Check admin permission
    if (!sl<PermissionService>().canManageRecipeMembers(recipe.id)) {
      _setError('Du har inte behörighet att lägga till medlemmar');
      return false;
    }

    final updatedRecipe = recipe.addMember(userId, permission);
    return await updateRecipe(updatedRecipe);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null || recipe.isPersonal) return false;

    // Check admin permission
    if (!sl<PermissionService>().canManageRecipeMembers(recipe.id)) {
      _setError('Du har inte behörighet att ta bort medlemmar');
      return false;
    }

    final updatedRecipe = recipe.removeMember(userId);
    return await updateRecipe(updatedRecipe);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, RecipePermission permission) async {
    final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null || recipe.isPersonal) return false;

    // Check admin permission
    if (!sl<PermissionService>().canManageRecipeMembers(recipe.id)) {
      _setError('Du har inte behörighet att ändra behörigheter');
      return false;
    }

    final updatedRecipe = recipe.updateMemberPermission(userId, permission);
    return await updateRecipe(updatedRecipe);
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  /// För befintlig kod som använder Recipe model
  Future<RecipeOperationResult> addRecipe(Recipe legacyRecipe) async {
    try {
      final recipeId = await createPersonalRecipe(
        name: legacyRecipe.title,
        description: legacyRecipe.description,
        ingredients: legacyRecipe.ingredients,
        instructions: legacyRecipe.instructions,
        imageUrls: legacyRecipe.imageUrls,
        mealType: legacyRecipe.mealType,
        portions: legacyRecipe.portions,
        timeMinutes: legacyRecipe.timeMinutes,
        rating: legacyRecipe.rating,
        tags: legacyRecipe.tags,
        sourceUrl: legacyRecipe.sourceUrl,
      );

      if (recipeId != null) {
        return RecipeOperationResult.success();
      } else {
        return RecipeOperationResult.failure(
            _error ?? 'Kunde inte skapa recept');
      }
    } catch (e) {
      return RecipeOperationResult.failure(e.toString());
    }
  }

  /// För befintlig kod som använder Recipe model
  Future<RecipeOperationResult> updateLegacyRecipe(Recipe legacyRecipe) async {
    try {
      // Find unified recipe by ID
      final unifiedRecipe =
          _recipes.where((r) => r.id == legacyRecipe.id).firstOrNull;
      if (unifiedRecipe == null) {
        return RecipeOperationResult.failure('Recept hittades inte');
      }

      // Convert legacy recipe to unified recipe
      final updatedRecipe = unifiedRecipe.copyWith(
        name: legacyRecipe.title,
        description: legacyRecipe.description,
        ingredients: legacyRecipe.ingredients,
        instructions: legacyRecipe.instructions,
        imageUrls: legacyRecipe.imageUrls,
        mealType: legacyRecipe.mealType,
        portions: legacyRecipe.portions,
        timeMinutes: legacyRecipe.timeMinutes,
        rating: legacyRecipe.rating,
        tags: legacyRecipe.tags,
        sourceUrl: legacyRecipe.sourceUrl,
        lastCookedAt: legacyRecipe.lastCookedAt,
      );

      final success = await updateRecipe(updatedRecipe);
      if (success) {
        return RecipeOperationResult.success();
      } else {
        return RecipeOperationResult.failure(
            _error ?? 'Kunde inte uppdatera recept');
      }
    } catch (e) {
      return RecipeOperationResult.failure(e.toString());
    }
  }

  /// För befintlig kod
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

      // Reload from cache first
      await _loadCachedRecipes();

      // Restart Firebase sync to get latest data
      stopFirebaseSync();
      if (_authRepository.currentUser != null) {
        startFirebaseSync();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Kunde inte uppdatera recept: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== PRIVATE SYNC METHODS =====

  void _scheduleSyncForRecipe(String recipeId) {
    // Use mixin's debounced sync method
    scheduleSyncForItem(recipeId);
  }

  void _scheduleDeleteForRecipe(String recipeId, bool isCollaborative) {
    // För borttagning, gör direkt utan debounce
    _deleteRecipeFromFirebase(recipeId, isCollaborative);
  }

  // Sync pending recipes now handled by mixin's processSyncItems method

  // ===== FIREBASE SYNC METHODS =====

  Future<void> _syncRecipeToFirebase(UnifiedRecipe recipe) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_recipes')
          .doc(recipe.id)
          .set(recipe.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Recept synkat: ${recipe.name}');
    } catch (e) {
      AppLogger.error('Firebase synk-fel för recept ${recipe.id}: $e');
    }
  }

  Future<void> _syncCollaborativeRecipeToFirebase(UnifiedRecipe recipe) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('unified_collaborative_recipes')
          .doc(recipe.id)
          .set(recipe.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Kollaborativt recept synkat: ${recipe.name}');
    } catch (e) {
      AppLogger.error(
          'Firebase synk-fel för kollaborativt recept ${recipe.id}: $e');
    }
  }

  // ===== FIREBASE SYNC MIXIN IMPLEMENTATION =====
  
  @override
  List<SyncCollection> get syncCollections => [
    SyncCollection(
      name: 'personal_recipes',
      query: () => firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('unified_recipes'),
      onAdded: (doc) => _handlePersonalRecipesChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handlePersonalRecipesChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handlePersonalRecipesChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Personal recipes sync error: $error'),
    ),
    SyncCollection(
      name: 'collaborative_recipes',
      query: () => firestore
          .collection('unified_collaborative_recipes')
          .where('memberPermissions.$currentUserId', isNotEqualTo: null),
      onAdded: (doc) => _handleCollaborativeRecipesChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handleCollaborativeRecipesChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handleCollaborativeRecipesChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Collaborative recipes sync error: $error'),
    ),
  ];
  
  @override
  Future<void> syncItemToFirebase(String itemId) async {
    final recipe = _recipes.where((r) => r.id == itemId).firstOrNull;
    if (recipe == null) return;

    if (recipe.isCollaborative) {
      await _syncCollaborativeRecipeToFirebase(recipe);
    } else {
      await _syncRecipeToFirebase(recipe);
    }
  }

  // Firebase sync now handled by mixin - removed manual subscription management

  void _handlePersonalRecipesChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final recipe = UnifiedRecipe.fromFirestore(doc);

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalRecipe(recipe);
          break;
        case DocumentChangeType.removed:
          _removeLocalRecipe(recipe.id);
          break;
      }
    } catch (e) {
      AppLogger.error('Fel vid hantering av personal recipes change: $e');
    }
  }

  void _handleCollaborativeRecipesChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final recipe = UnifiedRecipe.fromFirestore(doc);

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalRecipe(recipe);
          break;
        case DocumentChangeType.removed:
          _removeLocalRecipe(recipe.id);
          break;
      }
    } catch (e) {
      AppLogger.error(
          'Fel vid hantering av collaborative recipes change: $e');
    }
  }

  void _updateLocalRecipe(UnifiedRecipe updatedRecipe) {
    final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index != -1) {
      _recipes[index] = updatedRecipe;
    } else {
      _recipes.add(updatedRecipe);
    }
    _saveToCache(updatedRecipe);
  }

  /// Public method for feature interfaces to update local recipe
  void updateLocalRecipe(UnifiedRecipe updatedRecipe) {
    _updateLocalRecipe(updatedRecipe);
    notifyListeners();
  }

  void _removeLocalRecipe(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    _removeFromCache(recipeId);
  }

  // ===== CACHE METHODS =====

  Future<void> _loadCachedRecipes() async {
    try {
      final cachedRecipeIds = await _cacheHelper.getAllKeys();

      for (final recipeId in cachedRecipeIds) {
        final recipeData = await _cacheHelper.loadJson(recipeId);
        if (recipeData != null) {
          try {
            final recipe = UnifiedRecipe.fromJson(recipeData);
            _recipes.add(recipe);
            AppLogger.debug('Laddat cached recept: ${recipe.name}');
          } catch (e) {
            AppLogger.error('Fel vid parsing av cached recept $recipeId: $e');
            await _cacheHelper.delete(recipeId);
          }
        }
      }

      AppLogger.debug('✅ ${_recipes.length} cached recipes laddade');
    } catch (e) {
      AppLogger.error('Fel vid laddning av cached recipes: $e');
    }
  }

  Future<void> _saveToCache(UnifiedRecipe recipe) async {
    try {
      final recipeData = recipe.toJson();
      await _cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Recept cachat: ${recipe.name}');
    } catch (e) {
      AppLogger.error('Fel vid sparande till cache: $e');
    }
  }

  Future<void> _removeFromCache(String recipeId) async {
    try {
      await _cacheHelper.delete(recipeId);
      AppLogger.debug('Recept borttaget från cache: $recipeId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från cache: $e');
    }
  }

  Future<void> _deleteRecipeFromFirebase(
      String recipeId, bool isCollaborative) async {
    try {
      if (isCollaborative) {
        await firestore
            .collection('unified_collaborative_recipes')
            .doc(recipeId)
            .delete();
      } else {
        await firestore
            .collection('users')
            .doc(currentUserId)
            .collection('unified_recipes')
            .doc(recipeId)
            .delete();
      }
      AppLogger.debug('Recept borttaget från Firebase: $recipeId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från Firebase: $e');
    }
  }

  // ===== ERROR HANDLING =====

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearAll() {
    _recipes.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Error handling methods already exist in the class

  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}

// ===== LEGACY COMPATIBILITY =====
// RecipeOperationResult moved to types/recipe_types.dart to avoid duplication
