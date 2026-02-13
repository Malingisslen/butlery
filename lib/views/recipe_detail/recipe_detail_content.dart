// lib/views/recipe_detail/recipe_detail_content.dart
//
// UI Redesign: Converted to tab layout with Description/Tags/Allergens ABOVE tabs,
// and Ingredienser + Instruktioner (with checkable steps) inside tabs.

import 'package:flutter/material.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart' as img;
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe detail content widget with tabbed layout.
///
/// **UI Redesign:** Converted to tab-based layout:
/// - ABOVE TABS: Description, Tags, Allergens, Image Carousel
/// - TABS: Ingredienser (with PortionScaler) + Instruktioner (with checkable steps)
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

class _RecipeDetailContentState extends State<RecipeDetailContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Tracks which instruction steps are completed (local state, not persisted).
  final Set<int> _completedSteps = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        // Description moved to title section (recipe_detail_view.dart)

        // Tags (effective tags: auto-generated + user overrides)
        if (_hasEffectiveTags) ...[
          _buildTags(context),
          const SizedBox(height: AppDimensions.spacingSm),
        ],

        // Personal tags (user-defined categories)
        if (_hasPersonalTags) ...[
          _PersonalTagsSection(
            tagIds: viewModel.recipe.personalTagIds!,
            tagNames: personalTagNames!,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],

        // Allergen badges now rendered in title section (recipe_detail_view.dart)

        // Images
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          const SizedBox(height: AppDimensions.spacingMd),
        ],

        // Tabs: Ingredienser + Instruktioner
        _buildTabbedContent(context),
      ],
    );
  }

  /// Builds the tabbed section with Ingredienser and Instruktioner tabs.
  Widget _buildTabbedContent(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.forestGreen,
          indicatorWeight: 3,
          labelColor: AppColors.forestGreenDark,
          unselectedLabelColor: AppColors.textMedium,
          labelStyle: AppTextStyles.bodySmall.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.forestGreenDark,
          ),
          unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textMedium,
          ),
          tabs: [
            Tab(text: context.l10n.recipeIngredients),
            Tab(text: context.l10n.recipeInstructions),
          ],
        ),
        const Divider(height: 1, color: AppColors.creamDarker),
        AnimatedSize(
          duration: AppDimensions.animationDurationMedium,
          child: _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    // Use AnimatedBuilder to rebuild when tab changes
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return IndexedStack(
          index: _tabController.index,
          children: [
            _buildIngredientsTab(context),
            _buildInstructionsTab(context),
          ],
        );
      },
    );
  }

  /// Ingredients tab with portion scaler and structured table.
  Widget _buildIngredientsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portion scaler controls with background band
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingSm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.creamDarker,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
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
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.creamDarker,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                            color: AppColors.forestGreenDark,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingXl),
                      // Ingredient name
                      Expanded(
                        child: Row(
                          children: [
                            if (isAllergen)
                              const Padding(
                                padding: EdgeInsets.only(
                                  right: AppDimensions.spacingXs,
                                ),
                                child: Icon(
                                  Icons.warning_amber,
                                  size: AppDimensions.iconSizeS,
                                  color: AppColors.error,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                parsed.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isAllergen
                                      ? AppColors.error
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
  Widget _buildInstructionsTab(BuildContext context) {
    final instructions = viewModel.recipe.instructions;
    if (instructions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Text(
          context.l10n.recipeNoInstructions,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
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
                    _buildStepCheckbox(index + 1, isCompleted),
                    const SizedBox(width: AppDimensions.spacingMd),

                    // Instruction text
                    Expanded(
                      child: Text(
                        instruction,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isCompleted
                              ? AppColors.textMedium
                              : AppColors.textDark,
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

  Widget _buildStepCheckbox(int stepNumber, bool isCompleted) {
    return AnimatedContainer(
      duration: AppDimensions.animationDurationFast,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.forestGreen : AppColors.cardWhite,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.forestGreen,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(
                Icons.check,
                size: 16,
                color: AppColors.cardWhite,
              )
            : Text(
                '$stepNumber',
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.forestGreen,
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

    final nameLower = ingredientName.toLowerCase();
    for (final entry in allergenStatus.entries) {
      if (entry.value != TriState.contains) continue;
      if (!userAllergenPrefs!.contains(entry.key)) continue;
      // Check if allergen key appears in the ingredient name
      if (nameLower.contains(entry.key.toLowerCase())) return true;
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
    final recipe = viewModel.recipe;
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: AppColors.forestGreen,
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
                      ? AppColors.forestGreen
                          .withValues(alpha: AppDimensions.opacityLightSubtle)
                      : AppColors.forestGreen
                          .withValues(alpha: AppDimensions.opacityVeryLight),
                  border: Border.all(
                    color: isUserAdded
                        ? AppColors.forestGreen
                            .withValues(alpha: AppDimensions.opacityHalf)
                        : AppColors.forestGreen.withValues(
                            alpha: AppDimensions.opacityMediumLight),
                  ),
                ),
                child: Text(
                  displayName,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: AppColors.forestGreen,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
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
                  color: AppColors.forestGreen,
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
            label: 'Visa bild',
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
                color: AppColors.forestGreen,
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
        color: AppColors.forestGreen
            .withValues(alpha: AppDimensions.opacityLightSubtle),
        border: Border.all(
          color: AppColors.forestGreen
              .withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        name,
        style: AppTextStyles.metadataEmphasized.copyWith(
          color: AppColors.forestGreen,
        ),
      ),
    );
  }

  Widget _buildOverflowIndicator(int count) {
    return Semantics(
      label: 'Visa $count till',
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = true),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.forestGreen
                .withValues(alpha: AppDimensions.opacityVeryLight),
            border: Border.all(
              color: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityLight),
            ),
          ),
          child: Text(
            context.l10n.commonMoreCount(count),
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityDark),
            ),
          ),
        ),
      ),
    );
  }
}
