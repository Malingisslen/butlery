import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation of user-defined ingredients.
///
/// Stores user-created ingredient definitions in their user collection.
/// Path: /users/{userId}/ingredients/{ingredientId}
class FirebaseUserIngredientRepository
    with ErrorHandlingMixin
    implements UserIngredientRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  /// In-memory cache per user.
  final Map<String, Map<String, IngredientData>> _userCache = {};

  FirebaseUserIngredientRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository;

  /// Gets the user's ingredient collection.
  CollectionReference<Map<String, dynamic>> _getUserCollection(String userId) {
    return _firestore.collection(FirestoreCollections.users).doc(userId).collection(FirestoreCollections.ingredients);
  }

  /// Gets the current user ID or throws.
  String _requireUserId() {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user');
    }
    return userId;
  }

  @override
  Future<IngredientData?> getById(String userId, String ingredientId) async {
    // Check cache first
    if (_userCache.containsKey(userId) &&
        _userCache[userId]!.containsKey(ingredientId)) {
      return _userCache[userId]![ingredientId];
    }

    try {
      final doc = await _getUserCollection(userId).doc(ingredientId).get();
      if (!doc.exists) return null;

      final ingredient = IngredientData.fromFirestore(doc);

      // Cache it
      _userCache[userId] ??= {};
      _userCache[userId]![ingredientId] = ingredient;

      return ingredient;
    } catch (e, stack) {
      AppLogger.error('Failed to get user ingredient: $e', stack);
      return null;
    }
  }

  @override
  Future<IngredientData?> findByName(String userId, String name) async {
    final all = await getAll(userId);
    final normalized = name.toLowerCase().trim();

    return all.cast<IngredientData?>().firstWhere(
          (i) =>
              i!.swedish.toLowerCase().trim() == normalized ||
              i.english.toLowerCase().trim() == normalized,
          orElse: () => null,
        );
  }

  @override
  Future<List<IngredientData>> getAll(String userId) async {
    try {
      final snapshot = await _getUserCollection(userId).get();

      final ingredients = snapshot.docs
          .map((doc) => IngredientData.fromFirestore(doc))
          .toList();

      // Update cache
      _userCache[userId] = {
        for (final i in ingredients) i.id: i,
      };

      return ingredients;
    } catch (e, stack) {
      AppLogger.error('Failed to get user ingredients: $e', stack);
      return [];
    }
  }

  @override
  Future<IngredientData> create(
      String userId, IngredientData ingredient) async {
    try {
      final doc = _getUserCollection(userId).doc(ingredient.id);

      final withTimestamps = ingredient.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'user-defined',
      );

      await doc.set(withTimestamps.toFirestore());

      // Update cache
      _userCache[userId] ??= {};
      _userCache[userId]![ingredient.id] = withTimestamps;

      AppLogger.info('User ingredient created: ${ingredient.id}');
      return withTimestamps;
    } catch (e, stack) {
      AppLogger.error('Failed to create user ingredient: $e', stack);
      rethrow;
    }
  }

  @override
  Future<void> update(String userId, IngredientData ingredient) async {
    try {
      final doc = _getUserCollection(userId).doc(ingredient.id);

      final withTimestamp = ingredient.copyWith(
        updatedAt: DateTime.now(),
      );

      await doc.update(withTimestamp.toFirestore());

      // Update cache
      _userCache[userId] ??= {};
      _userCache[userId]![ingredient.id] = withTimestamp;

      AppLogger.info('User ingredient updated: ${ingredient.id}');
    } catch (e, stack) {
      AppLogger.error('Failed to update user ingredient: $e', stack);
      rethrow;
    }
  }

  @override
  Future<void> delete(String userId, String ingredientId) async {
    try {
      await _getUserCollection(userId).doc(ingredientId).delete();

      // Update cache
      _userCache[userId]?.remove(ingredientId);

      AppLogger.info('User ingredient deleted: $ingredientId');
    } catch (e, stack) {
      AppLogger.error('Failed to delete user ingredient: $e', stack);
      rethrow;
    }
  }

  @override
  Stream<List<IngredientData>> watchAll(String userId) {
    return _getUserCollection(userId).snapshots().map((snapshot) {
      final ingredients = snapshot.docs
          .map((doc) => IngredientData.fromFirestore(doc))
          .toList();

      // Update cache
      _userCache[userId] = {
        for (final i in ingredients) i.id: i,
      };

      return ingredients;
    });
  }

  /// Creates a user-defined ingredient from an unknown ingredient name.
  ///
  /// Returns an ingredient with default group 'other/unknown'.
  Future<IngredientData> createFromUnknown({
    required String name,
    required Set<String> properties,
    String? group,
  }) async {
    final userId = _requireUserId();

    // Generate ID from name
    final id = 'user-${name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}';

    final ingredient = IngredientData(
      id: id,
      swedish: name,
      english: name,
      group: group ?? 'other/unknown',
      properties: properties,
      status: 'user-defined',
    );

    return create(userId, ingredient);
  }

  /// Clears the cache for a user.
  void clearCache(String userId) {
    _userCache.remove(userId);
  }

  /// Clears all caches.
  void clearAllCaches() {
    _userCache.clear();
  }
}
