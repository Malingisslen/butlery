// lib/widgets/common/input/editable_menu_items_preview_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
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
      title: const Text('Förhandsgranska och redigera artiklar'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _editableItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: AppDimensions.iconSizeXxl,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      'Inga artiklar valda',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    Text(
                      'Du har tagit bort alla artiklar från menyn',
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
                      leading: const Icon(
                        Icons.shopping_cart,
                        size: AppDimensions.iconSizeM,
                        color: AppColors.primaryBlue,
                      ),
                      title: Text(
                        item.name,
                        style: AppTextStyles.text16Medium,
                      ),
                      subtitle: item.amount > 0
                          ? Text(
                              '${item.amount} ${item.unit}',
                              style: AppTextStyles.bodyMedium,
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AppColors.error,
                          size: AppDimensions.iconSizeAction,
                        ),
                        onPressed: () => _removeItem(index),
                        tooltip: 'Ta bort artikel',
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
            icon: const Icon(Icons.clear_all, color: AppColors.error),
            label: Text(
              'Ta bort alla',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'items': _editableItems,
            'addToList': false,
          }), // Cancel - save changes but don't add to list
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'items': _editableItems,
            'addToList': _editableItems.isNotEmpty,
          }),
          child: Text(_editableItems.isEmpty
              ? 'Stäng'
              : 'Till "${widget.selectedListName}" (${_editableItems.length})'),
        ),
      ],
    );
  }
}
