// lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';

/// Shopping item dialogs for adding and editing items
class ShoppingItemDialogs {
  static Future<void> showAddItemDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _AddItemDialog(viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.addItemToActiveList(
          name: result.name,
          amount: result.amount,
          unit: result.unit,
          category: result.category,
          note: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} tillagd!');
        } else {
          onError('Kunde inte lägga till ${result.name}');
        }
      } catch (e) {
        onError('Fel vid tillägg: $e');
      }
    }
  }

  static Future<void> showEditItemDialog(
    BuildContext context,
    UnifiedShoppingItem item,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _EditItemDialog(item: item, viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.updateItem(
          itemId: item.id,
          name: result.name,
          quantity: result.amount,
          unit: result.unit,
          category: result.category,
          notes: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} uppdaterad!');
        } else {
          onError('Kunde inte uppdatera ${result.name}');
        }
      } catch (e) {
        onError('Fel vid uppdatering: $e');
      }
    }
  }
}

class _AddItemDialog extends StatefulWidget {
  final UnifiedShoppingViewModel viewModel;

  const _AddItemDialog({required this.viewModel});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _priceController = TextEditingController();

  // UI Redesign: Track if user has manually edited category
  bool _categoryManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    // UI Redesign: Auto-suggest category based on item name
    _nameController.addListener(_suggestCategory);
    _categoryController.addListener(_onCategoryManualEdit);
  }

  @override
  void dispose() {
    _nameController.removeListener(_suggestCategory);
    _categoryController.removeListener(_onCategoryManualEdit);
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// UI Redesign: Track when user manually edits category to avoid overwriting
  void _onCategoryManualEdit() {
    if (_categoryController.text.isNotEmpty) {
      _categoryManuallyEdited = true;
    }
  }

  /// UI Redesign: Suggest category based on item name (Swedish ingredients)
  void _suggestCategory() {
    if (_categoryManuallyEdited) return;

    final name = _nameController.text.toLowerCase().trim();
    if (name.isEmpty) return;

    final suggestedCategory = _CategorySuggester.suggest(name);
    if (suggestedCategory != null &&
        _categoryController.text != suggestedCategory) {
      _categoryManuallyEdited = false; // Reset flag for auto-suggestion
      _categoryController.text = suggestedCategory;
      _categoryManuallyEdited = false; // Reset again after setting
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lägg till vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: 'Varunamn',
              hint: 'T.ex. Mjölk',
              validator: (value) =>
                  ValidationUtils.validateShoppingItemName(value),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: StyledInput(
                    controller: _amountController,
                    label: 'Mängd',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: 'Enhet',
                    hint: 'st, liter, kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: 'Kategori',
              hint: 'T.ex. Mejeri',
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: 'Anteckning (valfritt)',
              hint: 'T.ex. Laktosfri',
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: 'Avbryt',
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: 'Lägg till',
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = UnifiedShoppingItem.basic(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 1.0,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
      );

      Navigator.pop(context, item);
    }
  }
}

class _EditItemDialog extends StatefulWidget {
  final UnifiedShoppingItem item;
  final UnifiedShoppingViewModel viewModel;

  const _EditItemDialog({required this.item, required this.viewModel});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController =
        TextEditingController(text: widget.item.amount.toString());
    _unitController = TextEditingController(text: widget.item.unit);
    _categoryController = TextEditingController(text: widget.item.category);
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _priceController = TextEditingController(
        text: widget.item.estimatedPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redigera vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: 'Varunamn',
              hint: 'T.ex. Mjölk',
              validator: (value) =>
                  ValidationUtils.validateShoppingItemName(value),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: StyledInput(
                    controller: _amountController,
                    label: 'Mängd',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: 'Enhet',
                    hint: 'st, liter, kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: 'Kategori',
              hint: 'T.ex. Mejeri',
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: 'Anteckning (valfritt)',
              hint: 'T.ex. Laktosfri',
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: 'Avbryt',
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: 'Spara',
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = widget.item.copyWith(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? widget.item.amount,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        estimatedPrice: _priceController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceController.text),
        priority: widget.item.priority,
      );

      Navigator.pop(context, item);
    }
  }
}

/// UI Redesign: Category auto-suggestion based on Swedish ingredient names
class _CategorySuggester {
  static const Map<String, List<String>> _categoryKeywords = {
    'Mejeri': [
      'mjölk',
      'grädde',
      'ost',
      'smör',
      'yoghurt',
      'fil',
      'crème fraiche',
      'kvarg',
      'keso',
      'parmesan',
      'mozzarella',
      'cheddar',
      'brie',
      'cream cheese',
      'ricotta',
      'mascarpone',
      'feta',
    ],
    'Frukt & Grönt': [
      'äpple',
      'banan',
      'apelsin',
      'citron',
      'lime',
      'tomat',
      'gurka',
      'paprika',
      'lök',
      'vitlök',
      'morot',
      'potatis',
      'sallad',
      'spenat',
      'broccoli',
      'blomkål',
      'zucchini',
      'aubergine',
      'avokado',
      'mango',
      'ananas',
      'druvor',
      'jordgubbar',
      'blåbär',
      'hallon',
      'päron',
      'persika',
      'plommon',
      'kiwi',
      'champinjon',
      'svamp',
      'selleri',
      'purjolök',
      'rödbetor',
      'kål',
      'vitkål',
      'rödkål',
    ],
    'Kött & Fisk': [
      'kyckling',
      'nötkött',
      'fläsk',
      'lamm',
      'fisk',
      'lax',
      'torsk',
      'räkor',
      'bacon',
      'korv',
      'köttfärs',
      'biff',
      'entrecote',
      'filé',
      'kotlett',
      'skinka',
      'kalkon',
      'anka',
      'tonfisk',
      'sill',
      'makrill',
      'musslor',
      'krabba',
      'hummer',
    ],
    'Bröd & Bakverk': [
      'bröd',
      'limpa',
      'fralla',
      'bulle',
      'croissant',
      'bagel',
      'knäckebröd',
      'tortilla',
      'pitabröd',
      'hamburger',
      'korvbröd',
    ],
    'Skafferi': [
      'ris',
      'pasta',
      'spaghetti',
      'nudlar',
      'mjöl',
      'socker',
      'salt',
      'peppar',
      'olja',
      'olivolja',
      'vinäger',
      'soja',
      'ketchup',
      'senap',
      'majonnäs',
      'honung',
      'sylt',
      'müsli',
      'flingor',
      'havregryn',
      'linser',
      'bönor',
      'kikärtor',
      'kokosmjölk',
      'tomatpuré',
      'krossade tomater',
      'buljong',
      'fond',
    ],
    'Drycker': [
      'juice',
      'läsk',
      'vatten',
      'mineralvatten',
      'kaffe',
      'te',
      'öl',
      'vin',
      'cider',
      'smoothie',
    ],
    'Fryst': [
      'glass',
      'frysta',
      'fryst',
      'frysvaror',
      'fryspizza',
    ],
    'Snacks': [
      'chips',
      'nötter',
      'popcorn',
      'godis',
      'choklad',
      'kex',
      'kakor',
    ],
  };

  /// Suggest a category based on the item name
  static String? suggest(String itemName) {
    final lowerName = itemName.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerName.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }
}
