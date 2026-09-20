// lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';
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

/// Category auto-suggestion for the item-name field, delegating to the
/// maintained engine in `lib/services/shopping/ingredient_categorizer.dart`
/// (BUT-1890). The same engine builds the shopping list from the weekly menu,
/// so a name categorises identically wherever it is typed.
///
/// `categorize` returns [ShoppingCategory.other] for no match, never null,
/// and the caller relies on null to leave the field alone — so `other` is
/// mapped back to null here rather than stamped into every unknown item.
class _CategorySuggester {
  static String? suggest(String itemName) {
    final category = IngredientCategorizer.categorize(itemName);
    return category == ShoppingCategory.other ? null : category;
  }
}
