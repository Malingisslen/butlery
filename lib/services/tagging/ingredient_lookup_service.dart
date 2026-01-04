import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/tagging_events_tracker.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// Service for looking up ingredients from the database.
///
/// Searches both the global ingredient database and user-defined ingredients.
/// Returns coverage statistics and unknown ingredients list.
/// M3: Includes LRU cache to avoid repeated lookups in batch operations.
///
/// CRIT-3: Concurrency model - This service is designed for single-isolate use.
/// Cache operations are synchronous and atomic within Dart's event loop.
/// Do NOT use across isolates without additional synchronization.
class IngredientLookupService extends BaseService {
  final IngredientRepository _ingredientRepository;
  final UserIngredientRepository _userIngredientRepository;

  /// M3/CRIT-4: LRU cache for ingredient lookups (max 500 entries).
  /// Key format: "g\x00cleanedName" (global) or "u\x00userId\x00cleanedName" (user).
  /// Uses null character separator to prevent key collision attacks.
  /// Null values are cached to avoid repeated failed lookups.
  static const int _cacheMaxSize = 500;

  /// HIGH-11: Swedish compound word suffixes for space-insertion matching.
  /// TODO: Move to Firebase config (tagging_config/compound_suffixes) for
  /// dynamic updates without app release.
  static const List<String> _compoundSuffixes = [
    'bröst',
    'filé',
    'kött',
    'fläsk',
    'skinka',
    'korv',
    'färs',
    'mjölk',
    'grädde',
    'ost',
    'smör',
    'olja',
    'sås',
    'soppa',
    'bröd',
    'pasta',
    'ris',
    'potatis',
    'lök',
    'vitlök',
  ];

  /// HIGH-11: Swedish compound word endings for base extraction.
  /// Comprehensive list synced with IngredientNormalizer patterns.
  /// TODO: Move to Firebase config for dynamic updates.
  static const List<String> _compoundEndings = [
    // Primary meat/protein suffixes
    'sås',
    'filé',
    'kött',
    'fläsk',
    'skinka',
    'korv',
    'bröst',
    'lår',
    'ben',
    'bog',
    'rygg',
    'färs',
    'lever',
    'njure',
    'kotlett',
    'kotletter',
    'stek',
    // Dairy and fats
    'mjölk',
    'grädde',
    'smör',
    'ost',
    'olja',
    'fett',
    // Prepared foods and sauces
    'soppa',
    'bullar',
    'bröd',
    'kakor',
    'pasta',
    'puré',
    'passata',
    'buljong',
    'fond',
    // Vegetables
    'lök',
    'kål',
    'rot',
    'blad',
    'stjälk',
    'stjälkar',
    // Preparation/cuts
    'klyftor',
    'klyft',
    'skivor',
    'skiva',
    'bitar',
    'bit',
    'tärningar',
    // Other common
    'ris',
    'mjöl',
  ];

  /// CRIT-3: Cache version incremented on clear to detect stale operations.
  int _cacheVersion = 0;
  final Map<String, IngredientData?> _lookupCache = {};
  final List<String> _lruOrder = []; // CRIT-4: Tracks access order for LRU

  IngredientLookupService({
    required IngredientRepository ingredientRepository,
    required UserIngredientRepository userIngredientRepository,
  })  : _ingredientRepository = ingredientRepository,
        _userIngredientRepository = userIngredientRepository;

  @override
  String get serviceName => 'IngredientLookupService';

  /// M3: Clears the ingredient lookup cache.
  /// CRIT-3: Increments cache version to invalidate any in-flight lookups.
  void clearLookupCache() {
    _cacheVersion++; // CRIT-3: Invalidate in-flight lookups
    _lookupCache.clear();
    _lruOrder.clear(); // CRIT-4: Also clear LRU order
    AppLogger.debug(
        'M3: Ingredient lookup cache cleared (version=$_cacheVersion)');
  }

  /// M3: Current cache size for debugging.
  /// MED-3: This is a snapshot value; may change during concurrent operations.
  /// For Dart, this is acceptable since Map.length is atomic and this is
  /// only used for debugging/monitoring, not cache logic.
  int get cacheSize => _lookupCache.length;

