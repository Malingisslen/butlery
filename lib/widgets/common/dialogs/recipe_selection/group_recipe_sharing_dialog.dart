// lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/group_recipe_selection_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_list_item.dart';

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
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          showStats: true,
          resultCount: viewModel.filteredRecipes.isNotEmpty
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info bar showing filtered count and selection
        _buildInfo(context, viewModel),

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

  Widget _buildInfo(
    BuildContext context,
    GroupRecipeSelectionViewModel viewModel,
  ) {
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
    GroupRecipeSelectionViewModel viewModel,
  ) async {
    final success = await viewModel.shareSelectedRecipes();

    if (!context.mounted) return;

    if (success) {
      SnackBarUtils.showSuccess(
        context,
        viewModel.successMessage,
        duration: const Duration(seconds: 3),
      );
      Navigator.pop(context);
    } else if (viewModel.hasError) {
      SnackBarUtils.showFailure(context, what: viewModel.error!);
    }
  }
}
