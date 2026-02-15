// lib/widgets/common/input/shopping_list_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';

/// Shopping list actions handler
/// This module provides action handling for shopping lists including
/// rename, delete, export, and create operations.
class ShoppingListActions {
  /// Build actions button for list
  static Widget buildListActionsButton(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: AppDimensions.iconSizeAction),
      onSelected: (action) =>
          _handleListAction(context, action, list, viewModel),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit, size: AppDimensions.iconSizeAction),
              const SizedBox(width: AppDimensions.spacingM),
              Text(context.l10n.commonRename),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.share, size: AppDimensions.iconSizeAction),
              const SizedBox(width: AppDimensions.spacingM),
              Text(context.l10n.commonExport),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Builder(
            builder: (context) => Row(
              children: [
                Icon(
                  Icons.delete,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.commonDelete,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Handle list action
  static Future<void> _handleListAction(
    BuildContext context,
    String action,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    switch (action) {
      case 'rename':
        await showRenameDialog(context, list, viewModel);
        break;
      case 'export':
        await exportList(context, list, viewModel);
        break;
      case 'delete':
        await showDeleteDialog(context, list, viewModel);
        break;
    }
  }

  /// Show rename dialog
  static Future<void> showRenameDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    final controller = TextEditingController(text: list.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingRenameList),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: controller,
              label: context.l10n.shoppingNewName,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          StyledButton.secondary(
            text: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          StyledButton.primary(
            text: context.l10n.commonSave,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != list.name) {
      final success = await viewModel.renameList(list.id, newName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${context.l10n.shoppingRenameList} "$newName"'
                  : '${context.l10n.errorCouldNotUpdate(context.l10n.shoppingList)}: ${viewModel.error ?? context.l10n.errorUnexpected}',
            ),
            backgroundColor: success
                ? context.butleryColors.success
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Export list
  static Future<void> exportList(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    try {
      final exportText = viewModel.exportList();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exportText.isNotEmpty
                  ? '${context.l10n.shoppingList} "${list.name}" ${context.l10n.commonExport}'
                  : '${context.l10n.errorCouldNotUpdate(context.l10n.shoppingList)}: ${viewModel.error ?? context.l10n.errorUnexpected}',
            ),
            backgroundColor: exportText.isNotEmpty
                ? context.butleryColors.success
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Export list failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.l10n.errorCouldNotUpdate(context.l10n.shoppingList)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  static Future<void> showDeleteDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: list.name,
      itemType: context.l10n.shoppingList,
      warningMessage:
          '${context.l10n.confirmIrreversibleAction} ${context.l10n.shoppingItemsWillBeRemoved(list.totalItems)}',
      icon: Icons.list,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${context.l10n.shoppingList} "${list.name}" ${context.l10n.successItemDeleted(context.l10n.shoppingList).split(' ')[1]}'
                  : '${context.l10n.errorCouldNotDelete(context.l10n.shoppingList)}: ${viewModel.error ?? context.l10n.errorUnexpected}',
            ),
            backgroundColor: success
                ? context.butleryColors.success
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show create new list dialog
  static Future<String?> showCreateListDialog(BuildContext context) async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingCreateList),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: controller,
              label: context.l10n.shoppingListName,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          StyledButton.secondary(
            text: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          StyledButton.primary(
            text: context.l10n.commonCreate,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  /// Show add to list confirmation dialog
  static Future<bool> showAddToListConfirmation(
    BuildContext context,
    UnifiedShoppingList list,
    int itemCount,
  ) async {
    final result = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: '${context.l10n.shoppingAddToList} "${list.name}"',
      message: context.l10n.shoppingItemsFromMenuIn(itemCount, list.name),
      confirmText: context.l10n.commonAdd,
      icon: Icons.add_shopping_cart,
    );

    return result ?? false;
  }
}