  /// Looks up ingredients from a list of normalized names.
  ///
  /// Returns matched ingredients with their properties and any unknowns.
  Future<IngredientLookupResult> lookupIngredients(
    List<String> normalizedNames, {
    String? userId,
  }) async {
    if (normalizedNames.isEmpty) {
      return IngredientLookupResult.empty();
    }

    final matched = <IngredientData>[];
    final unmatched = <String>[];

    for (final name in normalizedNames) {
      final ingredient = await _findIngredient(name, userId: userId);
      if (ingredient != null) {
        matched.add(ingredient);
      } else {
        unmatched.add(name);
      }
    }

    final result = IngredientLookupResult.fromLists(
      matched: matched,
      unmatched: unmatched,
    );

    if (result.hasUnknowns) {
      AppLogger.debug(
        'Ingredient lookup: ${result.matchedCount}/${result.totalCount} matched, '
        'unknowns: ${result.unmatched.join(", ")}',
      );
    }

    return result;
  }

  /// Looks up a single ingredient by normalized name.
  ///
  /// Search order:
  /// 1. M3: Check cache first
  /// 2. User-defined ingredients (M2: checked first to allow override)
  /// 3. Global database by exact name
  /// 4. Global database by alias
  /// 5. Fuzzy match (compound words, common variations)
  ///
  /// CRIT-3: Captures cache version before async lookup to detect invalidation.
  Future<IngredientData?> _findIngredient(
    String normalizedName, {
    String? userId,
  }) async {
    if (normalizedName.isEmpty) return null;

    // Clean the name further
    final cleanName = _cleanForLookup(normalizedName);

    // CRIT-13: Empty name after cleaning means no valid ingredient
    // This prevents cache key collisions for whitespace-only inputs
    if (cleanName.isEmpty) {
      AppLogger.debug(
        'CRIT-13: Ingredient name empty after cleaning: "$normalizedName"',
        'IngredientLookupService',
      );
      return null;
    }

    // CRIT-3/HIGH-3: Create cache key using null character separator
    // Null character (\x00) cannot appear in user input, preventing collisions
    final cacheKey =
        userId != null ? 'u\x00$userId\x00$cleanName' : 'g\x00$cleanName';

    // M3: Check cache first (null means "not found" was cached)
    if (_lookupCache.containsKey(cacheKey)) {
      // CRIT-3: Defensive - verify key still exists after LRU update
      _lruOrder.remove(cacheKey);
      _lruOrder.add(cacheKey);
      // Return cached value (may be null for "not found")
      return _lookupCache[cacheKey];
    }

    // CRIT-3: Capture cache version before async operation
    final versionBeforeLookup = _cacheVersion;

    // Perform the actual lookup (async - may yield)
    final result = await _performLookup(cleanName, userId: userId);

    // CRIT-3: Only cache if version hasn't changed (cache wasn't cleared)
    if (_cacheVersion == versionBeforeLookup) {
      _cacheResult(cacheKey, result);
    } else {
      // MED-3: Log at INFO level for production visibility
      AppLogger.info(
        'Cache invalidated during lookup for "$cleanName" - result not cached (normal under high load)',
        'IngredientLookupService',
      );
    }

    return result;
  }

  /// M3: Performs the actual database lookup without caching.
  /// M2 fix: User-defined ingredients are checked FIRST to allow overrides.
  Future<IngredientData?> _performLookup(
    String cleanName, {
    String? userId,
  }) async {
    // 1. Try user-defined ingredients FIRST (allows override of global entries)
    // M2: This lets users customize properties for their own ingredients
    if (userId != null) {
      final userResult =
          await _userIngredientRepository.findByName(userId, cleanName);
      if (userResult != null) return userResult;
    }

    // 2. Try global database by exact name
    var result = await _ingredientRepository.findByName(cleanName);
    if (result != null) return result;

    // 3. Try global database by alias
    final byAlias = await _ingredientRepository.findByAlias(cleanName);
    if (byAlias.isNotEmpty) return byAlias.first;

    // 4. Try variations (for compound words and common patterns)
    final variations = _generateLookupVariations(cleanName);
    for (final variation in variations) {
      result = await _ingredientRepository.findByName(variation);
      if (result != null) return result;

      final aliasResults = await _ingredientRepository.findByAlias(variation);
      if (aliasResults.isNotEmpty) return aliasResults.first;
    }

    return null;
  }

