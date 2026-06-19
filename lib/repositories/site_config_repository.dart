import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for loading and caching site-specific parsing configurations.
///
/// Site configs are stored in Firestore under `/site_configs/{domain}` and
/// contain CSS selectors and metadata for extracting recipe data from
/// specific websites. This allows updating parsing logic without app releases.
///
/// BUT-886 (wave-7 audit gap): intentional bypass of [BaseFirebaseRepository]
/// + [PermissionValidationMixin] + audit logging.
///
/// CLIENT-SIDE READ-ONLY. The `/site_configs/{domain}` collection is
/// rules-gated to public read + admin-only write. The client never mutates
/// this collection — every `_collection.doc(...).set()` here is unreachable
/// because the security rules deny it. Writes happen via admin SDK / CI
/// deploy scripts, which have their own audit trail.
///
/// If a future feature lets users contribute site configs, reassess this
/// bypass and add appropriate user-scoped validation.
class SiteConfigRepository {
  final FirebaseFirestore _firestore;

  /// In-memory LRU cache of site configs (BUT-817 — migrated from manual
  /// FIFO eviction).
  late final LruMap<String, _CachedConfig> _cache = LruMap(
    maxSize: _maxCacheSize,
    onEvict: (key, _) => AppLogger.info(
        'cache_eviction service=SiteConfigRepository key=$key bound=$_maxCacheSize'),
  );

  /// Whether default configs have been ensured this session.
  bool _defaultsEnsured = false;

  /// How long cached configs remain valid.
  static const _cacheDuration = Duration(hours: 1);

  /// Maximum number of cached configs.
  static const int _maxCacheSize = 50;

  SiteConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for site configs.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.siteConfigs);

  /// Ensure default configs are available (uses built-in fallbacks).
  ///
  /// Client-side writes to site_configs are blocked by security rules.
  /// Missing configs fall back to built-in defaults via [getConfig].
  Future<void> ensureDefaultConfigs() async {
    if (_defaultsEnsured) return;
    _defaultsEnsured = true;
  }

  static final _defaultConfigs = [
    const SiteConfig(
      domain: 'ica.se',
      titleSelector: 'h1.recipe-title',
      titleSelectorFallback: '[itemprop="name"]',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredient-list li',
      instructionsSelector: '.recipe-steps li',
      instructionsSelectorFallback: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.9,
      notes: 'Schema.org JSON-LD + CSS selectors',
    ),
    const SiteConfig(
      domain: 'koket.se',
      titleSelector: 'h1.recipe-title',
      titleSelectorFallback: '[itemprop="name"]',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredient-list li',
      instructionsSelector: '.recipe-steps li',
      instructionsSelectorFallback: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.85,
      notes: 'Schema.org JSON-LD + CSS selectors',
    ),
    const SiteConfig(
      domain: 'arla.se',
      titleSelector: 'h1.recipe-title',
      titleSelectorFallback: '[itemprop="name"]',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredient-list li',
      instructionsSelector: '.recipe-steps li',
      instructionsSelectorFallback: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.9,
      notes: 'Schema.org JSON-LD + CSS selectors',
    ),
    const SiteConfig(
      domain: 'recept.se',
      titleSelector: 'h1.recipe-title',
      titleSelectorFallback: '[itemprop="name"]',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredient-list li',
      instructionsSelector: '.recipe-steps li',
      instructionsSelectorFallback: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.85,
      notes: 'Recipe aggregator, schema.org markup',
    ),
    const SiteConfig(
      domain: 'tasteline.com',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredients li',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      instructionsSelectorFallback: '.instructions li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.8,
    ),
    const SiteConfig(
      domain: 'coop.se',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredient-list li',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      instructionsSelectorFallback: '.recipe-instructions li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      descriptionSelector: '[itemprop="description"]',
      isSupported: true,
      qualityScore: 0.8,
    ),
    const SiteConfig(
      domain: 'recepten.se',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      ingredientsSelectorFallback: '.ingredients li',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.75,
    ),
    const SiteConfig(
      domain: 'mathem.se',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.75,
    ),
    const SiteConfig(
      domain: 'hemtrevligt.se',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.7,
    ),
    const SiteConfig(
      domain: 'alltommat.se',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.8,
    ),
    const SiteConfig(
      domain: 'bonappetit.com',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.85,
    ),
    const SiteConfig(
      domain: 'allrecipes.com',
      titleSelector: '[itemprop="name"]',
      titleSelectorFallback: 'h1',
      ingredientsSelector: '[itemprop="recipeIngredient"]',
      instructionsSelector: '[itemprop="recipeInstructions"] li',
      portionsSelector: '[itemprop="recipeYield"]',
      timeSelector: '[itemprop="totalTime"]',
      imageSelector: '[itemprop="image"]',
      isSupported: true,
      qualityScore: 0.85,
    ),
  ];

  void _cacheConfig(String domain, _CachedConfig config) {
    _cache[domain] = config;
  }

  /// Load a site config for a domain.
  ///
  /// Returns cached config if available and not expired.
  /// Falls back to default config if not found in Firestore.
  Future<SiteConfig> getConfig(String domain) async {
    // Normalize domain
    final normalizedDomain = _normalizeDomain(domain);

    // Check cache
    final cached = _cache[normalizedDomain];
    if (cached != null && !cached.isExpired) {
      return cached.config;
    }

    // Load from Firestore
    try {
      final doc = await _collection.doc(normalizedDomain).get();

      if (doc.exists && doc.data() != null) {
        final config = SiteConfig.fromFirestore(doc.data()!);
        _cacheConfig(normalizedDomain, _CachedConfig(config));
        AppLogger.debug(
          'SiteConfigRepository: Loaded config for $normalizedDomain',
        );
        return config;
      }
    } catch (e) {
      AppLogger.warning(
        'SiteConfigRepository: Failed to load config for $normalizedDomain: $e',
      );
    }

    // Return default config
    final defaultConfig = SiteConfig.defaultFor(normalizedDomain);
    _cacheConfig(normalizedDomain, _CachedConfig(defaultConfig));
    return defaultConfig;
  }

  /// Load a site config if it exists.
  ///
  /// Returns null if not found (unlike [getConfig] which returns a default).
  Future<SiteConfig?> getConfigIfExists(String domain) async {
    final normalizedDomain = _normalizeDomain(domain);

    // Check cache
    final cached = _cache[normalizedDomain];
    if (cached != null && !cached.isExpired) {
      return cached.config.isSupported ? cached.config : null;
    }

    // Load from Firestore
    try {
      final doc = await _collection.doc(normalizedDomain).get();

      if (doc.exists && doc.data() != null) {
        final config = SiteConfig.fromFirestore(doc.data()!);
        _cacheConfig(normalizedDomain, _CachedConfig(config));

        if (config.isSupported && config.hasSelectors) {
          return config;
        }
      }
    } catch (e) {
      AppLogger.warning(
        'SiteConfigRepository: Failed to load config for $normalizedDomain: $e',
      );
    }

    // Fallback: check built-in defaults (Firestore write may not have completed yet)
    final builtIn =
        _defaultConfigs.where((c) => c.domain == normalizedDomain).firstOrNull;
    if (builtIn != null && builtIn.isSupported && builtIn.hasSelectors) {
      return builtIn;
    }

    return null;
  }

  /// Get every site config in the collection, including auto-created stat-only
  /// docs that lack `isSupported`/selectors (these are written by the parse
  /// pipeline and carry success/failure counts). Unordered — callers sort
  /// client-side. Used by the admin import-health dashboard.
  Future<List<SiteConfig>> getAllConfigs({int limit = 200}) async {
    try {
      final snapshot = await _collection.limit(limit).get();
      return snapshot.docs.map((doc) {
        final config = SiteConfig.fromFirestore(doc.data());
        // Stat-only docs written by the parse pipeline carry no `domain`
        // field — the domain is the doc id. Backfill it so the UI isn't blank.
        return config.domain.isEmpty ? config.copyWith(domain: doc.id) : config;
      }).toList();
    } catch (e) {
      AppLogger.warning(
        'SiteConfigRepository: Failed to load all configs: $e',
      );
      return [];
    }
  }

  /// Get all supported site configs.
  Future<List<SiteConfig>> getSupportedConfigs() async {
    try {
      final snapshot = await _collection
          .where('isSupported', isEqualTo: true)
          .orderBy('qualityScore', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => SiteConfig.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.warning(
        'SiteConfigRepository: Failed to load supported configs: $e',
      );
      return [];
    }
  }

  /// Check if a domain has a high-quality config.
  bool isHighQualityDomain(String domain) {
    final cached = _cache[_normalizeDomain(domain)];
    return cached?.config.isReliable ?? false;
  }

  /// Clear the config cache.
  void clearCache() {
    _cache.clear();
    AppLogger.debug('SiteConfigRepository: Cache cleared');
  }

  /// Normalize a domain for consistent lookup.
  String _normalizeDomain(String domain) {
    var normalized = domain.toLowerCase().trim();

    // Remove common subdomains
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    } else if (normalized.startsWith('m.')) {
      normalized = normalized.substring(2);
    }

    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}

/// Cached site config with expiration.
class _CachedConfig {
  final SiteConfig config;
  final DateTime cachedAt;

  _CachedConfig(this.config) : cachedAt = clock.now();

  bool get isExpired =>
      clock.now().difference(cachedAt) > SiteConfigRepository._cacheDuration;
}
