// lib/services/menu/menu_allergen_trust.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// Trust-guarded allergen/dietary status for MENU filtering (BUT-1464).
///
/// Pure-compute static helper — deliberately NOT a `BaseService` (same
/// category as `ingredient_categorizer`): no async work, no Firebase reads,
/// no lifecycle. Everything here is derived from data already on the recipe.
///
/// WHY this exists: the 2026-07-01 menu-allergen audit found the menu filters
/// read `tagResult.getAllergenStatus(...)` raw, ignoring both the manual tag
/// overrides and the staleness guards that the recipe LIST already applies.
/// A user who manually corrected a recipe to "contains gluten" could still
/// get that recipe in a generated menu. This helper is the single shared
/// definition of "what status should menu filtering trust".
///
/// The trust model is deliberately ASYMMETRIC (Data/ML panel condition,
/// binding):
///
/// * A stale `FREE` claim is downgraded to `UNKNOWN`. Stale free-claims are
///   exactly what a generator-version bump (`needsRetagging`) distrusts —
///   the new engine may know about ingredients the old one missed. UNKNOWN
///   then flows through the existing `includeUnknownInMenu` soft path.
///   The same downgrade applies at `coverage < 1.0` (unmatched ingredients
///   can't prove absence) — defense-in-depth mirroring the recipe list; the
///   tagging engine already forces UNKNOWN below full coverage.
/// * A stale `CONTAINS` is NEVER downgraded. A danger verdict was computed
///   from a positive ingredient match at the time of tagging and stays
///   trustworthy — retagging can only refine it, not make the allergen
///   disappear from the ingredient list.
/// * Manual overrides are applied LAST: a human correction wins over both
///   the auto verdict and the staleness downgrade (mirrors
///   `TagEditingService.getEffectiveAllergenStatus`).
class MenuAllergenTrust {
  MenuAllergenTrust._();

  /// Effective allergen status for menu filtering: auto verdict, with the
  /// stale-FREE downgrade, then manual override on top.
  static TriState effectiveAllergenStatus(Recipe recipe, String allergenKey) {
    final tagResult = recipe.tagResult;
    // No tag data at all is functionally UNKNOWN (BUT-1394 semantics).
    var base = tagResult?.getAllergenStatus(allergenKey) ?? TriState.unknown;
    if (base == TriState.free &&
        tagResult != null &&
        (tagResult.needsRetagging || tagResult.coverage < 1.0)) {
      base = TriState.unknown;
    }
    final overrides = recipe.tagOverrides;
    if (overrides == null) return base;
    // Human wins over staleness — an explicit per-key override replaces the
    // (possibly downgraded) auto verdict entirely.
    return overrides.getEffectiveAllergenStatus(allergenKey, base);
  }

  /// Dietary counterpart of [effectiveAllergenStatus] with identical
  /// asymmetric semantics (stale FREE → UNKNOWN, CONTAINS kept, override last).
  static TriState effectiveDietaryStatus(Recipe recipe, String dietaryKey) {
    final tagResult = recipe.tagResult;
    var base = tagResult?.getDietaryStatus(dietaryKey) ?? TriState.unknown;
    if (base == TriState.free &&
        tagResult != null &&
        (tagResult.needsRetagging || tagResult.coverage < 1.0)) {
      base = TriState.unknown;
    }
    final overrides = recipe.tagOverrides;
    if (overrides == null) return base;
    return overrides.getEffectiveDietaryStatus(dietaryKey, base);
  }
}
