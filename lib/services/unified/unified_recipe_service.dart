// lib/services/unified/unified_recipe_service.dart
// ✅ FIXAD VERSION: description_collaborative -> descriptionCollaborative

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import '../../models/unified/unified_recipe.dart';
import '../../models/recipe.dart'; // För backwards compatibility
import '../../core/utils/logger.dart';

class UnifiedRecipeService extends ChangeNotifier {
  static const String _hiveBoxName = 'unified_recipes_cache';
  static const Duration _syncDebounce = Duration(seconds: 2);

final FirebaseFirestore _firestore;
final FirebaseAuthRepository _authRepository;

UnifiedRecipeService({
  FirebaseFirestore? firestore,
  FirebaseAuthRepository? authRepository,
})  : _firestore = firestore ?? FirebaseFirestore.instance,
      _authRepository = authRepository ?? FirebaseAuthRepository();


  // State
  final List<UnifiedRecipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  // Firebase listeners
  StreamSubscription<QuerySnapshot>? _personalRecipesSubscription;
  StreamSubscription<QuerySnapshot>? _collaborativeRecipesSubscription;
  Timer? _syncDebounceTimer;

  // Sync queue for offline operations
  final Set<String> _pendingSyncRecipeIds = {};

  // ===== GETTERS - Same API as your existing RecipeService =====

  List<UnifiedRecipe> get recipes => List.unmodifiable(_recipes);
  List<UnifiedRecipe> get personalRecipes =>
      recipes.where((r) => r.isPersonal).toList();
  List<UnifiedRecipe> get collaborativeRecipes =>
      recipes.where((r) => r.isCollaborative).toList();

