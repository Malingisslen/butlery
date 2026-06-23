// lib/views/social/menu_preview_view.dart
// Preview of shared menus with all recipes

import 'package:flutter/material.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/status_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// ✅ MenuPreviewView - Visa delad meny med alla recept
class MenuPreviewView extends StatelessWidget {
  final SharedMenu sharedMenu;

  const MenuPreviewView({
    super.key,
    required this.sharedMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Configure Swedish for timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                // BUT-1162: surface silent collaborative-edit conflict
                // resolutions on this shared menu (drop-in; idle-collapses).
                SliverToBoxAdapter(
                  child: ConflictBanner(filterDocId: sharedMenu.id),
                ),
                _buildMenuHeader(context),
                _buildMenuContent(context),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // BUT-706: stays a Material SliverAppBar for now. A CupertinoSliverNavigationBar
    // (iOS large-title) is possible here but is a visual/UX decision, not a
    // mechanical swap — deferred (see BUT-1362).
    return SliverAppBar(
      title: Text(sharedMenu.menuTitle),
      floating: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          onPressed: () => _shareMenu(context),
          icon: const Icon(Icons.share),
          tooltip: context.l10n.menuShareMenu,
        ),
      ],
    );
  }

  Widget _buildMenuHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delningsinformation
              Row(
                children: [
                  SocialAvatarComponents.avatar(
                    displayName: sharedMenu.sharedByDisplayName,
                    size: ImageSize.small,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n
                              .sharedByUser(sharedMenu.sharedByDisplayName),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        Text(
                          timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.primary(text: context.l10n.menuSharedMenu),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingL),

              // Meny titel och beskrivning
              Text(
                sharedMenu.menuTitle,
                style: AppTextStyles.sectionHeader.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingS),

              // Meny statistik
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: AppDimensions.iconSizeM,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    context.l10n.menuRecipeCount(sharedMenu.totalRecipeCount),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingL),
                  Icon(
                    Icons.category,
                    size: AppDimensions.iconSizeM,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    context.l10n
                        .menuCategoryCount(sharedMenu.categories.length),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),

              // Delningsmeddelande
              if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
                const SizedBox(height: AppDimensions.spacingL),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.commonMessage,
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        '"${sharedMenu.shareMessage}"',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ], // Close if statement spread array
            ], // Close children array of main Column
          ), // Close main Column
        ), // Close Container
      ),
    );
  }

  Widget _buildMenuContent(BuildContext context) {
    // Group recipes by category from menuSnapshot
    final menuContent = sharedMenu.menuSnapshot;

    if (menuContent.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: StateWidget.empty(
            title: context.l10n.menuNoRecipesInMenu,
            icon: Icons.restaurant_outlined,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final categories = menuContent.keys.toList();
          final category = categories[index];
          final recipes = menuContent[category] ?? [];

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacingS,
              AppDimensions.spacingS,
              AppDimensions.spacingS,
              index == categories.length - 1 ? AppDimensions.spacingL : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori header
                CategoryHeader(
                  title: category,
                  icon: _getCategoryIcon(category),
                  count: recipes.length,
                ),

                const SizedBox(height: AppDimensions.spacingS),

                // Recept i kategorin
                ...recipes.map((recipe) => Column(
                      children: [
                        ContentCard.compactRecipe(
                          recipe: recipe,
                          onTap: () => _navigateToRecipeDetail(context, recipe),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                      ],
                    )),
              ],
            ),
          );
        },
        childCount: menuContent.keys.length,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: AppDimensions.screenPadding,
        child: Consumer<SharedContentCoordinatorViewModel>(
          builder: (context, viewModel, _) {
            final isImported =
                viewModel.menuViewModel.isMenuImported(sharedMenu);

            // Use per-item loading state to avoid spinner on all items
            final isThisMenuOperating =
                viewModel.menuViewModel.isItemOperating(sharedMenu.id);

            return Column(
              children: [
                // Import knapp
                ActionButtons.primaryButton(
                  context,
                  label: isImported
                      ? context.l10n.menuImported
                      : context.l10n.menuImportAll,
                  icon: isImported ? Icons.check : Icons.download,
                  onPressed: isImported || isThisMenuOperating
                      ? null
                      : () => _importMenu(context, viewModel),
                  isLoading: isThisMenuOperating,
                  loadingText: context.l10n.commonImporting,
                  isExpanded: true,
                ),

                const SizedBox(height: AppDimensions.spacingS),

                // Dismiss knapp
                ActionButtons.outlinedButton(
                  context,
                  label: context.l10n.sharedHideFromList,
                  icon: Icons.visibility_off,
                  onPressed: () => _dismissMenu(context, viewModel),
                  isExpanded: true,
                ),

                const SizedBox(height: AppDimensions.spacingL),

                // Info text
                Text(
                  context.l10n
                      .menuImportDescription(sharedMenu.totalRecipeCount),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();

    if (categoryLower.contains('frukost')) {
      return Icons.free_breakfast;
    }
    if (categoryLower.contains('lunch')) {
      return Icons.lunch_dining;
    }
    if (categoryLower.contains('middag')) {
      return Icons.dinner_dining;
    }
    if (categoryLower.contains('mellanmål') ||
        categoryLower.contains('snack')) {
      return Icons.cookie;
    }
    if (categoryLower.contains('dessert')) {
      return Icons.cake;
    }
    if (categoryLower.contains('drink') || categoryLower.contains('dryck')) {
      return Icons.local_cafe;
    }

    return Icons.restaurant_menu;
  }

  void _navigateToRecipeDetail(BuildContext context, Recipe recipe) {
    Navigator.pushNamed(
      context,
      '/receptDetalj',
      arguments: recipe,
    );
  }

  Future<void> _importMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) async {
    final result = await viewModel.menuViewModel.importSharedMenu(sharedMenu);

    if (result != null && context.mounted) {
      if (result.isCollaborative) {
        // Navigate to collaborative menu view
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.l10n.menuConnectingCollaborative(sharedMenu.menuTitle)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        // Pop current view and navigate to realtime menu
        Navigator.pop(context);
        AppRouter.navigateTo(
          context,
          Routes.realtimeMenu,
          arguments: {'menuId': result.menuId},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.menuImportedSuccess(sharedMenu.menuTitle)),
            backgroundColor: context.butleryColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigera tillbaka efter lyckad import
        Navigator.pop(context);
      }
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              viewModel.menuViewModel.error ?? context.l10n.menuImportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _dismissMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) async {
    // Show confirmation dialog
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuHideMenu),
        content: Text(
          context.l10n.menuHideConfirm(
              sharedMenu.menuTitle, sharedMenu.sharedByDisplayName),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonHide,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success =
          await viewModel.menuViewModel.dismissSharedMenu(sharedMenu);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.menuHiddenFromList(sharedMenu.menuTitle)),
            backgroundColor: context.butleryColors.success,
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () =>
                  viewModel.menuViewModel.undismissSharedMenu(sharedMenu),
            ),
          ),
        );

        // Navigera tillbaka efter dismiss
        Navigator.pop(context);
      } else if (context.mounted && viewModel.menuViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                viewModel.menuViewModel.error ?? context.l10n.menuCouldNotHide),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shareMenu(BuildContext context) async {
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.menu(
          menu: sharedMenu.menuSnapshot,
          viewModel: shareViewModel,
          menuName: sharedMenu.menuTitle,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
        ),
      ),
    );
  }
}
