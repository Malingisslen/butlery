// lib/widgets/common/input/shopping_list_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/constants/app_strings.dart';
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
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: AppDimensions.iconSizeAction),
              SizedBox(width: AppDimensions.spacingM),
              Text(AppStrings.rename),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.share, size: AppDimensions.iconSizeAction),
              SizedBox(width: AppDimensions.spacingM),
              Text(AppStrings.export),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Builder(
            builder: (context) => Row(
              children: [
                const Icon(
                  Icons.delete,
                  size: AppDimensions.iconSizeAction,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.commonDelete,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
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
        title: const Text(AppStrings.renameList),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: controller,
              label: AppStrings.newName,
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
                  ? 'Lista döpt om till "$newName"'
                  : 'Kunde inte byta namn: ${viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
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
                  ? 'Lista "${list.name}" exporterad'
                  : 'Kunde inte exportera lista: ${viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor:
                exportText.isNotEmpty ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Export list failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte exportera lista'),
            backgroundColor: AppColors.error,
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
      itemType: 'inköpslista',
      warningMessage:
          'Denna åtgärd kan inte ångras och alla ${list.totalItems} artiklar försvinner.',
      icon: Icons.list,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista "${list.name}" borttagen'
                  : 'Kunde inte ta bort lista: ${viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
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
        title: const Text(AppStrings.createList),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: controller,
              label: AppStrings.listName,
              hint: 'T.ex. "Veckans inköpslista"',
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
      title: '${AppStrings.addToList} "${list.name}"',
      message:
          'Vill du lägga till $itemCount artiklar från menyn i "${list.name}"?',
      confirmText: context.l10n.commonAdd,
      icon: Icons.add_shopping_cart,
    );

    return result ?? false;
  }
}
