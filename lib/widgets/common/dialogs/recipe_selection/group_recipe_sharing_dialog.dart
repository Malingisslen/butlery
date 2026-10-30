// lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/group_recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_list_item.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_info_bar.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_dialog_frame.dart';

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
          return RecipeShareDialogFrame(
            recipientName: group.name,
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
    GroupRecipeSelectionViewModel viewModel,
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

    if (viewModel.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.dialogNoRecipes,
        subtitle: context.l10n.dialogNoRecipesToShare,
        icon: ButleryIcons.utensils,
      );
    }

    return Column(
      children: [
        // Search and filter
        SearchFilterWidget.searchOnly(
          searchQuery: viewModel.searchQuery,
          onSearchChanged: viewModel.setSearchQuery,
          searchHint: context.l10n.dialogSearchRecipes,
          padding: const EdgeInsets.all(AppDimensions.space12),
          showStats: true,
          resultCount: viewModel.filteredRecipes.isNotEmpty
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info bar showing filtered count and selection
        RecipeShareInfoBar(
          searchQuery: viewModel.searchQuery,
          filteredCount: viewModel.filteredCount,
          totalCount: viewModel.totalCount,
          hasSelectedRecipes: viewModel.hasSelectedRecipes,
          selectedCount: viewModel.selectedCount,
          onClearSelection: viewModel.clearSelections,
          onClearSearch: viewModel.clearSearch,
        ),

        const SizedBox(height: AppDimensions.space4),

        Divider(
          height: AppDimensions.borderWidthThin,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),

        // Recipe list
        Expanded(
          child: viewModel.filteredRecipes.isNotEmpty
              ? ListView.builder(
                  itemCount: viewModel.filteredCount,
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
    GroupRecipeSelectionViewModel viewModel,
  ) async {
    final success = await viewModel.shareSelectedRecipes();

    if (!context.mounted) return;

    if (success) {
      SnackBarUtils.showSuccess(
        context,
        viewModel.successMessage,
      );
      Navigator.pop(context);
    } else if (viewModel.hasError) {
      SnackBarUtils.showFailure(context, what: viewModel.error!);
    }
  }
}
