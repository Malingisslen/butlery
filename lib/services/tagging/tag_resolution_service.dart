import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';

/// Single source of truth for "what tags does this recipe have?"
///
/// Merges auto-generated tags (with user overrides) and personal tags
/// into a unified [ResolvedTagData]. Use this instead of manually
/// computing effective tags in widgets or viewmodels.
class TagResolutionService {
  final TagEditingService _tagEditingService;

  TagResolutionService({required TagEditingService tagEditingService})
      : _tagEditingService = tagEditingService;

  /// Resolves all tag data for a recipe into a single unified result.
  ///
  /// Combines:
  /// - Auto-generated tags (from TagResult)
  /// - User overrides (from TagOverrides: added/removed tags, status corrections)
  /// - Personal tags (from personalTagIds)
  ResolvedTagData resolve(Recipe recipe) {
    final effective = _tagEditingService.getEffectiveTagData(recipe);
    final personalTags = recipe.core.personalTagIds?.toSet() ?? <String>{};

    return ResolvedTagData(
      autoTags: recipe.tagResult?.tags.toSet() ?? <String>{},
      personalTags: personalTags,
      effectiveAutoTags: effective.tags,
      effectiveAllergenStatus: effective.allergenStatus,
      effectiveDietaryStatus: effective.dietaryStatus,
      hasManualEdits: effective.hasManualEdits,
      coverage: effective.coverage,
      unknownIngredients: effective.unknownIngredients,
    );
  }

  /// Quick check: does this recipe have any tags at all?
  bool hasTags(Recipe recipe) {
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final addedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveAuto = autoTags.union(addedTags).difference(removedTags);
    final personalTags = recipe.core.personalTagIds ?? [];
    return effectiveAuto.isNotEmpty || personalTags.isNotEmpty;
  }
}

/// Unified tag data for a recipe, combining all tag subsystems.
class ResolvedTagData {
  /// Raw auto-generated tags before overrides.
  final Set<String> autoTags;

  /// User-defined personal tags (stored as UUIDs via personalTagIds).
  final Set<String> personalTags;

  /// Auto-tags after applying user overrides (added/removed).
  final Set<String> effectiveAutoTags;

  /// Allergen status after applying overrides.
  final Map<String, TriState> effectiveAllergenStatus;

  /// Dietary status after applying overrides.
  final Map<String, TriState> effectiveDietaryStatus;

  /// Whether user has manually edited any tag/status.
  final bool hasManualEdits;

  /// Ingredient coverage ratio (0.0-1.0).
  final double coverage;

  /// Ingredients not found in the database.
  final List<String> unknownIngredients;

  const ResolvedTagData({
    required this.autoTags,
    required this.personalTags,
    required this.effectiveAutoTags,
    required this.effectiveAllergenStatus,
    required this.effectiveDietaryStatus,
    required this.hasManualEdits,
    required this.coverage,
    required this.unknownIngredients,
  });

  factory ResolvedTagData.empty() {
    return const ResolvedTagData(
      autoTags: {},
      personalTags: {},
      effectiveAutoTags: {},
      effectiveAllergenStatus: {},
      effectiveDietaryStatus: {},
      hasManualEdits: false,
      coverage: 0.0,
      unknownIngredients: [],
    );
  }

  /// All tags combined (auto + personal) for display.
  Set<String> get allTags => effectiveAutoTags.union(personalTags);

  /// Whether this recipe has any auto-tags.
  bool get hasAutoTags => effectiveAutoTags.isNotEmpty;

  /// Whether this recipe has any personal tags.
  bool get hasPersonalTags => personalTags.isNotEmpty;
}
