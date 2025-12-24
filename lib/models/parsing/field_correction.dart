/// Simple field correction for title, portions, time fields.
/// Captures the original and corrected values for non-list fields.
class FieldCorrection {
  /// Original value from parser (may be null if not extracted)
  final String? originalValue;

  /// Corrected value from user
  final String? correctedValue;

  const FieldCorrection({
    this.originalValue,
    this.correctedValue,
  });

  /// Returns true if values are meaningfully different
  bool get hasDifference {
    if (originalValue == correctedValue) return false;
    if (originalValue?.trim() == correctedValue?.trim()) return false;
    return true;
  }

  /// Factory to create from two values, returns null if no difference
  static FieldCorrection? create({
    String? original,
    String? corrected,
  }) {
    final correction = FieldCorrection(
      originalValue: original,
      correctedValue: corrected,
    );
    return correction.hasDifference ? correction : null;
  }

  /// Factory for integer fields (portions)
  static FieldCorrection? createFromInt({
    int? original,
    int? corrected,
  }) {
    if (original == corrected) return null;
    return FieldCorrection(
      originalValue: original?.toString(),
      correctedValue: corrected?.toString(),
    );
  }

  /// Factory for duration fields (time)
  static FieldCorrection? createFromDuration({
    Duration? original,
    Duration? corrected,
  }) {
    final originalMinutes = original?.inMinutes;
    final correctedMinutes = corrected?.inMinutes;
    if (originalMinutes == correctedMinutes) return null;
    return FieldCorrection(
      originalValue: originalMinutes?.toString(),
      correctedValue: correctedMinutes?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (originalValue != null) 'original': originalValue,
        if (correctedValue != null) 'corrected': correctedValue,
      };

  factory FieldCorrection.fromJson(Map<String, dynamic> json) {
    return FieldCorrection(
      originalValue: json['original'] as String?,
      correctedValue: json['corrected'] as String?,
    );
  }

  @override
  String toString() =>
      'FieldCorrection(original: $originalValue, corrected: $correctedValue)';
}
