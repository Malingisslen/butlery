// lib/views/recipe_detail/recipe_detail_content.dart
//
// Ingredients and instructions render inline (no tabs) for immediate visibility.

import 'package:flutter/material.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart' as img;
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/widgets/recipe/ingredient_substitution_sheet.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe detail content: tags, images, ingredients, and instructions rendered inline.
class RecipeDetailContent extends StatefulWidget {
  final RecipeDetailViewModel viewModel;
  final List<String> scaledIngredients;
  final int currentPortions;
  final Function(int, List<String>) onPortionChanged;
  final Function(List<String>, int) onImageTap;

  /// User allergen preferences for filtering displayed allergens
  final Set<String>? userAllergenPrefs;

  /// User dietary preferences for filtering displayed dietary info
  final Set<String>? userDietaryPrefs;

  /// Whether to show ingredient coverage indicator
  final bool showCoverage;

  /// Resolved personal tag names (tag ID → display name)
  final Map<String, String>? personalTagNames;

  const RecipeDetailContent({
    super.key,
    required this.viewModel,
    required this.scaledIngredients,
    required this.currentPortions,
    required this.onPortionChanged,
    required this.onImageTap,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.personalTagNames,
  });

  @override
  State<RecipeDetailContent> createState() => _RecipeDetailContentState();
}

class _RecipeDetailContentState extends State<RecipeDetailContent> {
  /// Tracks which instruction steps are completed (local state, not persisted).
  final Set<int> _completedSteps = {};

  RecipeDetailViewModel get viewModel => widget.viewModel;
  List<String> get scaledIngredients => widget.scaledIngredients;
  int get currentPortions => widget.currentPortions;
  Function(int, List<String>) get onPortionChanged => widget.onPortionChanged;
  Function(List<String>, int) get onImageTap => widget.onImageTap;
  Set<String>? get userAllergenPrefs => widget.userAllergenPrefs;
  Set<String>? get userDietaryPrefs => widget.userDietaryPrefs;
  bool get showCoverage => widget.showCoverage;
  Map<String, String>? get personalTagNames => widget.personalTagNames;

