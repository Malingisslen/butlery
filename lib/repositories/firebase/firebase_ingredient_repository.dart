import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation of the ingredient repository.
///
/// Read-only access to the global ingredients collection. The cache uses a
/// TTL with stale-while-revalidate semantics: cold-cache reads await a
/// fetch; stale reads serve immediately and refresh in the background.
/// A one-shot `.get()` (not `.snapshots()`) is used because the collection
/// is admin-managed and a permanent listener streamed the full set on
/// every Firestore reconnect.
class FirebaseIngredientRepository
    with ErrorHandlingMixin
    implements IngredientRepository {
  final FirebaseFirestore _firestore;

  final Map<String, IngredientData> _cache = {};
  final Map<String, String> _swedishNameIndex = {};
  final Map<String, String> _englishNameIndex = {};
  final Map<String, String> _aliasIndex = {};
  final Set<String> _compoundNames = {};

  /// When the cache was last populated. `null` means uninitialized.
  DateTime? _cacheLoadedAt;

  /// BUT-1475: highest server `updatedAt` seen across the loaded ingredients.
  /// The delta-refresh baseline — a background refresh only re-fetches docs
  /// changed since this timestamp (server-sourced on both sides, so it is
  /// immune to client clock skew). `null` when no loaded doc carried an
  /// `updatedAt` (legacy docs), which forces a full reload instead.
  Timestamp? _maxUpdatedAt;

  /// In-flight refresh so concurrent callers coalesce to one fetch.
  Future<void>? _inFlightLoad;

  /// Whether [_inFlightLoad] is a FULL reload (true) vs a delta/TTL refresh
  /// (false). A [forceRefresh] may coalesce onto an in-flight full load, but
  /// must never settle for an in-flight delta — it guarantees a complete
  /// re-fetch (BUT-1475). Only meaningful while [_inFlightLoad] is non-null.
  bool _inFlightIsFull = false;

  final DateTime Function() _now;

  /// How long the cache is considered fresh before a background refresh.
  final Duration cacheTtl;

  /// Callbacks to notify when cache is invalidated.
  final List<void Function()> _onCacheInvalidatedListeners = [];

  FirebaseIngredientRepository({
    FirebaseFirestore? firestore,
    Duration? cacheTtl,
    DateTime Function()? now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       cacheTtl = cacheTtl ?? const Duration(hours: 1),
       _now = now ?? DateTime.now;

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
  /// MED-8: Wraps each listener call in try-catch to prevent one failing
  /// listener from blocking others.
  void _notifyCacheInvalidated() {
    for (final listener in _onCacheInvalidatedListeners) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error(
          'MED-8: Cache invalidation listener failed',
          e,
          'FirebaseIngredientRepository',
          stack,
        );
        // Continue notifying other listeners even if one fails
      }
    }
  }

  /// Initializes the repository with a one-time cache load.
  ///
  /// Uses a single fetch instead of a permanent Firestore listener.
  /// The ingredients collection is admin-managed and changes rarely,
  /// so a one-time load per app session is sufficient. Call [forceRefresh]
  /// if a mid-session reload is needed.
  Future<void> initialize() async {
    await loadCache();
  }

  /// Forces a full cache reload from Firestore.
  ///
  /// Use when admin has updated the ingredients collection mid-session.
  Future<void> forceRefresh() async {
    await loadCache(forceReload: true);
    _notifyCacheInvalidated();
  }

  /// Collection reference.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.ingredients);

  bool get _cacheLoaded => _cacheLoadedAt != null;

  bool get _isCacheStale {
    final loadedAt = _cacheLoadedAt;
    if (loadedAt == null) return false;
    return _now().difference(loadedAt) >= cacheTtl;
  }

  /// Cold-cache reads await a fetch; stale reads return immediately and
  /// kick off a background refresh.
  Future<void> _ensureCacheLoaded() async {
    if (!_cacheLoaded) {
      await loadCache();
      return;
    }
    if (_isCacheStale) {
      // ignore: unawaited_futures
      _refreshCacheInBackground();
    }
  }

  /// BUT-1475: the TTL-driven background refresh fetches ONLY the ingredients
  /// changed since the last load (a delta query on `updatedAt`), instead of
  /// re-downloading the whole ~5.6k-doc collection every hour. In steady state
  /// (an admin-managed collection that changes rarely) the delta query returns
  /// zero docs, collapsing the hourly refresh from thousands of reads to one
  /// empty query. Coalesced through [_inFlightLoad] so concurrent stale reads
  /// fire a single refresh.
  Future<void> _refreshCacheInBackground() async {
    if (_inFlightLoad != null) return;
    final future = _deltaRefreshOrFull();
    _inFlightLoad = future;
    _inFlightIsFull = false;
    try {
      await future;
    } catch (_) {
      // _deltaRefreshOrFull already logged. Stale data continues to serve.
    } finally {
      _inFlightLoad = null;
    }
  }

  /// Re-fetches only ingredients with `updatedAt` newer than [_maxUpdatedAt]
  /// and merges them into the cache. Falls back to a full reload when there is
  /// no server-timestamp baseline, so a collection of legacy docs without
  /// `updatedAt` never silently stops refreshing. On any error the existing
  /// (stale) cache keeps serving — the same degrade-not-crash contract as the
  /// full load (BUT-1331).
  ///
  /// KNOWN LIMITATION (BUT-1475): a delta query on `updatedAt` cannot observe
  /// DELETED docs — once a baseline is set, every background refresh is a delta,
  /// so a removed ingredient lingers in the cache until the next `forceRefresh`
  /// or app restart (which do a full reload). Acceptable for this rarely-mutated,
  /// admin-managed collection; if ingredient deletions become routine, add a
  /// periodic full reload (e.g. every Nth refresh).
  Future<void> _deltaRefreshOrFull() async {
    final baseline = _maxUpdatedAt;
    if (baseline == null) {
      await _doLoadCache();
      return;
    }
    try {
      final snapshot = await _collection
          .where('updatedAt', isGreaterThan: baseline)
          .get();
      if (snapshot.docs.isEmpty) {
        // Nothing changed since the last load — restamp freshness so the TTL
        // window resets without another delta query until it lapses again.
        _cacheLoadedAt = _now();
        return;
      }
      var maxTs = baseline;
      for (final doc in snapshot.docs) {
        final ingredient = IngredientData.fromFirestore(doc);
        _cache[ingredient.id] = ingredient;
        final ts = _readUpdatedAt(doc.data());
        if (ts != null && ts.compareTo(maxTs) > 0) maxTs = ts;
      }
      // Rebuild the lookup indexes from the merged cache: an edited doc's old
      // name/alias keys must not linger, and index rebuild off the in-memory
      // map costs no extra reads.
      _rebuildIndexes();
      _maxUpdatedAt = maxTs;
      _cacheLoadedAt = _now();
      AppLogger.info(
        'Ingredient cache delta refresh: ${snapshot.docs.length} changed doc(s)',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Ingredient delta refresh failed; serving stale cache: $e',
        stack,
      );
    }
  }

  /// Reads a doc's server `updatedAt` timestamp, or `null` when absent/typed
  /// otherwise (a not-yet-resolved `serverTimestamp` sentinel included).
  Timestamp? _readUpdatedAt(Map<String, dynamic>? data) {
    final value = data?['updatedAt'];
    return value is Timestamp ? value : null;
  }

  /// Clears and repopulates every lookup index from the current [_cache]. Used
  /// after a delta merge so edited docs don't leave stale index entries.
  void _rebuildIndexes() {
    _swedishNameIndex.clear();
    _englishNameIndex.clear();
    _aliasIndex.clear();
    _compoundNames.clear();
    for (final ingredient in _cache.values) {
      _addToCache(ingredient);
    }
  }

  /// Loads all ingredients into memory.
  ///
  /// [forceReload] re-fetches even if already loaded (used by TTL refresh
  /// and [forceRefresh]).
  Future<void> loadCache({bool forceReload = false}) async {
    if (_cacheLoaded && !forceReload) return;
    final inFlight = _inFlightLoad;
    // A plain (non-forced) load coalesces onto ANY in-flight fetch. A
    // forceReload coalesces only onto an in-flight FULL load; if a delta
    // refresh is in flight it waits for that to drain, then runs its own full
    // load — it must never return a partial delta to a caller that asked for a
    // complete re-fetch (BUT-1475).
    if (inFlight != null && (!forceReload || _inFlightIsFull)) return inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // The in-flight fetch logged its own failure; proceed to a full load.
      }
    }

    final future = _doLoadCache();
    _inFlightLoad = future;
    _inFlightIsFull = true;
    try {
      await future;
    } finally {
      _inFlightLoad = null;
      _inFlightIsFull = false;
    }
  }

  Future<void> _doLoadCache() async {
    AppLogger.info('Loading ingredient cache...');
    final stopwatch = Stopwatch()..start();
    try {
      final snapshot = await _collection.get();
      _cache.clear();
      _swedishNameIndex.clear();
      _englishNameIndex.clear();
      _aliasIndex.clear();
      _compoundNames.clear();
      Timestamp? maxTs;
      for (final doc in snapshot.docs) {
        _addToCache(IngredientData.fromFirestore(doc));
        final ts = _readUpdatedAt(doc.data());
        if (ts != null && (maxTs == null || ts.compareTo(maxTs) > 0)) {
          maxTs = ts;
        }
      }
      // BUT-1475: record the delta baseline for the next background refresh.
      _maxUpdatedAt = maxTs;
      _cacheLoadedAt = _now();
      stopwatch.stop();
      AppLogger.info(
        'Ingredient cache loaded: ${_cache.length} ingredients in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, stack) {
      // BUT-1331: degrade to an empty/stale cache instead of rethrowing.
      // The global ingredients collection can be absent from Firestore's
      // persistence cache on a cold offline start, where `.get()` throws
      // `unavailable`. Rethrowing crashed every caller (cooking-mode
      // substitution, tagging, import, auto-categorize). `_cacheLoadedAt`
      // stays null here (it is set only after a successful fetch), so a later
      // online call retries; any existing stale cache is preserved because
      // `_cache.clear()` runs only after `.get()` succeeds. Lookups degrade to
      // empty results rather than throwing.
      AppLogger.error('Failed to load ingredient cache: $e', stack);
    }
  }

  /// BUT-1498: Writes a normalized key→ingredientId mapping into [index],
  /// logging when it silently overrides a DIFFERENT ingredient. A name/alias
  /// shared by two ingredient docs resolves to whichever the cache-load loop
  /// reached last — i.e. Firestore doc-ID order — which is invisible and can
  /// swing an allergen lookup to the wrong ingredient. Surface it so the
  /// duplicate gets deduplicated in the Sheet; the last-writer-wins behaviour
  /// itself is unchanged. Same-id re-indexing (an alias equal to the doc's own
  /// name, etc.) is not a collision and is not logged.
  void _indexIngredientKey(
    Map<String, String> index,
    String key,
    IngredientData ingredient,
    String indexName,
  ) {
    final existingId = index[key];
    if (existingId != null && existingId != ingredient.id) {
      AppLogger.warning(
        'Ingredient $indexName collision on "$key": doc "${ingredient.id}" '
            'overrides "$existingId" (doc-ID order decides the winner; '
            'deduplicate the name/alias in the ingredient Sheet)',
        'FirebaseIngredientRepository',
      );
    }
    index[key] = ingredient.id;
  }

  /// Adds an ingredient to all cache indexes.
  void _addToCache(IngredientData ingredient) {
    _cache[ingredient.id] = ingredient;

    // Index Swedish name
    final swedishNorm = _normalize(ingredient.swedish);
    if (swedishNorm.isNotEmpty) {
      _indexIngredientKey(_swedishNameIndex, swedishNorm, ingredient, 'name');
    }

    // Index English name
    final englishNorm = _normalize(ingredient.english);
    if (englishNorm.isNotEmpty) {
      _indexIngredientKey(
        _englishNameIndex,
        englishNorm,
        ingredient,
        'English name',
      );
    }

    // Index Swedish aliases
    for (final alias in ingredient.aliasesSv) {
      final aliasNorm = _normalize(alias);
      if (aliasNorm.isNotEmpty) {
        _indexIngredientKey(_aliasIndex, aliasNorm, ingredient, 'alias');
      }
    }

    // Index English aliases
    for (final alias in ingredient.aliasesEn) {
      final aliasNorm = _normalize(alias);
      if (aliasNorm.isNotEmpty) {
        _indexIngredientKey(_aliasIndex, aliasNorm, ingredient, 'alias');
      }
    }

    // Index search terms
    for (final term in ingredient.searchTerms) {
      final termNorm = _normalize(term);
      if (termNorm.isNotEmpty) {
        _indexIngredientKey(_aliasIndex, termNorm, ingredient, 'search term');
      }
    }

    // Index learned aliases (from user corrections, Cloud Function-managed)
    for (final alias in ingredient.learnedAliasesSv) {
      final aliasNorm = _normalize(alias);
      if (aliasNorm.isNotEmpty) {
        _indexIngredientKey(
          _aliasIndex,
          aliasNorm,
          ingredient,
          'learned alias',
        );
      }
    }

    // Index compound names
    if (ingredient.isCompoundName) {
      _compoundNames.add(ingredient.swedish.toLowerCase());
      for (final alias in ingredient.aliasesSv) {
        _compoundNames.add(alias.toLowerCase());
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
  Future<IngredientData?> findByName(
    String name, {
    String language = 'sv',
  }) async {
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

  /// M1/H1: Attempts fuzzy matching for compound ingredient names using scoring.
  ///
  /// Returns the best match based on a scoring algorithm:
  /// - Exact match: highest priority (return immediately)
  /// - Prefix match: high priority (0.9 - length penalty)
  /// - Suffix match: medium-high priority (0.8 - length penalty)
  /// - Substring match: medium priority (0.5 or 0.4), requires min 3 chars
  ///
  /// H1: Requires minimum 3 characters for substring matching to prevent
  /// false positives like "ris" matching "rädisor".
  IngredientData? _fuzzyMatch(String normalized) {
    // Try removing common prefixes/suffixes first
    final variations = _generateVariations(normalized);

    for (final variation in variations) {
      final id =
          _swedishNameIndex[variation] ??
          _englishNameIndex[variation] ??
          _aliasIndex[variation];
      if (id != null) {
        return _cache[id];
      }
    }

    // M1: Use scored matching instead of returning first partial match
    final candidates = <MapEntry<String, double>>[];

    for (final entry in _swedishNameIndex.entries) {
      double score = 0;
      final indexKey = entry.key;

      // Exact match (highest priority) - return immediately
      if (indexKey == normalized) {
        return _cache[entry.value];
      }

      // Prefix match (high priority): "kyckling" matches "kycklingbröst"
      if (indexKey.startsWith(normalized)) {
        // Score decreases slightly with length difference
        score = 0.9 - (indexKey.length - normalized.length) * 0.01;
      }
      // Reverse prefix: "kycklingbröst" matches "kyckling"
      else if (normalized.startsWith(indexKey)) {
        score = 0.8 - (normalized.length - indexKey.length) * 0.01;
      }
      // Substring match: input contains ingredient name
      // H1: Require minimum 3 characters to avoid false positives
      else if (indexKey.length >= 3 && normalized.contains(indexKey)) {
        // Longer ingredient names get higher scores when found as substring
        score = 0.4 + (indexKey.length * 0.01).clamp(0.0, 0.1);
      }
      // Reverse substring: ingredient contains input
      // H1: Require minimum 3 characters to avoid false positives
      else if (normalized.length >= 3 && indexKey.contains(normalized)) {
        score = 0.5;
      }

      if (score > 0) {
        candidates.add(MapEntry(entry.value, score));
      }
    }

    // Also check alias index for partial matches
    for (final entry in _aliasIndex.entries) {
      double score = 0;
      final indexKey = entry.key;

      if (indexKey.startsWith(normalized)) {
        score = 0.85 - (indexKey.length - normalized.length) * 0.01;
      } else if (normalized.startsWith(indexKey)) {
        score = 0.75 - (normalized.length - indexKey.length) * 0.01;
      } else if (indexKey.length >= 3 && normalized.contains(indexKey)) {
        // H1: Require minimum 3 characters
        score = 0.35 + (indexKey.length * 0.01).clamp(0.0, 0.1);
      } else if (normalized.length >= 3 && indexKey.contains(normalized)) {
        // H1: Require minimum 3 characters
        score = 0.45;
      }

      if (score > 0) {
        candidates.add(MapEntry(entry.value, score));
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by score descending and return best match
    candidates.sort((a, b) => b.value.compareTo(a.value));
    return _cache[candidates.first.key];
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
  Stream<List<IngredientData>> watchAll() async* {
    // ingredients collection — it streamed ~2230 docs on every reconnect.
    // Instead, emit the cached snapshot once. The TTL-driven background
    // refresh in _ensureCacheLoaded keeps the cache fresh across calls.
    await _ensureCacheLoaded();
    yield _cache.values.toList();
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
    _compoundNames.clear();
    _cacheLoadedAt = null;
    _maxUpdatedAt = null;
  }

  /// Disposes resources.
  void dispose() {
    _onCacheInvalidatedListeners.clear();
  }
}
