import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';

/// Firebase implementation of the ingredient repository.
///
/// Provides read-only access to the global ingredients collection.
/// Uses in-memory caching for fast lookups (2230 ingredients fit easily).
/// Automatically invalidates cache when ingredients are synced.
class FirebaseIngredientRepository
    with ErrorHandlingMixin
    implements IngredientRepository {
  final FirebaseFirestore _firestore;

  /// In-memory cache for all ingredients.
  final Map<String, IngredientData> _cache = {};

  /// Index of normalized Swedish names → ingredient ID.
  final Map<String, String> _swedishNameIndex = {};

  /// Index of normalized English names → ingredient ID.
  final Map<String, String> _englishNameIndex = {};

  /// Index of normalized aliases → ingredient ID.
  final Map<String, String> _aliasIndex = {};

  /// Whether the cache has been loaded.
  bool _cacheLoaded = false;

  /// Subscription to Firestore updates for cache invalidation.
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Callbacks to notify when cache is invalidated.
  final List<void Function()> _onCacheInvalidatedListeners = [];

  FirebaseIngredientRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Adds a listener to be notified when the ingredient cache is invalidated.
  ///
  /// Useful for triggering re-tagging of recipes after ingredient sync.
  void addCacheInvalidationListener(void Function() listener) {
    _onCacheInvalidatedListeners.add(listener);
  }

  /// Removes a cache invalidation listener.
  void removeCacheInvalidationListener(void Function() listener) {
    _onCacheInvalidatedListeners.remove(listener);
  }

  /// Notifies all listeners that the cache was invalidated.
  void _notifyCacheInvalidated() {
    for (final listener in _onCacheInvalidatedListeners) {
      listener();
    }
  }

  /// Initializes the repository with automatic cache updates.
  ///
  /// Sets up a listener for ingredient collection changes to automatically
  /// invalidate and refresh the cache when ingredients are synced.
  Future<void> initialize() async {
    // Load initial cache
    await loadCache();

    // Subscribe to changes for automatic invalidation
    _subscription = _collection.snapshots().listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        // Check if this is actual data change, not just initial load
        final hasRealChanges = snapshot.docChanges.any((change) =>
            change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified ||
            change.type == DocumentChangeType.removed);

        if (hasRealChanges && _cacheLoaded) {
          AppLogger.info(
            '🔄 Ingredient collection changed, invalidating cache (${snapshot.docChanges.length} changes)',
          );
          _invalidateAndReload(snapshot);
        }
      }
    });
  }

  /// Invalidates cache and reloads from snapshot.
  void _invalidateAndReload(QuerySnapshot snapshot) {
    _cache.clear();
    _swedishNameIndex.clear();
    _englishNameIndex.clear();
    _aliasIndex.clear();

    for (final doc in snapshot.docs) {
      final ingredient = IngredientData.fromFirestore(doc);
      _addToCache(ingredient);
    }

    AppLogger.info('✅ Cache reloaded with ${_cache.length} ingredients');
    _notifyCacheInvalidated();
  }

  /// Collection reference.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ingredients');

  /// Ensures the cache is loaded before querying.
  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    await loadCache();
  }

  /// Loads all ingredients into memory cache.
  ///
  /// Call this during app initialization for best performance.
  Future<void> loadCache() async {
    if (_cacheLoaded) return;

    try {
      AppLogger.info('Loading ingredient cache...');
      final stopwatch = Stopwatch()..start();

      final snapshot = await _collection.get();

      _cache.clear();
      _swedishNameIndex.clear();
      _englishNameIndex.clear();
      _aliasIndex.clear();

      for (final doc in snapshot.docs) {
        final ingredient = IngredientData.fromFirestore(doc);
        _addToCache(ingredient);
      }

      _cacheLoaded = true;
      stopwatch.stop();
      AppLogger.info(
        'Ingredient cache loaded: ${_cache.length} ingredients in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, stack) {
      AppLogger.error('Failed to load ingredient cache: $e', stack);
      rethrow;
    }
  }

  /// Adds an ingredient to all cache indexes.
  void _addToCache(IngredientData ingredient) {
    _cache[ingredient.id] = ingredient;

    // Index Swedish name
    final swedishNorm = _normalize(ingredient.swedish);
    if (swedishNorm.isNotEmpty) {
      _swedishNameIndex[swedishNorm] = ingredient.id;
    }

    // Index English name
    final englishNorm = _normalize(ingredient.english);
    if (englishNorm.isNotEmpty) {
      _englishNameIndex[englishNorm] = ingredient.id;
    }

    // Index Swedish aliases
    for (final alias in ingredient.aliasesSv) {
      final aliasNorm = _normalize(alias);
      if (aliasNorm.isNotEmpty) {
        _aliasIndex[aliasNorm] = ingredient.id;
      }
    }

    // Index English aliases
    for (final alias in ingredient.aliasesEn) {
      final aliasNorm = _normalize(alias);
      if (aliasNorm.isNotEmpty) {
        _aliasIndex[aliasNorm] = ingredient.id;
      }
    }

    // Index search terms
    for (final term in ingredient.searchTerms) {
      final termNorm = _normalize(term);
      if (termNorm.isNotEmpty) {
        _aliasIndex[termNorm] = ingredient.id;
      }
    }
  }

  /// Normalizes text for lookup (lowercase, trimmed, diacritics simplified).
  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('å', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  @override
  Future<IngredientData?> getById(String id) async {
    await _ensureCacheLoaded();
    return _cache[id];
  }

  @override
  Future<IngredientData?> findByName(String name,
      {String language = 'sv'}) async {
    await _ensureCacheLoaded();

    final normalized = _normalize(name);
    if (normalized.isEmpty) return null;

    // Try exact match in primary index
    String? ingredientId;
    if (language == 'sv') {
      ingredientId = _swedishNameIndex[normalized];
    } else {
      ingredientId = _englishNameIndex[normalized];
    }

    if (ingredientId != null) {
      return _cache[ingredientId];
    }

    // Try the other language
    ingredientId = language == 'sv'
        ? _englishNameIndex[normalized]
        : _swedishNameIndex[normalized];

    if (ingredientId != null) {
      return _cache[ingredientId];
    }

    // Try aliases
    ingredientId = _aliasIndex[normalized];
    if (ingredientId != null) {
      return _cache[ingredientId];
    }

    // Try fuzzy matching for compound ingredients
    return _fuzzyMatch(normalized);
  }

  /// Attempts fuzzy matching for compound ingredient names.
  IngredientData? _fuzzyMatch(String normalized) {
    // Try removing common prefixes/suffixes
    final variations = _generateVariations(normalized);

    for (final variation in variations) {
      final id = _swedishNameIndex[variation] ??
          _englishNameIndex[variation] ??
          _aliasIndex[variation];
      if (id != null) {
        return _cache[id];
      }
    }

    // Try partial match (for compound words)
    for (final entry in _swedishNameIndex.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return _cache[entry.value];
      }
    }

    return null;
  }

  /// Generates variations of a name for fuzzy matching.
  List<String> _generateVariations(String normalized) {
    final variations = <String>[];

    // Remove common Swedish suffixes
    if (normalized.endsWith('n')) {
      variations.add(normalized.substring(0, normalized.length - 1));
    }
    if (normalized.endsWith('en')) {
      variations.add(normalized.substring(0, normalized.length - 2));
    }
    if (normalized.endsWith('ar')) {
      variations.add(normalized.substring(0, normalized.length - 2));
    }
    if (normalized.endsWith('or')) {
      variations.add(normalized.substring(0, normalized.length - 2));
    }
    if (normalized.endsWith('er')) {
      variations.add(normalized.substring(0, normalized.length - 2));
    }

    // Remove common prefixes
    if (normalized.startsWith('farsk ')) {
      variations.add(normalized.substring(6));
    }
    if (normalized.startsWith('torkad ')) {
      variations.add(normalized.substring(7));
    }
    if (normalized.startsWith('rokt ')) {
      variations.add(normalized.substring(5));
    }

    return variations;
  }

  @override
  Future<List<IngredientData>> findByAlias(String alias) async {
    await _ensureCacheLoaded();

    final normalized = _normalize(alias);
    if (normalized.isEmpty) return [];

    final ingredientId = _aliasIndex[normalized];
    if (ingredientId != null) {
      final ingredient = _cache[ingredientId];
      if (ingredient != null) {
        return [ingredient];
      }
    }

    return [];
  }

  @override
  Future<List<IngredientData>> getByGroup(String groupPath) async {
    await _ensureCacheLoaded();

    return _cache.values.where((i) => i.isInGroup(groupPath)).toList();
  }

  @override
  Future<List<IngredientData>> getByProperty(String property) async {
    await _ensureCacheLoaded();

    return _cache.values.where((i) => i.hasProperty(property)).toList();
  }

  @override
  Future<List<IngredientData>> searchIngredients(
    String query, {
    int limit = 20,
  }) async {
    await _ensureCacheLoaded();

    final normalized = _normalize(query);
    if (normalized.isEmpty) return [];

    final results = <IngredientData>[];
    final scores = <String, int>{};

    for (final ingredient in _cache.values) {
      int score = 0;

      // Exact match in Swedish name
      if (_normalize(ingredient.swedish) == normalized) {
        score += 100;
      } else if (_normalize(ingredient.swedish).startsWith(normalized)) {
        score += 50;
      } else if (_normalize(ingredient.swedish).contains(normalized)) {
        score += 25;
      }

      // Exact match in English name
      if (_normalize(ingredient.english) == normalized) {
        score += 80;
      } else if (_normalize(ingredient.english).startsWith(normalized)) {
        score += 40;
      } else if (_normalize(ingredient.english).contains(normalized)) {
        score += 20;
      }

      // Match in aliases
      for (final alias in [...ingredient.aliasesSv, ...ingredient.aliasesEn]) {
        final aliasNorm = _normalize(alias);
        if (aliasNorm == normalized) {
          score += 60;
          break;
        } else if (aliasNorm.startsWith(normalized)) {
          score += 30;
        } else if (aliasNorm.contains(normalized)) {
          score += 15;
        }
      }

      if (score > 0) {
        results.add(ingredient);
        scores[ingredient.id] = score;
      }
    }

    // Sort by score descending
    results.sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return results.take(limit).toList();
  }

  @override
  Stream<List<IngredientData>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final ingredients = snapshot.docs
          .map((doc) => IngredientData.fromFirestore(doc))
          .toList();

      // Update cache
      _cache.clear();
      for (final ingredient in ingredients) {
        _addToCache(ingredient);
      }
      _cacheLoaded = true;

      return ingredients;
    });
  }

  @override
  Future<List<IngredientData>> getAll() async {
    await _ensureCacheLoaded();
    return _cache.values.toList();
  }

  @override
  Future<bool> exists(String id) async {
    await _ensureCacheLoaded();
    return _cache.containsKey(id);
  }

  @override
  Future<int> count() async {
    await _ensureCacheLoaded();
    return _cache.length;
  }

  /// Clears the cache (for testing or forced refresh).
  void clearCache() {
    _cache.clear();
    _swedishNameIndex.clear();
    _englishNameIndex.clear();
    _aliasIndex.clear();
    _cacheLoaded = false;
  }

  /// Disposes subscriptions.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
