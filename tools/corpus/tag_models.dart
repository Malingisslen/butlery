/// Tag-accuracy answer-key data contract.
///
/// Pure Dart — NO `package:butlery` / Flutter imports — so the metric layer and
/// these models run under plain `dart test`. The harness maps the real
/// `TagResult` onto these structs at the boundary (`TriState.name` →
/// [TagTriState]), exactly as [GoldRecipe] maps onto `ParsedIngredient`.
library;

/// Pure-Dart mirror of the app's `TriState` (contains / free / unknown).
///
/// The three values are kept DISTINCT on purpose: allergen safety must never
/// collapse FREE+UNKNOWN into one "safe-ish" bucket (the Data/ML integrity
/// mandate). `unknown` is the safe default for any unrecognized input.
enum TagTriState {
  contains,
  free,
  unknown
  ;

  /// Accepts enum-name (`free`) or Firestore (`FREE`) casing. Anything else —
  /// including null — becomes [unknown], never a false safety claim.
  static TagTriState fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'contains':
        return TagTriState.contains;
      case 'free':
        return TagTriState.free;
      default:
        return TagTriState.unknown;
    }
  }

  String get jsonValue => name;
}

/// A verified (or draft) tag answer key for one recipe. Lives next to the
/// recipe's `gold.json` as `tags.gold.json`. [verified] gates scoring — the
/// scorecard skips drafts and reports them as unlabeled, so silent
/// under-coverage never reads as a pass.
class GoldTags {
  final bool verified;

  /// Allergen key (e.g. `gluten`, `nötter`) → expected verdict.
  final Map<String, TagTriState> allergens;

  /// Dietary key (e.g. `vegansk`) → expected verdict.
  final Map<String, TagTriState> dietary;

  /// Expected classification tags (cuisine/method/dish-type/…). Optional —
  /// scored as a set when present.
  final Set<String> expectedTags;

  const GoldTags({
    required this.verified,
    this.allergens = const {},
    this.dietary = const {},
    this.expectedTags = const {},
  });

  Map<String, dynamic> toJson() => {
    'verified': verified,
    if (allergens.isNotEmpty)
      'allergens': {
        for (final e in allergens.entries) e.key: e.value.jsonValue,
      },
    if (dietary.isNotEmpty)
      'dietary': {
        for (final e in dietary.entries) e.key: e.value.jsonValue,
      },
    if (expectedTags.isNotEmpty) 'expectedTags': expectedTags.toList()..sort(),
  };

  factory GoldTags.fromJson(Map<String, dynamic> json) => GoldTags(
    verified: json['verified'] == true,
    allergens: _triMap(json['allergens']),
    dietary: _triMap(json['dietary']),
    expectedTags: ((json['expectedTags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
  );

  static Map<String, TagTriState> _triMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        e.key.toString(): TagTriState.fromString(e.value?.toString()),
    };
  }
}

/// The tagging pipeline's prediction for one recipe, in pure-Dart form. The
/// harness builds this from a real `TagResult` (mapping `TriState` → enum,
/// recording the lookup coverage) before handing it to the scorer.
class PredictedTags {
  final Map<String, TagTriState> allergens;
  final Map<String, TagTriState> dietary;
  final Set<String> tags;

  /// Ingredient-lookup coverage for this recipe (0.0–1.0). Recorded so the
  /// scorecard can surface unresolved-ingredient rate — the dominant cause of
  /// `unknown` allergen verdicts.
  final double coverage;

  /// Number of ingredient names the DB lookup failed to resolve.
  final int unmatchedIngredients;

  const PredictedTags({
    this.allergens = const {},
    this.dietary = const {},
    this.tags = const {},
    this.coverage = 0.0,
    this.unmatchedIngredients = 0,
  });

  Map<String, dynamic> toJson() => {
    'allergens': {
      for (final e in allergens.entries) e.key: e.value.jsonValue,
    },
    'dietary': {
      for (final e in dietary.entries) e.key: e.value.jsonValue,
    },
    'tags': tags.toList()..sort(),
    'coverage': coverage,
    'unmatchedIngredients': unmatchedIngredients,
  };

  factory PredictedTags.fromJson(Map<String, dynamic> json) => PredictedTags(
    allergens: GoldTags._triMap(json['allergens']),
    dietary: GoldTags._triMap(json['dietary']),
    tags: ((json['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
    coverage: (json['coverage'] as num?)?.toDouble() ?? 0.0,
    unmatchedIngredients: (json['unmatchedIngredients'] as num?)?.toInt() ?? 0,
  );
}
