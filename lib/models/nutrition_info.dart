import 'package:butlery/core/utils/serialization_utils.dart';

/// Structured nutrition data extracted from Schema.org NutritionInformation.
///
/// Schema.org uses strings like "270 calories" — we parse the numeric prefix
/// where possible and keep the raw string as fallback for display.
class NutritionInfo {
  final int? calories;
  final String? fat;
  final String? protein;
  final String? carbs;
  final String? fiber;
  final String? sugar;
  final String? sodium;

  const NutritionInfo({
    this.calories,
    this.fat,
    this.protein,
    this.carbs,
    this.fiber,
    this.sugar,
    this.sodium,
  });

  bool get isEmpty =>
      calories == null &&
      fat == null &&
      protein == null &&
      carbs == null &&
      fiber == null &&
      sugar == null &&
      sodium == null;

  Map<String, dynamic> toJson() => {
    if (calories != null) 'calories': calories,
    if (fat != null) 'fat': fat,
    if (protein != null) 'protein': protein,
    if (carbs != null) 'carbs': carbs,
    if (fiber != null) 'fiber': fiber,
    if (sugar != null) 'sugar': sugar,
    if (sodium != null) 'sodium': sodium,
  };

  Map<String, dynamic> toFirestore() => toJson();

  factory NutritionInfo.fromJson(Map<String, dynamic> json) => NutritionInfo(
    calories: SerializationUtils.safeNullableInt(json, 'calories'),
    fat: SerializationUtils.safeNullableString(json, 'fat'),
    protein: SerializationUtils.safeNullableString(json, 'protein'),
    carbs: SerializationUtils.safeNullableString(json, 'carbs'),
    fiber: SerializationUtils.safeNullableString(json, 'fiber'),
    sugar: SerializationUtils.safeNullableString(json, 'sugar'),
    sodium: SerializationUtils.safeNullableString(json, 'sodium'),
  );

  /// Parse from Schema.org NutritionInformation map.
  /// Fields use strings like "270 calories", "12 grams" — extract numeric prefix.
  factory NutritionInfo.fromSchemaOrg(Map<String, dynamic> data) {
    return NutritionInfo(
      calories: _parseCalories(data['calories']),
      fat: _capString(data['fatContent']),
      protein: _capString(data['proteinContent']),
      carbs: _capString(data['carbohydrateContent']),
      fiber: _capString(data['fiberContent']),
      sugar: _capString(data['sugarContent']),
      sodium: _capString(data['sodiumContent']),
    );
  }

  static int? _parseCalories(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final match = RegExp(r'(\d+)').firstMatch(s);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static String? _capString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    // Cap at 200 chars for safety (external input)
    return s.length > 200 ? s.substring(0, 200) : s;
  }

  NutritionInfo copyWith({
    Object? calories = _sentinel,
    Object? fat = _sentinel,
    Object? protein = _sentinel,
    Object? carbs = _sentinel,
    Object? fiber = _sentinel,
    Object? sugar = _sentinel,
    Object? sodium = _sentinel,
  }) => NutritionInfo(
    calories: calories == _sentinel ? this.calories : calories as int?,
    fat: fat == _sentinel ? this.fat : fat as String?,
    protein: protein == _sentinel ? this.protein : protein as String?,
    carbs: carbs == _sentinel ? this.carbs : carbs as String?,
    fiber: fiber == _sentinel ? this.fiber : fiber as String?,
    sugar: sugar == _sentinel ? this.sugar : sugar as String?,
    sodium: sodium == _sentinel ? this.sodium : sodium as String?,
  );

  @override
  String toString() => 'NutritionInfo(calories: $calories)';
}

const _sentinel = Object();
