import 'dart:typed_data';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Sealed class hierarchy for import results.
///
/// Provides type-safe handling of different import outcomes:
/// - [ImportSuccess] - Recipe extracted successfully
/// - [ImportPartial] - Partial extraction, needs enhancement
/// - [ImportNeedsAssistance] - Automation failed, user input needed
/// - [ImportNeedsScreenshot] - Platform requires screenshot for extraction
/// - [ImportFailure] - Import failed with error
sealed class ImportResultV2 {
  const ImportResultV2();

  /// Whether the import completed successfully
  bool get isSuccess => this is ImportSuccess;

  /// Whether the import needs user assistance
  bool get needsAssistance =>
      this is ImportNeedsAssistance || this is ImportNeedsScreenshot;

  /// Whether the import failed
  bool get isFailure => this is ImportFailure;

  /// Get the recipe if available (for Success or Partial)
  Recipe? get recipe {
    if (this is ImportSuccess) return (this as ImportSuccess).recipe;
    return null;
  }
}

/// Successful import with complete recipe data.
class ImportSuccess extends ImportResultV2 {
  /// The extracted recipe
  @override
  final Recipe recipe;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// The extraction pipeline used (e.g., "website", "youtube", "ocr")
  final String pipeline;

  /// Which tier within the pipeline succeeded (0-based)
  final int tier;

  /// The specific extraction method (e.g., "json-ld", "site-parser", "llm")
  final String method;

  /// Whether this result came from cache
  final bool fromCache;

  /// Whether LLM was used in extraction
  final bool usedLlm;

  /// Whether the result should be reviewed by user (LLM results)
  final bool requiresReview;

  /// Additional metadata about the extraction
  final Map<String, dynamic>? metadata;

  const ImportSuccess({
    required this.recipe,
    required this.confidence,
    required this.pipeline,
    required this.tier,
    required this.method,
    this.fromCache = false,
    this.usedLlm = false,
    this.requiresReview = false,
    this.metadata,
  });

  /// Create from legacy ImportManagerResult
  factory ImportSuccess.fromLegacy(
    Recipe recipe, {
    String? strategy,
    Map<String, dynamic>? metadata,
  }) {
    return ImportSuccess(
      recipe: recipe,
      confidence: 0.8,
      pipeline: metadata?['pipeline'] as String? ?? 'unknown',
      tier: metadata?['tier'] as int? ?? 0,
      method: strategy ?? 'unknown',
      fromCache: metadata?['fromCache'] as bool? ?? false,
      usedLlm: metadata?['usedLlm'] as bool? ?? false,
      requiresReview: metadata?['requiresReview'] as bool? ?? false,
      metadata: metadata,
    );
  }
}

/// Partial extraction - some data extracted but incomplete.
///
/// This result indicates that rule-based extraction got some data
/// but the recipe is incomplete. Can be passed to LLM for enhancement.
class ImportPartial extends ImportResultV2 {
  /// Partial recipe data as a map (not a complete Recipe)
  final Map<String, dynamic> partialData;

  /// Raw extracted text (for LLM context)
  final String? extractedText;

  /// Raw HTML (for LLM extraction)
  final String? rawHtml;

  /// Confidence score for partial data (typically 0.5-0.8)
  final double confidence;

  /// The pipeline that produced this partial result
  final String pipeline;

  /// Which tier produced this partial result
  final int tier;

  /// What fields are missing
  final List<String> missingFields;

  const ImportPartial({
    required this.partialData,
    this.extractedText,
    this.rawHtml,
    required this.confidence,
    required this.pipeline,
    required this.tier,
    this.missingFields = const [],
  });

  /// Check if we have enough data to attempt LLM enhancement
  bool get canEnhance =>
      partialData.isNotEmpty &&
      (extractedText != null || rawHtml != null) &&
      confidence >= 0.3;

  /// Get the title if available
  String? get title => partialData['title'] as String?;

  /// Get ingredients if available
  List<String>? get ingredients {
    final value = partialData['ingredients'];
    if (value is List) return value.cast<String>();
    return null;
  }
}

/// Import needs user assistance - automation failed.
///
/// This result is returned when all automated extraction tiers fail
/// but we have some extracted content the user can work with.
class ImportNeedsAssistance extends ImportResultV2 {
  /// Extracted text that user can select from
  final String extractedText;

  /// Any partial data we managed to extract
  final Map<String, dynamic>? partialData;

  /// Thumbnail URL if available (for visual reference)
  final String? thumbnailUrl;

  /// Image bytes if we have a photo
  final Uint8List? imageBytes;

