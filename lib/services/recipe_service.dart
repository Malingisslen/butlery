// lib/services/recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';
import '../core/error/failures.dart';
import 'offline_service.dart';
import 'package:uuid/uuid.dart';

/// RecipeService hanterar all receptlogik med Firestore OCH offline-support
class RecipeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineService _offlineService = OfflineService();

  // Lokala variabler
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _lastError;
  StreamSubscription<QuerySnapshot>? _recipesSubscription;

  // Getters
  List<Recipe> get recipes => List.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  bool get hasError => _lastError != null;
  String? get lastError => _lastError;

  /// Nuvarande användarens ID
  String? get _userId => _auth.currentUser?.uid;

  /// Firestore-referens till användarens recept
  CollectionReference<Map<String, dynamic>>? get _userRecipesRef {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId).collection('recipes');
  }

  /// Firestore-referens till Butlery-arkivet
  CollectionReference<Map<String, dynamic>> get _archiveRef {
    return _firestore.collection('butlery_archive');
  }

  /// Constructor - startar lyssnare om användare är inloggad
  RecipeService() {
    debugPrint('🔥 RecipeService constructor called');
    _auth.authStateChanges().listen((user) {
      debugPrint('🔥 Auth state changed: ${user?.email}');
      if (user != null) {
        debugPrint('🔥 User logged in, calling initialize()');
        initialize();
      } else {
        debugPrint('🔥 User logged out');
        _stopListening();
        _recipes.clear();
        notifyListeners();
      }
    });
  }

  /// Initiera service
  Future<void> initialize() async {
    debugPrint('🔥 RecipeService.initialize() called');
    debugPrint('🔥 Current userId: $_userId');

    if (_userId == null) {
      debugPrint('⚠️ Ingen användare inloggad, skippar initiering');
      return;
    }

    try {
      debugPrint(
        '🔥 Initierar RecipeService med Firestore och offline-support',
      );

      // Ladda offline-recept först för snabb start
      _loadOfflineRecipes();

      // Starta lyssnare för användarens recept
      await _startListening();

      debugPrint('✅ RecipeService.initialize() klar');
    } catch (e) {
      debugPrint('❌ Fel vid initiering av RecipeService: $e');
      _setError('Kunde inte initiera recept: $e');
    }
  }

  /// Ladda recept från offline-cache
  void _loadOfflineRecipes() {
    if (_offlineService.isInitialized) {
      final offlineRecipes = _offlineService.getAllOfflineRecipes();
      if (offlineRecipes.isNotEmpty) {
        _recipes = offlineRecipes;
        notifyListeners();
        AppLogger.info(
          '📦 ${offlineRecipes.length} recept laddade från offline-cache',
        );
      }
    }
  }

  /// Starta realtidslyssnare för användarens recept med GRANULÄR uppdatering
  Future<void> _startListening() async {
    if (_userRecipesRef == null) return;

    _setLoading(true);

    try {
      // Om offline, använd bara lokal cache
      if (!_offlineService.isOnline) {
        AppLogger.warning('📵 Offline-läge - använder lokal cache');
        _setLoading(false);
        return;
      }

      // Starta Firestore-lyssnare med granulär hantering
      _recipesSubscription = _userRecipesRef!
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              // VIKTIG ÄNDRING: Hantera bara de dokument som faktiskt ändrats
              for (final change in snapshot.docChanges) {
                final recipe = Recipe.fromFirestore(change.doc);

                switch (change.type) {
                  case DocumentChangeType.added:
                    // Lägg till recept om det inte redan finns lokalt
                    if (!_recipes.any((r) => r.id == recipe.id)) {
                      _recipes.insert(0, recipe);
                      // Synka bara detta recept till offline
                      _offlineService.saveRecipeOffline(recipe).catchError((e) {
                        AppLogger.error('Kunde inte spara recept offline', e);
                      });
                      AppLogger.info('➕ Nytt recept: "${recipe.title}"');
                    }
                    break;

                  case DocumentChangeType.modified:
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

                  case DocumentChangeType.removed:
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

              // Om det är första laddningen (metadata.isFromCache är false och vi har många ändringar)
              if (!snapshot.metadata.isFromCache &&
                  snapshot.docChanges.length > 5) {
                // Sortera listan en gång efter alla ändringar
                _recipes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                AppLogger.success(
                  '✅ Initial laddning: ${_recipes.length} recept',
                );
              }

              _setLoading(false);
              notifyListeners();
            },
            onError: (error) {
              AppLogger.error('Firestore lyssnare fel', error);
              _setError('Kunde inte lyssna på recept: $error');
              _setLoading(false);

              // Fallback till offline-recept vid fel
              _loadOfflineRecipes();
            },
          );
    } catch (e) {
      AppLogger.error('Fel vid start av lyssnare', e);
      _setError('Kunde inte starta lyssnare: $e');
      _setLoading(false);

      // Fallback till offline-recept vid fel
      _loadOfflineRecipes();
    }
  }

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

      // Om online och inloggad, synka till Firestore
      if (_offlineService.isOnline && _userRecipesRef != null) {
        try {
          await _userRecipesRef!.doc(recipe.id).set(recipe.toFirestore());
          AppLogger.success('✅ Recept "${recipe.title}" synkat till molnet');
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte synka till molnet, sparad lokalt');
          // Receptet är redan sparat offline, så det är OK
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
      if (_offlineService.isOnline && _userRecipesRef != null) {
        try {
          await _userRecipesRef!.doc(recipe.id).update(recipe.toFirestore());

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
      if (_offlineService.isOnline && _userRecipesRef != null) {
        try {
          await _userRecipesRef!.doc(id).delete();
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

      final snapshot = await _archiveRef.orderBy('title').get();

      final recipes =
          snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();

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

    if (_userRecipesRef == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att importera recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      // Hämta från arkivet
      final archiveDoc = await _archiveRef.doc(archiveRecipeId).get();
      if (!archiveDoc.exists) {
        throw ValidationFailure(message: 'Recept finns inte i arkivet');
      }

      // Skapa nytt recept med nytt ID
      final archiveRecipe = Recipe.fromFirestore(archiveDoc);

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
        imageUrl: archiveRecipe.imageUrl,
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

      final message =
          addedCount == recipes.length
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

      // Om online, försök hämta från Firestore
      if (_offlineService.isOnline && _userRecipesRef != null) {
        final snapshot =
            await _userRecipesRef!.orderBy('updatedAt', descending: true).get();
        final recipes =
            snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
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

  /// Skapa nytt recept (används av ShareService vid import)
  Future<RecipeOperationResult> createRecipe(Recipe recipe) async {
    // Använder samma logik som addRecipe
    return addRecipe(recipe);
  }

  /// Synkronisera alla offline-ändringar
  Future<void> syncOfflineChanges() async {
    if (!_offlineService.isOnline || _userRecipesRef == null) return;

    try {
      AppLogger.info('🔄 Synkroniserar offline-ändringar...');

      final offlineRecipes = _offlineService.getAllOfflineRecipes();
      int syncedCount = 0;

      for (final recipe in offlineRecipes) {
        if (recipe.needsSync) {
          try {
            // Synka till Firestore
            await _userRecipesRef!.doc(recipe.id).set(recipe.toFirestore());

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

  /// Manuell refresh
  Future<void> refresh() async {
    _setLoading(true);
    try {
      if (_offlineService.isOnline && _userRecipesRef != null) {
        // Om online, hämta från Firestore
        final snapshot = await _userRecipesRef!.get();
        _recipes =
            snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();

        // Synka ALLA till offline-cache vid manuell refresh
        await _syncAllToOfflineCache();
      } else {
        // Om offline, ladda från cache
        _loadOfflineRecipes();
      }

      notifyListeners();
    } catch (e) {
      _setError('Kunde inte uppdatera: $e');
    } finally {
      _setLoading(false);
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
