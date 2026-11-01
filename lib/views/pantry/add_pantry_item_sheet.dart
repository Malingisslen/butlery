/// Bottom sheet used to add a new pantry item or edit an existing one.
/// Drives the ingredient autocomplete via [PantryViewModel.searchIngredient].
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/butlery_switch.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_previous_version_row.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

class AddPantryItemSheet extends StatefulWidget {
  const AddPantryItemSheet({super.key, this.existingItem});

  final PantryItem? existingItem;

  static const stapleSwitchKey = ValueKey('pantry-staple-switch');

  /// The units this sheet offers, in display order.
  static const List<String> offeredUnits = [
    'st',
    'g',
    'kg',
    'ml',
    'dl',
    'l',
    'tsk',
    'msk',
  ];

  /// BUT-1858: the dropdown's item list for an item stored with [storedUnit].
  ///
  /// A stored unit the app does not offer is PREPENDED and stays selectable
  /// rather than being clamped away. `DropdownButtonFormField` asserts on every
  /// build that exactly one item matches its value, so with a FIXED item list
  /// clamping to 'st' was the only way to keep the control both up and
  /// populated (selecting nothing also satisfies the assert — that is what the
  /// empty case below does — but shows a blank box) — and it leaked into storage,
  /// because `_submit` writes the selection unconditionally. Widening the list
  /// per item keeps the screen up *and* keeps the value. Same seam as
  /// `RecipeFormState.mealTypeOptions`, for the same bug class; do not
  /// harmonise the two.
  ///
  /// An empty stored unit selects nothing rather than inventing one: it matches
  /// no item by design, and `PantryItem.copyWith(unit: null)` then preserves the
  /// stored value. Empty is a real stored unit — an amount-less recipe line
  /// yields it, and the shopping-checkoff flow stores it verbatim.
  ///
  /// The vocabulary is deliberately NOT replaced by `UnitDefinitions`'
  /// `standaloneUnits`. That set exists to RECOGNISE what a parser may find in
  /// a recipe — it holds 'pers', 'personer', 'gallons', 'tablespoons' — and a
  /// set you must recognise is not a set you should offer. Malin's call,
  /// 2026-08-15 — recorded in `.claude/rules/accepted-deviations-pantry.md` so it is
  /// checkable, and so nobody proposes the widening again.
  static ({List<String> values, String? selected}) unitOptions(
    String storedUnit,
  ) => (
    values: [
      if (storedUnit.isNotEmpty && !offeredUnits.contains(storedUnit))
        storedUnit,
      ...offeredUnits,
    ],
    selected: storedUnit.isEmpty ? null : storedUnit,
  );

  @override
  State<AddPantryItemSheet> createState() => _AddPantryItemSheetState();
}

