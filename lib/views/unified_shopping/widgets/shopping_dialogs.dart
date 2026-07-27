// lib/views/unified_shopping/widgets/shopping_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Main facade for shopping dialog coordination
class ShoppingDialogs {
  // Item management dialogs - delegate to ShoppingItemDialogs
  static Future<void> showAddItemDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingItemDialogs.showAddItemDialog(
      context,
      viewModel,
      onSuccess,
      onError,
    );
  }

  static Future<void> showEditItemDialog(
    BuildContext context,
    UnifiedShoppingItem item,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingItemDialogs.showEditItemDialog(
      context,
      item,
      viewModel,
      onSuccess,
      onError,
    );
  }

  // List operations - delegate to ShoppingListOperations
  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    return ShoppingListOperations.showCreateListDialog(
      context,
      viewModel,
      onSuccess,
    );
  }

  static Future<void> showClearCompletedConfirmation(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingListOperations.showClearCompletedConfirmation(
      context,
      viewModel,
      onSuccess,
      onError,
    );
  }

  static Future<void> showRenameListDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingListOperations.showRenameListDialog(
      context,
      list,
      viewModel,
      onSuccess,
      onError,
    );
  }

  static Future<void> showDeleteListConfirmationDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingListOperations.showDeleteListConfirmationDialog(
      context,
      list,
      viewModel,
      onSuccess,
      onError,
    );
  }

  // List conversion dialogs - delegate to ShoppingListOperations
  static Future<void> showConvertToCollaborativeDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingListOperations.showConvertToCollaborativeDialog(
      context,
      list,
      onSuccess,
      onError,
    );
  }

  static Future<void> showConvertToPersonalDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    return ShoppingListOperations.showConvertToPersonalDialog(
      context,
      list,
      onSuccess,
      onError,
    );
  }

  // Sharing dialogs - coordinated here
  static Future<void> showShareDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    if (viewModel.activeList == null) return;

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      AppLogger.info('Initializing friends service for sharing...');
      await friendsService.initialize();
      final availableFriends = friendsService.friends;
      AppLogger.info('Loaded ${availableFriends.length} friends for sharing');

      if (availableFriends.isEmpty) {
        AppLogger.warning('No friends available - showing info dialog');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.shoppingNoFriends),
              content: Text(context.l10n.shoppingNoFriendsDescription),
              actions: [
                ActionButtons.primaryButton(
                  context,
                  label: context.l10n.commonOk,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
        return;
      }

      final shareViewModel =
          ServiceLocator.get<UniversalShareDialogViewModel>();
      if (context.mounted) {
        AppLogger.info(
          'Showing share dialog for list: ${viewModel.activeList!.name}',
        );
        await showDialog(
          context: context,
          builder: (context) => UniversalShareDialog.shoppingList(
            shoppingList: viewModel.activeList!,
            viewModel: shareViewModel,
            availableFriends: availableFriends,
          ),
        );
        AppLogger.info('Share dialog completed');
      }
    } catch (e) {
      AppLogger.error('Error showing share dialog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shoppingCouldNotShowShareDialog(
                SnackBarUtils.userFriendlyMessage(context, e),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> showSharingStatus(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    final activeList = viewModel.activeList;
    if (activeList == null) return;

    final Map<String, String> userDisplayNames = {};
    if (activeList.isCollaborative) {
      try {
        final userService = ServiceLocator.get<UserService>();
        final allUserIds = <String>{
          activeList.ownerId,
          ...activeList.memberPermissions.keys,
        }.toList();

        final profiles = await userService.getUserProfiles(allUserIds);
        for (final profile in profiles) {
          userDisplayNames[profile.uid] = profile.displayName;
        }

        if (!userDisplayNames.containsKey(activeList.ownerId) &&
            activeList.ownerDisplayName.isNotEmpty) {
          userDisplayNames[activeList.ownerId] = activeList.ownerDisplayName;
        }
      } catch (e) {
        AppLogger.warning(
          'Could not load user profiles for sharing dialog: $e',
        );
        if (activeList.ownerDisplayName.isNotEmpty) {
          userDisplayNames[activeList.ownerId] = activeList.ownerDisplayName;
        }
      }
    }

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => ShoppingShareStatusDialog(
          list: activeList,
          userDisplayNames: userDisplayNames,
        ),
      );
    }
  }
}
