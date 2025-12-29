import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';

/// Service for looking up ingredients from the database.
///
/// Searches both the global ingredient database and user-defined ingredients.
/// Returns coverage statistics and unknown ingredients list.
/// M3: Includes LRU cache to avoid repeated lookups in batch operations.
class IngredientLookupService extends BaseService {
  final IngredientRepository _ingredientRepository;
  final UserIngredientRepository _userIngredientRepository;

  /// M3: LRU cache for ingredient lookups (max 500 entries).
  /// Key format: "cleanedName" or "userId:cleanedName" for user-specific lookups.
  /// Null values are cached to avoid repeated failed lookups.
  static const int _cacheMaxSize = 500;
  final Map<String, IngredientData?> _lookupCache = {};

  IngredientLookupService({
    required IngredientRepository ingredientRepository,
    required UserIngredientRepository userIngredientRepository,
  })  : _ingredientRepository = ingredientRepository,
        _userIngredientRepository = userIngredientRepository;

  @override
  String get serviceName => 'IngredientLookupService';

  /// M3: Clears the ingredient lookup cache.
  void clearLookupCache() {
    _lookupCache.clear();
    AppLogger.debug('M3: Ingredient lookup cache cleared');
  }

  /// M3: Current cache size for debugging.
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
  /// 2. Global database by exact name
  /// 3. User-defined ingredients
  /// 4. Global database by alias
  /// 5. Fuzzy match (compound words, common variations)
  Future<IngredientData?> _findIngredient(
    String normalizedName, {
    String? userId,
  }) async {
    if (normalizedName.isEmpty) return null;

    // Clean the name further
    final cleanName = _cleanForLookup(normalizedName);

    // M3: Create cache key (include userId for user-specific lookups)
    final cacheKey = userId != null ? '$userId:$cleanName' : cleanName;

    // M3: Check cache first (null means "not found" was cached)
    if (_lookupCache.containsKey(cacheKey)) {
      return _lookupCache[cacheKey];
    }

    // Perform the actual lookup
    final result = await _performLookup(cleanName, userId: userId);

    // M3: Cache the result (including null for "not found")
    _cacheResult(cacheKey, result);

    return result;
  }

  /// M3: Performs the actual database lookup without caching.
  Future<IngredientData?> _performLookup(
    String cleanName, {
    String? userId,
  }) async {
    // 1. Try global database by exact name
    var result = await _ingredientRepository.findByName(cleanName);
    if (result != null) return result;

    // 2. Try user-defined ingredients
    if (userId != null) {
      result = await _userIngredientRepository.findByName(userId, cleanName);
      if (result != null) return result;
    }

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

  /// M3: Caches a lookup result with LRU eviction.
  void _cacheResult(String key, IngredientData? result) {
    // Evict oldest entries if cache is full
    while (_lookupCache.length >= _cacheMaxSize) {
      _lookupCache.remove(_lookupCache.keys.first);
    }
    _lookupCache[key] = result;
  }

  /// Cleans a normalized name for database lookup.
  String _cleanForLookup(String name) {
    return name
        .toLowerCase()
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
    // Common Swedish food compound word suffixes
    final compoundSuffixes = [
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
    for (final suffix in compoundSuffixes) {
      if (name.endsWith(suffix) && name.length > suffix.length + 2) {
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
      // Swedish plural: äpplar → äpple
      variations.add(name.substring(0, name.length - 2));
      variations.add('${name.substring(0, name.length - 2)}e');
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

    // Split compound words (e.g., "vitlöksklyftor" → "vitlök")
    if (name.length > 6) {
      // Try common compound endings
      final compoundEndings = [
        'klyftor',
        'klyft',
        'skivor',
        'skiva',
        'bitar',
        'bit',
        'stjälk',
        'stjälkar',
        'blad',
        'kött',
        'mjöl',
        'olja',
        'sås',
        'pasta',
        'ris',
      ];

      for (final ending in compoundEndings) {
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
      final parsed = IngredientParser.parseIngredient(raw);
      final nameToNormalize = parsed.name.isNotEmpty ? parsed.name : raw;

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
