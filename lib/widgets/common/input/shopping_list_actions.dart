// lib/widgets/common/input/shopping_list_actions.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../viewmodels/unified_shopping_viewmodel.dart';
import '../../../core/utils/logger.dart';

/// Shopping list actions handler
///
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
      icon: AppTheme.actionIcon(context, Icons.more_vert),
      onSelected: (action) => _handleListAction(context, action, list, viewModel),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: AppTheme.iconSizeAction),
              AppTheme.smallHorizontalGap,
              Text('Byt namn'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.share, size: AppTheme.iconSizeAction),
              AppTheme.smallHorizontalGap,
              Text('Exportera'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: AppTheme.iconSizeAction,
                color: AppTheme.errorColor,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Ta bort',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ],
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
        title: Text('Byt namn på lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Nytt namn',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Spara'),
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
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
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
            backgroundColor: exportText.isNotEmpty ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Export list failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte exportera lista'),
            backgroundColor: AppTheme.errorColor,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            AppTheme.smallHorizontalGap,
            Text('Ta bort lista'),
          ],
        ),
        content: Text(
          'Är du säker på att du vill ta bort "${list.name}"?\n\n'
          'Denna åtgärd kan inte ångras och alla ${list.totalItems} artiklar försvinner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('Ta bort'),
          ),
        ],
      ),
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
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
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
        title: Text('Skapa ny handlista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Namn på lista',
                border: OutlineInputBorder(),
                hintText: 'T.ex. "Veckans handlista"',
              ),
              autofocus: true,
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Skapa'),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lägg till i "${list.name}"'),
        content: Text(
          'Vill du lägga till $itemCount artiklar från menyn i "${list.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Lägg till'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}