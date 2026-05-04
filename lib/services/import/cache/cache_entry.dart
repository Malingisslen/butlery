import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Represents a cached recipe entry in the global recipe cache.
///
/// This model stores extracted recipe data along with metadata about
/// the extraction process, enabling cross-user deduplication and
/// analytics on extraction success rates.
class CacheEntry {
  /// SHA256 hash of the normalized source URL (null for non-URL sources).
  final String? urlHash;

  /// Content-based fingerprint for deduplication across sources.
  final String contentFingerprint;

  /// Domain of the source URL (e.g., "ica.se").
  final String? domain;

  /// Source type identifier (e.g., "website", "youtube", "tiktok").
  final String sourceType;

  /// The cached recipe data as a map (compatible with Recipe.fromJson).
  final Map<String, dynamic> recipe;

  /// Metadata about how the recipe was extracted.
  final ExtractionMeta extractionMeta;

  /// When this entry was cached.
  final DateTime cachedAt;

  /// Time-to-live in days before this entry expires.
  final int ttlDays;

  /// Number of times this cache entry has been accessed.
  final int accessCount;

  /// When this entry was last accessed.
  final DateTime? lastAccessedAt;

  CacheEntry({
    this.urlHash,
    required this.contentFingerprint,
    this.domain,
    required this.sourceType,
    required this.recipe,
    required this.extractionMeta,
    DateTime? cachedAt,
    this.ttlDays = 90,
    this.accessCount = 1,
    this.lastAccessedAt,
  }) : cachedAt = cachedAt ?? clock.now();

  /// Create from Firestore document data.
  factory CacheEntry.fromFirestore(Map<String, dynamic> data) {
    return CacheEntry(
      urlHash: SerializationUtils.safeNullableString(data, 'urlHash'),
      contentFingerprint: SerializationUtils.safeString(
        data,
        'contentFingerprint',
      ),
      domain: SerializationUtils.safeNullableString(data, 'domain'),
      sourceType: SerializationUtils.safeString(
        data,
        'sourceType',
        defaultValue: 'unknown',
      ),
      recipe: SerializationUtils.safeMap(data, 'recipe'),
      extractionMeta: SerializationUtils.safeNestedObject(
            data,
            'extractionMeta',
            ExtractionMeta.fromMap,
          ) ??
          ExtractionMeta.empty(),
      cachedAt: SerializationUtils.safeDateTime(data, 'cachedAt'),
      ttlDays: SerializationUtils.safeInt(data, 'ttlDays', defaultValue: 90),
      accessCount: SerializationUtils.safeInt(
        data,
        'accessCount',
        defaultValue: 1,
      ),
      lastAccessedAt: SerializationUtils.safeDateTime(data, 'lastAccessedAt'),
    );
  }

  /// Convert to Firestore document data.
  Map<String, dynamic> toFirestore() {
    return {
      if (urlHash != null) 'urlHash': urlHash,
      'contentFingerprint': contentFingerprint,
      if (domain != null) 'domain': domain,
      'sourceType': sourceType,
      'recipe': recipe,
      'extractionMeta': extractionMeta.toMap(),
      'cachedAt': FieldValue.serverTimestamp(),
      'ttlDays': ttlDays,
      'expireAt': Timestamp.fromDate(clock.now().add(Duration(days: ttlDays))),
      'accessCount': accessCount,
      'lastAccessedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Check if this cache entry has expired.
  bool get isExpired {
    final expirationDate = cachedAt.add(Duration(days: ttlDays));
    return clock.now().isAfter(expirationDate);
  }

  /// Get the age of this cache entry in days.
  int get ageInDays {
    return clock.now().difference(cachedAt).inDays;
  }

  /// Create a copy with updated access stats.
  CacheEntry withAccessUpdate() {
    return CacheEntry(
      urlHash: urlHash,
      contentFingerprint: contentFingerprint,
      domain: domain,
      sourceType: sourceType,
      recipe: recipe,
      extractionMeta: extractionMeta,
      cachedAt: cachedAt,
      ttlDays: ttlDays,
      accessCount: accessCount + 1,
      lastAccessedAt: clock.now(),
    );
  }

  @override
  String toString() {
    return 'CacheEntry(domain: $domain, fingerprint: $contentFingerprint, '
        'source: $sourceType, age: ${ageInDays}d)';
  }
}

/// Metadata about how a recipe was extracted.
///
/// Used for analytics and debugging extraction pipelines.
class ExtractionMeta {
  /// The extraction pipeline used (e.g., "website", "youtube", "ocr").
  final String pipeline;

  /// Which tier within the pipeline succeeded (0-based index).
  final int tier;

  /// The specific extraction method (e.g., "json-ld", "site-parser", "llm").
  final String method;

  /// Confidence score of the extraction (0.0 to 1.0).
  final double confidence;

  /// Whether LLM was used in extraction.
  final bool usedLlm;

  /// Whether this extraction requires user review.
  final bool requiresReview;

  const ExtractionMeta({
    required this.pipeline,
    required this.tier,
    required this.method,
    required this.confidence,
    this.usedLlm = false,
    this.requiresReview = false,
  });

  /// Create an empty/unknown metadata object.
  factory ExtractionMeta.empty() {
    return const ExtractionMeta(
      pipeline: 'unknown',
      tier: 0,
      method: 'unknown',
      confidence: 0.0,
    );
  }

  /// Create from map data.
  factory ExtractionMeta.fromMap(Map<String, dynamic> data) {
    return ExtractionMeta(
      pipeline: SerializationUtils.safeString(
        data,
        'pipeline',
        defaultValue: 'unknown',
      ),
      tier: SerializationUtils.safeInt(data, 'tier'),
      method: SerializationUtils.safeString(
        data,
        'method',
        defaultValue: 'unknown',
      ),
      confidence: SerializationUtils.safeDouble(data, 'confidence'),
      usedLlm: SerializationUtils.safeBool(data, 'usedLlm'),
      requiresReview: SerializationUtils.safeBool(data, 'requiresReview'),
    );
  }

  /// Convert to map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'pipeline': pipeline,
      'tier': tier,
      'method': method,
      'confidence': confidence,
      'usedLlm': usedLlm,
      'requiresReview': requiresReview,
    };
  }

  /// Get a human-readable tier name.
  String get tierName {
    switch (pipeline) {
      case 'website':
        switch (tier) {
          case 0:
            return 'JSON-LD';
          case 1:
            return 'Site Parser';
          case 2:
            return 'Heuristic';
          case 3:
            return 'WebView';
          case 4:
            return 'LLM';
          default:
            return 'Tier $tier';
        }
      case 'youtube':
        switch (tier) {
          case 0:
            return 'Description';
          case 1:
            return 'Chapters';
          case 2:
            return 'Auto Captions';
          case 3:
            return 'Manual Captions';
          case 4:
            return 'LLM';
          case 5:
            return 'User Assisted';
          default:
            return 'Tier $tier';
        }
      case 'ocr':
        switch (tier) {
          case 0:
            return 'Tesseract';
          case 1:
            return 'OCR.space';
          case 2:
            return 'Google Vision';
          case 3:
            return 'LLM Vision';
          default:
            return 'Tier $tier';
        }
      default:
        return 'Tier $tier';
    }
  }

  @override
  String toString() {
    return 'ExtractionMeta(pipeline: $pipeline, tier: $tierName, '
        'method: $method, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }
}
