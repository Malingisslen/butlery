import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';

/// Shared context for parsing operations.
///
/// Contains pre-processed data to avoid redundant work across tiers.
/// Each parsing request creates one context that is shared by all tiers.
class ParsingContext {
  /// Original source URL, if applicable.
  final String? sourceUrl;

  /// Normalized/canonical URL for caching.
  final String? normalizedUrl;

  /// URL hash for cache lookups.
  final String? urlHash;

  /// Import source type.
  final ImportSource source;

  /// Whether the input source requires OCR error correction.
  bool get isOcrSource => source == ImportSource.photo;

  /// Domain extracted from URL.
  final String? domain;

  /// Raw input content (HTML, text, etc.).
  final String rawContent;

  /// Sanitized content.
  final String sanitizedContent;

  /// Content hash for cache key generation.
  final String contentHash;

  /// Pre-parsed HTML document (cached to avoid re-parsing).
  Object? parsedDocument;

  /// JSON-LD data extracted from HTML (cached).
  Map<String, dynamic>? jsonLdData;

  /// Sanitization result from security check.
  final SanitizationResult sanitizationResult;

  /// User ID for per-user cache isolation.
  final String userId;

  /// Parser version for cache invalidation.
  final String parserVersion;

  /// When parsing started.
  final DateTime startTime;

  /// Metadata accumulator for tier results.
  final List<TierResultEntry> tierResults;

  ParsingContext({
    required this.rawContent,
    required this.source,
    required this.userId,
    required this.parserVersion,
    this.sourceUrl,
    this.normalizedUrl,
    this.urlHash,
    this.domain,
    required this.sanitizedContent,
    required this.contentHash,
    required this.sanitizationResult,
  })  : startTime = DateTime.now(),
        tierResults = [];

  /// Create context from URL input.
  factory ParsingContext.fromUrl({
    required String url,
    required String htmlContent,
    required String userId,
    required String parserVersion,
    String? normalizedUrl,
    String? urlHash,
  }) {
    final sanitizer = HtmlSanitizer.instance;
    final sanitizationResult = sanitizer.check(htmlContent);
    final sanitizedContent = sanitizer.sanitize(htmlContent);
    final contentHash = _hashContent(sanitizedContent);
    final domain = _extractDomain(url);

    return ParsingContext(
      sourceUrl: url,
      normalizedUrl: normalizedUrl ?? url,
      urlHash: urlHash,
      source: ImportSource.url,
      domain: domain,
      rawContent: htmlContent,
      sanitizedContent: sanitizedContent,
      contentHash: contentHash,
      sanitizationResult: sanitizationResult,
      userId: userId,
      parserVersion: parserVersion,
    );
  }

  /// Create context from text input.
  factory ParsingContext.fromText({
    required String text,
    required ImportSource source,
    required String userId,
    required String parserVersion,
    String? sourceUrl,
  }) {
    final sanitizer = HtmlSanitizer.instance;
    final sanitizedContent = sanitizer.sanitizeText(text);
    final sanitizationResult = sanitizer.check(text);
    final contentHash = _hashContent(sanitizedContent);

    return ParsingContext(
      sourceUrl: sourceUrl,
      source: source,
      rawContent: text,
      sanitizedContent: sanitizedContent,
      contentHash: contentHash,
      sanitizationResult: sanitizationResult,
      userId: userId,
      parserVersion: parserVersion,
    );
  }

  /// Whether the content passed security checks.
  bool get isSecure =>
      sanitizationResult.isClean && !sanitizationResult.hasCriticalIssues;

  /// Whether this context has a URL source.
  bool get hasUrl => sourceUrl != null && sourceUrl!.isNotEmpty;

  /// Time elapsed since parsing started.
  Duration get elapsed => DateTime.now().difference(startTime);

  /// Best partial result from earlier tiers, for selective LLM enhancement.
  /// When set, the LLM tier can use enhance mode to patch only weak fields
  /// instead of doing full extraction.
  ParsedRecipePartial? bestPartialRecipe;

  // Single-entry cache for parseStructure results
  ParsedRecipeStructure? _cachedStructure;
  String? _structureCacheKey;

  /// Returns cached structure if text matches, otherwise parses fresh.
  ParsedRecipeStructure parseStructureCached(String text) {
    if (_cachedStructure != null && _structureCacheKey == text) {
      return _cachedStructure!;
    }
    final result = SwedishLineClassifier.instance.parseStructure(text);
    _cachedStructure = result;
    _structureCacheKey = text;
    return result;
  }

  /// Add a tier result to the context.
  void addTierResult(TierResultEntry result) {
    tierResults.add(result);
  }

  /// Get the best result so far (highest quality successful tier).
  TierResultEntry? get bestResult {
    final successful = tierResults.where((r) => r.success).toList();
    if (successful.isEmpty) return null;
    successful.sort((a, b) => b.quality.compareTo(a.quality));
    return successful.first;
  }

  /// Whether parsing should continue (no high-quality result yet).
  bool shouldContinueParsing({double qualityThreshold = 0.7}) {
    final best = bestResult;
    if (best == null) return true;
    return best.quality < qualityThreshold;
  }

  /// Extract domain from URL.
  static String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return null;
    }
  }

  /// Hash content for cache key using SHA-256 (16 hex chars).
  static String _hashContent(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  @override
  String toString() =>
      'ParsingContext(source: ${source.name}, domain: $domain, '
      'secure: $isSecure, tiers: ${tierResults.length})';
}

/// Entry for tracking tier results in context.
class TierResultEntry {
  final String tierName;
  final bool success;
  final double quality;
  final Duration duration;
  final String? failureReason;

  const TierResultEntry({
    required this.tierName,
    required this.success,
    required this.quality,
    required this.duration,
    this.failureReason,
  });

  @override
  String toString() =>
      'TierResultEntry($tierName: ${success ? "success" : "failed"}, '
      'quality: ${(quality * 100).toInt()}%)';
}

/// Partial recipe data from earlier tiers for selective LLM enhancement.
///
/// Contains good fields that don't need re-extraction and identifies
/// which fields the LLM should focus on.
class ParsedRecipePartial {
  final Map<String, dynamic> goodFields;
  final List<String> weakFields;

  const ParsedRecipePartial({
    required this.goodFields,
    required this.weakFields,
  });

  /// Whether enhancement mode should be used (few weak fields).
  bool get shouldEnhance => weakFields.length <= 2 && goodFields.isNotEmpty;
}
