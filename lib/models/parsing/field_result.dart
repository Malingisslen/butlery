import 'package:butlery/core/utils/serialization_utils.dart';

/// Confidence level for a parsed field value.
enum ParseConfidence {
  /// High confidence - value extracted from structured data (JSON-LD, schema.org)
  high,

  /// Medium confidence - value extracted but may need verification
  medium,

  /// Low confidence - value uncertain, likely needs user review
  low,

  /// Failed - could not extract value
  failed,
}

/// Extension to get numeric score from confidence level.
extension ParseConfidenceScore on ParseConfidence {
  /// Returns a 0.0-1.0 score for this confidence level.
  double get score => switch (this) {
        ParseConfidence.high => 1.0,
        ParseConfidence.medium => 0.7,
        ParseConfidence.low => 0.3,
        ParseConfidence.failed => 0.0,
      };

  /// Whether this confidence level indicates the value needs review.
  bool get needsReview =>
      this == ParseConfidence.low || this == ParseConfidence.failed;
}

/// Result of parsing a single field, with value and confidence tracking.
///
/// This enables smart merging of results from multiple parsing tiers
/// and targeted LLM patching of only low-confidence fields.
class FieldResult<T> {
  /// The extracted value, or null if extraction failed.
  final T? value;

  /// Confidence level of the extraction.
  final ParseConfidence confidence;

  /// Reason for failure or low confidence, if applicable.
  final String? failureReason;

  const FieldResult({
    this.value,
    required this.confidence,
    this.failureReason,
  });

  /// Creates a successful high-confidence result.
  factory FieldResult.success(T value) => FieldResult(
        value: value,
        confidence: ParseConfidence.high,
      );

  /// Creates a medium-confidence result (uncertain but has value).
  factory FieldResult.uncertain(T value) => FieldResult(
        value: value,
        confidence: ParseConfidence.medium,
      );

  /// Creates a low-confidence result that likely needs user review.
  factory FieldResult.low(T value, {String? reason}) => FieldResult(
        value: value,
        confidence: ParseConfidence.low,
        failureReason: reason,
      );

  /// Creates a failed result with reason.
  factory FieldResult.failed(String reason) => FieldResult(
        value: null,
        confidence: ParseConfidence.failed,
        failureReason: reason,
      );

  /// Creates a medium-confidence result with optional reason.
  factory FieldResult.mediumConfidence(T value, [String? reason]) =>
      FieldResult(
        value: value,
        confidence: ParseConfidence.medium,
        failureReason: reason,
      );

  /// Maps a numeric confidence score to the appropriate confidence level.
  ///
  /// Thresholds: ≥0.7 → success, ≥0.5 → medium, ≥0.3 → low, <0.3 → low.
  static FieldResult<T> fromConfidenceScore<T>(
    T value,
    double score,
    String source,
  ) {
    if (score >= 0.7) return FieldResult.success(value);
    if (score >= 0.5) {
      return FieldResult.mediumConfidence(value, 'Parsed via $source');
    }
    if (score >= 0.3) {
      return FieldResult.lowConfidence(
        value,
        '$source: some items unstructured',
      );
    }
    return FieldResult.lowConfidence(
      value,
      '$source: most items unstructured',
    );
  }

  /// Creates a low-confidence result with optional reason.
  factory FieldResult.lowConfidence(T value, [String? reason]) => FieldResult(
        value: value,
        confidence: ParseConfidence.low,
        failureReason: reason,
      );

  /// Whether this result has a value.
  bool get hasValue => value != null;

  /// Whether this result needs user review.
  bool get needsReview => confidence.needsReview;

  /// Numeric confidence score (0.0-1.0).
  double get confidenceScore => confidence.score;

  /// Converts to JSON with optional value converter.
  Map<String, dynamic> toJson([Object? Function(T)? valueConverter]) => {
        'value': value != null
            ? (valueConverter != null ? valueConverter(value as T) : value)
            : null,
        'confidence': confidence.name,
        if (failureReason != null) 'failureReason': failureReason,
      };

  /// Creates from JSON with value converter.
  factory FieldResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) valueConverter,
  ) =>
      FieldResult(
        value: json['value'] != null ? valueConverter(json['value']) : null,
        confidence: SerializationUtils.safeEnumByName(ParseConfidence.values,
            json['confidence']?.toString() ?? 'medium', ParseConfidence.medium),
        failureReason: json['failureReason']?.toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldResult<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          confidence == other.confidence &&
          failureReason == other.failureReason;

  @override
  int get hashCode => Object.hash(value, confidence, failureReason);

  @override
  String toString() =>
      'FieldResult(value: $value, confidence: ${confidence.name})';
}
