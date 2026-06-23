/// Bottom sheet used to add a new pantry item or edit an existing one.
/// Drives the ingredient autocomplete via [PantryViewModel.searchIngredient].
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

class AddPantryItemSheet extends StatefulWidget {
  const AddPantryItemSheet({super.key, this.existingItem});

  final PantryItem? existingItem;

  @override
  State<AddPantryItemSheet> createState() => _AddPantryItemSheetState();
}

class _AddPantryItemSheetState extends State<AddPantryItemSheet> {
  static const _units = ['st', 'g', 'kg', 'ml', 'dl', 'l', 'tsk', 'msk'];

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  String _unit = 'st';
  PantryLocation _location = PantryLocation.pantry;
  DateTime? _expiryDate;
  IngredientData? _selectedIngredient;
  bool _showSuggestions = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    if (existing != null) {
      _nameController.text = existing.ingredientName;
      _quantityController.text = existing.formattedQuantity;
      _unit = _units.contains(existing.unit) ? existing.unit : 'st';
      _location = existing.location;
      _expiryDate = existing.expiryDate;
      _noteController.text = existing.note.orEmpty();
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<PantryViewModel>().searchIngredient(query);
    setState(() {
      _showSuggestions = query.trim().isNotEmpty;
      _selectedIngredient = null;
    });
  }

  void _onSuggestionTap(IngredientData ingredient) {
    setState(() {
      _selectedIngredient = ingredient;
      _nameController.text = ingredient.swedish;
      _showSuggestions = false;
      _location = PantryLocation.fromTypicalStorage(ingredient.typicalStorage);
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickExpiryDate() async {
    final now = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final quantity =
        double.tryParse(
          _quantityController.text.replaceAll(',', '.'),
        ) ??
        1.0;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final viewModel = context.read<PantryViewModel>();
    final navigator = Navigator.of(context);

    if (_isEditing) {
      final updated = widget.existingItem!.copyWith(
        ingredientName: name,
        quantity: quantity,
        unit: _unit,
        location: _location,
        expiryDate: _expiryDate,
        note: note,
        clearExpiryDate: _expiryDate == null,
        clearNote: note == null,
      );
      await viewModel.updateItem(updated);
    } else if (_selectedIngredient != null) {
      await viewModel.addItemFromIngredient(
        _selectedIngredient!,
        quantity: quantity,
        unit: _unit,
        location: _location,
        expiryDate: _expiryDate,
        note: note,
      );
    } else {
      await viewModel.addItemFromText(
        name,
        quantity: quantity,
        unit: _unit,
        location: _location,
        expiryDate: _expiryDate,
        note: note,
      );
    }

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PantryViewModel>();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingMd,
          AppDimensions.spacingLg,
          AppDimensions.spacingXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                color: cs.outlineVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              _isEditing ? l10n.pantryEditSheetTitle : l10n.pantryAddSheetTitle,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            TextField(
              controller: _nameController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: l10n.pantryIngredientLabel,
                hintText: l10n.pantryIngredientHint,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            if (_showSuggestions && viewModel.searchResults.isNotEmpty)
              IngredientSuggestionList(
                results: viewModel.searchResults,
                onTap: _onSuggestionTap,
              ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.pantryQuantityLabel,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: InputDecoration(
                      labelText: l10n.pantryUnitLabel,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    items: [
                      for (final unit in _units)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _unit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            DropdownButtonFormField<PantryLocation>(
              initialValue: _location,
              decoration: InputDecoration(
                labelText: l10n.pantryLocationLabel,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: PantryLocation.fridge,
                  child: Text(l10n.pantryLocationFridge),
                ),
                DropdownMenuItem(
                  value: PantryLocation.freezer,
                  child: Text(l10n.pantryLocationFreezer),
                ),
                DropdownMenuItem(
                  value: PantryLocation.pantry,
                  child: Text(l10n.pantryLocationPantry),
                ),
                DropdownMenuItem(
                  value: PantryLocation.spiceRack,
                  child: Text(l10n.pantryLocationSpiceRack),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _location = value);
              },
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Semantics(
              label: l10n.a11yPantryPickExpiry,
              button: true,
              child: InkWell(
                onTap: _pickExpiryDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.pantryExpiryLabel,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    suffixIcon: _expiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expiryDate = null),
                          )
                        : const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _expiryDate == null
                        ? l10n.pantryExpiryNone
                        : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.pantryNoteLabel,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            ActionButtons.primaryButton(
              context,
              label: _isEditing ? l10n.commonSave : l10n.pantryAddAction,
              onPressed: _submit,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            ActionButtons.secondaryButton(
              context,
              label: l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
