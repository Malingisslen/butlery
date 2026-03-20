import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/import/cache/url_normalizer.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/services/import/cache/cache_entry.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Global cross-user recipe cache for deduplication.
///
/// This service prevents redundant scraping by caching extracted recipes
/// across all users. When a user imports a URL that another user has
/// already imported, the cached result is returned instead of re-scraping.
///
/// The cache uses two lookup keys:
/// 1. URL hash - for exact URL matches
/// 2. Content fingerprint - for detecting duplicates from different sources
class GlobalRecipeCache extends BaseService {
  @override
  String get serviceName => 'GlobalRecipeCache';

  final FirestoreRepository _firestoreRepo;
  final UrlNormalizer _urlNormalizer;
  final ContentFingerprint _fingerprinter;

  static const String _collectionName = FirestoreCollections.globalRecipeCache;

  /// TTL by source type (in days)
  static const Map<String, int> _ttlBySource = {
    'youtube': 180, // YouTube videos rarely change
    'website': 90, // Web pages update occasionally
    'tiktok': 60, // Social media content may be deleted
    'instagram': 60,
    'text': 30, // Manual text input less reliable
    'ocr': 30, // OCR may have errors
  };

  GlobalRecipeCache({
    required FirestoreRepository firestoreRepository,
    required UrlNormalizer urlNormalizer,
    required ContentFingerprint fingerprinter,
  })  : _firestoreRepo = firestoreRepository,
        _urlNormalizer = urlNormalizer,
        _fingerprinter = fingerprinter;

  /// Find a cached recipe by URL.
  ///
  /// Returns the cached entry if found and not expired, null otherwise.
  Future<CacheEntry?> findByUrl(String url) async {
    final urlHash = _urlNormalizer.hash(url);
    if (urlHash == null) {
      AppLogger.debug('GlobalRecipeCache: Invalid URL, cannot lookup: $url');
      return null;
    }

    try {
      final doc = await _collection.doc(urlHash).get();

      if (!doc.exists) {
        AppLogger.debug('GlobalRecipeCache: Cache miss for URL hash $urlHash');
        AppLogger.analytics('cache_miss', {
          'urlHash': urlHash,
        });
        return null;
      }

      final entry = CacheEntry.fromFirestore(doc.data()!);

      if (entry.isExpired) {
        AppLogger.debug(
          'GlobalRecipeCache: Entry expired (age: ${entry.ageInDays}d, '
          'ttl: ${entry.ttlDays}d)',
        );
        return null;
      }

      AppLogger.info(
        'GlobalRecipeCache: Cache hit for ${entry.domain ?? "unknown"} '
        '(age: ${entry.ageInDays}d, accesses: ${entry.accessCount})',
      );
      AppLogger.analytics('cache_hit', {
        'domain': entry.domain,
        'sourceType': entry.sourceType,
        'ageInDays': entry.ageInDays,
      });

      // Update access stats (fire and forget)
      _updateAccessStats(doc.reference);

      return entry;
    } catch (e) {
      AppLogger.warning('GlobalRecipeCache: Error finding by URL: $e');
      return null;
    }
  }

  /// Find a cached recipe by content fingerprint.
  ///
  /// This enables detection of duplicate recipes from different sources.
  /// Returns the cached entry if found and not expired, null otherwise.
  Future<CacheEntry?> findByContent({
    required String title,
    required List<String> ingredients,
    required int instructionCount,
  }) async {
    final fingerprint = _fingerprinter.generate(
      title: title,
      ingredients: ingredients,
      instructionCount: instructionCount,
    );

    if (fingerprint == null) {
      AppLogger.debug(
        'GlobalRecipeCache: Cannot generate fingerprint for content',
      );
      return null;
    }

    return findByFingerprint(fingerprint);
  }