  /// M3/CRIT-4: Caches a lookup result with proper LRU eviction.
  ///
  /// CRIT-3: This method is synchronous and atomic within Dart's event loop.
  /// Uses a separate list to track access order for true LRU behavior.
  void _cacheResult(String key, IngredientData? result) {
    // CRIT-4: If key already exists, remove from LRU order (will be re-added)
    if (_lookupCache.containsKey(key)) {
      _lruOrder.remove(key);
    }

    // CRIT-4: Evict least-recently-used entries atomically
    // CRIT-6: Check if key exists in cache before removing to handle edge cases
    // where _lruOrder and _lookupCache could become desynchronized
    while (_lookupCache.length >= _cacheMaxSize && _lruOrder.isNotEmpty) {
      final lruKey = _lruOrder.removeAt(0); // Oldest = least recently used
      if (_lookupCache.containsKey(lruKey)) {
        _lookupCache.remove(lruKey);
      }
    }

    // Add to cache and LRU order
    _lookupCache[key] = result;
    _lruOrder.add(key);

    // CRIT-3: Sanity check - cache and LRU list should stay in sync
    assert(
      _lookupCache.length == _lruOrder.length,
      'CRIT-3: Cache/LRU desync: cache=${_lookupCache.length}, lru=${_lruOrder.length}',
    );

    // CRIT-3: Production validation - also check in release builds and auto-recover
    if (_lookupCache.length != _lruOrder.length) {
      AppLogger.error(
        'CRIT-3: Cache/LRU desync detected: '
            'cache=${_lookupCache.length}, lru=${_lruOrder.length}. '
            'Auto-recovering by clearing cache.',
        'IngredientLookupService',
      );
      _reportCacheDesync();
      // CRIT-3: Auto-recover by clearing both to restore consistency
      _lookupCache.clear();
      _lruOrder.clear();
      _cacheVersion++; // Invalidate any in-flight lookups
      AppLogger.info(
        'CRIT-3: Cache cleared and version incremented to $_cacheVersion',
        'IngredientLookupService',
      );
    }
  }

  /// CRIT-3: Reports cache desync to analytics.
  void _reportCacheDesync() {
    try {
      final tracker = ServiceLocator.get<TaggingEventsTracker>();
      tracker.logCacheDesync(
        cacheLength: _lookupCache.length,
        lruLength: _lruOrder.length,
      );
    } catch (_) {
      // Analytics not available
    }
  }

  /// Cleans a normalized name for database lookup.
  ///
  /// CRIT-14: Uses SwedishCharacterNormalizer for consistent handling of
  /// å→a, ä→a, ö→o. This ensures "köttfärs" matches "kottfars" in the database
  /// regardless of whether the input contains Swedish diacritics.
  String _cleanForLookup(String name) {
    // CRIT-14: Apply Swedish character normalization (includes toLowerCase)
    return SwedishCharacterNormalizer.normalize(name)
        .trim()
        // Remove common Swedish articles
        .replaceAll(RegExp(r'^(en|ett|den|det|de)\s+'), '')
        // Remove trailing quantities left over
        .replaceAll(RegExp(r'\s+\d+\s*$'), '')
        .trim();
  }

