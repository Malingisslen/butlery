import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for loading and caching site-specific parsing configurations.
///
/// Site configs are stored in Firestore under `/site_configs/{domain}` and
/// contain CSS selectors and metadata for extracting recipe data from
/// specific websites. This allows updating parsing logic without app releases.
class SiteConfigRepository {
  final FirebaseFirestore _firestore;

  /// In-memory cache of site configs.
  final Map<String, _CachedConfig> _cache = {};

  /// Whether default configs have been ensured this session.
  bool _defaultsEnsured = false;

  /// How long cached configs remain valid.
  static const _cacheDuration = Duration(hours: 1);

  SiteConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for site configs.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.siteConfigs);

  /// Ensure configs exist for known recipe sites.
  ///
  /// Reads all default config docs in parallel, then batch-writes any missing
  /// ones. Skips entirely if already called this session.
  Future<void> ensureDefaultConfigs() async {
    if (_defaultsEnsured) return;

    try {
      final docs = await Future.wait(
        _defaultConfigs.map((c) => _collection.doc(c.domain).get()),
      );

      final missing = <SiteConfig>[];
      for (var i = 0; i < docs.length; i++) {
        if (!docs[i].exists) {
          missing.add(_defaultConfigs[i]);
        }
      }

      if (missing.isNotEmpty) {
        final batch = _firestore.batch();
        for (final config in missing) {
          batch.set(_collection.doc(config.domain), config.toFirestore());
        }
        await batch.commit();
        AppLogger.debug(
            'SiteConfigRepository: Added ${missing.length} missing configs');
      }

      _defaultsEnsured = true;
    } catch (e) {
      AppLogger.warning(
          'SiteConfigRepository: Failed to ensure default configs: $e');
    }
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
        _cache[normalizedDomain] = _CachedConfig(config);
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
    _cache[normalizedDomain] = _CachedConfig(defaultConfig);
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
        _cache[normalizedDomain] = _CachedConfig(config);

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

  /// Report a successful parse from a domain.
  ///
  /// Increments the success count and updates quality score.
  Future<void> reportSuccess(String domain) async {
    final normalizedDomain = _normalizeDomain(domain);

    try {
      await _collection.doc(normalizedDomain).set(
        {
          'successCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Invalidate cache
      _cache.remove(normalizedDomain);
    } catch (e) {
      AppLogger.debug('SiteConfigRepository: Failed to report success: $e');
    }
  }

  /// Report a failed parse from a domain.
  ///
  /// Increments the failure count.
  Future<void> reportFailure(String domain) async {
    final normalizedDomain = _normalizeDomain(domain);

    try {
      await _collection.doc(normalizedDomain).set(
        {
          'failureCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Invalidate cache
      _cache.remove(normalizedDomain);
    } catch (e) {
      AppLogger.debug('SiteConfigRepository: Failed to report failure: $e');
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

  _CachedConfig(this.config) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > SiteConfigRepository._cacheDuration;
}
