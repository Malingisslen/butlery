import 'package:clock/clock.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/parsing/tier_result.dart';

/// Source type for recipe import.
enum ImportSource {
  /// Recipe from a web URL.
  url,

  /// Plain text input.
  text,

  /// Instagram post.
  instagram,

  /// TikTok video.
  tiktok,

  /// YouTube video.
  youtube,

  /// Photo/image (OCR).
  photo,

  /// Voice-dictated recipe (on-device transcription).
  voice,

  /// File import (CSV, Excel).
  file,

  /// Recipe archive.
  archive,

  /// Unknown source.
  unknown,
}

/// Extension methods for ImportSource.
extension ImportSourceExtension on ImportSource {
  /// Whether this source requires network access.
  bool get requiresNetwork => switch (this) {
    ImportSource.url ||
    ImportSource.instagram ||
    ImportSource.tiktok ||
    ImportSource.youtube => true,
    _ => false,
  };

  /// Whether this source may contain social media formatting.
  bool get isSocialMedia => switch (this) {
    ImportSource.instagram || ImportSource.tiktok => true,
    _ => false,
  };

  /// Whether this source might need LLM enhancement.
  bool get mayNeedLlm => switch (this) {
    ImportSource.text ||
    ImportSource.instagram ||
    ImportSource.tiktok ||
    ImportSource.youtube ||
    ImportSource.photo => true,
    _ => false,
  };

  /// Default TTL in days for caching recipes from this source.
  int get defaultCacheTtlDays => switch (this) {
    ImportSource.youtube => 180,
    ImportSource.url => 90,
    ImportSource.instagram || ImportSource.tiktok => 60,
    ImportSource.text || ImportSource.photo => 30,
    _ => 90,
  };
}

/// Metadata about how a recipe was parsed.
///
/// Contains information about the parsing process, source,
/// timing, and results from each tier.
class ParseMetadata {
  /// The source type.
  final ImportSource source;

  /// Domain of the source URL, if applicable.
  final String? domain;

  /// Original source URL, if applicable.
  final String? sourceUrl;

  /// Cache key for this parse result.
  final String? cacheKey;

  /// Results from each parsing tier that was attempted.
  final List<TierResult> tierResults;

  /// Total time taken to parse.
  final Duration totalParseTime;

  /// Parser version used.
  final String parserVersion;

  /// Timestamp when parsing completed.
  final DateTime timestamp;

  /// Total cost in SEK (for LLM usage).
  final double? totalCostSek;

  /// Total tokens used (for LLM usage).
  final int? totalTokensUsed;

  const ParseMetadata({
    required this.source,
    required this.tierResults,
    required this.totalParseTime,
    required this.parserVersion,
    required this.timestamp,
    this.domain,
    this.sourceUrl,
    this.cacheKey,
    this.totalCostSek,
    this.totalTokensUsed,
  });

  /// Creates metadata for a cache hit (no parsing needed).
  factory ParseMetadata.cacheHit({
    required ImportSource source,
    required String parserVersion,
    String? domain,
    String? cacheKey,
  }) => ParseMetadata(
    source: source,
    domain: domain,
    cacheKey: cacheKey,
    tierResults: const [],
    totalParseTime: Duration.zero,
    parserVersion: parserVersion,
    timestamp: clock.now(),
  );

  /// The tier that succeeded, if any.
  String? get successfulTier =>
      tierResults.where((t) => t.success).map((t) => t.tierName).firstOrNull;

  /// Whether parsing used LLM.
  bool get usedLlm => tierResults.any(
    (t) => t.tierName == 'LLM' && t.success && t.tokensUsed != null,
  ); // matches LlmTier.tierIdentifier

  /// The quality from the final successful tier.
  double get finalQuality =>
      tierResults.where((t) => t.success).lastOrNull?.quality ?? 0.0;

  /// Summary of tier attempts for logging.
  Map<String, String> get tierSummary => {
    for (final tier in tierResults)
      tier.tierName: tier.success
          ? 'success'
          : tier.failureReason?.name ?? 'failed',
  };

  /// Creates a copy with updated fields.
  ParseMetadata copyWith({
    ImportSource? source,
    String? domain,
    String? sourceUrl,
    String? cacheKey,
    List<TierResult>? tierResults,
    Duration? totalParseTime,
    String? parserVersion,
    DateTime? timestamp,
    double? totalCostSek,
    int? totalTokensUsed,
  }) => ParseMetadata(
    source: source ?? this.source,
    domain: domain ?? this.domain,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    cacheKey: cacheKey ?? this.cacheKey,
    tierResults: tierResults ?? this.tierResults,
    totalParseTime: totalParseTime ?? this.totalParseTime,
    parserVersion: parserVersion ?? this.parserVersion,
    timestamp: timestamp ?? this.timestamp,
    totalCostSek: totalCostSek ?? this.totalCostSek,
    totalTokensUsed: totalTokensUsed ?? this.totalTokensUsed,
  );

  /// Converts to JSON (minimal version for storage).
  Map<String, dynamic> toJson() => {
    'source': source.name,
    if (domain != null) 'domain': domain,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (cacheKey != null) 'cacheKey': cacheKey,
    'parserVersion': parserVersion,
    'timestamp': timestamp.toIso8601String(),
    'totalParseTimeMs': totalParseTime.inMilliseconds,
    if (successfulTier != null) 'successfulTier': successfulTier,
    if (totalCostSek != null) 'totalCostSek': totalCostSek,
    if (totalTokensUsed != null) 'totalTokensUsed': totalTokensUsed,
  };

  /// Creates from JSON.
  factory ParseMetadata.fromJson(Map<String, dynamic> json) => ParseMetadata(
    source: SerializationUtils.safeEnumByName(
      ImportSource.values,
      json['source']?.toString() ?? 'url',
      ImportSource.url,
    ),
    domain: json['domain']?.toString(),
    sourceUrl: json['sourceUrl']?.toString(),
    cacheKey: json['cacheKey']?.toString(),
    parserVersion: json['parserVersion']?.toString() ?? '1.0',
    timestamp: SerializationUtils.safeRequiredDateTime(json, 'timestamp'),
    totalParseTime: Duration(
      milliseconds: SerializationUtils.safeInt(json, 'totalParseTimeMs'),
    ),
    tierResults: const [],
    totalCostSek: SerializationUtils.safeNullableDouble(json, 'totalCostSek'),
    totalTokensUsed: SerializationUtils.safeNullableInt(
      json,
      'totalTokensUsed',
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParseMetadata &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          cacheKey == other.cacheKey &&
          parserVersion == other.parserVersion;

  @override
  int get hashCode => Object.hash(source, cacheKey, parserVersion);

  @override
  String toString() =>
      'ParseMetadata(source: ${source.name}, tier: $successfulTier, '
      'time: ${totalParseTime.inMilliseconds}ms)';
}
