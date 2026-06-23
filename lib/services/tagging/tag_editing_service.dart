import 'package:clock/clock.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// Service for user-driven tag editing with safety controls.
///
/// Manages user overrides to auto-generated tag results while
/// ensuring allergen safety through confirmation requirements.
///
/// Key safety features:
/// - Removing allergen CONTAINS status requires confirmation
/// - Overrides persist across automatic retagging
/// - "Manually edited" status is tracked and displayed
class TagEditingService extends BaseService {
  @override
  String get serviceName => 'TagEditingService';

  /// Applies an allergen override to a recipe.
  ///
  /// If [newStatus] is not CONTAINS and the current auto-generated
  /// status is CONTAINS, [requiresConfirmation] will be true in the result.
  TagEditResult applyAllergenOverride({
    required Recipe recipe,
    required String allergenKey,
    required TriState newStatus,
    required String editedBy,
    bool userConfirmed = false,
  }) {
    if (recipe.tagResult == null) {
      return TagEditResult.error(
        'Recipe has no tag analysis — run auto-tagging first',
      );
    }

    final autoStatus = recipe.tagResult?.allergenStatus[allergenKey];

    // Safety check: removing CONTAINS status requires confirmation
    if (autoStatus == TriState.contains &&
        newStatus != TriState.contains &&
        !userConfirmed) {
      AppLogger.warning(
        '⚠️ Allergen override requires confirmation: '
        '$allergenKey from CONTAINS to ${newStatus.name}',
      );
      return TagEditResult.requiresConfirmation(
        allergenKey: allergenKey,
        currentStatus: autoStatus!,
        requestedStatus: newStatus,
      );
    }

    final currentOverrides = recipe.tagOverrides ?? const TagOverrides();
    final updatedOverrides = currentOverrides.withAllergenOverride(
      allergenKey,
      newStatus,
      editedBy: editedBy,
    );

    final updatedRecipe = recipe.copyWith(tagOverrides: updatedOverrides);

    AppLogger.info(
      '✏️ Applied allergen override: $allergenKey → ${newStatus.name}',
    );

    return TagEditResult.success(updatedRecipe);
  }

  /// Applies a dietary status override to a recipe.
  TagEditResult applyDietaryOverride({
    required Recipe recipe,
    required String dietaryKey,
    required TriState newStatus,
    required String editedBy,
  }) {
    if (recipe.tagResult == null) {
      return TagEditResult.error(
        'Recipe has no tag analysis — run auto-tagging first',
      );
    }

    final currentOverrides = recipe.tagOverrides ?? const TagOverrides();
    final updatedOverrides = currentOverrides.withDietaryOverride(
      dietaryKey,
      newStatus,
      editedBy: editedBy,
    );

    final updatedRecipe = recipe.copyWith(tagOverrides: updatedOverrides);

    AppLogger.info(
      '✏️ Applied dietary override: $dietaryKey → ${newStatus.name}',
    );

    return TagEditResult.success(updatedRecipe);
  }

  /// Adds a user-defined tag to the recipe.
  TagEditResult addTag({
    required Recipe recipe,
    required String tag,
    required String editedBy,
  }) {
    final currentOverrides = recipe.tagOverrides ?? const TagOverrides();
    final updatedOverrides = currentOverrides.withTagAdded(
      tag,
      editedBy: editedBy,
    );

    final updatedRecipe = recipe.copyWith(tagOverrides: updatedOverrides);

    AppLogger.info('✏️ Added user tag: $tag');

    return TagEditResult.success(updatedRecipe);
  }

  /// Removes a tag from the recipe (hides from display).
  TagEditResult removeTag({
    required Recipe recipe,
    required String tag,
    required String editedBy,
  }) {
    final currentOverrides = recipe.tagOverrides ?? const TagOverrides();
    final updatedOverrides = currentOverrides.withTagRemoved(
      tag,
      editedBy: editedBy,
    );

    final updatedRecipe = recipe.copyWith(tagOverrides: updatedOverrides);

    AppLogger.info('✏️ Removed user tag: $tag');

    return TagEditResult.success(updatedRecipe);
  }

  /// Clears all user overrides, reverting to auto-generated tags.
  TagEditResult clearAllOverrides({
    required Recipe recipe,
    required String editedBy,
  }) {
    final clearedOverrides = const TagOverrides().copyWith(
      lastEditedAt: clock.now(),
      lastEditedBy: editedBy,
    );

    final updatedRecipe = recipe.copyWith(tagOverrides: clearedOverrides);

    AppLogger.info('✏️ Cleared all tag overrides');

    return TagEditResult.success(updatedRecipe);
  }

