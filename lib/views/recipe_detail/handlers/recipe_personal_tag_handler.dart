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
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';

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

    final result = await showButlerySheet<List<String>>(
      context: context,
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
        rev: recipe.rev,
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
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.taggingCouldNotSaveTags,
        );
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
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
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
    // After pop() the sheet's context is unmounted, so the navigator is
    // captured first.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed(Routes.settingsPersonalTags);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppDimensions.space16),
            ButlerySheetHeader(
              title: context.l10n.taggingPersonalTags,
              leading: const ButleryIcon(ButleryIcons.tag),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ButleryTextButton(
                    onPressed: _cancel,
                    label: context.l10n.commonCancel,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  ActionButtons.primaryButton(
                    context,
                    onPressed: _save,
                    label: context.l10n.commonSave,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            const ButleryDivider(spacing: 1),
            // Content
            Expanded(
              child: _buildContent(context, scrollController),
            ),
          ],
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
      return StateWidget.loading(message: context.l10n.loadingPersonalTags);
    }

    if (!_viewModel.hasTags) {
      return _buildEmptyState(context);
    }

    final tags = _viewModel.tags;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.space24),
      children: [
        // Selected count
        if (_selectedTagIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            ),
            child: Row(
              children: [
                const ButleryIcon(
                  ButleryIcons.circleCheck,
                  size: AppDimensions.iconSize18,
                ),
                const SizedBox(width: AppDimensions.space8),
                Text(
                  context.l10n.taggingTagsSelected(_selectedTagIds.length),
                  style: AppTextStyles.contentLabel.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                ButleryTextButton(
                  onPressed: () => setState(() => _selectedTagIds.clear()),
                  tone: ButleryTextButtonTone.onSelectionBanner,
                  label: context.l10n.commonClear,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
        ],

        // Suggested tags section
        if (_suggestedTagIds.isNotEmpty) ...[
          Text(
            context.l10n.tagSuggested,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppDimensions.space8),
          _buildTagWrap(tags.where((tag) => _suggestedTagIds.contains(tag.id))),
          const SizedBox(height: AppDimensions.space16),
          Text(
            context.l10n.tagAll,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppDimensions.space8),
        ],

        // All tags (excluding suggested if suggestions shown)
        _buildTagWrap(
          tags.where(
            (tag) =>
                _suggestedTagIds.isEmpty || !_suggestedTagIds.contains(tag.id),
          ),
        ),
        const SizedBox(height: AppDimensions.space32),

        // Manage tags link
        Center(
          child: ButleryTextButton(
            onPressed: _navigateToManageTags,
            icon: ButleryIcons.settings,
            label: context.l10n.taggingManageTags,
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ButleryIcon(
              ButleryIcons.tag,
              size: AppDimensions.iconSizeXXXl,
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(
              context.l10n.taggingNoPersonalTags,
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Text(
              context.l10n.taggingCreateTagsToOrganize,
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            ActionButtons.primaryButton(
              context,
              onPressed: _navigateToManageTags,
              icon: ButleryIcons.plus,
              label: context.l10n.taggingCreateTag,
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

    return ButleryFilterChip(
      label: tag.name,
      selected: isSelected,
      onSelected: (_) => onTap(),
      unselectedAvatar: SizedBox.square(
        dimension: AppDimensions.space12,
        child: ButleryDisc(paintOnly: true, color: cs.onSurface),
      ),
    );
  }
}
