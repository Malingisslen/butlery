// lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/group_recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Dialog for sharing recipes with group members
class GroupRecipeSharingDialog extends StatelessWidget {
  final FriendCategory group;
  final List<UserProfile> members;

  const GroupRecipeSharingDialog({
    super.key,
    required this.group,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupRecipeSelectionViewModel(
        recipeService: ServiceLocator.get<UnifiedRecipeService>(),
        targetGroup: group,
        groupMembers: members,
      )..loadRecipes(),
      child: Consumer<GroupRecipeSelectionViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text(
              context.l10n.dialogShareRecipesWith(group.name),
              style: AppTextStyles.headlineSmall,
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel,
                    style: AppTextStyles.labelLarge),
              ),
              if (viewModel.hasSelectedRecipes)
                FilledButton.icon(
                  onPressed: viewModel.isSharing
                      ? null
                      : () => _shareSelectedRecipes(context, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                      vertical: AppDimensions.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                  ),
                  icon: viewModel.isSharing
                      ? SizedBox(
                          width: AppDimensions.iconSizeAction,
                          height: AppDimensions.iconSizeAction,
                          child: SizedBox(
                            width: AppDimensions.iconSizeS,
                            height: AppDimensions.iconSizeS,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest),
                            ),
                          ),
                        )
                      : const Icon(Icons.share),
                  label: Text(
                    viewModel.isSharing
                        ? context.l10n.dialogSharing
                        : '${context.l10n.commonShare} (${viewModel.selectedCount})',
                    style: AppTextStyles.labelLarge,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, GroupRecipeSelectionViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: context.l10n.dialogLoadingRecipes);
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.loadRecipes,
      );
    }

    if (viewModel.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.dialogNoRecipes,
        subtitle: context.l10n.dialogNoRecipesToShare,
        icon: Icons.restaurant_menu,
      );
    }

    return Column(
      children: [
        // Search and filter
        SearchFilterWidget.searchOnly(
          searchQuery: viewModel.searchQuery,
          onSearchChanged: viewModel.setSearchQuery,
          searchHint: context.l10n.dialogSearchRecipes,
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          showStats: true,
          resultCount: viewModel.filteredRecipes.isNotEmpty
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info bar showing filtered count and selection
        _buildInfo(context, viewModel),

        const SizedBox(height: AppDimensions.spacingS),

        Divider(
            height: AppDimensions.borderWidthThin,
            color: Theme.of(context).colorScheme.outlineVariant),

        // Recipe list
        Expanded(
          child: viewModel.filteredRecipes.isNotEmpty
              ? ListView.builder(
                  itemCount: viewModel.filteredCount,
                  itemBuilder: (context, index) {
                    final unifiedRecipe = viewModel.filteredRecipes[index];
                    return GroupRecipeListItem(
                      recipe: unifiedRecipe,
                      isSelected: viewModel.isRecipeSelected(unifiedRecipe.id),
                      isAlreadyShared:
                          viewModel.isRecipeAlreadyShared(unifiedRecipe.id),
                      onSelectionChanged: (selected) {
                        viewModel.toggleRecipeSelection(unifiedRecipe.id);
                      },
                    );
                  },
                )
              : StateWidget.noSearchResults(onAction: viewModel.clearSearch),
        ),
      ],
    );
  }

  Widget _buildInfo(
      BuildContext context, GroupRecipeSelectionViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Row(
        children: [
          if (viewModel.searchQuery.isNotEmpty)
            Text(
              context.l10n.dialogFilteredRecipeCount(
                  viewModel.filteredCount, viewModel.totalCount),
              style: AppTextStyles.bodySmall,
            ),
          if (viewModel.hasSelectedRecipes) ...[
            if (viewModel.searchQuery.isNotEmpty) const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingXs,
                vertical: AppDimensions.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: AppDimensions.opacityVeryLight),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                context.l10n.dialogSelectedCount(viewModel.selectedCount),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (viewModel.hasSelectedRecipes)
            TextButton(
              onPressed: viewModel.clearSelections,
              child: Text(context.l10n.dialogClearSelection,
                  style: AppTextStyles.labelLarge),
            )
          else if (viewModel.searchQuery.isNotEmpty)
            TextButton(
              onPressed: viewModel.clearSearch,
              child: Text(context.l10n.commonClear,
                  style: AppTextStyles.labelLarge),
            ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedRecipes(
    BuildContext context,
    GroupRecipeSelectionViewModel viewModel,
  ) async {
    final success = await viewModel.shareSelectedRecipes();

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.successMessage),
          backgroundColor: context.butleryColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else if (viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Recipe list item for group sharing
class GroupRecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final bool isAlreadyShared;
  final ValueChanged<bool> onSelectionChanged;

  const GroupRecipeListItem({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.isAlreadyShared,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final successColor = context.butleryColors.success;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      leading: recipe.imageUrls.isNotEmpty
          ? NetworkImageWidget(
              imageUrl: recipe.imageUrls.first,
              width: AppDimensions.iconSizeXl,
              height: AppDimensions.iconSizeXl,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              errorWidget: _buildPlaceholder(context),
            )
          : _buildPlaceholder(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              recipe.title,
              style: isAlreadyShared
                  ? AppTextStyles.titleMediumMuted
                  : AppTextStyles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAlreadyShared)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingXs,
                vertical: AppDimensions.spacingXs,
              ),
              decoration: BoxDecoration(
                color: successColor.withValues(
                    alpha: AppDimensions.opacityVeryLight),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                    color: successColor.withValues(
                        alpha: AppDimensions.opacityMediumLight)),
              ),
              child: Text(
                context.l10n.dialogAlreadyShared,
                style: AppTextStyles.labelSmallSuccess,
              ),
            ),
        ],
      ),
      subtitle: _buildSubtitle(context),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: isAlreadyShared ? cs.onSurfaceVariant : cs.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final successColor = context.butleryColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: isAlreadyShared
              ? AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.onSurfaceVariant,
                )
              : AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.primary,
                ),
        ),
        if (recipe.description.isNotEmpty)
          Text(
            recipe.description,
            style: isAlreadyShared
                ? AppTextStyles.metadataEmphasized
                : AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            if (recipe.timeMinutes != null) ...[
              Icon(
                Icons.access_time,
                size: AppDimensions.iconSizeM,
                color: isAlreadyShared ? successColor : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                '${recipe.timeMinutes} min',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall.copyWith(
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      ),
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                const SizedBox(width: AppDimensions.spacingM),
                Text('•', style: AppTextStyles.bodySmall),
                const SizedBox(width: AppDimensions.spacingM),
              ],
              Icon(
                Icons.people,
                size: AppDimensions.iconSizeM,
                color: isAlreadyShared ? successColor : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                '${recipe.portions} port',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall.copyWith(
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final successColor = context.butleryColors.success;
    return Container(
      width: AppDimensions.iconSizeXl,
      height: AppDimensions.iconSizeXl,
      decoration: BoxDecoration(
        color: isAlreadyShared
            ? successColor.withValues(alpha: AppDimensions.opacityVeryLight)
            : cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: isAlreadyShared ? successColor : cs.primary,
        size: AppDimensions.iconSizeAction,
      ),
    );
  }
}
