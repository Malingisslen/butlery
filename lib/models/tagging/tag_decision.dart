import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// H3: Structured decision log for allergen/dietary tag decisions.
///
/// Captures WHY a recipe received a specific allergen or dietary status,
/// enabling users to understand and trust the tagging system.
class TagDecision {
  /// Decision category: 'allergen' or 'dietary'.
  final String type;

  /// The specific allergen or dietary key (e.g., 'gluten', 'vegetarisk').
  final String key;

  /// The resulting TriState from this decision.
  final TriState result;

  /// Human-readable explanation of why this decision was made.
  ///
  /// Examples:
  /// - "Coverage 75% < 100% - cannot confirm"
  /// - "Ingredient 'mjölk' has property 'dairy'"
  /// - "No ingredients with property 'gluten' at 100% coverage"
  final String reason;

  /// Ingredients that triggered this decision (for CONTAINS status).
  final List<String>? triggeringIngredients;

  const TagDecision({
    required this.type,
    required this.key,
    required this.result,
    required this.reason,
    this.triggeringIngredients,
  });

  /// Creates an allergen decision.
  factory TagDecision.allergen({
    required String key,
    required TriState result,
    required String reason,
    List<String>? triggeringIngredients,
  }) {
    return TagDecision(
      type: 'allergen',
      key: key,
      result: result,
      reason: reason,
      triggeringIngredients: triggeringIngredients,
    );
  }

  /// Creates a dietary decision.
  factory TagDecision.dietary({
    required String key,
    required TriState result,
    required String reason,
    List<String>? triggeringIngredients,
  }) {
    return TagDecision(
      type: 'dietary',
      key: key,
      result: result,
      reason: reason,
      triggeringIngredients: triggeringIngredients,
    );
  }

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'key': key,
      'result': result.toFirestore(),
      'reason': reason,
      if (triggeringIngredients != null && triggeringIngredients!.isNotEmpty)
        'triggeringIngredients': triggeringIngredients,
    };
  }

  /// Creates from JSON.
  factory TagDecision.fromJson(Map<String, dynamic> json) {
    return TagDecision(
      type: SerializationUtils.safeString(
        json,
        'type',
        defaultValue: 'unknown',
      ),
      key: (json['key'] as String?).orEmpty(),
      result: TriStateExtension.fromFirestore(json['result']),
      reason: (json['reason'] as String?).orEmpty(),
      triggeringIngredients: (json['triggeringIngredients'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  @override
  String toString() {
    final triggers = triggeringIngredients?.isNotEmpty == true
        ? ' [${triggeringIngredients!.join(", ")}]'
        : '';
    return 'TagDecision($type:$key=${result.name}: $reason$triggers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TagDecision) return false;
    return type == other.type &&
        key == other.key &&
        result == other.result &&
        reason == other.reason &&
        _listEquals(triggeringIngredients, other.triggeringIngredients);
  }

  @override
  int get hashCode => Object.hash(
    type,
    key,
    result,
    reason,
    triggeringIngredients != null
        ? Object.hashAll(triggeringIngredients!)
        : null,
  );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
