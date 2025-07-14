// lib/services/recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/recipe_change.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';
import 'offline_service.dart';
import 'package:uuid/uuid.dart';
import '../repositories/interfaces/recipe_repository.dart';
import '../repositories/interfaces/auth_repository.dart';

/// RecipeService hanterar all receptlogik med Firestore OCH offline-support
class RecipeService extends ChangeNotifier {
  final RecipeRepository _recipeRepository;
  final AuthRepository _authRepository;
  final OfflineService _offlineService = OfflineService();

  // Lokala variabler
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _lastError;
  StreamSubscription? _recipesSubscription;

  // Getters
  List<Recipe> get recipes => List.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  bool get hasError => _lastError != null;
  String? get lastError => _lastError;

  /// Nuvarande användarens ID
  String? get _userId => _authRepository.currentUserId;

  /// Constructor - startar lyssnare om användare är inloggad
  RecipeService({
    required RecipeRepository recipeRepository,
    required AuthRepository authRepository,
  })  : _recipeRepository = recipeRepository,
        _authRepository = authRepository {
    debugPrint('🔥 RecipeService constructor called');

    // Enhanced auth state listener med komplett cleanup
    _authRepository.authStateChanges().listen((_) async {
      final userId = _authRepository.currentUserId;
      debugPrint('🔥 Auth state changed: $userId');
      // TODO: starta/stäng prenumeration på recept

      if (userId == null) {
        // LOGOUT: Komplett cleanup
        debugPrint('👋 User logged out - clearing all data');
        _offlineService.setCurrentUser(null);
        await _performLogoutCleanup();
      } else {
        // LOGIN: Setup för användare (oavsett om ny eller samma)
        debugPrint('👤 User logged in: $userId');
        _offlineService.setCurrentUser(userId);
        await _performLoginSetup(userId);
      }
    });
  }

  // Du kan lägga till metoder som:
  // - fetchUserRecipes()
  // - fetchArchiveRecipes()
  // - subscribeToUserRecipes()
  // osv – och låta RecipeRepository sköta Firestore-åtkomsten.

  /// Enhanced initialize med better user checking
  Future<void> initialize() async {
    final currentUserId = _userId;
    debugPrint('🔥 RecipeService.initialize() called for user: $currentUserId');

    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, skipping initialization');
      _recipes.clear();
      notifyListeners();
      return;
    }