  bool get hasRecipes => _recipes.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _authRepository.currentUserId;
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
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings redan satta');
        }
      }

      // Öppna Hive box för caching
      final box = await Hive.openBox<String>(_hiveBoxName);

      // Ladda cached data först (offline-first)
      await _loadCachedRecipes(box);

      // Lyssna på auth changes
      _authRepository.authStateChanges().listen((user) {
        if (user != null) {
          _startFirebaseSync();
        } else {
          _stopFirebaseSync();
          _clearAll();
        }
      });

      // Starta Firebase sync om inloggad
      if (_authRepository.currentUser != null) {
        _startFirebaseSync();
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
    if (currentUserId == null) {
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
    if (currentUserId == null) {
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
    if (recipe.isCollaborative && currentUserId != null) {
      if (!recipe.canBeEditedBy(currentUserId!)) {
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
    if (currentUserId != null && !recipe.canManageMembersBy(currentUserId!)) {
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
    if (currentUserId != null && !recipe.canManageMembersBy(currentUserId!)) {
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
    if (currentUserId != null && !recipe.canManageMembersBy(currentUserId!)) {
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
      final box = await Hive.openBox<String>(_hiveBoxName);
      await _loadCachedRecipes(box);

      // Restart Firebase sync to get latest data
      _stopFirebaseSync();
      if (_authRepository.currentUser != null) {
        _startFirebaseSync();
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
    _pendingSyncRecipeIds.add(recipeId);

    // Avbryt tidigare timer
    _syncDebounceTimer?.cancel();

    // Starta ny timer
    _syncDebounceTimer = Timer(_syncDebounce, () {
      _syncPendingRecipes();
    });
  }

  void _scheduleDeleteForRecipe(String recipeId, bool isCollaborative) {
    // För borttagning, gör direkt utan debounce
    _deleteRecipeFromFirebase(recipeId, isCollaborative);
  }

  Future<void> _syncPendingRecipes() async {
    if (_pendingSyncRecipeIds.isEmpty || currentUserId == null) return;

    final recipesToSync = List<String>.from(_pendingSyncRecipeIds);
    _pendingSyncRecipeIds.clear();

    for (final recipeId in recipesToSync) {
      try {
        final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
        if (recipe == null) continue;

        if (recipe.isCollaborative) {
          await _syncCollaborativeRecipeToFirebase(recipe);
        } else {
          await _syncRecipeToFirebase(recipe);
        }
      } catch (e) {
        AppLogger.error('Kunde inte synka recept $recipeId: $e');
      }
    }
  }

  // ===== FIREBASE SYNC METHODS =====

  Future<void> _syncRecipeToFirebase(UnifiedRecipe recipe) async {
    if (currentUserId == null) return;

    try {
      await _firestore
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
      await _firestore
          .collection('unified_collaborative_recipes')
          .doc(recipe.id)
          .set(recipe.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Kollaborativt recept synkat: ${recipe.name}');
    } catch (e) {
      AppLogger.error(
          'Firebase synk-fel för kollaborativt recept ${recipe.id}: $e');
    }
  }

  void _startFirebaseSync() {
    if (currentUserId == null) return;

    AppLogger.info('🔄 Startar Firebase sync för unified recipes...');

    try {
      // Personal recipes
      _personalRecipesSubscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_recipes')
          .snapshots()
          .listen(
        _handlePersonalRecipesSnapshot,
        onError: (error) {
          AppLogger.error('Personal recipes snapshot error: $error');
        },
      );

      // Collaborative recipes
      _collaborativeRecipesSubscription = _firestore
          .collection('unified_collaborative_recipes')
          .where('memberPermissions.$currentUserId', isNotEqualTo: null)
          .snapshots()
          .listen(
        _handleCollaborativeRecipesSnapshot,
        onError: (error) {
          AppLogger.error('Collaborative recipes snapshot error: $error');
        },
      );

      AppLogger.success('✅ Firebase sync startat för recipes');
    } catch (e) {
      AppLogger.error('❌ Kunde inte starta Firebase sync: $e');
    }
  }

  void _stopFirebaseSync() {
    _personalRecipesSubscription?.cancel();
    _collaborativeRecipesSubscription?.cancel();
    _personalRecipesSubscription = null;
    _collaborativeRecipesSubscription = null;
  }

  void _handlePersonalRecipesSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        final recipe = UnifiedRecipe.fromFirestore(change.doc);

        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _updateLocalRecipe(recipe);
            break;
          case DocumentChangeType.removed:
            _removeLocalRecipe(recipe.id);
            break;
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid hantering av personal recipes snapshot: $e');
    }
  }

  void _handleCollaborativeRecipesSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        final recipe = UnifiedRecipe.fromFirestore(change.doc);

        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _updateLocalRecipe(recipe);
            break;
          case DocumentChangeType.removed:
            _removeLocalRecipe(recipe.id);
            break;
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error(
          'Fel vid hantering av collaborative recipes snapshot: $e');
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

  void _removeLocalRecipe(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    _removeFromCache(recipeId);
  }

  // ===== CACHE METHODS =====

  Future<void> _loadCachedRecipes(Box<String> box) async {
    try {
      final cachedRecipeIds = box.keys.toList();

      for (final recipeId in cachedRecipeIds) {
        final cachedData = box.get(recipeId);
        if (cachedData != null) {
          try {
            final recipeData = jsonDecode(cachedData);
            final recipe = UnifiedRecipe.fromJson(recipeData);
            _recipes.add(recipe);
            AppLogger.debug('Laddat cached recept: ${recipe.name}');
          } catch (e) {
            AppLogger.error('Fel vid parsing av cached recept $recipeId: $e');
            await box.delete(recipeId);
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
      final box = await Hive.openBox<String>(_hiveBoxName);
      final recipeData = recipe.toJson();
      final recipeJson = jsonEncode(recipeData);
      await box.put(recipe.id, recipeJson);
      AppLogger.debug('Recept cachat: ${recipe.name}');
    } catch (e) {
      AppLogger.error('Fel vid sparande till cache: $e');
    }
  }

  Future<void> _removeFromCache(String recipeId) async {
    try {
      final box = await Hive.openBox<String>(_hiveBoxName);
      await box.delete(recipeId);
      AppLogger.debug('Recept borttaget från cache: $recipeId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från cache: $e');
    }
  }

  Future<void> _deleteRecipeFromFirebase(
      String recipeId, bool isCollaborative) async {
    try {
      if (isCollaborative) {
        await _firestore
            .collection('unified_collaborative_recipes')
            .doc(recipeId)
            .delete();
      } else {
        await _firestore
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
    _isSyncing = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopFirebaseSync();
    _syncDebounceTimer?.cancel();
    super.dispose();
  }
}

// ===== LEGACY COMPATIBILITY =====

/// Result class för legacy compatibility
class RecipeOperationResult {
  final bool isSuccess;
  final String? message;

  RecipeOperationResult._(this.isSuccess, this.message);

  factory RecipeOperationResult.success([String? message]) =>
      RecipeOperationResult._(true, message);

  factory RecipeOperationResult.failure(String message) =>
      RecipeOperationResult._(false, message);
}
