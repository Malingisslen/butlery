/// Handler for personal tag operations on recipe detail view.
///
/// Provides quick-add/remove personal tags functionality directly from
/// the recipe detail view without navigating to full edit mode.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';

/// Handler for personal tag operations from recipe detail view.
class RecipePersonalTagHandler {
  /// Shows quick personal tag selector for a recipe.
  ///
  /// Opens a bottom sheet with available tags for quick selection/deselection.
  /// Works with tag IDs internally, produces both personalTagIds and personalTags.
  static Future<void> showQuickTagSelector(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;
    final currentTagIds = recipe.core.personalTagIds ?? [];

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PersonalTagQuickSelector(
        selectedTagIds: currentTagIds,
      ),
    );

    if (result != null && context.mounted) {
      await _savePersonalTags(context, viewModel, recipe, result);
    }
  }

  /// Saves the updated personal tags to the recipe.
  ///
  /// [newTagIds] contains tag UUIDs from the quick selector.
  /// Builds both personalTagIds (flat ID array) and personalTags (rich objects).
  static Future<void> _savePersonalTags(
    BuildContext context,
    RecipeDetailViewModel viewModel,
    Recipe recipe,
    List<String> newTagIds,
  ) async {
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final tagVm = ServiceLocator.get<PersonalTagViewModel>();

      // Build rich personalTags from selected IDs
      List<RecipePersonalTag>? newPersonalTags;
      if (newTagIds.isNotEmpty) {
        newPersonalTags = newTagIds.map((id) {
          final tag = tagVm.getTagById(id);
          return RecipePersonalTag.manual(
            tagId: id,
            name: tag?.name ?? id,
          );
        }).toList();
      }

      // Update recipe with both fields
      final updatedCore = recipe.core.copyWith(
        personalTagIds: newTagIds.isEmpty ? null : newTagIds,
        personalTags: newPersonalTags,
      );

      final updatedRecipe = Recipe(
        core: updatedCore,
        type: recipe.type,
        socialData: recipe.socialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      // Save to database
      await recipeService.updateRecipe(updatedRecipe);

      // Update view model
      viewModel.updateRecipe(updatedRecipe);

      if (context.mounted) {
        final tagCount = newTagIds.length;
        SnackBarUtils.showSuccess(
          context,
          tagCount == 0
              ? 'Personliga taggar borttagna'
              : '$tagCount personliga taggar sparade',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Kunde inte spara taggar');
      }
    }
  }
}

/// Bottom sheet for quick personal tag selection.
class _PersonalTagQuickSelector extends StatefulWidget {
  final List<String> selectedTagIds;

  const _PersonalTagQuickSelector({
    required this.selectedTagIds,
  });

  @override
  State<_PersonalTagQuickSelector> createState() =>
      _PersonalTagQuickSelectorState();
}

class _PersonalTagQuickSelectorState extends State<_PersonalTagQuickSelector> {
  late PersonalTagViewModel _viewModel;
  late List<String> _selectedTagIds;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List.from(widget.selectedTagIds);
    _viewModel = ServiceLocator.get<PersonalTagViewModel>();
    _initialized = true;
  }

  void _toggleTag(PersonalTag tag) {
    setState(() {
      if (_selectedTagIds.contains(tag.id)) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
  }

  bool _isTagSelected(PersonalTag tag) {
    return _selectedTagIds.contains(tag.id);
  }

  void _save() {
    Navigator.of(context).pop(_selectedTagIds);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _navigateToManageTags() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PersonalTagsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadius2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    const Icon(Icons.label),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        'Personliga taggar',
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _cancel,
                      child: const Text('Avbryt'),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Spara'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _buildContent(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_viewModel.hasTags) {
      return _buildEmptyState(context);
    }

    final tags = _viewModel.tags;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      children: [
        // Selected count
        if (_selectedTagIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: AppDimensions.iconSize18,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  '${_selectedTagIds.length} tagg${_selectedTagIds.length == 1 ? '' : 'ar'} vald${_selectedTagIds.length == 1 ? '' : 'a'}',
                  style: AppTextStyles.text14Medium.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedTagIds.clear()),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                  child: const Text('Rensa'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
        ],

        // Tag grid
        Wrap(
          spacing: AppDimensions.spacingSm,
          runSpacing: AppDimensions.spacingSm,
          children: tags.map((tag) {
            return _QuickTagChip(
              tag: tag,
              isSelected: _isTagSelected(tag),
              onTap: () => _toggleTag(tag),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Manage tags link
        Center(
          child: TextButton.icon(
            onPressed: _navigateToManageTags,
            icon: const Icon(Icons.settings, size: AppDimensions.iconSize18),
            label: const Text('Hantera taggar'),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.label_outline,
              size: 64,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Inga personliga taggar',
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              'Skapa taggar för att organisera dina recept',
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            FilledButton.icon(
              onPressed: _navigateToManageTags,
              icon: const Icon(Icons.add),
              label: const Text('Skapa tagg'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chip for quick tag selection with visual feedback.
class _QuickTagChip extends StatelessWidget {
  final PersonalTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickTagChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isSelected
          ? '${tag.name}, vald. Dubbeltryck för att ta bort.'
          : '${tag.name}. Dubbeltryck för att välja.',
      selected: isSelected,
      button: true,
      child: FilterChip(
        label: Text(tag.name),
        avatar: isSelected
            ? null
            : const CircleAvatar(
                radius: 6,
                backgroundColor: AppColors.forestGreen,
              ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.cream,
        selectedColor: AppColors.forestGreen
            .withValues(alpha: AppDimensions.opacityLightMedium),
        checkmarkColor: AppColors.forestGreen,
        side: BorderSide(
          color: isSelected ? AppColors.forestGreen : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
        labelStyle:
            (isSelected ? AppTextStyles.bodyBold : AppTextStyles.bodyMedium)
                .copyWith(
          color: isSelected ? AppColors.forestGreen : AppColors.textDark,
        ),
        showCheckmark: isSelected,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
      ),
    );
  }
}
