// lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_list_item.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_info_bar.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_dialog_frame.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
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
          return RecipeShareDialogFrame(
            recipientName: friend.displayName,
            content: _buildContent(context, viewModel),
            hasSelectedRecipes: viewModel.hasSelectedRecipes,
            selectedCount: viewModel.selectedCount,
            isSharing: viewModel.isSharing,
            onShare: () => _shareSelectedRecipes(context, viewModel),
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
          // The navigator outlives this dialog, so the sheet can open from it.
          final navigatorContext = Navigator.of(context).context;
          Navigator.pop(context);
          showButleryAddSheet(navigatorContext);
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
          padding: const EdgeInsets.all(AppDimensions.space12),
          showStats: true,
          resultCount: viewModel.hasSearchResults
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info and actions
        if (viewModel.searchQuery.isNotEmpty || viewModel.hasSelectedRecipes)
          RecipeShareInfoBar(
            searchQuery: viewModel.searchQuery,
            filteredCount: viewModel.filteredCount,
            totalCount: viewModel.totalCount,
            hasSelectedRecipes: viewModel.hasSelectedRecipes,
            selectedCount: viewModel.selectedCount,
            onClearSelection: viewModel.clearSelections,
            onClearSearch: viewModel.clearSearch,
          ),

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
      );
    } else if (!success && context.mounted) {
      SnackBarUtils.showFailure(
        context,
        what: viewModel.error ?? context.l10n.chatCouldNotShareRecipe,
      );
    }
  }
}
