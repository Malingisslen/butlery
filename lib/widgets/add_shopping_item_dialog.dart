// lib/widgets/add_shopping_item_dialog.dart

import 'package:flutter/material.dart';
import '../models/unified/unified_shopping_item.dart';
import '../theme/app_theme.dart';

/// ✅ FÖRBÄTTRAD: Dialog för att lägga till ny artikel med korrekt enhetshantering
/// 🔧 FIXAD: Layout overflow-problem på rad 180 genom bättre flex-fördelning
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
          Icon(
            isEditing ? Icons.edit : Icons.add_shopping_cart,
            color: AppTheme.primaryColor,
            size: AppTheme.iconSizeAction,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Text(
            isEditing ? 'Redigera artikel' : 'Lägg till artikel',
            style: AppTheme.cardTitleStyle,
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
                style: AppTheme.bodyStyle,
                decoration: InputDecoration(
                  labelText: 'Artikel',
                  labelStyle: AppTheme.formLabelStyle,
                  hintText: 'T.ex. Mjölk',
                  hintStyle: AppTheme.inputHintStyle,
                  prefixIcon: Icon(
                    Icons.shopping_basket,
                    color: AppTheme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                  ),
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
                    flex:
                        1, // 🔧 ÄNDRAT: från 2 till 1 för att ge dropdown mer plats
                    child: TextFormField(
                      controller: _amountController,
                      style: AppTheme.bodyStyle,
                      decoration: InputDecoration(
                        labelText: 'Antal',
                        labelStyle: AppTheme.formLabelStyle,
                        hintText: '1',
                        hintStyle: AppTheme.inputHintStyle,
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: AppTheme.primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                        ),
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
                  SizedBox(width: AppTheme.spacingSm),

                  // 🔧 FIXAD: ENHET - mer utrymme för dropdown (flex: 2)
                  Expanded(
                    flex: 2, // 🔧 ÄNDRAT: från 3 till 2, ger bättre balans
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      style: AppTheme.bodyStyle,
                      decoration: InputDecoration(
                        labelText: 'Enhet',
                        labelStyle: AppTheme.formLabelStyle,
                        prefixIcon: Icon(
                          Icons.straighten,
                          color: AppTheme.primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                        ),
                        contentPadding: AppTheme.inputPadding,
                      ),
                      // 🔧 TILLAGT: Gör dropdown mer kompakt
                      isDense: true,
                      isExpanded:
                          true, // 🔧 VIKTIGT: Ser till att dropdown tar hela tillgängliga bredden
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['value'],
                          child: Text(
                            unit['dropdown']!, // Visa "liter" i dropdown
                            style: AppTheme.bodyStyle,
                            overflow: TextOverflow
                                .ellipsis, // 🔧 TILLAGT: Förhindra text-overflow
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
                style: AppTheme.bodyStyle,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  labelStyle: AppTheme.formLabelStyle,
                  prefixIcon: Icon(
                    Icons.category,
                    color: AppTheme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  contentPadding: AppTheme.inputPadding,
                ),
                isExpanded:
                    true, // 🔧 TILLAGT: För att förhindra overflow även här
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: AppTheme.bodyStyle,
                      overflow:
                          TextOverflow.ellipsis, // 🔧 TILLAGT: Säkerhetsåtgärd
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
          style: AppTheme.secondaryButtonStyle,
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _submitForm,
          style: AppTheme.primaryButtonStyle,
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
