/// Protein-category classification for weekly-menu balance (BUT-1324).
///
/// Groups the fine-grained protein tags produced by
/// `Phase1NutritionCalculator.calculateProteinTags` into a small set of
/// balancing CATEGORIES, so the menu generator can cap how many dinners share
/// the same protein across a week. Without this, a week of four chicken dinners
/// spread over four different cuisines still reads as "chicken every night" and
/// passes the cuisine-diversity check. Rule-based, no LLM.
///
/// A recipe with no protein tag has no category (`null`) and is left
/// unconstrained by the balance pass — it is never penalised for lacking a
/// signal, mirroring how the cuisine pass ignores recipes with no cuisine tag.
library;

import 'package:butlery/models/recipe_unified.dart';

/// Maps a recipe's protein tags to a coarse protein category used for
/// week-level balance. The category vocabulary intentionally stays small
/// (beef / pork / lamb / game / poultry / fish / shellfish / plant-based / egg)
/// — the goal is variety across the week, not a nutrition taxonomy.
class ProteinCategory {
  ProteinCategory._();

  static const String beef = 'beef';
  static const String pork = 'pork';
  static const String lamb = 'lamb';
  static const String game = 'game';
  static const String poultry = 'poultry';
  static const String fish = 'fish';
  static const String shellfish = 'shellfish';
  static const String plantBased = 'plant-based';
  static const String egg = 'egg';

  /// Fine-grained protein tag → balancing category. The keys are exactly the
  /// tags emitted by `Phase1NutritionCalculator.calculateProteinTags`; keep the
  /// two in sync if new protein tags are added there.
  static const Map<String, String> _tagToCategory = {
    // Red meat
    'nötkött': beef,
    'fläskkött': pork,
    'lamm': lamb,
    'vilt': game,

    // Poultry
    'kyckling': poultry,
    'anka': poultry,
    'kalkon': poultry,

    // Fish (generic + species specifics)
    'fisk': fish,
    'lax': fish,
    'torsk': fish,
    'sill': fish,

    // Shellfish
    'skaldjur': shellfish,
    'räkor': shellfish,

    // Plant-based proteins (incl. legumes as a plant-protein source)
    'tofu': plantBased,
    'tempeh': plantBased,
    'seitan': plantBased,
    'quorn': plantBased,
    'växtfärs': plantBased,
    'bönprotein': plantBased,
    'oumph': plantBased,
    'växtprotein': plantBased,
    'baljväxter': plantBased,

    // Egg
    'ägg': egg,
  };

  /// All recognised protein tags, for fast membership tests.
  static final Set<String> allTags = _tagToCategory.keys.toSet();

  /// "Center of plate" precedence for a multi-protein dish: the primary protein
  /// wins over a trace/secondary one. **Order-independent by design** — we must
  /// NOT rely on tag iteration order, because `TagResult` persists its tags
  /// alphabetically sorted ("M15" in tag_result.dart), so a reloaded chicken +
  /// fish dish would otherwise bucket as fish ('fisk' < 'kyckling'). Egg and
  /// plant-based sit last so a meat/fish dish with a trace egg (e.g. egg-wash)
  /// or bean garnish still classifies by its main protein.
  static const List<String> _categoryPrecedence = [
    beef,
    pork,
    lamb,
    game,
    poultry,
    fish,
    shellfish,
    plantBased,
    egg,
  ];

  /// The balancing protein category for [recipe], or `null` when the recipe
  /// carries no recognised protein tag (unconstrained by the balance pass).
  ///
  /// Mirrors `CuisineConfig.extractCuisineTag` in spirit, but resolves a
  /// multi-protein dish by the fixed [_categoryPrecedence] above rather than by
  /// tag order — deterministic regardless of how the tag set was stored. Balance
  /// is a soft nudge, not an audit.
  static String? categoryOf(Recipe recipe) {
    final tags = recipe.tagResult?.tags;
    if (tags == null || tags.isEmpty) return null;
    String? best;
    var bestRank = _categoryPrecedence.length;
    for (final tag in tags) {
      final category = _tagToCategory[tag];
      if (category == null) continue;
      final rank = _categoryPrecedence.indexOf(category);
      if (rank < bestRank) {
        bestRank = rank;
        best = category;
      }
    }
    return best;
  }
}
