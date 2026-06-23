/// Handler for personal tag operations on recipe detail view.
///
/// Provides quick-add/remove personal tags functionality directly from
/// the recipe detail view without navigating to full edit mode.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
        recipe: recipe,
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
              ? context.l10n.taggingPersonalTagsRemoved
              : context.l10n.taggingPersonalTagsSaved(tagCount),
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.taggingCouldNotSaveTags);
      }
    }
  }
}

/// Bottom sheet for quick personal tag selection.
class _PersonalTagQuickSelector extends StatefulWidget {
  final List<String> selectedTagIds;
  final Recipe recipe;

  const _PersonalTagQuickSelector({
    required this.selectedTagIds,
    required this.recipe,
  });

  @override
  State<_PersonalTagQuickSelector> createState() =>
      _PersonalTagQuickSelectorState();
}

class _PersonalTagQuickSelectorState extends State<_PersonalTagQuickSelector> {
  late PersonalTagViewModel _viewModel;
  late List<String> _selectedTagIds;
  bool _initialized = false;
  Set<String> _suggestedTagIds = {};

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List.from(widget.selectedTagIds);
    _viewModel = ServiceLocator.get<PersonalTagViewModel>();
    _initialized = true;
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final tagService = ServiceLocator.get<PersonalTagService>();
      final suggested = await tagService.suggestTagsForRecipe(widget.recipe);
      if (mounted) {
        setState(() {
          _suggestedTagIds = suggested.map((t) => t.id).toSet();
        });
      }
    } catch (e) {
      AppLogger.warning('Could not load tag suggestions: $e');
    }
  }

  Widget _buildTagWrap(Iterable<PersonalTag> tagsToShow) {
    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: tagsToShow
          .map(
            (tag) => _QuickTagChip(
              tag: tag,
              isSelected: _isTagSelected(tag),
              onTap: () => _toggleTag(tag),
            ),
          )
          .toList(),
    );
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
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadius2,
                  ),
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
                        context.l10n.taggingPersonalTags,
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _cancel,
                      child: Text(context.l10n.commonCancel),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    FilledButton(
                      onPressed: _save,
                      child: Text(context.l10n.commonSave),
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
      return StateWidget.loading();
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
                  context.l10n.taggingTagsSelected(_selectedTagIds.length),
                  style: AppTextStyles.contentLabel.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedTagIds.clear()),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                  child: Text(context.l10n.commonClear),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
        ],

        // Suggested tags section
        if (_suggestedTagIds.isNotEmpty) ...[
          Text(
            context.l10n.tagSuggested,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _buildTagWrap(tags.where((tag) => _suggestedTagIds.contains(tag.id))),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.tagAll,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],

        // All tags (excluding suggested if suggestions shown)
        _buildTagWrap(
          tags.where(
            (tag) =>
                _suggestedTagIds.isEmpty || !_suggestedTagIds.contains(tag.id),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Manage tags link
        Center(
          child: TextButton.icon(
            onPressed: _navigateToManageTags,
            icon: const Icon(Icons.settings, size: AppDimensions.iconSize18),
            label: Text(context.l10n.taggingManageTags),
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
              context.l10n.taggingNoPersonalTags,
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              context.l10n.taggingCreateTagsToOrganize,
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            FilledButton.icon(
              onPressed: _navigateToManageTags,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.taggingCreateTag),
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
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: isSelected
          ? context.l10n.a11yTagSelected(tag.name)
          : context.l10n.a11yTagUnselected(tag.name),
      selected: isSelected,
      button: true,
      child: FilterChip(
        label: Text(tag.name),
        avatar: isSelected
            ? null
            : CircleAvatar(
                radius: 6,
                backgroundColor: cs.primary,
              ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: cs.surface,
        selectedColor: cs.primary.withValues(
          alpha: AppDimensions.opacityLightMedium,
        ),
        checkmarkColor: cs.primary,
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        labelStyle:
            (isSelected ? AppTextStyles.bodyBold : AppTextStyles.bodyMedium)
                .copyWith(
                  color: isSelected ? cs.primary : cs.onSurface,
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
