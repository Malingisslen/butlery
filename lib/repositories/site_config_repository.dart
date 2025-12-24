import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/core/utils/logger.dart';

/// Repository for loading and caching site-specific parsing configurations.
///
/// Site configs are stored in Firestore under `/site_configs/{domain}` and
/// contain CSS selectors and metadata for extracting recipe data from
/// specific websites. This allows updating parsing logic without app releases.
class SiteConfigRepository {
  final FirebaseFirestore _firestore;

  /// In-memory cache of site configs.
  final Map<String, _CachedConfig> _cache = {};

  /// How long cached configs remain valid.
  static const _cacheDuration = Duration(hours: 1);

  SiteConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for site configs.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('site_configs');

  /// Seed site configs if the collection is empty.
  ///
  /// This is a one-time operation that populates the site_configs collection
  /// with CSS selectors for Swedish recipe sites. It calls the seedSiteConfigs
  /// Cloud Function which requires authentication.
  ///
  /// This is non-blocking - if seeding fails, parsing still works (just without
  /// site-specific selectors from Firestore).
  Future<void> seedConfigsIfEmpty() async {
    try {
      final snapshot = await _collection.limit(1).get();

      if (snapshot.docs.isEmpty) {
        AppLogger.info('SiteConfigRepository: Collection empty, seeding configs...');

        final result = await FirebaseFunctions.instance
            .httpsCallable('seedSiteConfigs')
            .call<Map<String, dynamic>>({});

        final data = result.data;
        final count = data['count'] ?? 0;
        AppLogger.info('SiteConfigRepository: Seeded $count site configs');
      } else {
        AppLogger.debug('SiteConfigRepository: Site configs already exist');
      }
    } catch (e) {
      // Non-blocking - parsing still works without site configs
      AppLogger.warning('SiteConfigRepository: Failed to seed configs: $e');
    }
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

    // Remove www prefix
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
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
