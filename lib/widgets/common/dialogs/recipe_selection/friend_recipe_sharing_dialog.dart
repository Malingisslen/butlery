// lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
              'Dela recept med ${friend.displayName}',
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
                child: Text('Avbryt', style: AppTextStyles.labelLarge),
              ),
              if (viewModel.hasSelectedRecipes)
                FilledButton.icon(
                  onPressed: viewModel.isSharing
                      ? null
                      : () => _shareSelectedRecipes(context, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.cardWhite,
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
                      ? const SizedBox(
                          width: AppDimensions.iconSizeAction,
                          height: AppDimensions.iconSizeAction,
                          child: SizedBox(
                            width: AppDimensions.iconSizeS,
                            height: AppDimensions.iconSizeS,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.cardWhite),
                            ),
                          ),
                        )
                      : const Icon(Icons.share),
                  label: Text(
                    viewModel.isSharing
                        ? 'Delar...'
                        : 'Dela (${viewModel.selectedCount})',
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
      return StateWidget.loading(message: 'Laddar recept...');
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
          searchHint: 'Sök recept...',
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          showStats: true,
          resultCount: viewModel.hasSearchResults
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info and actions
        if (viewModel.searchQuery.isNotEmpty || viewModel.hasSelectedRecipes)
          _buildInfo(context, viewModel),

        const Divider(
            height: AppDimensions.borderWidthThin, color: AppColors.divider),

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
              '${viewModel.filteredCount} av ${viewModel.totalCount} recept',
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
                color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusRound),
              ),
              child: Text(
                '${viewModel.selectedCount} valda',
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (viewModel.hasSelectedRecipes)
            TextButton(
              onPressed: viewModel.clearSelections,
              child: Text('Rensa val', style: AppTextStyles.labelLarge),
            )
          else if (viewModel.searchQuery.isNotEmpty)
            TextButton(
              onPressed: viewModel.clearSearch,
              child: Text('Rensa', style: AppTextStyles.labelLarge),
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
            style:
                AppTextStyles.bodyLargeLight,
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.error ?? 'Kunde inte dela recept',
            style:
                AppTextStyles.bodyLargeLight,
          ),
          backgroundColor: AppColors.error,
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
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              recipe.title,
              style: isAlreadyShared
                  ? AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textMedium)
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
                color: AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusRound),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: AppDimensions.opacityMediumLight)),
              ),
              child: Text('Delad',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.success)),
            ),
        ],
      ),
      subtitle: _buildSubtitle(),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor:
            isAlreadyShared ? AppColors.textMedium : AppColors.primaryBlue,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadiusRound)),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: isAlreadyShared
              ? AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.textMedium,
                )
              : AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.primaryBlue,
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
                color:
                    isAlreadyShared ? AppColors.success : AppColors.textMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${recipe.timeMinutes} min',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
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
                color:
                    isAlreadyShared ? AppColors.success : AppColors.textMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${recipe.portions} port',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
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

  Widget _buildPlaceholder() {
    return Container(
      width: AppDimensions.iconSizeXl,
      height: AppDimensions.iconSizeXl,
      decoration: BoxDecoration(
        color: isAlreadyShared
            ? AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight)
            : AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: isAlreadyShared ? AppColors.success : AppColors.primaryBlue,
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
