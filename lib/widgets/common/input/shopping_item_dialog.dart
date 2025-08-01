// lib/widgets/common/input/shopping_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/validators/form_validators.dart';

/// Dialog for adding/editing unified shopping items
///
/// This dialog provides a form for creating or editing shopping items with
/// fields for name, amount, unit, and category selection.
class AddUnifiedShoppingItemDialog extends StatefulWidget {
  final UnifiedShoppingItem? initialItem;

  const AddUnifiedShoppingItemDialog({
    super.key,
    this.initialItem,
  });

  @override
  State<AddUnifiedShoppingItemDialog> createState() =>
      _AddUnifiedShoppingItemDialogState();
}

class _AddUnifiedShoppingItemDialogState
    extends State<AddUnifiedShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  late String _selectedUnit;
  late String _selectedCategory;

  // Units with correct dropdown-text and display-text
  final List<Map<String, String>> _units = [
    {'value': 'st', 'display': 'st', 'dropdown': 'st'},
    {'value': 'liter', 'display': 'l', 'dropdown': 'liter'},
    {'value': 'dl', 'display': 'dl', 'dropdown': 'dl'},
    {'value': 'msk', 'display': 'msk', 'dropdown': 'msk'},
    {'value': 'krm', 'display': 'krm', 'dropdown': 'krm'},
    {'value': 'ml', 'display': 'ml', 'dropdown': 'ml'},
    {'value': 'cl', 'display': 'cl', 'dropdown': 'cl'},
    {'value': 'g', 'display': 'g', 'dropdown': 'g'},
    {'value': 'kg', 'display': 'kg', 'dropdown': 'kg'},
    {'value': 'förpackning', 'display': 'förp', 'dropdown': 'förpackning'},
    {'value': 'tsk', 'display': 'tsk', 'dropdown': 'tsk'},
    {'value': 'påse', 'display': 'påse', 'dropdown': 'påse'},
    {'value': 'burk', 'display': 'burk', 'dropdown': 'burk'},
    {'value': 'flaska', 'display': 'flaska', 'dropdown': 'flaska'},
    {'value': 'bit', 'display': 'bit', 'dropdown': 'bit'},
    {'value': 'klyfta', 'display': 'klyfta', 'dropdown': 'klyfta'},
  ];

  // Sorted categories for better grouping
  final List<String> _categories = [
    'Frukt & Grönt',
    'Mejeri',
    'Kött & Fisk',
    'Bröd',
    'Skafferi',
    'Fryst',
    'Dryck',
    'Snacks & Godis',
    'Städ & Hygien',
    'Övrigt',
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialItem?.name ?? '');
    _amountController = TextEditingController(
      text: widget.initialItem?.formattedAmount ?? '1',
    );
    _selectedUnit = widget.initialItem?.unit ?? 'st';
    _selectedCategory = widget.initialItem?.category ?? 'Övrigt';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.add_shopping_cart,
            color: AppColors.primaryBlue,
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Text(
            isEditing ? 'Redigera artikel' : 'Lägg till artikel',
            style: AppTextStyles.headlineSmall,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Article name - focus first
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Artikel',
                  labelStyle: AppTextStyles.labelLarge,
                  hintText: 'T.ex. Mjölk',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
                  prefixIcon: const Icon(
                    Icons.shopping_basket,
                    color: AppColors.primaryBlue,
                    size: AppDimensions.iconSizeAction,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: FormValidators.shoppingItemName(),
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Amount and unit on same row - adjusted flex values
              Row(
                children: [
                  // Amount (less space - flex: 1)
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _amountController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Antal',
                        labelStyle: AppTextStyles.labelLarge,
                        hintText: '1',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
                        prefixIcon: const Icon(
                          Icons.numbers,
                          color: AppColors.primaryBlue,
                          size: AppDimensions.iconSizeAction,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: FormValidators.shoppingItemAmount(),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),

                  // Unit - more space for dropdown (flex: 2)
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      style: AppTextStyles.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Enhet',
                        labelStyle: AppTextStyles.labelLarge,
                        prefixIcon: Icon(
                          Icons.straighten,
                          color: AppColors.primaryBlue,
                          size: AppDimensions.iconSizeAction,
                        ),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(AppDimensions.paddingM),
                      ),
                      isDense: true,
                      isExpanded: true,
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['value'],
                          child: Text(
                            unit['dropdown']!,
                            style: AppTextStyles.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          if (mounted) setState(() {
                            _selectedUnit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  labelStyle: AppTextStyles.labelLarge,
                  prefixIcon: Icon(
                    Icons.category,
                    color: AppColors.primaryBlue,
                    size: AppDimensions.iconSizeAction,
                  ),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(AppDimensions.paddingM),
                ),
                isExpanded: true,
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: AppTextStyles.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    if (mounted) setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt', style: AppTextStyles.labelLarge),
        ),
        FilledButton.icon(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.neutralLight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
          ),
          icon: Icon(
            isEditing ? Icons.save : Icons.add,
            size: AppDimensions.iconSizeAction,
          ),
          label: Text(
            isEditing ? 'Spara' : 'Lägg till',
            style: AppTextStyles.labelLarge,
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      final item = UnifiedShoppingItem(
        id: widget.initialItem?.id,
        name: _nameController.text.trim(),
        amount: amount,
        unit: _selectedUnit,
        category: _selectedCategory,
        bought: widget.initialItem?.bought ?? false,
      );

      Navigator.pop(context, item);
    }
  }
}