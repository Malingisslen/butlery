import 'package:butlery/core/utils/serialization_utils.dart';

/// BUT-202: Pure-Dart model for a single substitution suggestion used by
/// cooking-mode "out of X? try…" bottom sheet.
///
/// Firestore schema — `ingredient_substitutions` collection keyed on
/// canonical ingredient IDs emitted by `IngredientLookupService.lookupFromRaw`:
///
///   ingredient_substitutions/{canonicalIngredientId}
///     substitutes: [
///       { name: "yoghurt", ratio: 1.0, context: "i bakning" },
///       { name: "crème fraîche", ratio: 0.75 }
///     ]
///
/// Read-only to users this sprint; admin-side seeding is future work.
class IngredientSubstitution {
  /// Display name of the substitute (e.g. "yoghurt").
  final String name;

  /// Proportional amount relative to original — 1.0 = 1:1, 0.75 = 75%.
  final double ratio;

  /// Optional context hint, e.g. "i bakning", "för stekning". May be null.
  final String? context;

  const IngredientSubstitution({
    required this.name,
    required this.ratio,
    this.context,
  });

  /// Safe-map deserializer — null/missing `context` stays null in the model.
  factory IngredientSubstitution.fromMap(Map<String, dynamic> data) {
    return IngredientSubstitution(
      name: SerializationUtils.safeString(data, 'name'),
      // Default ratio 1.0 so a malformed entry degrades to a 1:1 badge
      // rather than "0%", which would be meaningless in the sheet.
      ratio: SerializationUtils.safeDouble(data, 'ratio', defaultValue: 1.0),
      context: SerializationUtils.safeNullableString(data, 'context'),
    );
  }

  /// Writes `name`/`ratio` unconditionally; omits `context` when null so
  /// round-tripped docs don't grow a sentinel field.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'ratio': ratio,
    };
    if (context != null) {
      map['context'] = context;
    }
    return map;
  }
}
