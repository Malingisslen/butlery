// lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

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

    if (result != null && context.mounted) {
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

        if (context.mounted) {
          if (success) {
            onSuccess(context.l10n.shoppingItemAdded(result.name));
          } else {
            onError(context.l10n.shoppingCouldNotAddItem(result.name));
          }
        }
      } catch (e) {
        if (context.mounted) {
          onError(
            context.l10n.shoppingErrorAdding(
              SnackBarUtils.userFriendlyMessage(context, e),
            ),
          );
        }
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

    if (result != null && context.mounted) {
      try {
        final success = await viewModel.updateItem(
          itemId: item.id,
          name: result.name,
          quantity: result.amount,
          unit: result.unit,
          category: result.category,
          // Every layer under `updateItem` reads a null `notes` as "leave this
          // field alone" (`UnifiedShoppingService.updateItemInActiveList` ->
          // `ShoppingItemManagementModule`, and the personal-list operation
          // beside it), so a cleared note has to travel as an empty string or
          // the old text is written straight back. Readers already treat an
          // empty note as no note — the item tile renders it only on
          // `note?.isNotEmpty == true` — and reopening this dialog shows an
          // empty field either way (BUT-1874).
          notes: result.note.orEmpty(),
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (context.mounted) {
          if (success) {
            onSuccess(context.l10n.shoppingItemUpdated(result.name));
          } else {
            onError(context.l10n.shoppingCouldNotUpdateItem(result.name));
          }
        }
      } catch (e) {
        if (context.mounted) {
          onError(
            context.l10n.shoppingErrorUpdating(
              SnackBarUtils.userFriendlyMessage(context, e),
            ),
          );
        }
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
      title: Text(context.l10n.shoppingAddItem),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: context.l10n.shoppingItemName,
              hint: context.l10n.shoppingItemNameHint,
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
                    label: context.l10n.shoppingAmount,
                    hint: '1',
                    // decimal: true asks the OS for a keyboard that HAS a
                    // separator key; the formatter decides what may land in the
                    // field. Both are needed - a numeric pad without the key
                    // makes the formatter unreachable on a phone, and the
                    // keyboard alone would let "1,5,5" through.
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [SwedishDecimalInputFormatter()],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: context.l10n.shoppingUnit,
                    hint: context.l10n.shoppingUnitHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: context.l10n.shoppingCategory,
              hint: context.l10n.shoppingCategoryHint,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: context.l10n.shoppingNoteOptional,
              hint: context.l10n.shoppingNoteHint,
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.commonAdd,
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      // basic() omits note, so layer it on with copyWith — otherwise the note
      // the user typed is silently dropped on add.
      final item =
          UnifiedShoppingItem.basic(
            name: _nameController.text.trim(),
            amount: parseSwedishDecimal(_amountController.text) ?? 1.0,
            unit: _unitController.text.trim(),
            category: _categoryController.text.trim().isEmpty
                ? ShoppingCategory.other
                : _categoryController.text.trim(),
          ).copyWith(
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    // The field is seeded in the same spelling the formatter enforces while
    // typing, so reopening an edited item does not show a period the user can
    // no longer type.
    _amountController = TextEditingController(
      text: formatSwedishDecimal(widget.item.amount),
    );
    _unitController = TextEditingController(text: widget.item.unit);
    _categoryController = TextEditingController(text: widget.item.category);
    _noteController = TextEditingController(text: widget.item.note.orEmpty());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.shoppingEditItem),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: context.l10n.shoppingItemName,
              hint: context.l10n.shoppingItemNameHint,
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
                    label: context.l10n.shoppingAmount,
                    hint: '1',
                    // decimal: true asks the OS for a keyboard that HAS a
                    // separator key; the formatter decides what may land in the
                    // field. Both are needed - a numeric pad without the key
                    // makes the formatter unreachable on a phone, and the
                    // keyboard alone would let "1,5,5" through.
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [SwedishDecimalInputFormatter()],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: context.l10n.shoppingUnit,
                    hint: context.l10n.shoppingUnitHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: context.l10n.shoppingCategory,
              hint: context.l10n.shoppingCategoryHint,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: context.l10n.shoppingNoteOptional,
              hint: context.l10n.shoppingNoteHint,
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.commonSave,
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final note = _noteController.text.trim();
      final item = widget.item.copyWith(
        name: _nameController.text.trim(),
        amount:
            parseSwedishDecimal(_amountController.text) ?? widget.item.amount,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? ShoppingCategory.other
            : _categoryController.text.trim(),
        note: note.isEmpty ? null : note,
        // A null `note` alone cannot express "the user emptied the field" —
        // copyWith reads it as "leave unchanged", so an erased note came back
        // on the next save. Emptying the field is a real edit and needs its own
        // signal (BUT-1874).
        clearNote: note.isEmpty,
        priority: widget.item.priority,
      );

      Navigator.pop(context, item);
    }
  }
}

/// Category auto-suggestion based on Swedish ingredient names.
///
/// **This is a DUPLICATE, and `IngredientCategorizer` is the source of truth.**
/// That one is the maintained engine (`lib/services/shopping/ingredient_categorizer.dart`,
/// used by `menu_shopping_aggregator.dart` and `shopping_list_generator.dart`).
/// This map is a second, older implementation of the same job, and it still
/// carries defects that were fixed centrally and never ported back. Measured by
/// running this class, not by reading it (BUT-1890, 2026-08-17):
///
///     Rostbiff -> dairy        Ostbågar -> dairy       Kokosmjölk -> dairy
///     Rostat bröd -> dairy     Diskborste -> drinks    Vitlökspulver -> fruit_veg
///
/// FIVE of those six ANSWERS CHANGE when routed centrally; only four become
/// right. `Ostbågar` does NOT change — `IngredientCategorizer` answers `dairy`
/// too, deliberately: its cheese rule is "at least one word boundary", because
/// cheese legitimately LEADS a Swedish compound ("ostskiva"). And
/// `Vitlökspulver` only moves `fruit_veg` -> `veg`; it is a spice in neither
/// engine. So do not read the table as six bugs.
///
/// The cause of the rest is a lowercased unbounded `contains` over ordered
/// buckets, first match wins: `ost` matches inside "r-ost-biff", and the
/// two-letter `te` makes a dish brush a beverage. BUT-1666 replaced exactly that
/// bare `ost` with Swedish-aware lookarounds. BUT-1004 split meat/fish and
/// fruit/veg into the fine-grained `meat`/`fish`/`fruit`/`veg`; the legacy
/// `meatFish`/`fruitVeg` constants survive for stored documents and are still
/// user-selectable, but `IngredientCategorizer` no longer PRODUCES them — while
/// this class still does.
///
/// One trap for whoever routes this (BUT-1890): `IngredientCategorizer.categorize`
/// returns `ShoppingCategory.other` for no match, never null, and `_suggestCategory`
/// relies on null to leave the field alone. A naive delegation stamps `other` into
/// every unrecognised item.
///
/// Do NOT extend the map to patch a case. Route this through
/// `IngredientCategorizer` instead — that is BUT-1890, kept separate because it
/// changes what the user sees. Until then, `category_suggester_test.dart` pins
/// what this DOES, not what it should do.
class _CategorySuggester {
  static const Map<String, List<String>> _categoryKeywords = {
    ShoppingCategory.dairy: [
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
    ShoppingCategory.fruitVeg: [
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
    ShoppingCategory.meatFish: [
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
    ShoppingCategory.breadGrain: [
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
    ShoppingCategory.pantry: [
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
    ShoppingCategory.drinks: [
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
    ShoppingCategory.frozen: [
      'glass',
      'frysta',
      'fryst',
      'frysvaror',
      'fryspizza',
    ],
    ShoppingCategory.snacks: [
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