  /// User-friendly message explaining what happened
  final String message;

  /// Suggested title if we detected one
  final String? suggestedTitle;

  /// Lines that look like ingredients (pre-selected for user)
  final List<int> likelyIngredientLines;

  const ImportNeedsAssistance({
    required this.extractedText,
    this.partialData,
    this.thumbnailUrl,
    this.imageBytes,
    required this.message,
    this.suggestedTitle,
    this.likelyIngredientLines = const [],
  });

  /// Get the extracted text as lines
  List<String> get textLines =>
      extractedText.split('\n').where((l) => l.trim().isNotEmpty).toList();
}

/// Import needs a screenshot from the user.
///
/// This is returned for platforms where we can't extract content
/// programmatically (e.g., Instagram private accounts, TikTok videos).
class ImportNeedsScreenshot extends ImportResultV2 {
  /// The platform name (e.g., "TikTok", "Instagram")
  final String platform;

  /// The original URL
  final String url;

  /// Thumbnail URL if available
  final String? thumbnailUrl;

  /// User-friendly message explaining why screenshot is needed
  final String message;

  const ImportNeedsScreenshot({
    required this.platform,
    required this.url,
    this.thumbnailUrl,
    required this.message,
  });
}

/// Import failed with error.
class ImportFailure extends ImportResultV2 {
  /// User-friendly error message
  final String message;

  /// Error code for programmatic handling
  final ImportErrorCode errorCode;

  /// When to retry (for rate limiting)
  final Duration? retryAfter;

  /// Technical details for logging
  final String? technicalDetails;

  /// The pipeline that failed
  final String? pipeline;

  /// Which tier failed
  final int? tier;

  const ImportFailure({
    required this.message,
    required this.errorCode,
    this.retryAfter,
    this.technicalDetails,
    this.pipeline,
    this.tier,
  });

  /// Create from exception — generic user message, technical details logged only.
  factory ImportFailure.fromException(Object error, {String? pipeline}) {
    return ImportFailure(
      message: AppLocale.current.importErrorUnexpected,
      errorCode: ImportErrorCode.unknown,
      technicalDetails: error.toString(),
      pipeline: pipeline,
    );
  }

  /// Create rate limit failure
  factory ImportFailure.rateLimited({
    required String message,
    required Duration retryAfter,
  }) {
    return ImportFailure(
      message: message,
      errorCode: ImportErrorCode.rateLimited,
      retryAfter: retryAfter,
    );
  }
}

/// Error codes for programmatic handling of import failures.
enum ImportErrorCode {
  /// Unknown or unclassified error
  unknown,

  /// Network error (no connection, timeout)
  network,

  /// Rate limit exceeded
  rateLimited,

  /// LLM quota exceeded
  llmQuotaExceeded,

  /// Invalid URL format
  invalidUrl,

  /// URL not accessible (404, 403, etc.)
  urlNotAccessible,

  /// Platform blocked (requires login, geo-restricted)
  platformBlocked,

  /// No recipe content detected
  noRecipeContent,

  /// OCR failed
  ocrFailed,

  /// Parsing failed
  parsingFailed,

  /// Save to database failed
  saveFailed,

  /// User cancelled
  cancelled,
}

/// Extension for error code messages
extension ImportErrorCodeExtension on ImportErrorCode {
  /// Get localized user-friendly message
  String get swedishMessage {
    final l = AppLocale.current;
    switch (this) {
      case ImportErrorCode.unknown:
        return l.importErrorUnexpected;
      case ImportErrorCode.network:
        return l.importErrorNoInternet;
      case ImportErrorCode.rateLimited:
        return l.importErrorTooManyImports;
      case ImportErrorCode.llmQuotaExceeded:
        return l.importErrorAiQuotaExhausted;
      case ImportErrorCode.invalidUrl:
        return l.importErrorInvalidUrl;
      case ImportErrorCode.urlNotAccessible:
        return l.importErrorCouldNotReachPage;
      case ImportErrorCode.platformBlocked:
        return l.importErrorLoginRequired;
      case ImportErrorCode.noRecipeContent:
        return l.importErrorNoRecipeFound;
      case ImportErrorCode.ocrFailed:
        return l.importErrorCouldNotReadImage;
      case ImportErrorCode.parsingFailed:
        return l.importErrorCouldNotParseRecipe;
      case ImportErrorCode.saveFailed:
        return l.importErrorCouldNotSaveRecipe;
      case ImportErrorCode.cancelled:
        return l.importErrorCancelled;
    }
  }
}