    try {
      debugPrint(
          '🔥 Initializing RecipeService with Firestore and offline support');

      // Ladda offline-recept först för snabb start (men bara för denna användare)
      _loadOfflineRecipesForUser(currentUserId);

      // Starta lyssnare för användarens recept
      await _startListening();

      debugPrint('✅ RecipeService.initialize() complete');
    } catch (e) {
      debugPrint('❌ Error initializing RecipeService: $e');
      _setError('Kunde inte initiera recept: $e');
    }
  }

  /// Ladda offline recept för specifik användare - USER-SPECIFIC
  void _loadOfflineRecipesForUser(String userId) {
    if (_offlineService.isInitialized) {
      final offlineRecipes = _offlineService.getAllOfflineRecipes();

      // Filtrera offline recept för denna användare (om du har userId i offline data)
      // För nu, ladda alla offline recept men logga vilken användare
      if (offlineRecipes.isNotEmpty) {
        _recipes = offlineRecipes;
        notifyListeners();
        AppLogger.info(
            '📦 ${offlineRecipes.length} offline recept laddade för användare: $userId');
      } else {
        debugPrint('📦 Inga offline recept hittades för användare: $userId');
      }
    }
  }

  /// Starta realtidslyssnare för användarens recept med GRANULÄR uppdatering
  Future<void> _startListening() async {
    final userId = _userId;
    if (userId == null) return;

    _setLoading(true);

    try {
      // Om offline, använd bara lokal cache
      if (!_offlineService.isOnline) {
        AppLogger.warning('📵 Offline-läge - använder lokal cache');
        _setLoading(false);
        return;
      }

      // Starta lyssnare via repository
      _recipesSubscription = _recipeRepository.subscribeToUserRecipes(
        userId,
        (changes) {
          for (final change in changes) {
            final recipe = change.recipe;

            switch (change.type) {
              case RecipeChangeType.added:
                if (!_recipes.any((r) => r.id == recipe.id)) {
                  _recipes.insert(0, recipe);
                  _offlineService.saveRecipeOffline(recipe).catchError((e) {
                    AppLogger.error('Kunde inte spara recept offline', e);
                  });
                  AppLogger.info('➕ Nytt recept: "${recipe.title}"');
                }
                break;

              case RecipeChangeType.modified:
                // Uppdatera befintligt recept
                final index = _recipes.indexWhere((r) => r.id == recipe.id);
                if (index != -1) {
                  _recipes[index] = recipe;
                  // Synka bara detta recept till offline
                  _offlineService.saveRecipeOffline(recipe).catchError((e) {
                    AppLogger.error(
                      'Kunde inte uppdatera recept offline',
                      e,
                    );
                  });
                  AppLogger.info('✏️ Uppdaterat recept: "${recipe.title}"');
                }
                break;

              case RecipeChangeType.removed:
                // Ta bort recept
                _recipes.removeWhere((r) => r.id == recipe.id);
                // Ta bort från offline-cache
                _offlineService.deleteRecipeOffline(recipe.id).catchError((
                  e,
                ) {
                  AppLogger.error('Kunde inte ta bort recept offline', e);
                });
                AppLogger.info('🗑️ Borttaget recept: "${recipe.title}"');
                break;
            }
          }

          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          AppLogger.error('Firestore lyssnare fel', error);
          _setError('Kunde inte lyssna på recept: $error');
          _setLoading(false);

          // Fallback till offline-recept vid fel
          final userId = _userId;
          if (userId != null) {
            _loadOfflineRecipesForUser(userId);
          }
        },
      );
    } catch (e) {
      AppLogger.error('Fel vid start av lyssnare', e);
      _setError('Kunde inte starta lyssnare: $e');
      _setLoading(false);

      // Fallback till offline-recept vid fel
      final userId = _userId;
      if (userId != null) {
        _loadOfflineRecipesForUser(userId);
      }
    } // ✅ LÄGG TILL DENNA RAD
  } // ✅ DENNA SKA REDAN FINNAS

  /// Synkronisera ALLA recept till offline-cache (används vid manuell refresh)
  Future<void> _syncAllToOfflineCache() async {
    try {
      for (final recipe in _recipes) {
        await _offlineService.saveRecipeOffline(recipe);
      }
      AppLogger.info('💾 Alla recept synkade till offline-cache');
    } catch (e) {
      AppLogger.error('Kunde inte synka alla till offline-cache', e);
    }
  }

  /// Stoppa lyssnare
  void _stopListening() {
    _recipesSubscription?.cancel();
    _recipesSubscription = null;
  }

  /// Lägg till nytt recept
  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    try {
      _setLoading(true);
      clearError();

      // Spara offline först (fungerar alltid)
      await _offlineService.saveRecipeOffline(recipe);

      // Lägg till i lokal lista omedelbart för snabb UI-uppdatering
      _recipes.insert(0, recipe);
      notifyListeners();

      // Om online och inloggad, synka till Firestore via repository
      if (_offlineService.isOnline && _userId != null) {
        try {
          await _recipeRepository.create(recipe);
          AppLogger.success('✅ Recept "${recipe.title}" synkat till molnet');
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte synka till molnet, sparad lokalt');
        }
      } else {
        AppLogger.info('📵 Offline - recept sparat lokalt');
      }

      return RecipeOperationResult.success('Recept "${recipe.title}" sparat');
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte lägga till recept', e);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Uppdatera befintligt recept
  Future<RecipeOperationResult> updateRecipe(Recipe recipe) async {
    try {
      _setLoading(true);
      clearError();

      // Markera som modifierad offline direkt på objektet
      recipe.isModifiedOffline = true;

      // Spara offline först
      await _offlineService.saveRecipeOffline(recipe);

      // Uppdatera i lokal lista
      final index = _recipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) {
        _recipes[index] = recipe;
        notifyListeners();
      }

      // Om online och inloggad, synka till Firestore
      if (_offlineService.isOnline && _userId != null) {
        try {
          await _recipeRepository.update(recipe);

          // Markera som synkad efter lyckad uppladdning
          recipe.isModifiedOffline = false;
          recipe.lastSyncedAt = DateTime.now();

          // Spara uppdaterat recept offline igen
          await _offlineService.saveRecipeOffline(recipe);

          AppLogger.success('✅ Recept "${recipe.title}" uppdaterat i molnet');
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte synka uppdatering, sparad lokalt');
        }
      } else {
        AppLogger.info('📵 Offline - uppdatering sparad lokalt');
      }

      return RecipeOperationResult.success(
        'Recept "${recipe.title}" uppdaterat',
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte uppdatera recept', e);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Ta bort recept
  Future<RecipeOperationResult> deleteRecipe(String id) async {
    try {
      _setLoading(true);
      clearError();

      // Hämta receptet för att få titeln
      final recipe = getRecipeById(id);
      final title = recipe?.title ?? 'Recept';

      // Ta bort från offline-cache
      await _offlineService.deleteRecipeOffline(id);

      // Ta bort från lokal lista
      _recipes.removeWhere((r) => r.id == id);
      notifyListeners();

      // Om online och inloggad, ta bort från Firestore
      if (_offlineService.isOnline && _userId != null) {
        try {
          await _recipeRepository.delete(id);
          AppLogger.success('✅ Recept borttaget från molnet');
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte ta bort från molnet');
          // TODO: Lägg till i delete-kö för senare synk
        }
      } else {
        AppLogger.info('📵 Offline - recept borttaget lokalt');
      }

      return RecipeOperationResult.success('Recept "$title" borttaget');
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte ta bort recept', e);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Hämta recept via ID
  Recipe? getRecipeById(String id) {
    try {
      // Kolla först i minnet
      return _recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      // Om inte i minnet, kolla offline-cache
      return _offlineService.getOfflineRecipe(id);
    }
  }

  /// Hämta recept från Butlery-arkivet
  Future<List<Recipe>> getArchivedRecipes() async {
    try {
      AppLogger.info('📚 Hämtar recept från arkivet...');

      // Om offline, returnera tom lista med varning
      if (!_offlineService.isOnline) {
        AppLogger.warning('📵 Offline - kan inte hämta arkivrecept');
        throw 'Du måste vara online för att komma åt arkivet';
      }

      final recipes = await _recipeRepository.fetchArchiveRecipes();

      AppLogger.success('✅ ${recipes.length} recept hämtade från arkivet');
      return recipes;
    } catch (e) {
      AppLogger.error('Kunde inte hämta arkiverade recept', e);
      rethrow;
    }
  }

  /// Importera recept från arkivet
  Future<RecipeOperationResult> importFromArchive(
    String archiveRecipeId,
  ) async {
    if (!_offlineService.isOnline) {
      return RecipeOperationResult.error(
        'Du måste vara online för att importera från arkivet',
      );
    }

    if (_userId == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att importera recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      // Hämta från arkivet via repository
      final archiveRecipe =
          await _recipeRepository.fetchArchiveRecipe(archiveRecipeId);

      // Generera nytt ID
      final newId = const Uuid().v4();

      // Skapa en kopia av receptet med uppdaterat datum
      final newRecipe = Recipe(
        id: newId,
        title: archiveRecipe.title,
        description: archiveRecipe.description,
        portions: archiveRecipe.portions,
        timeMinutes: archiveRecipe.timeMinutes,
        ingredients: archiveRecipe.ingredients,
        instructions: archiveRecipe.instructions,
        tags: archiveRecipe.tags,
        rating: archiveRecipe.rating,
        imageUrls: archiveRecipe.imageUrls, // UPPDATERAD till imageUrls
        mealType: archiveRecipe.mealType,
        sourceUrl: 'Importerat från Butlery-arkivet',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Lägg till receptet (använder offline-logiken)
      final result = await addRecipe(newRecipe);

      if (result.isSuccess) {
        AppLogger.success('✅ Recept importerat från arkivet');
        return RecipeOperationResult.success(
          'Recept "${newRecipe.title}" importerat',
        );
      } else {
        return result;
      }
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte importera från arkivet', e);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Lägg till flera recept samtidigt (för bulk import)
  Future<RecipeOperationResult> addMultipleRecipes(List<Recipe> recipes) async {
    try {
      _setLoading(true);
      clearError();

      final warnings = <String>[];
      int addedCount = 0;

      // Hämta befintliga recept-IDs för att undvika dubbletter
      final existingIds = _recipes.map((r) => r.id).toSet();

      for (final recipe in recipes) {
        if (existingIds.contains(recipe.id)) {
          warnings.add('Recept "${recipe.title}" finns redan');
          continue;
        }

        // Lägg till varje recept (med offline-support)
        final result = await addRecipe(recipe);
        if (result.isSuccess) {
          addedCount++;
        } else {
          warnings.add(
            'Kunde inte lägga till "${recipe.title}": ${result.message}',
          );
        }
      }

      final message = addedCount == recipes.length
          ? 'Alla $addedCount recept importerade'
          : '$addedCount av ${recipes.length} recept importerade';

      AppLogger.info(message);
      return RecipeOperationResult.success(
        message,
        warnings: warnings.isNotEmpty ? warnings : null,
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte importera flera recept', e);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Hämta alla recept för export
  /// Returnerar alla användarens recept från minnet eller offline-cache
  Future<List<Recipe>> getAllRecipes() async {
    try {
      AppLogger.info('📦 Hämtar alla recept för export...');

      // Om vi har recept i minnet, använd dem
      if (_recipes.isNotEmpty) {
        AppLogger.success('✅ ${_recipes.length} recept hämtade från minnet');
        return _recipes;
      }

      // Annars hämta från offline-cache
      final offlineRecipes = _offlineService.getAllOfflineRecipes();
      if (offlineRecipes.isNotEmpty) {
        AppLogger.success(
          '✅ ${offlineRecipes.length} recept hämtade från offline-cache',
        );
        return offlineRecipes;
      }

      // Om online, försök hämta från Firestore via repository
      if (_offlineService.isOnline && _userId != null) {
        final recipes =
            await _recipeRepository.fetchUserRecipes(_userId!);
        AppLogger.success('✅ ${recipes.length} recept hämtade från Firestore');
        return recipes;
      }

      AppLogger.warning('Inga recept hittades');
      return [];
    } catch (e) {
      AppLogger.error('Kunde inte hämta alla recept för export', e);
      throw 'Kunde inte hämta recept: $e';
    }
  }

  /// Hämta alla användarens recept (alias för getAllRecipes för kompatibilitet)
  Future<List<Recipe>> getUserRecipes() async {
    try {
      AppLogger.info('📦 Hämtar användarens recept...');

      // Återanvänd den befintliga getAllRecipes logiken
      return await getAllRecipes();
    } catch (e) {
      AppLogger.error('Kunde inte hämta användarrecept', e);
      throw Exception('Kunde inte hämta recept: $e');
    }
  }

  /// Skapa nytt recept (används av ShareService vid import)
  Future<RecipeOperationResult> createRecipe(Recipe recipe) async {
    // Använder samma logik som addRecipe
    return addRecipe(recipe);
  }

  /// Synkronisera alla offline-ändringar
  Future<void> syncOfflineChanges() async {
    final userId = _userId;
    if (!_offlineService.isOnline || userId == null) return;

    try {
      AppLogger.info('🔄 Synkroniserar offline-ändringar...');

      final offlineRecipes = _offlineService.getAllOfflineRecipes();
      int syncedCount = 0;

      for (final recipe in offlineRecipes) {
        if (recipe.needsSync) {
          try {
            // Synka till Firestore via repository
            await _recipeRepository.create(recipe);

            // Markera som synkad direkt på objektet
            recipe.isModifiedOffline = false;
            recipe.lastSyncedAt = DateTime.now();

            // Spara uppdaterat recept offline
            await _offlineService.saveRecipeOffline(recipe);

            syncedCount++;
          } catch (e) {
            AppLogger.error('Kunde inte synka recept ${recipe.id}', e);
          }
        }
      }

      if (syncedCount > 0) {
        AppLogger.success('✅ $syncedCount recept synkade till molnet');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Fel vid synkronisering', e);
    }
  }

  /// Sätt loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Sätt error state
  void _setError(String message) {
    _lastError = message;
    notifyListeners();
  }

  /// Rensa error
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Enhanced manual refresh med user validation
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) {
      debugPrint('⚠️ Cannot refresh - no user logged in');
      return;
    }

    debugPrint('🔄 Refreshing recipes for user: $userId');

    _setLoading(true);

    try {
      if (_offlineService.isOnline && _userId != null) {
        final fetched = await _recipeRepository.fetchUserRecipes(userId);
        _recipes = fetched;
        debugPrint(
            '✅ Refreshed ${_recipes.length} recipes from Firestore for user: $userId');

        // Synka till offline-cache
        await _syncAllToOfflineCache();
      } else {
        // Om offline, ladda från cache för denna användare
        _loadOfflineRecipesForUser(userId);
        debugPrint('📵 Offline - loaded recipes from cache for user: $userId');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error refreshing recipes for user $userId: $e');
      _setError('Kunde inte uppdatera: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Komplett cleanup vid logout - ENHANCED
  Future<void> _performLogoutCleanup() async {
    try {
      // 1. Stoppa alla aktiva listeners
      await _recipesSubscription?.cancel();
      _recipesSubscription = null;
      debugPrint('✅ Firestore listeners stopped');

      // 2. Rensa all lokal state
      _recipes.clear();
      _isLoading = false;
      _lastError = null;
      debugPrint('✅ Local state cleared');

      // 3. Notifiera UI omedelbart
      notifyListeners();
      debugPrint('✅ UI notified of empty state');

      // 4. Rensa offline cache för säkerhets skull (optional)
      try {
        final userId = _authRepository.currentUserId;
        if (userId != null) {
          await _offlineService.clearUserData(userId);
          debugPrint('✅ Offline cache cleared for user: $userId');
        } else {
          debugPrint('⚠️ No user ID available for cache cleanup');
        }
      } catch (e) {
        debugPrint('⚠️ Could not clear offline cache: $e');
        // Inte kritiskt - fortsätt ändå
      }

      debugPrint('🎉 Logout cleanup complete');
    } catch (e) {
      debugPrint('❌ Error during logout cleanup: $e');
      // Säkerställ att vi ändå har tom state
      _recipes.clear();
      _isLoading = false;
      _lastError = null;
      notifyListeners();
    }
  }

  /// Setup för ny användare - ENHANCED
  Future<void> _performLoginSetup(String userId) async {
    try {
      debugPrint('🔄 Setting up for new user: $userId');

      // 1. Sätt loading state
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      // 2. Vänta lite för att säkerställa att Firebase auth är helt klar
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Verifiera att användaren fortfarande är inloggad
      if (_authRepository.currentUserId != userId) {
        debugPrint('⚠️ User changed during setup, aborting');
        return;
      }

      // 4. Initialize för ny användare
      await initialize();

      debugPrint('✅ New user setup complete');
    } catch (e) {
      debugPrint('❌ Error during new user setup: $e');
      _setError('Kunde inte ladda data för ny användare');
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}

/// Resultat av en RecipeService operation
class RecipeOperationResult {
  final bool isSuccess;
  final String message;
  final List<String>? warnings;

  const RecipeOperationResult({
    required this.isSuccess,
    required this.message,
    this.warnings,
  });

  factory RecipeOperationResult.success(
    String message, {
    List<String>? warnings,
  }) {
    return RecipeOperationResult(
      isSuccess: true,
      message: message,
      warnings: warnings,
    );
  }

  factory RecipeOperationResult.error(String message) {
    return RecipeOperationResult(isSuccess: false, message: message);
  }
}