  /// Generates variations of a name for fuzzy matching.
  List<String> _generateLookupVariations(String name) {
    final variations = <String>[];

    // M6: Add space-removed variation ("kyckling bröst" → "kycklingbröst")
    final noSpaces = name.replaceAll(' ', '');
    if (noSpaces != name && noSpaces.length > 2) {
      variations.add(noSpaces);
    }

    // M6: Add space-inserted variations for compound words
    // HIGH-11: Use centralized compound suffixes list
    // MED-6: Guard requires at least 3 chars before suffix (2 base + 1 for meaningful word)
    // Example: "ost" (3 chars) with suffix "ost" (3 chars) → 3 > 3+2 = false (no variation)
    // Example: "smörgåsost" (10 chars) with suffix "ost" (3 chars) → 10 > 3+2 = true (creates "smörgås ost")
    const minBaseLength = 2; // Minimum meaningful base word length
    for (final suffix in _compoundSuffixes) {
      if (name.endsWith(suffix) &&
          name.length > suffix.length + minBaseLength) {
        final base = name.substring(0, name.length - suffix.length);
        if (base.isNotEmpty) {
          variations.add('$base $suffix');
        }
      }
    }

    // Singular/plural variations
    if (name.endsWith('or')) {
      // Swedish plural: tomator → tomat
      variations.add(name.substring(0, name.length - 2));
    }
    if (name.endsWith('ar')) {
      // L3 fix: Swedish plural "äpplar" → "äpple" (with 'e') is the correct form.
      // Check the correct form first, then fallback to without 'e'.
      variations
          .add('${name.substring(0, name.length - 2)}e'); // "äpple" - correct
      variations.add(name.substring(0, name.length - 2)); // "äppl" - fallback
    }
    if (name.endsWith('er')) {
      // Swedish plural: morötter → morot
      variations.add(name.substring(0, name.length - 2));
    }
    if (name.endsWith('n')) {
      // Definite form: löken → lök
      variations.add(name.substring(0, name.length - 1));
    }
    if (name.endsWith('en')) {
      // Definite form: smöret → smör
      variations.add(name.substring(0, name.length - 2));
    }
    if (name.endsWith('et')) {
      // Definite neuter: smöret → smör
      variations.add(name.substring(0, name.length - 2));
    }

    // Remove common adjectives
    final adjectives = [
      'färsk',
      'färska',
      'torkad',
      'torkade',
      'hackad',
      'hackade',
      'riven',
      'rivna',
      'strimlad',
      'strimlade',
      'skivad',
      'skivade',
      'mald',
      'malda',
      'rökt',
      'rökte',
      'stekt',
      'stekta',
      'kokt',
      'kokta',
      'rå',
      'råa',
      'grön',
      'gröna',
      'röd',
      'röda',
      'vit',
      'vita',
      'gul',
      'gula',
      'stor',
      'stora',
      'liten',
      'lilla',
      'små',
    ];

    for (final adj in adjectives) {
      if (name.startsWith('$adj ')) {
        variations.add(name.substring(adj.length + 1));
      }
      if (name.endsWith(' $adj')) {
        variations.add(name.substring(0, name.length - adj.length - 1));
      }
    }

    // Split compound words (e.g., "vitlöksklyftor" → "vitlök", "mangosås" → "mango")
    // L4 fix: This also handles cases where IngredientNormalizer._extractBaseIngredient
    // didn't extract the base because it wasn't in KnownIngredients. By trying the
    // extracted base as a variation here, we can still match unknown compounds.
    // HIGH-11: Use centralized compound endings list
    if (name.length > 6) {
      for (final ending in _compoundEndings) {
        if (name.endsWith(ending) && name.length > ending.length + 2) {
          variations.add(name.substring(0, name.length - ending.length));
        }
      }
    }

    return variations.where((v) => v.length > 2).toList();
  }

  /// Looks up ingredients from raw ingredient strings.
  ///
  /// M2: Parses raw strings to extract ingredient names, then normalizes.
  /// Handles strings like "2 dl mjölk" → parses to "mjölk" → normalizes.
  /// H2: Deduplicates ingredients before lookup to avoid skewed coverage.
  Future<IngredientLookupResult> lookupFromRaw(
    List<String> rawIngredients, {
    String? userId,
  }) async {
    // H2: Deduplicate before lookup, preserving order
    final seen = <String>{};
    final normalized = <String>[];

    for (final raw in rawIngredients) {
      // M2: Parse raw ingredient to extract name (strips quantity and unit)
      // "2 dl mjölk" → ParsedIngredient(quantity: 2, unit: "dl", name: "mjölk")
      // LOW-2: Wrap parsing in try-catch to prevent failures from bad input
      String nameToNormalize;
      try {
        final parsed = IngredientParser.parseIngredient(raw);
        nameToNormalize = parsed.name.isNotEmpty ? parsed.name : raw;
      } catch (e) {
        // Fallback to raw string if parsing fails
        AppLogger.warning(
          'LOW-2: Failed to parse ingredient "$raw": $e, using raw string',
        );
        nameToNormalize = raw;
      }

      // Now normalize the extracted name
      final result = IngredientNormalizer.normalize(nameToNormalize);
      final norm = result.normalized;

      if (norm.isNotEmpty && !seen.contains(norm)) {
        seen.add(norm);
        normalized.add(norm);
      }
    }

    // H2: Log if duplicates were found
    if (normalized.length < rawIngredients.length) {
      final duplicateCount = rawIngredients.length - normalized.length;
      AppLogger.debug(
        'H2: Deduplicated $duplicateCount duplicate ingredient(s) before lookup',
      );
    }

    return lookupIngredients(normalized, userId: userId);
  }

  /// Searches for ingredients matching a query.
  ///
  /// Useful for autocomplete and ingredient selection.
  Future<List<IngredientData>> search(String query, {int limit = 20}) async {
    return _ingredientRepository.searchIngredients(query, limit: limit);
  }

  /// Gets an ingredient by ID.
  Future<IngredientData?> getById(String id) async {
    return _ingredientRepository.getById(id);
  }

  /// Gets all ingredients in a group.
  Future<List<IngredientData>> getByGroup(String groupPath) async {
    return _ingredientRepository.getByGroup(groupPath);
  }

  /// Gets all ingredients with a property.
  Future<List<IngredientData>> getByProperty(String property) async {
    return _ingredientRepository.getByProperty(property);
  }
}
