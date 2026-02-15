import 'package:butlery/core/utils/serialization_utils.dart';

/// Model representing an ingredient and its possible substitutions.
/// Used by the substitution database for ingredient replacement suggestions.
class IngredientSubstitution {
  final String ingredientName;
  final String? ingredientNameEn;
  final List<SubstitutionOption> substitutions;

  const IngredientSubstitution({
    required this.ingredientName,
    this.ingredientNameEn,
    required this.substitutions,
  });

  factory IngredientSubstitution.fromMap(Map<String, dynamic> data) {
    return IngredientSubstitution(
      ingredientName: SerializationUtils.safeString(data, 'ingredientName'),
      ingredientNameEn:
          SerializationUtils.safeNullableString(data, 'ingredientNameEn'),
      substitutions: SerializationUtils.safeObjectList(
        data,
        'substitutions',
        (s) => SubstitutionOption.fromMap(s),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'ingredientName': ingredientName,
        'ingredientNameEn': ingredientNameEn,
        'substitutions': substitutions.map((s) => s.toMap()).toList(),
      };
}

/// A single substitution option for an ingredient.
class SubstitutionOption {
  final String name;
  final String? ratio;
  final String? notes;
  final List<String> dietaryTags;

  const SubstitutionOption({
    required this.name,
    this.ratio,
    this.notes,
    this.dietaryTags = const [],
  });

  factory SubstitutionOption.fromMap(Map<String, dynamic> data) {
    return SubstitutionOption(
      name: SerializationUtils.safeString(data, 'name'),
      ratio: SerializationUtils.safeNullableString(data, 'ratio'),
      notes: SerializationUtils.safeNullableString(data, 'notes'),
      dietaryTags: SerializationUtils.safeStringList(data, 'dietaryTags'),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ratio': ratio,
        'notes': notes,
        'dietaryTags': dietaryTags,
      };
}
