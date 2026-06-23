import 'package:butlery/models/parsing/parsed_recipe.dart';

/// Reason why a parsing tier failed.
enum TierFailureReason {
  /// Tier was skipped (not applicable for this input).
  skipped,

  /// Tier timed out.
  timeout,

  /// No data found to parse.
  noData,

  /// Error during parsing.
  parseError,

  /// Network error (e.g., fetching URL).
  networkError,

  /// Rate limited.
  rateLimited,

  /// Invalid response from external service (e.g., LLM).
  invalidResponse,

  /// Input too large for this tier.
  inputTooLarge,

  /// Blocked for security reasons.
  securityBlocked,

  /// DOM traversal deadline exceeded.
  deadlineExceeded,

  /// Schema validation failed (e.g., LLM response).
  schemaValidationFailed,
}

/// Result from a single parsing tier.
///
/// Each tier attempts to parse the recipe and returns success/failure
/// along with quality metrics and cost information.
class TierResult {
  /// Name of the tier (e.g., "SchemaOrg", "SiteConfig", "RuleBased", "LLM").
  final String tierName;

  /// The parsed recipe, if successful.
  final ParsedRecipe? recipe;

  /// Whether parsing succeeded.
  final bool success;

  /// Quality score (0.0-1.0) of the parsed result.
  final double quality;

  /// Time taken to parse.
  final Duration duration;

  /// Cost in SEK (for LLM tier).
  final double? costSek;

  /// Reason for failure, if applicable.
  final TierFailureReason? failureReason;

  /// Number of tokens used (for LLM tier).
  final int? tokensUsed;

  /// Prompt version that produced this result (LLM/OCR tiers only).
  /// Threads from server response → analytics for per-version quality bisection.
  final String? promptVersion;

  const TierResult({
    required this.tierName,
    required this.success,
    required this.quality,
    required this.duration,
    this.recipe,
    this.costSek,
    this.failureReason,
    this.tokensUsed,
    this.promptVersion,
  });

  /// Creates a successful tier result.
  factory TierResult.success({
    required String tierName,
    required ParsedRecipe recipe,
    required Duration duration,
    double? costSek,
    int? tokensUsed,
    String? promptVersion,
  }) => TierResult(
    tierName: tierName,
    recipe: recipe,
    success: true,
    quality: recipe.overallQuality,
    duration: duration,
    costSek: costSek,
    tokensUsed: tokensUsed,
    promptVersion: promptVersion,
  );

  /// Creates a failed tier result.
  factory TierResult.failure({
    required String tierName,
    required TierFailureReason reason,
    required Duration duration,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: reason,
  );

  /// Creates a skipped tier result (tier not applicable).
  factory TierResult.skipped({
    required String tierName,
    Duration duration = Duration.zero,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: TierFailureReason.skipped,
  );

  /// Creates a no-data tier result.
  factory TierResult.noData({
    required String tierName,
    required Duration duration,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: TierFailureReason.noData,
  );

  /// Creates a timeout tier result.
  factory TierResult.timeout({
    required String tierName,
    required Duration duration,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: TierFailureReason.timeout,
  );

  /// Creates a parse error tier result.
  factory TierResult.parseError({
    required String tierName,
    required Duration duration,
    String? message,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: TierFailureReason.parseError,
  );

  /// Creates a copy with updated fields.
  TierResult copyWith({
    String? tierName,
    ParsedRecipe? recipe,
    bool? success,
    double? quality,
    Duration? duration,
    double? costSek,
    TierFailureReason? failureReason,
    int? tokensUsed,
    String? promptVersion,
  }) => TierResult(
    tierName: tierName ?? this.tierName,
    recipe: recipe ?? this.recipe,
    success: success ?? this.success,
    quality: quality ?? this.quality,
    duration: duration ?? this.duration,
    costSek: costSek ?? this.costSek,
    failureReason: failureReason ?? this.failureReason,
    tokensUsed: tokensUsed ?? this.tokensUsed,
    promptVersion: promptVersion ?? this.promptVersion,
  );

  /// Whether this tier was skipped.
  bool get wasSkipped => failureReason == TierFailureReason.skipped;

  /// Whether this tier timed out.
  bool get timedOut => failureReason == TierFailureReason.timeout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TierResult &&
          runtimeType == other.runtimeType &&
          tierName == other.tierName &&
          success == other.success &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(tierName, success, quality);

  @override
  String toString() =>
      'TierResult($tierName: ${success ? "success" : failureReason?.name ?? "failed"}, quality: ${quality.toStringAsFixed(2)})';
}

/// User-facing Swedish messages for tier failure reasons.
/// Used by RecipeParserService to surface actionable feedback.
extension TierFailureReasonMessage on TierFailureReason {
  String get userMessage => switch (this) {
    TierFailureReason.rateLimited => 'Daglig gräns nådd. Försök igen imorgon.',
    TierFailureReason.noData => 'Kunde inte hitta receptinformation.',
    TierFailureReason.invalidResponse => 'AI-svaret kunde inte tolkas.',
    TierFailureReason.schemaValidationFailed =>
      'Receptet hade ogiltiga värden.',
    TierFailureReason.parseError => 'Ett tekniskt fel uppstod.',
    TierFailureReason.timeout => 'Tidsgränsen överskreds. Försök igen.',
    TierFailureReason.networkError =>
      'Nätverksfel. Kontrollera din anslutning.',
    TierFailureReason.securityBlocked =>
      'Innehållet blockerades av säkerhetsskäl.',
    TierFailureReason.inputTooLarge => 'Texten är för lång för bearbetning.',
    TierFailureReason.deadlineExceeded => 'Bearbetningen tog för lång tid.',
    TierFailureReason.skipped => 'Kunde inte hitta receptinformation.',
  };
}
