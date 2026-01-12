// lib/views/recipe_detail/recipe_detail_content.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/unknown_ingredient_dialog.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart' as img;
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Recipe detail content widget
/// This widget displays the main recipe content including:
/// - Recipe description
/// - Tags display
/// - Image carousel
/// - Instructions list
/// - Portion scaler integration
class RecipeDetailContent extends StatelessWidget {
  final RecipeDetailViewModel viewModel;
  final List<String> scaledIngredients;
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
    required this.onPortionChanged,
    required this.onImageTap,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.personalTagNames,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = viewModel.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        if (recipe.description.isNotEmpty) ...[
          _buildDescription(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],

        // Tags (effective tags: auto-generated + user overrides)
        if (_hasEffectiveTags) ...[
          _buildTags(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],

        // Personal tags (user-defined categories)
        if (_hasPersonalTags) ...[
          _PersonalTagsSection(
            tagIds: viewModel.recipe.personalTagIds!,
            tagNames: personalTagNames!,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
        ],

        // Allergen and dietary information from tagging system
        if (recipe.tagResult != null) ...[
          _buildTaggingInfo(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],

        // Images
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],

        // Portion scaler
        _buildPortionScaler(context),
        const SizedBox(height: AppDimensions.spacingXl),

        // Instructions
        if (recipe.instructions.isNotEmpty) ...[
          _buildInstructions(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                'Beskrivning',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            viewModel.recipe.description,
            style: AppTextStyles.bodyLarge,
          ),
        ],
      ),
    );
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
    final recipe = viewModel.recipe;
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                'Taggar',
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
                      ? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLightSubtle)
                      : AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusRound),
                  border: Border.all(
                    color: isUserAdded
                        ? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityHalf)
                        : AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityMediumLight),
                  ),
                ),
                child: Text(
                  displayName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryBlue,
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

  Widget _buildTaggingInfo(BuildContext context) {
    final tagResult = viewModel.recipe.tagResult;
    if (tagResult == null) return const SizedBox.shrink();

    return TagResultDisplay(
      tagResult: tagResult,
      userAllergenPrefs: userAllergenPrefs,
      userDietaryPrefs: userDietaryPrefs,
      showCoverage: showCoverage,
      onUnknownIngredientsTap: tagResult.hasUnknowns
          ? () => _showUnknownIngredientsDialog(context, tagResult)
          : null,
    );
  }

  void _showUnknownIngredientsDialog(BuildContext context, dynamic tagResult) {
    showDialog(
      context: context,
      builder: (context) => UnknownIngredientDialog(
        unknownIngredients: tagResult.unknownIngredients,
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Bilder',
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${viewModel.recipe.imageUrls.length} ${viewModel.recipe.imageUrls.length == 1 ? 'bild' : 'bilder'}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          // Image carousel
          GestureDetector(
            onTap: () => onImageTap(viewModel.recipe.imageUrls, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.borderRadiusM),
                bottomRight: Radius.circular(AppDimensions.borderRadiusM),
              ),
              child: img.UniversalImageManager.recipeDetail(
                imageUrls: viewModel.recipe.imageUrls,
                size: ImageSize.large, // Now properly sized for recipe detail
                showNavigationDots: true,
                showImageCounter: true,
                onImageTap: (index) =>
                    onImageTap(viewModel.recipe.imageUrls, index),
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

  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                'Instruktioner',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                viewModel.recipe.instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < viewModel.recipe.instructions.length - 1
                      ? AppDimensions.spacingS
                      : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsetsDirectional.only(
                          end: AppDimensions.spacingS),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.neutralLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Instruction text
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          instruction,
                          style: AppTextStyles.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
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
    final names = _resolvedNames;
    if (names.isEmpty) return const SizedBox.shrink();

    final hasOverflow = names.length > _collapsedLimit;
    final displayNames =
        _isExpanded ? names : names.take(_collapsedLimit).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          Row(
            children: [
              const Icon(
                Icons.label_outline,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Text(
                  'Personliga taggar',
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
                  label: Text(
                      _isExpanded ? 'Dölj' : 'Visa alla (${names.length})'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
              ...displayNames.map(_buildPersonalTag),
              if (!_isExpanded && hasOverflow)
                _buildOverflowIndicator(names.length - _collapsedLimit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTag(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLightSubtle),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        name,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOverflowIndicator(int count) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLight),
          ),
        ),
        child: Text(
          '+$count till',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