class _AddPantryItemSheetState extends State<AddPantryItemSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final _expiryController = TextEditingController();

  // Null means "no unit selected", which only an item stored with an empty
  // unit can produce. `copyWith(unit: null)` then preserves what is stored.
  String? _unit = 'st';
  PantryLocation _location = PantryLocation.pantry;
  DateTime? _expiryDate;
  IngredientData? _selectedIngredient;
  bool _showSuggestions = false;

  /// "Finns alltid hemma": a staple needs neither an amount nor a date, so
  /// those fields are hidden.
  bool _isStaple = false;

  /// The last save failed; the sheet shows the error line (P5-U14).
  bool _saveFailed = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    if (existing != null) {
      _nameController.text = existing.ingredientName;
      _quantityController.text = existing.formattedQuantity;
      // BUT-1858: a non-empty stored unit is taken as-is, on or off the
      // offered list; an empty one selects nothing (see `unitOptions`).
      // `AddPantryItemSheet.unitOptions` widens the dropdown to include it, so
      // `DropdownButtonFormField`'s one-match assert is satisfied without the
      // clamp to 'st' this line used to perform — a clamp that leaked into
      // storage, because `_submit` writes the selection unconditionally.
      //
      // Off-list units get here through a shipped path. The shopping-checkoff
      // flow (`ShoppingCheckoffPantryService.onItemCheckedOff` ->
      // `PantryService.addFromShoppingItem` -> `addFromText`) stores the
      // shopping item's unit verbatim — `UnifiedShoppingItem.unit` is a
      // non-nullable free-text String, so neither fallback on the way down
      // fires (`addFromText`'s `match?.typicalUnit`, `_buildItem`'s 'st') —
      // and that text comes from a free-text field in
      // `lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart`
      // (plural; the singular `common/input/shopping_item_dialog.dart` was
      // deleted by BUT-1849) or from parsed recipe units ('förp', 'påse',
      // 'krm', ''). It sits behind the `autoAddBoughtToPantry` opt-in, off by
      // default but shipped.
      //
      // That flow also dedups on name + unit, which is why the old clamp cost
      // more than the label: a 'förp' row rewritten to 'st' stopped matching
      // the next checkoff and produced a duplicate row instead of aggregating.
      _unit = AddPantryItemSheet.unitOptions(existing.unit).selected;
      _location = existing.location;
      _expiryDate = existing.expiryDate;
      _noteController.text = existing.note.orEmpty();
      _isStaple = existing.isStaple;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncExpiryText();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    _expiryController.dispose();
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
      switchToInputEntryModeIcon: const ButleryIcon(ButleryIcons.pencil),
      switchToCalendarEntryModeIcon: const ButleryIcon(ButleryIcons.calendar),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
      _syncExpiryText();
    }
  }

  // The field only shows the date; the date itself lives in _expiryDate.
  void _syncExpiryText() {
    _expiryController.text = _expiryDate == null
        ? ''
        : DateFormat.yMMMMd(context.l10n.localeName).format(_expiryDate!);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_saveFailed) setState(() => _saveFailed = false);

    // An empty or unreadable field is never turned into an amount: on edit it
    // keeps what the item had, otherwise it means "har hemma" without one.
    final existing = widget.existingItem;
    final quantity = _isStaple
        ? null
        : parseSwedishDecimal(_quantityController.text) ?? existing?.quantity;
    final expiryDate = _isStaple ? null : _expiryDate;
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
        expiryDate: expiryDate,
        note: note,
        isStaple: _isStaple,
        clearQuantity: quantity == null,
        clearExpiryDate: expiryDate == null,
        clearNote: note == null,
      );
      await viewModel.updateItem(updated);
    } else if (_selectedIngredient != null) {
      await viewModel.addItemFromIngredient(
        _selectedIngredient!,
        quantity: quantity,
        unit: _unit,
        location: _location,
        expiryDate: expiryDate,
        note: note,
        isStaple: _isStaple,
      );
    } else {
      await viewModel.addItemFromText(
        name,
        quantity: quantity,
        unit: _unit,
        location: _location,
        expiryDate: expiryDate,
        note: note,
        isStaple: _isStaple,
      );
    }

    if (!mounted) return;
    // The VM swallows save failures into `hasError` (offline / Firestore
    // write error). Don't dismiss on failure — that silently loses the item;
    // keep the sheet open with feedback so the user can retry.
    //
    // P5-U14: the three-part failure (content-style-guide.md:87-97): the
    // item was not saved, what was typed is still in the sheet, and Försök
    // igen saves again. Interpretation: it is a line in the sheet, not a
    // snackbar. A snackbar belongs to the view under this modal sheet, so it
    // would sit behind the sheet and its scrim, and Försök igen could not be
    // pressed.
    if (viewModel.hasError) {
      setState(() => _saveFailed = true);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PantryViewModel>();
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final unitValues = AddPantryItemSheet.unitOptions(
      (widget.existingItem?.unit).orEmpty(),
    ).values;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space16,
          AppDimensions.space24,
          AppDimensions.space32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? l10n.pantryEditSheetTitle : l10n.pantryAddSheetTitle,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            if (widget.existingItem case final existing?)
              PantryPreviousVersionRow(item: existing),
            StyledInput(
              label: l10n.pantryIngredientLabel,
              hint: l10n.pantryIngredientHint,
              controller: _nameController,
              onChanged: _onSearchChanged,
            ),
            if (_showSuggestions && viewModel.searchResults.isNotEmpty)
              IngredientSuggestionList(
                results: viewModel.searchResults,
                onTap: _onSuggestionTap,
              ),
            const SizedBox(height: AppDimensions.space16),
            _StapleRow(
              value: _isStaple,
              onChanged: (v) => setState(() => _isStaple = v),
            ),
            if (!_isStaple) ...[
              const SizedBox(height: AppDimensions.space24),
              Row(
                children: [
                  Expanded(
                    child: StyledInput(
                      label: l10n.pantryQuantityLabel,
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [SwedishDecimalInputFormatter()],
                      // Empty with "1" as a hint, never a prefilled "1": the
                      // cursor landed after it, so typing 6 gave 16 (BUT-2261).
                      hint: _isEditing ? null : '1',
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: LabeledField(
                      label: l10n.pantryUnitLabel,
                      child: ButleryDropdown<String>(
                        semanticLabel: l10n.pantryUnitLabel,
                        value: _unit,
                        // Derived from the STORED unit, not from `_unit`, so an
                        // off-list row stays on offer after the user picks
                        // something else and can be picked back.
                        options: [
                          for (final unit in unitValues)
                            ButleryDropdownOption(value: unit, label: unit),
                        ],
                        onChanged: (value) => setState(() => _unit = value),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.space24),
            LabeledField(
              label: l10n.pantryLocationLabel,
              child: ButleryDropdown<PantryLocation>(
                semanticLabel: l10n.pantryLocationLabel,
                value: _location,
                options: [
                  ButleryDropdownOption(
                    value: PantryLocation.fridge,
                    label: l10n.pantryLocationFridge,
                  ),
                  ButleryDropdownOption(
                    value: PantryLocation.freezer,
                    label: l10n.pantryLocationFreezer,
                  ),
                  ButleryDropdownOption(
                    value: PantryLocation.pantry,
                    label: l10n.pantryLocationPantry,
                  ),
                  ButleryDropdownOption(
                    value: PantryLocation.spiceRack,
                    label: l10n.pantryLocationSpiceRack,
                  ),
                ],
                onChanged: (value) => setState(() => _location = value),
              ),
            ),
            if (!_isStaple) ...[
              const SizedBox(height: AppDimensions.space24),
              Semantics(
                label: l10n.a11yPantryPickExpiry,
                button: true,
                onTap: _pickExpiryDate,
                child: StyledInput(
                  label: l10n.pantryExpiryLabel,
                  hint: l10n.pantryExpiryNone,
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _pickExpiryDate,
                  suffixIcon: _expiryDate != null
                      ? AppIconButton(
                          icon: ButleryIcons.x,
                          semanticLabel: l10n.commonClear,
                          onPressed: () {
                            setState(() => _expiryDate = null);
                            _syncExpiryText();
                          },
                        )
                      : const ButleryIcon(ButleryIcons.calendar),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space24),
            StyledInput(
              label: l10n.pantryNoteLabel,
              controller: _noteController,
            ),
            if (_saveFailed) ...[
              const SizedBox(height: AppDimensions.space24),
              InlineError(
                what: l10n.pantryCouldNotSaveItem,
                preserved: l10n.errorPreservedForm,
                actionLabel: l10n.commonRetry,
                onAction: _submit,
              ),
            ],
            const SizedBox(height: AppDimensions.space32),
            ActionButtons.primaryButton(
              context,
              label: _isEditing ? l10n.commonSave : l10n.pantryAddAction,
              // Disable + show progress while saving: the sheet now stays open
              // on failure, so without this a fast double-tap could fire a
              // second _submit() over the still-running first.
              onPressed: viewModel.isLoading ? null : _submit,
              isLoading: viewModel.isLoading,
            ),
            const SizedBox(height: AppDimensions.space8),
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

class _StapleRow extends StatelessWidget {
  const _StapleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.pantryStapleTitle, style: AppTextStyles.bodyMedium),
                Text(
                  l10n.pantryStapleBody,
                  style: AppTextStyles.captionBase.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ButlerySwitch(
            key: AddPantryItemSheet.stapleSwitchKey,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
