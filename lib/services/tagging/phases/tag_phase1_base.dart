import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_allergen.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_dietary.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_method.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_nutrition.dart';

/// Phase 1: Base tags calculated directly from ingredient properties and recipe metadata.
///
/// Generates:
/// - Time tags (under-15-min, under-30-min, etc.)
/// - Allergen status (tri-valued logic)
/// - Dietary status (vegetarian, vegan, etc.)
/// - Protein tags (kyckling, nötkött, fisk, etc.)
/// - Base/carb tags (pastabaserad, risbaserad, etc.)
/// - Cooking method tags (ugnsbakad, stekt, etc.)
/// - Dish type tags (soppa, sallad, gryta, etc.)
///
/// ## String Matching Design Decision (H2 - Swedish Character Handling)
///
/// This class uses two patterns for string matching:
///
/// 1. **Word-boundary regex** for short Swedish words (2-4 chars) that could appear
///    as substrings in other words. Example: "ris" in "korianderfrisk".
///    Pattern: `RegExp(r'(?:^|[^a-zåäö])word(?:[^a-zåäö]|$)')`
///
/// 2. **Simple `.contains()`** for:
///    - Longer unique words (5+ chars) like "potatis", "nudl", "pannkaka"
///    - Words within already-filtered groups (e.g., fish names within fish group)
///    - Multi-word phrases like "gräddfil", "hälsans kök"
///
/// The Swedish letters å, ä, ö are included in word boundaries to properly
/// handle Swedish ingredient names and recipe text.
class TagPhase1Base {
  /// Creates a word-boundary regex pattern for Swedish text.
  static RegExp _swedishWordPattern(String word) {
    return RegExp(
      '(?:^|[^a-zåäö])${RegExp.escape(word)}(?:[^a-zåäö]|\$)',
      caseSensitive: false,
    );
  }

  /// Checks if text contains a Swedish word (with word boundaries).
  ///
  /// Use for short words to avoid false positives.
  /// For longer unique words, use simple `.contains()`.
  static bool containsSwedishWord(String text, String word) {
    return _swedishWordPattern(word).hasMatch(text);
  }

  /// Firebase-backed config (optional, falls back to static config).
  final FirebaseTagConfig? _firebaseConfig;

  TagPhase1Base({FirebaseTagConfig? firebaseConfig})
    : _firebaseConfig = firebaseConfig;

  /// Calculates Phase 1 tags.
  Phase1Result calculate(IngredientLookupResult lookup, Recipe recipe) {
    final tags = <String>{};
    final decisions = <TagDecision>[];

    // Time tags from metadata
    tags.addAll(_calculateTimeTags(recipe.core.timeMinutes));

    // Allergen status using tri-valued logic
    final allergenResult = Phase1AllergenCalculator.calculate(
      lookup,
      _firebaseConfig,
    );

    // Dietary status
    final dietaryResult = Phase1DietaryCalculator.calculate(
      lookup,
      _firebaseConfig,
    );

    decisions.addAll(allergenResult.decisions);
    decisions.addAll(dietaryResult.decisions);

    // Protein tags from ingredient groups
    tags.addAll(Phase1NutritionCalculator.calculateProteinTags(lookup));

    // Carb/base tags
    tags.addAll(Phase1NutritionCalculator.calculateCarbTags(lookup, recipe));

    // Cooking method tags from instructions
    tags.addAll(
      Phase1MethodCalculator.calculateCookingMethodTags(
        recipe.core.instructions,
      ),
    );

    // Dish type tags from title
    tags.addAll(
      Phase1MethodCalculator.calculateDishTypeTags(recipe.core.title),
    );

    return Phase1Result(
      tags: tags,
      allergenStatus: allergenResult.status,
      dietaryStatus: dietaryResult.status,
      lookup: lookup,
      decisions: decisions,
    );
  }

  /// Calculates time-based tags from recipe duration.
  Set<String> _calculateTimeTags(int? timeMinutes) {
    if (timeMinutes == null || timeMinutes <= 0) return {};

    final tags = <String>{};

    if (timeMinutes <= 15) tags.add('under-15-min');
    if (timeMinutes <= 30) tags.add('under-30-min');
    if (timeMinutes <= 45) tags.add('under-45-min');
    if (timeMinutes <= 60) tags.add('under-60-min');
    if (timeMinutes > 60) tags.add('över-60-min');

    return tags;
  }
}

/// Result of Phase 1 calculation.
class Phase1Result {
  final Set<String> tags;
  final Map<String, TriState> allergenStatus;
  final Map<String, TriState> dietaryStatus;
  final IngredientLookupResult lookup;

  /// Decision logs explaining why each allergen/dietary status was set.
  final List<TagDecision> decisions;

  const Phase1Result({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.lookup,
    this.decisions = const [],
  });

  bool hasProperty(String property) => lookup.hasProperty(property);
  bool hasTag(String tag) => tags.contains(tag);

  TriState getAllergenStatus(String key) =>
      allergenStatus[key] ?? TriState.unknown;

  TriState getDietaryStatus(String key) =>
      dietaryStatus[key] ?? TriState.unknown;

  TagDecision? getAllergenDecision(String key) =>
      decisions.where((d) => d.type == 'allergen' && d.key == key).firstOrNull;

  TagDecision? getDietaryDecision(String key) =>
      decisions.where((d) => d.type == 'dietary' && d.key == key).firstOrNull;
}

/// Helper class for returning both status and decisions.
class StatusWithDecisions {
  final Map<String, TriState> status;
  final List<TagDecision> decisions;

  const StatusWithDecisions({
    required this.status,
    required this.decisions,
  });
}