  /// Gets the effective allergen status, applying overrides.
  TriState getEffectiveAllergenStatus(Recipe recipe, String allergenKey) {
    final autoStatus =
        recipe.tagResult?.allergenStatus[allergenKey] ?? TriState.unknown;
    final overrides = recipe.tagOverrides;

    if (overrides == null) return autoStatus;

    return overrides.getEffectiveAllergenStatus(allergenKey, autoStatus);
  }

  /// Gets the effective dietary status, applying overrides.
  TriState getEffectiveDietaryStatus(Recipe recipe, String dietaryKey) {
    final autoStatus =
        recipe.tagResult?.dietaryStatus[dietaryKey] ?? TriState.unknown;
    final overrides = recipe.tagOverrides;

    if (overrides == null) return autoStatus;

    return overrides.getEffectiveDietaryStatus(dietaryKey, autoStatus);
  }

  /// Gets effective tags, merging auto-generated with user additions/removals.
  Set<String> getEffectiveTags(Recipe recipe) {
    final autoTags = recipe.tagResult?.tags.toSet() ?? <String>{};
    final overrides = recipe.tagOverrides;

    if (overrides == null) return autoTags;

    return overrides.getEffectiveTags(autoTags);
  }

  /// Checks if the recipe has any manual tag edits.
  bool hasManualEdits(Recipe recipe) {
    return recipe.tagOverrides?.hasManualEdits ?? false;
  }

  /// Checks if a specific allergen has been overridden.
  bool hasAllergenOverride(Recipe recipe, String allergenKey) {
    return recipe.tagOverrides?.hasAllergenOverride(allergenKey) ?? false;
  }

  /// Checks if a specific dietary status has been overridden.
  bool hasDietaryOverride(Recipe recipe, String dietaryKey) {
    return recipe.tagOverrides?.hasDietaryOverride(dietaryKey) ?? false;
  }

  /// Merges TagResult with TagOverrides to produce final display data.
  EffectiveTagData getEffectiveTagData(Recipe recipe) {
    final tagResult = recipe.tagResult;
    final overrides = recipe.tagOverrides;

    if (tagResult == null) {
      return EffectiveTagData.empty();
    }

    // Merge allergen statuses
    final effectiveAllergens = <String, TriState>{};
    for (final entry in tagResult.allergenStatus.entries) {
      effectiveAllergens[entry.key] =
          overrides?.getEffectiveAllergenStatus(entry.key, entry.value) ??
          entry.value;
    }

    // Merge dietary statuses
    final effectiveDietary = <String, TriState>{};
    for (final entry in tagResult.dietaryStatus.entries) {
      effectiveDietary[entry.key] =
          overrides?.getEffectiveDietaryStatus(entry.key, entry.value) ??
          entry.value;
    }

    // Merge tags
    final effectiveTags =
        overrides?.getEffectiveTags(tagResult.tags.toSet()) ??
        tagResult.tags.toSet();

    return EffectiveTagData(
      tags: effectiveTags,
      allergenStatus: effectiveAllergens,
      dietaryStatus: effectiveDietary,
      hasManualEdits: overrides?.hasManualEdits ?? false,
      coverage: tagResult.coverage,
      unknownIngredients: tagResult.unknownIngredients,
    );
  }
}

/// Result of a tag editing operation.
class TagEditResult {
  final bool success;
  final Recipe? updatedRecipe;
  final bool requiresConfirmation;
  final String? allergenKey;
  final TriState? currentStatus;
  final TriState? requestedStatus;
  final String? errorMessage;

  const TagEditResult._({
    required this.success,
    this.updatedRecipe,
    this.requiresConfirmation = false,
    this.allergenKey,
    this.currentStatus,
    this.requestedStatus,
    this.errorMessage,
  });

  factory TagEditResult.success(Recipe recipe) {
    return TagEditResult._(
      success: true,
      updatedRecipe: recipe,
    );
  }

  factory TagEditResult.requiresConfirmation({
    required String allergenKey,
    required TriState currentStatus,
    required TriState requestedStatus,
  }) {
    return TagEditResult._(
      success: false,
      requiresConfirmation: true,
      allergenKey: allergenKey,
      currentStatus: currentStatus,
      requestedStatus: requestedStatus,
    );
  }

  factory TagEditResult.error(String message) {
    return TagEditResult._(
      success: false,
      errorMessage: message,
    );
  }
}

/// Merged tag data with overrides applied.
class EffectiveTagData {
  final Set<String> tags;
  final Map<String, TriState> allergenStatus;
  final Map<String, TriState> dietaryStatus;
  final bool hasManualEdits;
  final double coverage;
  final List<String> unknownIngredients;

  const EffectiveTagData({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.hasManualEdits,
    required this.coverage,
    required this.unknownIngredients,
  });

  factory EffectiveTagData.empty() {
    return const EffectiveTagData(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      hasManualEdits: false,
      coverage: 0.0,
      unknownIngredients: [],
    );
  }
}