  @override
  Widget build(BuildContext context) {
    final recipe = viewModel.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasEffectiveTags) ...[
          _buildTags(context),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        if (_hasPersonalTags) ...[
          _PersonalTagsSection(
            tagIds: viewModel.recipe.personalTagIds!,
            tagNames: personalTagNames!,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          const SizedBox(height: AppDimensions.spacingMd),
        ],
        _buildIngredientsSection(context),
        const SizedBox(height: AppDimensions.spacingMd),
        _buildInstructionsSection(context),
      ],
    );
  }

  /// Ingredients section with section header, portion scaler and structured table.
  Widget _buildIngredientsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Text(
            context.l10n.recipeIngredients,
            style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
          ),
        ),
        _buildIngredientsContent(context),
      ],
    );
  }

  /// Instructions section with section header and checkable steps.
  Widget _buildInstructionsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.surfaceContainerHigh),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Text(
            context.l10n.recipeInstructions,
            style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
          ),
        ),
        _buildInstructionsContent(context),
      ],
    );
  }

  /// Ingredients content with portion scaler and structured table.
  Widget _buildIngredientsContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portion scaler controls with background band
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingM,
              horizontal: AppDimensions.paddingL,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant,
                ),
              ),
            ),
            child: _buildPortionScaler(context),
          ),

          // Ingredient rows with dividers
          ...scaledIngredients.asMap().entries.map((entry) {
            final index = entry.key;
            final ingredient = entry.value;
            final parsed = IngredientParser.parseIngredient(ingredient);
            final isAllergen = _isAllergenIngredient(parsed.name);

            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.surfaceContainerHigh,
                  ),
                InkWell(
                  onTap: () => _showSubstitutionSheet(context, parsed.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingModerate),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quantity + unit column
                        SizedBox(
                          width: 70,
                          child: Text(
                            parsed.unit.isNotEmpty
                                ? '${_formatQuantity(parsed.quantity)} ${parsed.unit}'
                                : parsed.quantity > 0
                                    ? _formatQuantity(parsed.quantity)
                                    : '',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingXl),
                        // Ingredient name (tap for substitutions)
                        Expanded(
                          child: Row(
                            children: [
                              if (isAllergen)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppDimensions.spacingXs,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber,
                                    size: AppDimensions.iconSizeS,
                                    color: cs.error,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  parsed.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isAllergen ? cs.error : cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Instructions tab with checkable steps.
  Widget _buildInstructionsContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final instructions = viewModel.recipe.instructions;
    if (instructions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Text(
          context.l10n.recipeNoInstructions,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction = entry.value;
          final isCompleted = _completedSteps.contains(index);

          return Padding(
            padding: EdgeInsets.only(
              bottom:
                  index < instructions.length - 1 ? AppDimensions.spacingMd : 0,
            ),
            child: InkWell(
              onTap: () => _toggleStepCompletion(index),
              borderRadius: BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingXs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkable step indicator
                    _buildStepCheckbox(context, index + 1, isCompleted),
                    const SizedBox(width: AppDimensions.spacingMd),

                    // Instruction text
                    Expanded(
                      child: Text(
                        instruction,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color:
                              isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepCheckbox(
      BuildContext context, int stepNumber, bool isCompleted) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: AppDimensions.animationDurationFast,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted ? cs.primary : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.primary,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? Icon(
                Icons.check,
                size: 16,
                color: cs.onPrimary,
              )
            : Text(
                '$stepNumber',
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  /// Checks if an ingredient name matches a known allergen with 'contains' status.
  bool _isAllergenIngredient(String ingredientName) {
    if (userAllergenPrefs == null || userAllergenPrefs!.isEmpty) return false;
    final allergenStatus = viewModel.recipe.tagResult?.allergenStatus;
    if (allergenStatus == null) return false;

    // Normalize both sides to ASCII for case-insensitive Swedish matching
    final nameNormalized = SwedishCharacterNormalizer.normalize(ingredientName);
    for (final entry in allergenStatus.entries) {
      if (entry.value != TriState.contains) continue;
      if (!userAllergenPrefs!.contains(entry.key)) continue;
      final keyNormalized = SwedishCharacterNormalizer.normalize(entry.key);
      if (nameNormalized.contains(keyNormalized)) return true;
    }
    return false;
  }

  /// Formats a quantity for display, removing trailing .0 for whole numbers.
  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(1);
  }

  void _showSubstitutionSheet(BuildContext context, String ingredientName) {
    if (ingredientName.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (_) => IngredientSubstitutionSheet(
        ingredientName: ingredientName,
      ),
    );
  }

  void _toggleStepCompletion(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  /// Whether there are effective tags to display.
  bool get _hasEffectiveTags {
    final recipe = viewModel.recipe;
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return effectiveTags.isNotEmpty;
  }

  /// Whether there are personal tags to display.
  bool get _hasPersonalTags {
    final tagIds = viewModel.recipe.personalTagIds;
    if (tagIds == null || tagIds.isEmpty) return false;
    if (personalTagNames == null || personalTagNames!.isEmpty) return false;
    return tagIds.any((id) => personalTagNames!.containsKey(id));
  }

  /// Gets the top 5 effective tags with smart priority.
  List<String> get _topEffectiveTags {
    final recipe = viewModel.recipe;
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return TagDisplayUtils.getTopTags(effectiveTags, userAddedTags, limit: 5);
  }

  Widget _buildTags(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recipe = viewModel.recipe;
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: cs.primary,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                context.l10n.recipeTags,
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: _topEffectiveTags.map((tag) {
              final isUserAdded = userAddedTags.contains(tag);
              final displayName = TagDisplayUtils.getDisplayName(tag);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: isUserAdded
                      ? cs.primary
                          .withValues(alpha: AppDimensions.opacityLightSubtle)
                      : cs.primary
                          .withValues(alpha: AppDimensions.opacityVeryLight),
                  border: Border.all(
                    color: isUserAdded
                        ? cs.primary
                            .withValues(alpha: AppDimensions.opacityHalf)
                        : cs.primary.withValues(
                            alpha: AppDimensions.opacityMediumLight),
                  ),
                ),
                child: Text(
                  displayName,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: cs.primary,
                    fontWeight: isUserAdded ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: cs.primary,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.recipeImagesTitle,
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                Text(
                  context.l10n
                      .recipeImageCount(viewModel.recipe.imageUrls.length),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          // Image carousel
          Semantics(
            label: context.l10n.a11yShowImage,
            button: true,
            child: GestureDetector(
              onTap: () => onImageTap(viewModel.recipe.imageUrls, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: img.UniversalImageManager.recipeDetail(
                  imageUrls: viewModel.recipe.imageUrls,
                  size: ImageSize.large,
                  showNavigationDots: true,
                  showImageCounter: true,
                  onImageTap: (index) =>
                      onImageTap(viewModel.recipe.imageUrls, index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionScaler(BuildContext context) {
    return InputComponents.portionScaler(
      originalPortions: viewModel.recipe.portions ?? 1,
      originalIngredients: viewModel.recipe.ingredients,
      onPortionChanged: onPortionChanged,
      minPortions: 1,
      maxPortions: 20,
    );
  }
}

/// Collapsible section for personal tags display.
class _PersonalTagsSection extends StatefulWidget {
  final List<String> tagIds;
  final Map<String, String> tagNames;

  const _PersonalTagsSection({
    required this.tagIds,
    required this.tagNames,
  });

  @override
  State<_PersonalTagsSection> createState() => _PersonalTagsSectionState();
}

class _PersonalTagsSectionState extends State<_PersonalTagsSection> {
  bool _isExpanded = false;
  static const int _collapsedLimit = 3;

  List<String> get _resolvedNames {
    return widget.tagIds
        .where((id) => widget.tagNames.containsKey(id))
        .map((id) => widget.tagNames[id]!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = _resolvedNames;
    if (names.isEmpty) return const SizedBox.shrink();

    final hasOverflow = names.length > _collapsedLimit;
    final displayNames =
        _isExpanded ? names : names.take(_collapsedLimit).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          Row(
            children: [
              Icon(
                Icons.label_outline,
                color: cs.primary,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Text(
                  context.l10n.recipePersonalTags,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (hasOverflow)
                TextButton.icon(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: AppDimensions.iconSizeM,
                  ),
                  label: Text(_isExpanded
                      ? context.l10n.commonHide
                      : context.l10n.commonShowAllCount(names.length)),
                  style: TextButton.styleFrom(
                    padding: AppDimensions.paddingHorizontal8,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          // Tags
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: [
              ...displayNames.map((name) => _buildPersonalTag(context, name)),
              if (!_isExpanded && hasOverflow)
                _buildOverflowIndicator(
                    context, names.length - _collapsedLimit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTag(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityLightSubtle),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        name,
        style: AppTextStyles.metadataEmphasized.copyWith(
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildOverflowIndicator(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: context.l10n.a11yShowMore(count),
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = true),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
            border: Border.all(
              color: cs.primary.withValues(alpha: AppDimensions.opacityLight),
            ),
          ),
          child: Text(
            context.l10n.commonMoreCount(count),
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: cs.primary.withValues(alpha: AppDimensions.opacityDark),
            ),
          ),
        ),
      ),
    );
  }
}
