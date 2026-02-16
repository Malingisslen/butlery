import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/ingredient_substitution.dart';
import 'package:butlery/repositories/firestore_repository.dart';

/// Service for looking up ingredient substitutions.
///
/// Data sources (priority order):
/// 1. LRU cache (in-memory)
/// 2. Firestore `ingredient_substitutions` collection
/// 3. Bundled JSON fallback asset
///
/// Normalizes ingredient names (lowercase, trim) for consistent lookup.
class IngredientSubstitutionService extends BaseService {
  final FirestoreRepository _firestoreRepository;

  IngredientSubstitutionService({
    required FirestoreRepository firestoreRepository,
  }) : _firestoreRepository = firestoreRepository;
  static const int _cacheMaxSize = 100;
  static const String _assetPath = 'assets/data/ingredient_substitutions.json';
  static const String _firestoreCollection = 'ingredient_substitutions';

  /// LRU cache: normalized name -> substitution (null = looked up, not found)
  final Map<String, IngredientSubstitution?> _cache = {};

  /// Parsed bundled fallback data, loaded lazily
  List<IngredientSubstitution>? _bundledData;

  @override
  String get serviceName => 'IngredientSubstitutionService';

  /// Returns substitutions for the given ingredient name, or null if none found.
  /// Checks cache first, then Firestore, then bundled JSON.
  Future<IngredientSubstitution?> getSubstitutions(
    String ingredientName,
  ) async {
    final normalized = _normalize(ingredientName);
    if (normalized.isEmpty) return null;

    // 1. Check LRU cache
    if (_cache.containsKey(normalized)) {
      final cached = _cache.remove(normalized);
      _cache[normalized] = cached;
      return cached;
    }

    // 2. Try Firestore
    final firestoreResult = await _lookupFromFirestore(normalized);
    if (firestoreResult != null) {
      _cacheResult(normalized, firestoreResult);
      return firestoreResult;
    }

    // 3. Try bundled JSON fallback
    final bundledResult = await _lookupFromBundled(normalized);
    _cacheResult(normalized, bundledResult);
    return bundledResult;
  }

  /// Returns filtered substitution options for an ingredient.
  /// Optionally filters by dietary tags and excludes allergens.
  Future<List<SubstitutionOption>> getFilteredSubstitutions(
    String ingredientName, {
    List<String>? dietaryFilters,
    List<String>? allergenFilters,
  }) async {
    final substitution = await getSubstitutions(ingredientName);
    if (substitution == null) return [];

    var options = substitution.substitutions;

    // Keep only options that match ALL requested dietary filters
    if (dietaryFilters != null && dietaryFilters.isNotEmpty) {
      options = options.where((option) {
        final lowerTags =
            option.dietaryTags.map((t) => t.toLowerCase()).toSet();
        return dietaryFilters
            .every((filter) => lowerTags.contains(filter.toLowerCase()));
      }).toList();
    }

    // Exclude options whose name matches any allergen filter
    if (allergenFilters != null && allergenFilters.isNotEmpty) {
      final lowerAllergens =
          allergenFilters.map((a) => a.toLowerCase()).toSet();
      options = options.where((option) {
        final nameLower = option.name.toLowerCase();
        return !lowerAllergens.any((allergen) => nameLower.contains(allergen));
      }).toList();
    }

    return options;
  }

  /// Clears the in-memory cache.
  void clearSubstitutionCache() {
    _cache.clear();
    AppLogger.debug('Substitution cache cleared');
  }

  int get cacheSize => _cache.length;

  // -- Private helpers --

  String _normalize(String name) => name.toLowerCase().trim();

  Future<IngredientSubstitution?> _lookupFromFirestore(
    String normalized,
  ) async {
    try {
      final snapshot = await _firestoreRepository.firestore
          .collection(_firestoreCollection)
          .where('ingredientName', isEqualTo: normalized)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return IngredientSubstitution.fromMap(
        snapshot.docs.first.data(),
      );
    } catch (e) {
      AppLogger.warning(
        'Firestore substitution lookup failed for "$normalized": $e',
        'IngredientSubstitutionService',
      );
      return null;
    }
  }

  Future<IngredientSubstitution?> _lookupFromBundled(
    String normalized,
  ) async {
    final data = await _loadBundledData();
    try {
      return data.firstWhere(
        (s) => _normalize(s.ingredientName) == normalized,
      );
    } on StateError {
      // No match found
      return null;
    }
  }

  Future<List<IngredientSubstitution>> _loadBundledData() async {
    if (_bundledData != null) return _bundledData!;

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _bundledData = jsonList
          .map(
            (item) => IngredientSubstitution.fromMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.warning(
        'Failed to load bundled substitutions: $e',
        'IngredientSubstitutionService',
      );
      _bundledData = [];
    }

    return _bundledData!;
  }

  /// LRU cache insert with eviction when at capacity.
  void _cacheResult(String key, IngredientSubstitution? result) {
    _cache.remove(key);

    while (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = result;
  }
}