  /// Find a cached recipe by pre-computed fingerprint.
  Future<CacheEntry?> findByFingerprint(String fingerprint) async {
    try {
      final query = await _collection
          .where('contentFingerprint', isEqualTo: fingerprint)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppLogger.debug(
          'GlobalRecipeCache: No content match for fingerprint $fingerprint',
        );
        return null;
      }

      final doc = query.docs.first;
      final entry = CacheEntry.fromFirestore(doc.data());

      if (entry.isExpired) {
        AppLogger.debug(
          'GlobalRecipeCache: Content match expired (age: ${entry.ageInDays}d)',
        );
        return null;
      }

      AppLogger.info(
        'GlobalRecipeCache: Content match found (domain: ${entry.domain})',
      );

      // Update access stats (fire and forget)
      _updateAccessStats(doc.reference);

      return entry;
    } catch (e) {
      AppLogger.warning('GlobalRecipeCache: Error finding by fingerprint: $e');
      return null;
    }
  }

  /// Save a successfully extracted recipe to the cache.
  ///
  /// [input] The original input (URL or other source identifier)
  /// [recipeData] The extracted recipe data as a map
  /// [extractionMeta] Metadata about how the recipe was extracted
  /// [sourceType] Type of source (website, youtube, tiktok, etc.)
  Future<bool> save({
    required String input,
    required Map<String, dynamic> recipeData,
    required ExtractionMeta extractionMeta,
    required String sourceType,
  }) async {
    return await executeServiceOperation(
          () async {
            // Generate cache keys
            final urlHash = _urlNormalizer.looksLikeUrl(input)
                ? _urlNormalizer.hash(input)
                : null;

            final fingerprint = _fingerprinter.generateFromMap(recipeData);

            if (urlHash == null && fingerprint == null) {
              AppLogger.warning(
                'GlobalRecipeCache: Cannot cache - no valid key generated',
              );
              return false;
            }

            // Determine TTL
            final ttlDays = _ttlBySource[sourceType] ?? 90;

            // Extract domain if URL
            final domain = _urlNormalizer.looksLikeUrl(input)
                ? _urlNormalizer.extractDomain(input)
                : null;

            // Create cache entry
            final entry = CacheEntry(
              urlHash: urlHash,
              contentFingerprint: fingerprint ?? '',
              domain: domain,
              sourceType: sourceType,
              recipe: recipeData,
              extractionMeta: extractionMeta,
              ttlDays: ttlDays,
            );

            // Use URL hash as document ID if available, otherwise generate from fingerprint
            final docId = urlHash ?? 'fp_$fingerprint';

            await _collection.doc(docId).set(
                  entry.toFirestore(),
                  SetOptions(merge: false), // Overwrite if exists
                );

            AppLogger.info(
              'GlobalRecipeCache: Cached recipe from $domain '
              '(source: $sourceType, ttl: ${ttlDays}d)',
            );
            AppLogger.analytics('cache_save', {
              'domain': domain,
              'sourceType': sourceType,
              'pipeline': extractionMeta.pipeline,
              'tier': extractionMeta.tier,
            });

            return true;
          },
          operationName: 'Save to cache',
          requiresAuth: true,
        ) ??
        false;
  }

  /// Get cache statistics for monitoring.
  Future<CacheStats?> getStats() async {
    return executeServiceOperation(
      () async {
        final snapshot = await _collection.count().get();
        final totalCount = snapshot.count ?? 0;

        // Sample recent entries for stats
        final recentDocs = await _collection
            .orderBy('cachedAt', descending: true)
            .limit(100)
            .get();

        int expiredCount = 0;
        int totalAccesses = 0;
        final domainCounts = <String, int>{};

        for (final doc in recentDocs.docs) {
          final entry = CacheEntry.fromFirestore(doc.data());
          if (entry.isExpired) expiredCount++;
          totalAccesses += entry.accessCount;
          if (entry.domain != null) {
            domainCounts[entry.domain!] =
                (domainCounts[entry.domain!] ?? 0) + 1;
          }
        }

        return CacheStats(
          totalEntries: totalCount,
          sampleSize: recentDocs.docs.length,
          expiredInSample: expiredCount,
          totalAccessesInSample: totalAccesses,
          topDomains: domainCounts,
        );
      },
      operationName: 'Get stats',
      requiresAuth: true,
    );
  }

  /// Get the cache collection reference
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestoreRepo.firestore.collection(_collectionName);

  /// Update access statistics (fire and forget)
  void _updateAccessStats(DocumentReference<Map<String, dynamic>> ref) {
    // Don't await - this is a fire-and-forget operation
    ref.update({
      'accessCount': FieldValue.increment(1),
      'lastAccessedAt': FieldValue.serverTimestamp(),
    }).catchError((e) {
      // Log but don't fail
      AppLogger.debug('GlobalRecipeCache: Failed to update access stats: $e');
    });
  }
}

/// Statistics about the global recipe cache.
class CacheStats {
  final int totalEntries;
  final int sampleSize;
  final int expiredInSample;
  final int totalAccessesInSample;
  final Map<String, int> topDomains;

  const CacheStats({
    required this.totalEntries,
    required this.sampleSize,
    required this.expiredInSample,
    required this.totalAccessesInSample,
    required this.topDomains,
  });

  double get sampleHitRate =>
      sampleSize > 0 ? totalAccessesInSample / sampleSize : 0;

  double get estimatedExpiredPercent =>
      sampleSize > 0 ? expiredInSample / sampleSize * 100 : 0;

  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, sampleHits: $totalAccessesInSample, '
        'expired: ${estimatedExpiredPercent.toStringAsFixed(1)}%)';
  }
}
