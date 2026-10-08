// lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_list_item.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
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
                child: Text(
                  context.l10n.commonCancel,
                  style: AppTextStyles.labelLarge,
                ),
              ),
              if (viewModel.hasSelectedRecipes)
                // The theme's ink filled button (onPrimary on primary in both
                // schemes); sharing says so and draws the plate line along
                // its bottom edge, never a spinner (Komponentark v1:365,
                // :372).
                BusyButtonSemantics(
                  busy: viewModel.isSharing,
                  name:
                      '${context.l10n.commonShare} (${viewModel.selectedCount})',
                  busyLabel: context.l10n.dialogSharing,
                  child: FilledButton.icon(
                    onPressed: viewModel.isSharing
                        ? PlateLineButton.ignore
                        : () => _shareSelectedRecipes(context, viewModel),
                    style: viewModel.isSharing
                        ? PlateLineButton.busyStyle(
                            null,
                            Theme.of(context).filledButtonTheme.style,
                          )
                        : null,
                    icon: const ButleryIcon(ButleryIcons.share2),
                    label: Text(
                      viewModel.isSharing
                          ? context.l10n.dialogSharing
                          : '${context.l10n.commonShare} (${viewModel.selectedCount})',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    RecipeSelectionViewModel viewModel,
  ) {
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
          Navigator.pushNamed(context, Routes.addRecipe);
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
          color: Theme.of(context).colorScheme.outlineVariant,
        ),

        // Recipe list
        Expanded(
          child: viewModel.hasSearchResults
              ? ListView.builder(
                  itemCount: viewModel.filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final unifiedRecipe = viewModel.filteredRecipes[index];
                    return RecipeShareListItem(
                      recipe: unifiedRecipe,
                      isSelected: viewModel.isRecipeSelected(unifiedRecipe.id),
                      isAlreadyShared: viewModel.isRecipeAlreadyShared(
                        unifiedRecipe.id,
                      ),
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
                viewModel.filteredCount,
                viewModel.totalCount,
              ),
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                context.l10n.dialogSelectedCount(viewModel.selectedCount),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (viewModel.hasSelectedRecipes)
            TextButton(
              onPressed: viewModel.clearSelections,
              child: Text(
                context.l10n.dialogClearSelection,
                style: AppTextStyles.labelLarge,
              ),
            )
          else if (viewModel.searchQuery.isNotEmpty)
            TextButton(
              onPressed: viewModel.clearSearch,
              child: Text(
                context.l10n.commonClear,
                style: AppTextStyles.labelLarge,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedRecipes(
    BuildContext context,
    RecipeSelectionViewModel viewModel,
  ) async {
    final shareMessage = viewModel.getShareMessage();
    final success = await viewModel.shareSelectedRecipes();

    if (success && context.mounted) {
      Navigator.pop(context);
      SnackBarUtils.showSuccess(
        context,
        shareMessage,
        duration: const Duration(seconds: 3),
      );
    } else if (!success && context.mounted) {
      SnackBarUtils.showFailure(
        context,
        what: viewModel.error ?? context.l10n.chatCouldNotShareRecipe,
      );
    }
  }
}
