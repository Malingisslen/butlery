import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:clock/clock.dart';

/// Temporary in-memory cache for ParsedRecipe objects.
///
/// Bridges the gap between the import flow (where ParsedRecipe is created)
/// and the recipe form (where we need it for diff calculation).
///
/// This cache:
/// - Stores ParsedRecipe keyed by sourceUrl
/// - Auto-expires entries after 30 minutes
/// - Removes entries on retrieval (one-time use)
/// - Bounded at [_maxSize] entries (BUT-817 — TTL alone permits unbounded
///   growth between cleanup passes during rapid imports).
///
/// Used by the parser feedback loop to capture user corrections
/// as training data for parser improvement.
class ParsedRecipeCache {
  static const _maxAge = Duration(minutes: 30);
  static const _maxSize = 50;
  late final LruMap<String, _CacheEntry> _cache = LruMap(
    maxSize: _maxSize,
    onEvict: (key, _) => AppLogger.info(
      'cache_eviction service=ParsedRecipeCache key=$key bound=$_maxSize',
    ),
  );

  /// Store ParsedRecipe keyed by sourceUrl.
  ///
  /// Called from UrlImportStrategy when a recipe is successfully parsed.
  /// The ParsedRecipe will be retrieved later in RecipeFormViewModel.
  void store(String sourceUrl, ParsedRecipe parsed) {
    _cleanup();
    _cache[sourceUrl] = _CacheEntry(parsed, clock.now());
  }

  /// Retrieve and remove ParsedRecipe by sourceUrl.
  ///
  /// Returns null if not found or expired.
  /// The entry is removed after retrieval (one-time use).
  ParsedRecipe? retrieve(String sourceUrl) {
    _cleanup();
    final entry = _cache.remove(sourceUrl);
    return entry?.parsed;
  }

  /// Check if a ParsedRecipe exists for the given sourceUrl.
  bool contains(String sourceUrl) {
    _cleanup();
    return _cache.containsKey(sourceUrl);
  }

  /// Clear all cached entries.
  void clear() {
    _cache.clear();
  }

  /// Remove expired entries.
  void _cleanup() {
    final now = clock.now();
    _cache.removeWhere((_, entry) => now.difference(entry.timestamp) > _maxAge);
  }
}

class _CacheEntry {
  final ParsedRecipe parsed;
  final DateTime timestamp;

  _CacheEntry(this.parsed, this.timestamp);
}
