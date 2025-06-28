// lib/widgets/add_shopping_item_dialog.dart

import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../theme/app_theme.dart';

/// Dialog för att lägga till ny artikel i inköpslistan
class AddShoppingItemDialog extends StatefulWidget {
  final ShoppingItem? initialItem;

  const AddShoppingItemDialog({this.initialItem, super.key});

  @override
  State<AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _unitController;

  late String _selectedCategory;

  // Vanliga kategorier
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

  // Vanliga enheter
  final List<String> _commonUnits = [
    'st',
    'kg',
    'g',
    'l',
    'dl',
    'ml',
    'förp',
    'påse',
    'burk',
    'flaska',
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialItem?.name ?? '');
    _amountController = TextEditingController(
      text: widget.initialItem?.amount.toString() ?? '1',
    );
    _unitController =
        TextEditingController(text: widget.initialItem?.unit ?? '');
    _selectedCategory = widget.initialItem?.category ?? 'Övrigt';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
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
          ),
          SizedBox(width: AppTheme.spacingSm),
          Text(isEditing ? 'Redigera artikel' : 'Lägg till artikel'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Artikelnamn
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Artikel',
                  hintText: 'T.ex. Mjölk',
                  prefixIcon: Icon(Icons.shopping_basket),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ange artikelnamn';
                  }
                  return null;
                },
              ),
              AppTheme.mediumGap,

              // Mängd och enhet
              Row(
                children: [
                  // Mängd
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Mängd',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ange mängd';
                        }
                        final amount = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Ogiltig mängd';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMd),

                  // Enhet
                  Expanded(
                    flex: 3,
                    child: Autocomplete<String>(
                      initialValue:
                          TextEditingValue(text: _unitController.text),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _commonUnits;
                        }
                        return _commonUnits.where((unit) {
                          return unit.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        // Synka controllers
                        controller.addListener(() {
                          _unitController.text = controller.text;
                        });
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Enhet',
                            hintText: 'st, kg, l...',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          onFieldSubmitted: (value) => onFieldSubmitted(),
                        );
                      },
                      onSelected: (selection) {
                        _unitController.text = selection;
                      },
                    ),
                  ),
                ],
              ),
              AppTheme.mediumGap,

              // Kategori
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
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
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _submitForm,
          icon: Icon(isEditing ? Icons.save : Icons.add),
          label: Text(isEditing ? 'Spara' : 'Lägg till'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      final item = ShoppingItem(
        name: _nameController.text.trim(),
        amount: amount,
        unit: _unitController.text.trim(),
        category: _selectedCategory,
        bought: widget.initialItem?.bought ?? false,
      );

      Navigator.pop(context, item);
    }
  }
}
