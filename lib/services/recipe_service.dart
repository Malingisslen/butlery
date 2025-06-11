// lib/services/recipe_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';
import '../core/error/failures.dart';
import 'package:uuid/uuid.dart';

/// RecipeService hanterar all receptlogik med Firestore
class RecipeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      debugPrint('🔥 Initierar RecipeService med Firestore');

      // Starta lyssnare för användarens recept
      await _startListening();

      debugPrint('✅ RecipeService.initialize() klar');
    } catch (e) {
      debugPrint('❌ Fel vid initiering av RecipeService: $e');
      _setError('Kunde inte initiera recept: $e');
    }
  }

  /// Starta realtidslyssnare för användarens recept
  Future<void> _startListening() async {
    if (_userRecipesRef == null) return;

    _setLoading(true);

    try {
      // Starta Firestore-lyssnare
      _recipesSubscription = _userRecipesRef!
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _recipes =
                  snapshot.docs
                      .map((doc) => Recipe.fromFirestore(doc))
                      .toList();
              _setLoading(false);
              notifyListeners();

              AppLogger.success(
                '✅ ${_recipes.length} recept laddade från Firestore',
              );
            },
            onError: (error) {
              AppLogger.error('Firestore lyssnare fel', error);
              _setError('Kunde inte lyssna på recept: $error');
              _setLoading(false);
            },
          );
    } catch (e) {
      AppLogger.error('Fel vid start av lyssnare', e);
      _setError('Kunde inte starta lyssnare: $e');
      _setLoading(false);
    }
  }

  /// Stoppa lyssnare
  void _stopListening() {
    _recipesSubscription?.cancel();
    _recipesSubscription = null;
  }

  /// Lägg till nytt recept
  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    if (_userRecipesRef == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att lägga till recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      // Lägg till i Firestore
      await _userRecipesRef!.doc(recipe.id).set(recipe.toFirestore());

      AppLogger.success('✅ Recept "${recipe.title}" tillagt');
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
    if (_userRecipesRef == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att uppdatera recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      // Uppdatera i Firestore
      await _userRecipesRef!.doc(recipe.id).update(recipe.toFirestore());

      AppLogger.success('✅ Recept "${recipe.title}" uppdaterat');
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
    if (_userRecipesRef == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att ta bort recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      // Hämta receptet för att få titeln
      final recipe = getRecipeById(id);
      final title = recipe?.title ?? 'Recept';

      // Ta bort från Firestore
      await _userRecipesRef!.doc(id).delete();

      AppLogger.success('✅ Recept borttaget');
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
      return _recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Hämta recept från Butlery-arkivet
  Future<List<Recipe>> getArchivedRecipes() async {
    try {
      AppLogger.info('📚 Hämtar recept från arkivet...');

      final snapshot = await _archiveRef.orderBy('title').get();

      final recipes =
          snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();

      AppLogger.success('✅ ${recipes.length} recept hämtade från arkivet');
      return recipes;
    } catch (e) {
      AppLogger.error('Kunde inte hämta arkiverade recept', e);
      // Om arkivet inte finns, returnera tom lista
      return [];
    }
  }

  /// Importera recept från arkivet
  Future<RecipeOperationResult> importFromArchive(
    String archiveRecipeId,
  ) async {
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
      final newRecipe = archiveRecipe.copyWith(updatedAt: DateTime.now());

      // Lägg till i användarens samling med det nya ID:t
      await _userRecipesRef!.doc(newId).set({
        ...newRecipe.toFirestore(),
        'id': newId, // Överskriver det gamla ID:t
        'sourceUrl': 'Importerat från Butlery-arkivet',
      });

      AppLogger.success('✅ Recept importerat från arkivet');
      return RecipeOperationResult.success(
        'Recept "${newRecipe.title}" importerat',
      );
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
    if (_userRecipesRef == null) {
      return RecipeOperationResult.error(
        'Du måste vara inloggad för att importera recept',
      );
    }

    try {
      _setLoading(true);
      clearError();

      final batch = _firestore.batch();
      final warnings = <String>[];
      int addedCount = 0;

      // Hämta befintliga recept-IDs för att undvika dubbletter
      final existingIds = _recipes.map((r) => r.id).toSet();

      for (final recipe in recipes) {
        if (existingIds.contains(recipe.id)) {
          warnings.add('Recept "${recipe.title}" finns redan');
          continue;
        }

        final docRef = _userRecipesRef!.doc(recipe.id);
        batch.set(docRef, recipe.toFirestore());
        addedCount++;
      }

      if (addedCount > 0) {
        await batch.commit();
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
    if (_userRecipesRef == null) return;

    _setLoading(true);
    try {
      final snapshot = await _userRecipesRef!.get();
      _recipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
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
