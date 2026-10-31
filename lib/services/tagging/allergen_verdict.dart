// lib/services/tagging/allergen_verdict.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// The one answer to "does this recipe contain X", shared by the recipe list,
/// the menu, the detail view and sharing so the same recipe never reads FREE in
/// one place and UNKNOWN in another.
///
/// The trust model is deliberately asymmetric:
/// * A stale or low-coverage `FREE` is downgraded to `UNKNOWN`: a newer tagger
///   may know ingredients the old one missed, and unmatched ingredients cannot
///   prove absence.
/// * `CONTAINS` is never downgraded: it came from a positive ingredient match.
/// * A manual override is applied last and replaces the auto verdict entirely.
class AllergenVerdict {
  /// What every consumer should act on.
  final TriState effective;

  /// The tagger's own status, before staleness and override. UNKNOWN when the
  /// recipe has no tag data.
  final TriState auto;

  /// The tagger's status after the staleness downgrade but before any
  /// override: what [effective] would be if the user had not corrected it.
  final TriState trusted;

  /// True when a manual override decided [effective].
  final bool overridden;

  const AllergenVerdict({
    required this.effective,
    required this.auto,
    required this.trusted,
    required this.overridden,
  });

  /// The user marked an allergen as ok that the tagger found. Anything that
  /// repeats the verdict to someone else has to say so.
  bool get overrideHidesContains =>
      overridden && auto == TriState.contains && effective != TriState.contains;

  static AllergenVerdict forAllergen(Recipe recipe, String allergenKey) =>
      _resolve(
        recipe,
        autoStatus: recipe.tagResult?.getAllergenStatus(allergenKey),
        override: recipe.tagOverrides?.allergenOverrides[allergenKey],
      );

  static AllergenVerdict forDietary(Recipe recipe, String dietaryKey) =>
      _resolve(
        recipe,
        autoStatus: recipe.tagResult?.getDietaryStatus(dietaryKey),
        override: recipe.tagOverrides?.dietaryOverrides[dietaryKey],
      );

  static AllergenVerdict _resolve(
    Recipe recipe, {
    required TriState? autoStatus,
    required TriState? override,
  }) {
    final tagResult = recipe.tagResult;
    final auto = autoStatus ?? TriState.unknown;
    var trusted = auto;
    if (trusted == TriState.free &&
        tagResult != null &&
        (tagResult.needsRetagging || tagResult.coverage < 1.0)) {
      trusted = TriState.unknown;
    }
    return AllergenVerdict(
      effective: override ?? trusted,
      auto: auto,
      trusted: trusted,
      overridden: override != null,
    );
  }
}
