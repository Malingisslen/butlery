// lib/views/social/menu_preview_view.dart
// Preview of shared menus with all recipes

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/bold_names_text.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';
import 'package:butlery/views/social/menu_preview/menu_preview_dishes.dart';

/// ✅ MenuPreviewView - Visa delad meny med alla recept
class MenuPreviewView extends StatelessWidget {
  final SharedMenu sharedMenu;

  const MenuPreviewView({
    super.key,
    required this.sharedMenu,
  });

  @override
  Widget build(BuildContext context) {
    // The menu's own name stands in the header below the bar.
    return ButleryPage.undersida(
      title: context.l10n.menuPreviewTitle,
      actions: [
        AppIconButton(
          onPressed: () => _shareMenu(context),
          icon: ButleryIcons.share2,
          semanticLabel: context.l10n.menuShareMenu,
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // BUT-1162: surface silent collaborative-edit conflict
                // resolutions on this shared menu (drop-in; idle-collapses).
                SliverToBoxAdapter(
                  child: ConflictBanner(
                    filterDocId: sharedMenu.realtimeMenuId ?? sharedMenu.id,
                  ),
                ),
                _buildMenuHeader(context),
                MenuPreviewDishes(sharedMenu: sharedMenu),
                _buildImportNote(context),
              ],
            ),
          ),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildMenuHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final line = context.l10n.menuPreviewSharedLine(
      sharedMenu.sharedByDisplayName,
      sharedMenu.menuTitle,
    );
    final bold = AppTextStyles.bodyBold.copyWith(color: cs.onSurface);
    return SliverToBoxAdapter(
      child: Padding(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AvatarCircle(
                  displayName: sharedMenu.sharedByDisplayName,
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface,
                      ),
                      children: boldNameSpans(line, [
                        sharedMenu.sharedByDisplayName,
                        sharedMenu.menuTitle,
                      ], bold),
                    ),
                  ),
                ),
              ],
            ),
            if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
              const SizedBox(height: AppDimensions.space12),
              Text(
                '”${sharedMenu.shareMessage}”',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space12),
            const ButleryDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildImportNote(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: AppDimensions.responsiveContentPadding(context).add(
          const EdgeInsets.symmetric(vertical: AppDimensions.space12),
        ),
        child: Text(
          context.l10n.menuImportDescription(sharedMenu.totalRecipeCount),
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: Consumer<SharedContentCoordinatorViewModel>(
        builder: (context, viewModel, _) {
          final isImported = viewModel.menuViewModel.isMenuImported(sharedMenu);

          // Per-item loading state avoids a spinner on every item.
          final isThisMenuOperating = viewModel.menuViewModel.isItemOperating(
            sharedMenu.id,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The view's one saffron action, "Spara till mina menyer" as
              // drawn (Skarmar v12 del 3 #menyforhands). Imported, it takes
              // the hero's disabled surface; importing keeps the name and
              // draws the plate line.
              HeroButton(
                key: const ValueKey('menuPreview.import'),
                label: isImported
                    ? context.l10n.menuImported
                    : context.l10n.menuImportAll,
                icon: isImported ? ButleryIcons.check : null,
                onPressed: isImported
                    ? null
                    : () => _importMenu(context, viewModel),
                busy: isThisMenuOperating,
                busyLabel: context.l10n.commonImporting,
                expand: true,
              ),
              ButleryTextButton(
                key: const ValueKey('menuPreview.decline'),
                onPressed: () => _dismissMenu(context, viewModel),
                label: context.l10n.menuPreviewDecline,
              ),
            ],
          );
        },
      ),
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
        SnackBarUtils.showInfo(
          context,
          context.l10n.menuConnectingCollaborative(sharedMenu.menuTitle),
          duration: const Duration(seconds: 2),
        );
        // Pop current view and navigate to realtime menu
        Navigator.pop(context);
        AppRouter.navigateTo(
          context,
          Routes.realtimeMenu,
          arguments: {'menuId': result.menuId},
        );
      } else {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.menuImportedSuccess(sharedMenu.menuTitle),
          duration: const Duration(seconds: 3),
        );
        // Navigera tillbaka efter lyckad import
        Navigator.pop(context);
      }
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      SnackBarUtils.showFailure(
        context,
        what: viewModel.menuViewModel.error ?? context.l10n.menuImportFailed,
      );
    }
  }

  Future<void> _dismissMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) async {
    // Show confirmation dialog
    final shouldDismiss = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.menuHideMenu,
      message: context.l10n.menuHideConfirm(
        sharedMenu.menuTitle,
        sharedMenu.sharedByDisplayName,
      ),
      confirmText: context.l10n.commonHide,
      icon: ButleryIcons.eyeOff,
    );

    if (shouldDismiss == true) {
      final success = await viewModel.menuViewModel.dismissSharedMenu(
        sharedMenu,
      );

      if (success && context.mounted) {
        // PQ-07 = A (produktbeslut 2026-09-23): the confirmation question
        // stays, and Ångra goes through the undo primitive with its 7 s
        // window like every other undo (produktregler.md:131-132). The view
        // pops right after, and SnackbarRouteObserver clears snackbars on
        // every pop, so the messenger is captured here and the snackbar is
        // shown once the route is gone.
        final undo = UndoSnackBar.capture(context);
        final message = context.l10n.menuHiddenFromList(sharedMenu.menuTitle);

        // Navigera tillbaka efter dismiss
        Navigator.pop(context);
        undo.show(
          message,
          onUndo: () => viewModel.menuViewModel.undismissSharedMenu(sharedMenu),
        );
      } else if (context.mounted && viewModel.menuViewModel.hasError) {
        SnackBarUtils.showFailure(
          context,
          what: viewModel.menuViewModel.error ?? context.l10n.menuCouldNotHide,
        );
      }
    }
  }

  Future<void> _shareMenu(BuildContext context) async {
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    try {
      if (!friendsService.isInitialized) await friendsService.initialize();
    } catch (e) {
      AppLogger.warning('Friends list load before share failed: $e');
    }
    if (!context.mounted) return;

    await showUniversalShareSheet(
      context,
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
