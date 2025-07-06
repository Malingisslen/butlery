// lib/widgets/add_shopping_item_dialog.dart
// ✅ 100% AppTheme migrerad - ANVÄNDER ENDAST BEFINTLIGA APPTHEME PROPERTIES
// 🔧 KOMPLETT FIL med alla metoder och korrekt syntax

import 'package:flutter/material.dart';
import '../models/unified/unified_shopping_item.dart';
import '../theme/app_theme.dart';

/// ✅ FÖRBÄTTRAD: Dialog för att lägga till ny artikel med korrekt enhetshantering
/// 🔧 FIXAD: Layout overflow-problem + 100% AppTheme migration med befintliga properties
class AddUnifiedShoppingItemDialog extends StatefulWidget {
  final UnifiedShoppingItem? initialItem;

  const AddUnifiedShoppingItemDialog({this.initialItem, super.key});

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

  // ✅ DIN SPECIFIKATION: Enheter med korrekt dropdown-text och visningstext
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

  // ✅ SORTERADE KATEGORIER för bättre gruppering
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
          AppTheme.actionIcon(
            context,
            isEditing ? Icons.edit : Icons.add_shopping_cart,
            color: AppTheme.primaryColor,
          ),
          AppTheme.smallHorizontalGap,
          Text(
            isEditing ? 'Redigera artikel' : 'Lägg till artikel',
            style: AppTheme
                .sectionTitleStyle, // ✅ Använder befintlig sectionTitleStyle
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
              // ✅ ARTIKELNAMN - fokus först
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: AppTheme.bodyStyle, // ✅ Använder befintlig bodyStyle
                decoration: InputDecoration(
                  labelText: 'Artikel',
                  labelStyle: AppTheme
                      .formLabelStyle, // ✅ Använder befintlig formLabelStyle
                  hintText: 'T.ex. Mjölk',
                  hintStyle: AppTheme
                      .inputHintStyle, // ✅ Använder befintlig inputHintStyle
                  prefixIcon: AppTheme.actionIcon(
                    context,
                    Icons.shopping_basket,
                    color: AppTheme.primaryColor,
                  ),
                  border: const OutlineInputBorder(), // ✅ Hårdkodad border
                  contentPadding: AppTheme.inputPadding,
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

              // 🔧 FIXAD: ANTAL och ENHET på samma rad - justerade flex-värden
              Row(
                children: [
                  // Antal (mindre utrymme - flex: 1)
                  Expanded(
                    flex: 1, // 🔧 Optimerad flex-fördelning
                    child: TextFormField(
                      controller: _amountController,
                      style:
                          AppTheme.bodyStyle, // ✅ Använder befintlig bodyStyle
                      decoration: InputDecoration(
                        labelText: 'Antal',
                        labelStyle: AppTheme
                            .formLabelStyle, // ✅ Använder befintlig formLabelStyle
                        hintText: '1',
                        hintStyle: AppTheme
                            .inputHintStyle, // ✅ Använder befintlig inputHintStyle
                        prefixIcon: AppTheme.actionIcon(
                          context,
                          Icons.numbers,
                          color: AppTheme.primaryColor,
                        ),
                        border:
                            const OutlineInputBorder(), // ✅ Hårdkodad border
                        contentPadding: AppTheme.inputPadding,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ange antal';
                        }
                        final amount = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Ogiltigt antal';
                        }
                        return null;
                      },
                    ),
                  ),
                  AppTheme.smallHorizontalGap,

                  // 🔧 FIXAD: ENHET - mer utrymme för dropdown (flex: 2)
                  Expanded(
                    flex: 2, // 🔧 Optimerad flex-fördelning för bättre balans
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      style:
                          AppTheme.bodyStyle, // ✅ Använder befintlig bodyStyle
                      decoration: InputDecoration(
                        labelText: 'Enhet',
                        labelStyle: AppTheme
                            .formLabelStyle, // ✅ Använder befintlig formLabelStyle
                        prefixIcon: AppTheme.actionIcon(
                          context,
                          Icons.straighten,
                          color: AppTheme.primaryColor,
                        ),
                        border:
                            const OutlineInputBorder(), // ✅ Hårdkodad border
                        contentPadding: AppTheme.inputPadding,
                      ),
                      // 🔧 Optimerade dropdown-inställningar
                      isDense: true,
                      isExpanded: true,
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['value'],
                          child: Text(
                            unit['dropdown']!, // Visa "liter" i dropdown
                            style: AppTheme
                                .bodyStyle, // ✅ Använder befintlig bodyStyle
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              AppTheme.mediumGap,

              // ✅ KATEGORI - dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: AppTheme.bodyStyle, // ✅ Använder befintlig bodyStyle
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  labelStyle: AppTheme
                      .formLabelStyle, // ✅ Använder befintlig formLabelStyle
                  prefixIcon: AppTheme.actionIcon(
                    context,
                    Icons.category,
                    color: AppTheme.primaryColor,
                  ),
                  border: const OutlineInputBorder(), // ✅ Hårdkodad border
                  contentPadding: AppTheme.inputPadding,
                ),
                isExpanded: true,
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style:
                          AppTheme.bodyStyle, // ✅ Använder befintlig bodyStyle
                      overflow: TextOverflow.ellipsis,
                    ),
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
          child: Text('Avbryt',
              style: AppTheme
                  .buttonTextStyle), // ✅ Använder befintlig buttonTextStyle
        ),
        FilledButton.icon(
          onPressed: _submitForm,
          style: AppTheme.primaryButtonStyle,
          icon: AppTheme.actionIcon(
            context,
            isEditing ? Icons.save : Icons.add,
          ),
          label: Text(
            isEditing ? 'Spara' : 'Lägg till',
            style: AppTheme
                .buttonTextStyle, // ✅ Använder befintlig buttonTextStyle
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
        id: widget.initialItem?.id, // Behåll ID vid redigering
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
