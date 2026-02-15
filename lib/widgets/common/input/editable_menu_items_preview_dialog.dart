// lib/widgets/common/input/editable_menu_items_preview_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Dialog for previewing and editing menu items before adding to shopping list.
/// Allows users to remove individual items or clear all items.
class EditableMenuItemsPreviewDialog extends StatefulWidget {
  final List<UnifiedShoppingItem> items;
  final String selectedListName;

  const EditableMenuItemsPreviewDialog({
    super.key,
    required this.items,
    required this.selectedListName,
  });

  @override
  State<EditableMenuItemsPreviewDialog> createState() =>
      _EditableMenuItemsPreviewDialogState();
}

class _EditableMenuItemsPreviewDialogState
    extends State<EditableMenuItemsPreviewDialog> {
  late List<UnifiedShoppingItem> _editableItems;

  @override
  void initState() {
    super.initState();
    _editableItems = List.from(widget.items);
  }

  void _removeItem(int index) {
    setState(() {
      _editableItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.shoppingPreviewAndEditItems),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _editableItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: AppDimensions.iconSizeXxl,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      context.l10n.shoppingNoItemsSelected,
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    Text(
                      context.l10n.shoppingAllItemsRemovedFromMenu,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _editableItems.length,
                itemBuilder: (context, index) {
                  final item = _editableItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingXs,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.shopping_cart,
                        size: AppDimensions.iconSizeM,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        item.name,
                        style: AppTextStyles.contentTitle,
                      ),
                      subtitle: item.amount > 0
                          ? Text(
                              '${item.amount} ${item.unit}',
                              style: AppTextStyles.bodyMedium,
                            )
                          : null,
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                          size: AppDimensions.iconSizeAction,
                        ),
                        onPressed: () => _removeItem(index),
                        tooltip: context.l10n.shoppingRemoveItem,
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        if (_editableItems.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _editableItems.clear();
              });
            },
            icon: Icon(Icons.clear_all,
                color: Theme.of(context).colorScheme.error),
            label: Text(
              context.l10n.shoppingRemoveAll,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'items': _editableItems,
            'addToList': false,
          }), // Cancel - save changes but don't add to list
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'items': _editableItems,
            'addToList': _editableItems.isNotEmpty,
          }),
          child: Text(_editableItems.isEmpty
              ? context.l10n.commonClose
              : context.l10n.shoppingToListWithCount(
                  widget.selectedListName, _editableItems.length)),
        ),
      ],
    );
  }
}
