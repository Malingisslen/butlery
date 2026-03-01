// lib/widgets/common/input/shopping_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';

/// Dialog for adding/editing unified shopping items
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

  // Units: value is stored in Firestore, dropdown is displayed to user
  List<Map<String, String>> _getUnits(BuildContext context) => [
        {'value': 'st', 'display': 'st', 'dropdown': context.l10n.unitPieces},
        {'value': 'liter', 'display': 'l', 'dropdown': context.l10n.unitLiter},
        {'value': 'dl', 'display': 'dl', 'dropdown': 'dl'},
        {
          'value': 'msk',
          'display': 'msk',
          'dropdown': context.l10n.unitTablespoon
        },
        {'value': 'krm', 'display': 'krm', 'dropdown': context.l10n.unitPinch},
        {'value': 'ml', 'display': 'ml', 'dropdown': 'ml'},
        {'value': 'cl', 'display': 'cl', 'dropdown': 'cl'},
        {'value': 'g', 'display': 'g', 'dropdown': 'g'},
        {'value': 'kg', 'display': 'kg', 'dropdown': 'kg'},
        {
          'value': 'förpackning',
          'display': context.l10n.unitPackageShort,
          'dropdown': context.l10n.unitPackage
        },
        {
          'value': 'tsk',
          'display': 'tsk',
          'dropdown': context.l10n.unitTeaspoon
        },
        {
          'value': 'påse',
          'display': context.l10n.unitBag,
          'dropdown': context.l10n.unitBag
        },
        {
          'value': 'burk',
          'display': context.l10n.unitCan,
          'dropdown': context.l10n.unitCan
        },
        {
          'value': 'flaska',
          'display': context.l10n.unitBottle,
          'dropdown': context.l10n.unitBottle
        },
        {
          'value': 'bit',
          'display': context.l10n.unitPiece,
          'dropdown': context.l10n.unitPiece
        },
        {
          'value': 'klyfta',
          'display': context.l10n.unitClove,
          'dropdown': context.l10n.unitClove
        },
      ];

  // Category values stored in Firestore (language-neutral constants) → localized display labels
  static const List<String> _categoryValues = [
    ShoppingCategory.fruitVeg,
    ShoppingCategory.dairy,
    ShoppingCategory.meatFish,
    ShoppingCategory.breadGrain,
    ShoppingCategory.pantry,
    ShoppingCategory.frozen,
    ShoppingCategory.drinks,
    ShoppingCategory.snacks,
    ShoppingCategory.cleaning,
    ShoppingCategory.spices,
    ShoppingCategory.canned,
    ShoppingCategory.dryGoods,
    ShoppingCategory.other,
  ];

  String _categoryLabel(BuildContext context, String value) {
    switch (value) {
      case ShoppingCategory.fruitVeg:
        return context.l10n.categoryFruitVeg;
      case ShoppingCategory.dairy:
        return context.l10n.categoryDairy;
      case ShoppingCategory.meatFish:
        return context.l10n.categoryMeatFish;
      case ShoppingCategory.breadGrain:
        return context.l10n.categoryBread;
      case ShoppingCategory.pantry:
        return context.l10n.categoryPantry;
      case ShoppingCategory.frozen:
        return context.l10n.categoryFrozen;
      case ShoppingCategory.drinks:
        return context.l10n.categoryBeverage;
      case ShoppingCategory.snacks:
        return context.l10n.categorySnacks;
      case ShoppingCategory.cleaning:
        return context.l10n.categoryHygiene;
      case ShoppingCategory.spices:
        return context.l10n.categorySpices;
      case ShoppingCategory.canned:
        return context.l10n.categoryCanned;
      case ShoppingCategory.dryGoods:
        return context.l10n.categoryDryGoods;
      case ShoppingCategory.other:
        return context.l10n.categoryOther;
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialItem?.name ?? '');
    _amountController = TextEditingController(
      text: widget.initialItem?.formattedAmount ?? '1',
    );
    _selectedUnit = widget.initialItem?.unit ?? 'st';
    _selectedCategory = widget.initialItem?.category ?? ShoppingCategory.other;
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
            color: Theme.of(context).colorScheme.primary,
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Text(
            isEditing
                ? context.l10n.shoppingEditItem
                : context.l10n.shoppingAddItem,
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
              StyledInput(
                controller: _nameController,
                autofocus: true,
                label: context.l10n.shoppingItemName,
                hint: context.l10n.shoppingItemHint,
                prefixIcon: Icon(
                  Icons.shopping_basket,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppDimensions.iconSizeAction,
                ),
                validator: FormValidators.shoppingItemName(),
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Amount and unit on same row - adjusted flex values
              Row(
                children: [
                  // Amount (less space - flex: 1)
                  Expanded(
                    flex: 1,
                    child: StyledInput(
                      controller: _amountController,
                      label: context.l10n.shoppingAmount,
                      hint: '1',
                      prefixIcon: Icon(
                        Icons.numbers,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppDimensions.iconSizeAction,
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
                      initialValue: _selectedUnit,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: context.l10n.shoppingUnit,
                        labelStyle: AppTextStyles.labelLarge,
                        prefixIcon: Icon(
                          Icons.straighten,
                          color: Theme.of(context).colorScheme.primary,
                          size: AppDimensions.iconSizeAction,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding:
                            const EdgeInsets.all(AppDimensions.paddingM),
                      ),
                      isDense: true,
                      isExpanded: true,
                      items: _getUnits(context).map((unit) {
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
                          if (mounted) {
                            setState(() {
                              _selectedUnit = value;
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: context.l10n.shoppingCategory,
                  labelStyle: AppTextStyles.labelLarge,
                  prefixIcon: Icon(
                    Icons.category,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppDimensions.iconSizeAction,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
                ),
                isExpanded: true,
                items: _categoryValues.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      _categoryLabel(context, category),
                      style: AppTextStyles.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    if (mounted) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        StyledButton.secondary(
          text: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        StyledButton.primary(
          text: isEditing ? context.l10n.commonSave : context.l10n.commonAdd,
          icon: Icon(isEditing ? Icons.save : Icons.add),
          onPressed: _submitForm,
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(
        _amountController.text.replaceAll(',', '.'),
      ) ?? 1.0;

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
