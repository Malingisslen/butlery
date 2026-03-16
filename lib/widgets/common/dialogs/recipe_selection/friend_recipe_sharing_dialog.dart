// lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Dialog for sharing recipes with friends
class FriendRecipeSharingDialog extends StatelessWidget {
  final UserProfile friend;

  const FriendRecipeSharingDialog({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeSelectionViewModel(
        recipeService: ServiceLocator.get<UnifiedRecipeService>(),
        targetFriend: friend,
      )..loadRecipes(),
      child: Consumer<RecipeSelectionViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text(
              context.l10n.dialogShareRecipesWith(friend.displayName),
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
      BuildContext context, RecipeSelectionViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: context.l10n.dialogLoadingRecipes);
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.loadRecipes,
      );
    }

    if (!viewModel.hasRecipes) {
      return StateWidget.noRecipes(
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/laggTill');
        },
      );
    }

    return Column(
      children: [
        // Search and filter
        SearchFilterWidget.searchOnly(
          searchQuery: viewModel.searchQuery,
          onSearchChanged: viewModel.updateSearch,
          searchHint: context.l10n.dialogSearchRecipes,
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          showStats: true,
          resultCount: viewModel.hasSearchResults
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info and actions
        if (viewModel.searchQuery.isNotEmpty || viewModel.hasSelectedRecipes)
          _buildInfo(context, viewModel),

        Divider(
            height: AppDimensions.borderWidthThin,
            color: Theme.of(context).colorScheme.outlineVariant),

        // Recipe list
        Expanded(
          child: viewModel.hasSearchResults
              ? ListView.builder(
                  itemCount: viewModel.filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final unifiedRecipe = viewModel.filteredRecipes[index];
                    return FriendRecipeListItem(
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

  Widget _buildInfo(BuildContext context, RecipeSelectionViewModel viewModel) {
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusRound),
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
      BuildContext context, RecipeSelectionViewModel viewModel) async {
    final shareMessage = viewModel.getShareMessage();
    final success = await viewModel.shareSelectedRecipes();

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shareMessage,
            style: AppTextStyles.bodyLargeLight,
          ),
          backgroundColor: context.butleryColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.error ?? context.l10n.chatCouldNotShareRecipe,
            style: AppTextStyles.bodyLargeLight,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Recipe list item for friend sharing
class FriendRecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final bool isAlreadyShared;
  final ValueChanged<bool> onSelectionChanged;

  const FriendRecipeListItem({
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
          horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: recipe.imageUrls.isNotEmpty
            ? Image.network(
                recipe.imageUrls.first,
                width: AppDimensions.iconSizeXl,
                height: AppDimensions.iconSizeXl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: AppDimensions.iconSizeXl,
                    height: AppDimensions.iconSizeXl,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusRound),
                border: Border.all(
                    color: successColor.withValues(
                        alpha: AppDimensions.opacityMediumLight)),
              ),
              child: Text(context.l10n.dialogAlreadyShared,
                  style: AppTextStyles.labelSmallSuccess),
            ),
        ],
      ),
      subtitle: _buildSubtitle(context),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: isAlreadyShared ? cs.onSurfaceVariant : cs.primary,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadiusRound)),
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
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${recipe.timeMinutes} min',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall
                        .copyWith(fontSize: AppTextStyles.labelSmall.fontSize),
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text('•', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              Icon(
                Icons.people,
                size: AppDimensions.iconSizeM,
                color: isAlreadyShared ? successColor : cs.onSurfaceVariant,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${recipe.portions} port',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall
                        .copyWith(fontSize: AppTextStyles.labelSmall.fontSize),
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

  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources    super.dispose();
  }
}
