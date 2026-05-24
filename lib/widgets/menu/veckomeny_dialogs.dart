// lib/widgets/menu/veckomeny_dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Dialog helpers for the Veckomeny (weekly menu) view.
/// Extracts dialog logic from the main view for better separation of concerns.
class VeckomenyDialogs {
  /// Shows save menu dialog.
  static Future<void> showSaveMenuDialog(
    BuildContext context, {
    required MenuViewModel viewModel,
    required List<UserProfile> availableFriends,
  }) async {
    if (!viewModel.hasMenu) {
      SnackBarUtils.showWarning(context, context.l10n.menuCreateBeforeSave);
      return;
    }

    await LayoutComponents.showSaveMenuDialog(
      context,
      viewModel: viewModel,
      availableFriends: availableFriends,
    );
  }

  /// Shows load menu bottom sheet with saved menus and templates tabs.
  static Future<void> showLoadMenuBottomSheet(
    BuildContext context, {
    required MenuViewModel viewModel,
    ValueChanged<String>? onTemplateSelected,
  }) async {
    await LayoutComponents.showLoadMenuDialog(
      context,
      viewModel: viewModel,
      onTemplateSelected: onTemplateSelected,
    );
  }

  /// Shows social menu share dialog with friend selection.
  static Future<void> showSocialMenuShareDialog(
    BuildContext context, {
    required MenuViewModel menuViewModel,
    required UnifiedFriendsService friendsService,
  }) async {
    if (!menuViewModel.hasMenu) {
      SnackBarUtils.showWarning(context, context.l10n.menuCreateBeforeShare);
      return;
    }

    final menuName = await showMenuNameDialog(context, menuViewModel);
    if (!context.mounted) return;
    if (menuName == null || menuName.isEmpty) {
      return;
    }

    List<UserProfile> availableFriends = [];
    try {
      availableFriends = friendsService.friends;
    } catch (e) {
      AppLogger.warning('Kunde inte hämta vänner: $e');
    }

    showDialog(
      context: context,
      builder: (context) => UniversalShareDialog.menu(
        menu: menuViewModel.menu,
        menuName: menuName,
        viewModel: ServiceLocator.get<UniversalShareDialogViewModel>(),
        initialMessage: context.l10n.menuShareDefaultMessage,
        availableFriends: availableFriends,
      ),
    );
  }

  /// Shows menu name input dialog for sharing.
  static Future<String?> showMenuNameDialog(
    BuildContext context,
    MenuViewModel menuViewModel,
  ) async {
    final TextEditingController nameController = TextEditingController();

    // Generate default name suggestion
    final recipeCount = menuViewModel.totalRecipeCount;
    nameController.text = context.l10n.menuDefaultName(recipeCount);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuNameYourMenu),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.menuNameBeforeShare),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: nameController,
              hint: context.l10n.menuNameHint,
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonShare,
            icon: Icons.share,
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
          ),
        ],
      ),
    );

    return result;
  }

  /// Shows shopping list selector for creating shopping list from menu.
  static Future<void> showShoppingListSelector(
    BuildContext context, {
    required MenuViewModel viewModel,
  }) async {
    if (!viewModel.hasMenu || viewModel.menu.isEmpty) {
      SnackBarUtils.showWarning(
          context, context.l10n.menuCreateBeforeShoppingList);
      return;
    }

    await InputComponents.showListSelector(
      context,
      menu: viewModel.menu,
      onListSelected: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, Routes.shoppingList);
      },
    );
  }

  /// Shows exit confirmation dialog.
  static Future<void> showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuExitTitle),
        content: Text(context.l10n.menuExitMessage),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.menuExitConfirm,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }
}
