import 'package:butlery/core/utils/serialization_utils.dart';

/// Types of corrections that can be made to ingredients.
enum IngredientCorrectionType {
  /// New ingredient added by user (not in original parse)
  added,

  /// Ingredient removed by user (was in original parse)
  removed,

  /// Quantity was wrong (e.g., "1" → "2")
  quantityFixed,

  /// Unit was wrong (e.g., "msk" → "dl")
  unitFixed,

  /// Ingredient name was wrong (e.g., "skinka" → "rökt skinka")
  nameFixed,

  /// Multiple fields were corrected
  multipleFixed,

  /// Only order changed (low priority for training)
  reordered,
}

/// Correction record for a single ingredient.
/// Captures what the parser extracted vs what the user corrected.
class IngredientCorrection {
  /// Type of correction made
  final IngredientCorrectionType type;

  /// Index in original parsed list (null if added)
  final int? originalIndex;

  /// Index in corrected list (null if removed)
  final int? correctedIndex;

  /// Original parsed ingredient line (truncated to 200 chars)
  final String? originalLine;

  /// Original parsed quantity
  final String? originalQuantity;

  /// Original parsed unit
  final String? originalUnit;

  /// Original parsed ingredient name
  final String? originalName;

  /// Corrected ingredient line from user (truncated to 200 chars)
  final String? correctedLine;

  /// Whether quantity was changed
  final bool quantityChanged;

  /// Whether unit was changed
  final bool unitChanged;

  /// Whether name was changed
  final bool nameChanged;

  /// The corrected ingredient name (just the name, not the full line).
  /// Populated when nameChanged is true, used by Cloud Function to learn aliases.
  final String? correctedName;

  const IngredientCorrection({
    required this.type,
    this.originalIndex,
    this.correctedIndex,
    this.originalLine,
    this.originalQuantity,
    this.originalUnit,
    this.originalName,
    this.correctedLine,
    this.correctedName,
    this.quantityChanged = false,
    this.unitChanged = false,
    this.nameChanged = false,
  });

  /// Factory for when user adds a new ingredient
  factory IngredientCorrection.added({
    required int correctedIndex,
    required String correctedLine,
  }) {
    return IngredientCorrection(
      type: IngredientCorrectionType.added,
      correctedIndex: correctedIndex,
      correctedLine: _truncate(correctedLine),
    );
  }

  /// Factory for when user removes an ingredient
  factory IngredientCorrection.removed({
    required int originalIndex,
    required String originalLine,
    String? originalQuantity,
    String? originalUnit,
    String? originalName,
  }) {
    return IngredientCorrection(
      type: IngredientCorrectionType.removed,
      originalIndex: originalIndex,
      originalLine: _truncate(originalLine),
      originalQuantity: originalQuantity,
      originalUnit: originalUnit,
      originalName: originalName,
    );
  }

  /// Factory for when user modifies an ingredient
  factory IngredientCorrection.modified({
    required int originalIndex,
    required int correctedIndex,
    required String originalLine,
    required String correctedLine,
    String? originalQuantity,
    String? originalUnit,
    String? originalName,
    String? correctedName,
    required bool quantityChanged,
    required bool unitChanged,
    required bool nameChanged,
  }) {
    final changeCount = (quantityChanged ? 1 : 0) +
        (unitChanged ? 1 : 0) +
        (nameChanged ? 1 : 0);

    IngredientCorrectionType type;
    if (changeCount > 1) {
      type = IngredientCorrectionType.multipleFixed;
    } else if (quantityChanged) {
      type = IngredientCorrectionType.quantityFixed;
    } else if (unitChanged) {
      type = IngredientCorrectionType.unitFixed;
    } else if (nameChanged) {
      type = IngredientCorrectionType.nameFixed;
    } else {
      type = IngredientCorrectionType.reordered;
    }

    return IngredientCorrection(
      type: type,
      originalIndex: originalIndex,
      correctedIndex: correctedIndex,
      originalLine: _truncate(originalLine),
      originalQuantity: originalQuantity,
      originalUnit: originalUnit,
      originalName: originalName,
      correctedLine: _truncate(correctedLine),
      correctedName: correctedName,
      quantityChanged: quantityChanged,
      unitChanged: unitChanged,
      nameChanged: nameChanged,
    );
  }

  /// Truncate string to max 200 characters
  static String? _truncate(String? text, [int maxLength = 200]) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (originalIndex != null) 'originalIndex': originalIndex,
        if (correctedIndex != null) 'correctedIndex': correctedIndex,
        if (originalLine != null) 'originalLine': originalLine,
        if (originalQuantity != null) 'originalQuantity': originalQuantity,
        if (originalUnit != null) 'originalUnit': originalUnit,
        if (originalName != null) 'originalName': originalName,
        if (correctedLine != null) 'correctedLine': correctedLine,
        if (correctedName != null) 'correctedName': correctedName,
        if (quantityChanged) 'quantityChanged': true,
        if (unitChanged) 'unitChanged': true,
        if (nameChanged) 'nameChanged': true,
      };

  factory IngredientCorrection.fromJson(Map<String, dynamic> json) {
    return IngredientCorrection(
      type: IngredientCorrectionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => IngredientCorrectionType.multipleFixed,
      ),
      originalIndex: SerializationUtils.safeNullableInt(json, 'originalIndex'),
      correctedIndex:
          SerializationUtils.safeNullableInt(json, 'correctedIndex'),
      originalLine: json['originalLine']?.toString(),
      originalQuantity: json['originalQuantity']?.toString(),
      originalUnit: json['originalUnit']?.toString(),
      originalName: json['originalName']?.toString(),
      correctedLine: json['correctedLine']?.toString(),
      correctedName: json['correctedName']?.toString(),
      quantityChanged: SerializationUtils.safeBool(json, 'quantityChanged'),
      unitChanged: SerializationUtils.safeBool(json, 'unitChanged'),
      nameChanged: SerializationUtils.safeBool(json, 'nameChanged'),
    );
  }

  @override
  String toString() =>
      'IngredientCorrection(type: $type, original: $originalLine, corrected: $correctedLine)';
}
