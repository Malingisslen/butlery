/// lib/widgets/common/input_components.dart


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/unified/unified_shopping_item.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/recipe.dart';
import '../../viewmodels/unified_shopping_viewmodel.dart';
import '../../utils/text_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/validators/form_validators.dart';
import 'state_widget.dart';

/// 🎯 UNIFIED INPUT COMPONENTS
/// Samlar alla input widgets för konsistent API och styling
/// VIKTIG: Behåller ALL originalfunktionalitet från befintliga widgets
class InputComponents {
  // ===== INSTRUCTION EDITOR =====

  /// 📝 Dynamisk instruktionseditor med Enter-stöd för nya steg
  /// EXAKT som original instruction_editor.dart
  static Widget instructionEditor({
    required List<String> initialInstructions,
    ValueChanged<List<String>>? onChanged,
  }) {
    return _InstructionEditor(
      initialInstructions: initialInstructions,
      onChanged: onChanged,
    );
  }

  // ===== PORTION SCALER =====

  /// ⚖️ Smart portionsskalare med ingrediens-uppdatering och enhetskonvertering
  /// EXAKT som original portion_scaler.dart - INGEN funktionalitet borttagen
  static Widget portionScaler({
    required int originalPortions,
    required List<String> originalIngredients,
    required Function(int newPortions, List<String> scaledIngredients)
        onPortionChanged,
    int minPortions = 1,
    int maxPortions = 20,
  }) {
    return _PortionScaler(
      originalPortions: originalPortions,
      originalIngredients: originalIngredients,
      onPortionChanged: onPortionChanged,
      minPortions: minPortions,
      maxPortions: maxPortions,
    );
  }

  // ===== DEBOUNCED CHECKBOX =====

  /// ✓ Checkbox med debounce för att undvika spam-klick
  /// EXAKT som original debounced_checkbox.dart
  static Widget debouncedCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    Color? activeColor,
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    return _DebouncedCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      debounceDuration: debounceDuration,
    );
  }

  // ===== SHOPPING ITEM DIALOG =====

  /// 🛒 Dialog för att lägga till/redigera shoppingartiklar
  /// EXAKT som original add_shopping_item_dialog.dart
  static Future<UnifiedShoppingItem?> showShoppingItemDialog(
    BuildContext context, {
    UnifiedShoppingItem? initialItem,
  }) {
    return showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _AddUnifiedShoppingItemDialog(
        initialItem: initialItem,
      ),
    );
  }

  // ===== SHOPPING LIST SELECTOR =====

  /// 📋 Bottom sheet för val av inköpslista
  /// EXAKT som original shopping_list_selector.dart
  static Future<void> showListSelector(
    BuildContext context, {
    VoidCallback? onListSelected,
    Map<String, List<Recipe>>? menu,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.transparent,
      builder: (context) => _ShoppingListSelector(
        onListSelected: onListSelected,
        menu: menu,
      ),
    );
  }
}

// ===== PRIVATE IMPLEMENTATION CLASSES =====
// DESSA ÄR EXAKTA KOPIOR AV ORIGINALWIDGETARNA

/// 📝 INSTRUCTION EDITOR - EXAKT som lib/widgets/instruction_editor.dart
class _InstructionEditor extends StatefulWidget {
  final List<String> initialInstructions;
  final ValueChanged<List<String>>? onChanged;

  const _InstructionEditor({
    required this.initialInstructions,
    this.onChanged,
  });

  @override
  State<_InstructionEditor> createState() => _InstructionEditorState();
}

class _InstructionEditorState extends State<_InstructionEditor> {
  List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    controllers = widget.initialInstructions
        .map((text) => TextEditingController(text: text))
        .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleEnterPressed(int index, TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    setState(() {
      controller.text = before;
      controller.selection = TextSelection.collapsed(offset: before.length);
      final newController = TextEditingController(text: after);
      controllers.insert(index + 1, newController);
    });

    // Notifiera parent om ändringar
    _notifyChanges();
  }

  void _notifyChanges() {
    if (widget.onChanged != null) {
      final instructions = controllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      widget.onChanged!(instructions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(controllers.length, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppTheme.spacingXs,
          ),
          child: TextFormField(
            controller: controllers[i],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: AppTheme.mediumRadius,
              ),
              labelText: 'Instruktion ${i + 1}',
              labelStyle: AppTheme.formLabelStyle,
              contentPadding: AppTheme.inputPadding,
            ),
            style: AppTheme.bodyStyle,
            onFieldSubmitted: (_) => _handleEnterPressed(i, controllers[i]),
            onChanged: (_) => _notifyChanges(),
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            maxLines: null,
          ),
        );
      }),
    );
  }
}

/// ✓ DEBOUNCED CHECKBOX - EXAKT som lib/widgets/debounced_checkbox.dart
class _DebouncedCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final Duration debounceDuration;

  const _DebouncedCheckbox({
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
    );
  }
}

/// 🛒 SHOPPING ITEM DIALOG - EXAKT som lib/widgets/add_shopping_item_dialog.dart
class _AddUnifiedShoppingItemDialog extends StatefulWidget {
  final UnifiedShoppingItem? initialItem;

  const _AddUnifiedShoppingItemDialog({this.initialItem});

  @override
  State<_AddUnifiedShoppingItemDialog> createState() =>
      _AddUnifiedShoppingItemDialogState();
}

class _AddUnifiedShoppingItemDialogState
    extends State<_AddUnifiedShoppingItemDialog> {
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
            style: AppTheme.sectionTitleStyle,
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
                  prefixIcon: AppTheme.actionIcon(
                    context,
                    Icons.shopping_basket,
                    color: AppTheme.primaryColor,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: AppTheme.inputPadding,
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: FormValidators.shoppingItemName(),
              ),
              AppTheme.mediumGap,

              // 🔧 FIXAD: ANTAL och ENHET på samma rad - justerade flex-värden
              Row(
                children: [
                  // Antal (mindre utrymme - flex: 1)
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _amountController,
                      style: AppTheme.bodyStyle,
                      decoration: InputDecoration(
                        labelText: 'Antal',
                        labelStyle: AppTheme.formLabelStyle,
                        hintText: '1',
                        hintStyle: AppTheme.inputHintStyle,
                        prefixIcon: AppTheme.actionIcon(
                          context,
                          Icons.numbers,
                          color: AppTheme.primaryColor,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: AppTheme.inputPadding,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: FormValidators.shoppingItemAmount(),
                    ),
                  ),
                  AppTheme.smallHorizontalGap,

                  // 🔧 FIXAD: ENHET - mer utrymme för dropdown (flex: 2)
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      style: AppTheme.bodyStyle,
                      decoration: InputDecoration(
                        labelText: 'Enhet',
                        labelStyle: AppTheme.formLabelStyle,
                        prefixIcon: AppTheme.actionIcon(
                          context,
                          Icons.straighten,
                          color: AppTheme.primaryColor,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: AppTheme.inputPadding,
                      ),
                      isDense: true,
                      isExpanded: true,
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['value'],
                          child: Text(
                            unit['dropdown']!,
                            style: AppTheme.bodyStyle,
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
                style: AppTheme.bodyStyle,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  labelStyle: AppTheme.formLabelStyle,
                  prefixIcon: AppTheme.actionIcon(
                    context,
                    Icons.category,
                    color: AppTheme.primaryColor,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: AppTheme.inputPadding,
                ),
                isExpanded: true,
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: AppTheme.bodyStyle,
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
          child: Text('Avbryt', style: AppTheme.buttonTextStyle),
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
            style: AppTheme.buttonTextStyle,
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

/// ⚖️ PORTION SCALER - EXAKT som lib/widgets/portion_scaler.dart
/// MED ALL ORIGINALFUNKTIONALITET BEVARAD
class _PortionScaler extends StatefulWidget {
  final int originalPortions;
  final List<String> originalIngredients;
  final Function(int newPortions, List<String> scaledIngredients)
      onPortionChanged;
  final int minPortions;
  final int maxPortions;

  const _PortionScaler({
    required this.originalPortions,
    required this.originalIngredients,
    required this.onPortionChanged,
    this.minPortions = 1,
    this.maxPortions = 20,
  });

  @override
  State<_PortionScaler> createState() => _PortionScalerState();
}

class _PortionScalerState extends State<_PortionScaler>
    with SingleTickerProviderStateMixin {
  late int _currentPortions;
  late List<String> _scaledIngredients;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _convertToSwedish = false; // NY! Toggle för enhetskonvertering
  bool _hasAmericanUnits =
      false; // NY! Detekterar om receptet har amerikanska enheter

  @override
  void initState() {
    super.initState();
    _currentPortions = widget.originalPortions;
    _scaledIngredients = List.from(widget.originalIngredients);
    _hasAmericanUnits = _detectAmericanUnits(); // Detektera amerikanska enheter

    // Animation för visuell feedback
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePortions(int newPortions) {
    if (newPortions < widget.minPortions || newPortions > widget.maxPortions) {
      return;
    }

    setState(() {
      _currentPortions = newPortions;
      _scaledIngredients = _scaleIngredients(newPortions);
    });

    // Visuell feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Callback till parent
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  // NY METOD för att detektera amerikanska enheter
  bool _detectAmericanUnits() {
    const americanUnits = {
      'cup',
      'cups',
      'oz',
      'fl oz',
      'floz',
      'tbsp',
      'tsp',
      'lb',
      'lbs',
      'pound',
      'pounds',
      'ounce',
      'ounces',
      'pint',
      'pints',
      'quart',
      'quarts',
      'gallon',
      'gallons',
      'tablespoon',
      'tablespoons',
      'teaspoon',
      'teaspoons',
    };

    for (final ingredient in widget.originalIngredients) {
      // Först: försök med parser
      final parsed = IngredientParser.parseIngredient(ingredient);

      if (americanUnits.contains(parsed.unit.toLowerCase())) {
        return true;
      }

      // Fallback: enkel strängkontroll
      final lowerIngredient = ingredient.toLowerCase();
      for (final unit in americanUnits) {
        if (lowerIngredient.contains(' $unit ') ||
            lowerIngredient.startsWith('$unit ') ||
            lowerIngredient.endsWith(' $unit')) {
          return true;
        }
      }
    }
    return false;
  }

  // NY METOD för enhetskonvertering toggle
  void _toggleUnitConversion() {
    setState(() {
      _convertToSwedish = !_convertToSwedish;
      _scaledIngredients = _scaleIngredients(_currentPortions);
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Callback till parent
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  List<String> _scaleIngredients(int newPortions) {
    if (widget.originalPortions == 0 ||
        newPortions == widget.originalPortions) {
      // ÄVEN om portionerna är samma, kör konvertering om _convertToSwedish är true
      if (_convertToSwedish) {
        final scaledList = <String>[];
        for (final ingredient in widget.originalIngredients) {
          final converted = _scaleIndividualIngredient(
            ingredient,
            1.0,
          ); // Scalefactor 1.0
          scaledList.add(converted);
        }
        return scaledList;
      }

      return List.from(widget.originalIngredients);
    }

    final scaleFactor = newPortions / widget.originalPortions;
    final scaledList = <String>[];

    for (final ingredient in widget.originalIngredients) {
      final scaled = _scaleIndividualIngredient(ingredient, scaleFactor);
      scaledList.add(scaled);
    }

    return scaledList;
  }

  String _scaleIndividualIngredient(String ingredient, double scaleFactor) {
    if (ingredient.trim().isEmpty) return ingredient;

    final parsed = IngredientParser.parseIngredient(ingredient);

    // Om ingen kvantitet hittades, returnera oförändrad
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == ingredient) {
      return ingredient;
    }

    // Skala kvantiteten
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Enhetskonvertering
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    // Amerikanska → Svenska konvertering (om aktiverad)
    if (_convertToSwedish && parsed.unit.isNotEmpty) {
      final americanUnits = {
        'cup',
        'cups',
        'oz',
        'fl oz',
        'floz',
        'tbsp',
        'tsp',
        'lb',
        'lbs',
        'pound',
        'pounds',
        'ounce',
        'ounces',
        'pint',
        'pints',
        'quart',
        'quarts',
        'gallon',
        'gallons',
        'tablespoon',
        'tablespoons',
        'teaspoon',
        'teaspoons',
      };

      if (americanUnits.contains(parsed.unit.toLowerCase())) {
        final converted = SmartUnitConverter.convertToReadableUnit(
          scaledQuantity,
          parsed.unit,
        );
        finalQuantity = converted.quantity;
        finalUnit = converted.unit;
      }
    }

    // Normal svensk enhetskonvertering (alltid aktiv)
    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(finalQuantity, finalUnit)) {
      final converted = SmartUnitConverter.convertToReadableUnit(
        finalQuantity,
        finalUnit,
      );
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    // Formatera med svenska bråk och enheter
    final formattedQuantity = toSwedishHalfFraction(finalQuantity);

    // Bygg ihop igen
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Använd pluralisering för ingredienser utan enhet
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header med portionskontroller
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).colorScheme.primary,
                size: AppTheme.iconSizeSmall,
              ),
              const SizedBox(width: AppTheme.spacingXs),
              Text(
                'Portioner',
                style: AppTheme.getTextStyle(
                  context,
                  AppTheme.subtitleStyle,
                  color: Theme.of(context).colorScheme.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _buildPortionControls(context),
            ],
          ),

          AppTheme.smallGap,

          // Info om skalning och enhetskonvertering
          if (_currentPortions != widget.originalPortions ||
              _convertToSwedish) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _convertToSwedish ? Icons.language : Icons.calculate,
                    size: AppTheme.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Flexible(
                    child: Text(
                      _buildStatusText(),
                      style: AppTheme.captionStyle.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.smallGap,
          ],

          // Enhetskonvertering toggle (bara om receptet har amerikanska enheter)
          if (_hasAmericanUnits) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleUnitConversion,
                      icon: Icon(
                        _convertToSwedish ? Icons.check_circle : Icons.language,
                        size: AppTheme.iconSizeSmall,
                      ),
                      label: Text(
                        _convertToSwedish
                            ? 'Använder svenska enheter'
                            : 'Konvertera amerikanska enheter',
                        style: AppTheme.captionStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _convertToSwedish
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color: _convertToSwedish
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        backgroundColor: _convertToSwedish
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3)
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Skalade ingredienser
          _buildScaledIngredients(context),
        ],
      ),
    );
  }

  Widget _buildPortionControls(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus knapp
                _buildControlButton(
                  context,
                  icon: Icons.remove,
                  onPressed: _currentPortions > widget.minPortions
                      ? () => _updatePortions(_currentPortions - 1)
                      : null,
                ),

                // Nuvarande portioner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Text(
                    '$_currentPortions',
                    style: AppTheme.getTextStyle(
                      context,
                      AppTheme.cardTitleStyle,
                      color: Theme.of(context).colorScheme.primary,
                    ).copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Plus knapp
                _buildControlButton(
                  context,
                  icon: Icons.add,
                  onPressed: _currentPortions < widget.maxPortions
                      ? () => _updatePortions(_currentPortions + 1)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: AppTheme.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: Icon(
            icon,
            size: AppTheme.iconSizeSmall,
            color: onPressed != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  String _buildStatusText() {
    final List<String> status = [];

    if (_currentPortions != widget.originalPortions) {
      status.add(
        'Skalat från ${widget.originalPortions} till $_currentPortions portioner',
      );
    }

    if (_convertToSwedish) {
      status.add('Amerikanska enheter konverterade till svenska');
    }

    return status.join(' • ');
  }

  Widget _buildScaledIngredients(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredienser för $_currentPortions ${_currentPortions == 1 ? 'portion' : 'portioner'}:',
          style: AppTheme.getTextStyle(
            context,
            AppTheme.bodyStyle,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        AppTheme.smallGap,
        Container(
          width: double.infinity,
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppTheme.cardBorderRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _scaledIngredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final originalIngredient =
                  index < widget.originalIngredients.length
                      ? widget.originalIngredients[index]
                      : '';
              final isChanged = _currentPortions != widget.originalPortions ||
                  _convertToSwedish ||
                  ingredient != originalIngredient;

              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppTheme.spacingXxs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bullet point
                    Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(
                        top: 8,
                        right: AppTheme.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: isChanged
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Ingrediens text
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: AppTheme.getTextStyle(
                          context,
                          AppTheme.bodyStyle,
                          color: isChanged
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ).copyWith(
                          fontWeight:
                              isChanged ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(ingredient),
                      ),
                    ),

                    // Ändrad indikator
                    if (isChanged)
                      Icon(
                        Icons.refresh,
                        size: AppTheme.iconSizeSmall,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 📋 SHOPPING LIST SELECTOR - EXAKT som lib/widgets/shopping_list_selector.dart
/// MED ALL ORIGINALFUNKTIONALITET BEVARAD
class _ShoppingListSelector extends StatefulWidget {
  final VoidCallback? onListSelected;
  final Map<String, List<Recipe>>? menu;

  const _ShoppingListSelector({
    this.onListSelected,
    this.menu,
  });

  @override
  State<_ShoppingListSelector> createState() => _ShoppingListSelectorState();
}

class _ShoppingListSelectorState extends State<_ShoppingListSelector> {
  late UnifiedShoppingViewModel _viewModel;
  String? _selectedListId;
  bool _isAddingToList = false;

  @override
  void initState() {
    super.initState();
    _viewModel = UnifiedShoppingViewModel();
    _selectedListId = _viewModel.activeList?.id;
  }

  List<UnifiedShoppingItem> _convertMenuToShoppingItems() {
    if (widget.menu == null || widget.menu!.isEmpty) return [];

    final items = <UnifiedShoppingItem>[];
    final seenIngredients = <String>{};

    for (final entry in widget.menu!.entries) {
      for (final recipe in entry.value) {
        for (final ingredient in recipe.ingredients) {
          final normalizedIngredient = ingredient.toLowerCase().trim();
          if (!seenIngredients.contains(normalizedIngredient)) {
            seenIngredients.add(normalizedIngredient);

            items.add(UnifiedShoppingItem.basic(
              name: ingredient.trim(),
              amount: 1.0,
              unit: '',
              category: _categorizeIngredient(ingredient),
            ));
          }
        }
      }
    }

    AppLogger.info('Konverterade ${items.length} unika ingredienser från meny');
    return items;
  }

  String _categorizeIngredient(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();

    // Frukt & Grönt
    if (lowerIngredient.contains('tomat') ||
        lowerIngredient.contains('lök') ||
        lowerIngredient.contains('äpple') ||
        lowerIngredient.contains('banan') ||
        lowerIngredient.contains('morot') ||
        lowerIngredient.contains('gurka') ||
        lowerIngredient.contains('sallad') ||
        lowerIngredient.contains('potatis')) {
      return 'Frukt & Grönt';
    }

    // Mejeri
    if (lowerIngredient.contains('mjölk') ||
        lowerIngredient.contains('ost') ||
        lowerIngredient.contains('yoghurt') ||
        lowerIngredient.contains('smör') ||
        lowerIngredient.contains('grädde') ||
        lowerIngredient.contains('ägg')) {
      return 'Mejeri';
    }

    // Kött & Fisk
    if (lowerIngredient.contains('kött') ||
        lowerIngredient.contains('kyckling') ||
        lowerIngredient.contains('fisk') ||
        lowerIngredient.contains('fläsk') ||
        lowerIngredient.contains('nöt') ||
        lowerIngredient.contains('lax')) {
      return 'Kött & Fisk';
    }

    // Skafferi
    if (lowerIngredient.contains('mjöl') ||
        lowerIngredient.contains('socker') ||
        lowerIngredient.contains('salt') ||
        lowerIngredient.contains('olja') ||
        lowerIngredient.contains('pasta') ||
        lowerIngredient.contains('ris')) {
      return 'Skafferi';
    }

    return 'Övrigt';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<UnifiedShoppingViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: AppTheme.cardPadding,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: AppTheme.bottomSheetBorderRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: AppTheme.iconSizeDisplay,
                  height: AppTheme.spacingXs,
                  margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(AppTheme.spacingXxs),
                  ),
                ),

                // Header
                _buildHeader(),

                AppTheme.mediumGap,

                // Main content
                Flexible(
                  child: _buildContent(viewModel),
                ),

                AppTheme.mediumGap,

                // Action buttons
                _buildActionButtons(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AppTheme.actionIcon(
          context,
          Icons.list_alt,
          color: AppTheme.primaryColor,
        ),
        AppTheme.smallHorizontalGap,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Välj inköpslista',
                style: AppTheme.sectionTitleStyle,
              ),
              if (widget.menu != null) ...[
                AppTheme.tinyGap,
                Text(
                  '${_convertMenuToShoppingItems().length} ingredienser från menyn',
                  style: AppTheme.subtitleStyle.copyWith(
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: AppTheme.actionIcon(context, Icons.close),
          tooltip: 'Stäng',
        ),
      ],
    );
  }

  Widget _buildContent(UnifiedShoppingViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: 'Laddar listor...');
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error ?? 'Okänt fel',
      );
    }

    if (!viewModel.hasLists) {
      return StateWidget.empty(
        title: 'Inga inköpslistor',
        subtitle: 'Skapa din första lista för att komma igång',
        icon: Icons.list_alt,
      );
    }

    return _buildListSelection(viewModel);
  }

  Widget _buildListSelection(UnifiedShoppingViewModel viewModel) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: viewModel.lists.length,
      separatorBuilder: (context, index) => Divider(
        height: AppTheme.dividerHeight,
        color: AppTheme.dividerColor,
      ),
      itemBuilder: (context, index) {
        final list = viewModel.lists[index];
        final isSelected = _selectedListId == list.id;
        final isActive = viewModel.activeList?.id == list.id;

        return _buildListTile(list, isSelected, isActive, viewModel);
      },
    );
  }

  Widget _buildListTile(
    UnifiedShoppingList list,
    bool isSelected,
    bool isActive,
    UnifiedShoppingViewModel viewModel,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : AppTheme.cardColor,
      ),
      child: ListTile(
        contentPadding: AppTheme.listItemPadding,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radio button
            Radio<String>(
              value: list.id,
              groupValue: _selectedListId,
              onChanged: (value) {
                setState(() {
                  _selectedListId = value;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),

            // Lista typ ikon
            Icon(
              list.isCollaborative ? Icons.people : Icons.person,
              color: list.isCollaborative
                  ? AppTheme.accentColor
                  : AppTheme.textSecondary,
              size: AppTheme.iconSizeInfo,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                list.name,
                style: AppTheme.cardTitleStyle.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isActive) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: AppTheme.successContainerDecoration,
                child: Text(
                  'AKTIV',
                  style: AppTheme.chipLabelStyle.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTheme.tinyGap,
            Text(
              list.summary,
              style: AppTheme.subtitleStyle,
            ),
            AppTheme.tinyGap,
            _buildListMetadata(list),
          ],
        ),
        trailing: _buildListActions(list, viewModel),
        onTap: () {
          setState(() {
            _selectedListId = list.id;
          });
        },
      ),
    );
  }

  Widget _buildListMetadata(UnifiedShoppingList list) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      children: [
        // Sync status
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXs,
            vertical: AppTheme.spacingXxs,
          ),
          decoration: BoxDecoration(
            color: _getSyncStatusColor(list).withValues(alpha: 0.1),
            borderRadius: AppTheme.chipRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                list.syncStatusEmoji,
                style: AppTheme.captionStyle.copyWith(fontSize: AppTheme.microText.fontSize),
              ),
              AppTheme.tinyGap,
              Text(
                _getSyncStatusText(list),
                style: AppTheme.captionStyle.copyWith(
                  color: _getSyncStatusColor(list),
                ),
              ),
            ],
          ),
        ),

        // Kollaborativ info
        if (list.isCollaborative) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXs,
              vertical: AppTheme.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Text(
              '${list.memberCount} medlemmar',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.accentColor,
              ),
            ),
          ),
        ],

        // Recent activity
        if (list.hasRecentActivity) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXs,
              vertical: AppTheme.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.warningColor,
                ),
                AppTheme.tinyGap,
                Text(
                  'Aktiv',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListActions(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) {
    return PopupMenuButton<String>(
      icon: AppTheme.actionIcon(context, Icons.more_vert),
      onSelected: (action) => _handleListAction(action, list, viewModel),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              AppTheme.actionIcon(context, Icons.edit),
              AppTheme.smallHorizontalGap,
              Text('Byt namn', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              AppTheme.actionIcon(context, Icons.download),
              AppTheme.smallHorizontalGap,
              Text('Exportera', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        if (viewModel.lists.length > 1) ...[
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                AppTheme.actionIcon(context, Icons.delete,
                    color: AppTheme.errorColor),
                AppTheme.smallHorizontalGap,
                Text(
                  'Ta bort',
                  style: AppTheme.errorTextStyle,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(UnifiedShoppingViewModel viewModel) {
    return Column(
      children: [
        // Skapa ny lista knapp
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCreateListDialog(viewModel),
            icon: AppTheme.actionIcon(context, Icons.add),
            label: Text('Skapa ny lista', style: AppTheme.buttonTextStyle),
            style: AppTheme.secondaryButtonStyle,
          ),
        ),

        AppTheme.smallGap,

        // Lägg till knapp med loading
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectedListId != null && !_isAddingToList
                ? () => _addMenuToListAndNavigate(viewModel)
                : null,
            icon: _isAddingToList
                ? AppTheme.smallLoadingIndicator()
                : AppTheme.actionIcon(context, Icons.add_shopping_cart),
            label: Text(
              _isAddingToList
                  ? 'Lägger till...'
                  : widget.menu != null
                      ? 'Lägg till ingredienser'
                      : 'Öppna lista',
              style: AppTheme.buttonTextStyle,
            ),
            style: AppTheme.primaryButtonStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _addMenuToListAndNavigate(
      UnifiedShoppingViewModel viewModel) async {
    if (_selectedListId == null) return;

    setState(() {
      _isAddingToList = true;
    });

    try {
      // Sätt aktiv lista om det inte redan är det
      if (_selectedListId != viewModel.activeList?.id) {
        final success = await viewModel.setActiveList(_selectedListId!);
        if (!success) {
          throw Exception('Kunde inte aktivera lista');
        }
      }

      // Lägg till ingredienser från meny om det finns
      if (widget.menu != null) {
        final ingredientItems = _convertMenuToShoppingItems();

        for (final item in ingredientItems) {
          await viewModel.addItemToActiveList(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            category: item.category,
          );
        }

        AppLogger.success(
            '✅ Lade till ${ingredientItems.length} ingredienser från meny');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Lade till ${ingredientItems.length} ingredienser från menyn'),
              backgroundColor: AppTheme.successColor,
              duration: AppTheme.wait3s,
            ),
          );
        }
      }

      // Navigera till shopping view
      if (mounted) {
        widget.onListSelected?.call();
        Navigator.pushReplacementNamed(context, '/unified-shopping');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid tillägg av ingredienser: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte lägga till ingredienser: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToList = false;
        });
      }
    }
  }

  // Helper methods
  Color _getSyncStatusColor(UnifiedShoppingList list) {
    switch (list.syncStatus) {
      case SyncStatus.synced:
        return AppTheme.successColor;
      case SyncStatus.pending:
        return AppTheme.warningColor;
      case SyncStatus.conflict:
        return AppTheme.errorColor;
      case SyncStatus.local:
        return AppTheme.textTertiary;
      case SyncStatus.error:
        return AppTheme.errorColor;
    }
  }

  String _getSyncStatusText(UnifiedShoppingList list) {
    switch (list.syncStatus) {
      case SyncStatus.synced:
        return 'Synkad';
      case SyncStatus.pending:
        return 'Synkar...';
      case SyncStatus.conflict:
        return 'Konflikt';
      case SyncStatus.local:
        return 'Lokal';
      case SyncStatus.error:
        return 'Fel';
    }
  }

  Future<void> _showCreateListDialog(UnifiedShoppingViewModel viewModel) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            AppTheme.actionIcon(context, Icons.add_circle_outline),
            AppTheme.smallHorizontalGap,
            Text('Skapa ny lista', style: AppTheme.sectionTitleStyle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Listnamn *',
                labelStyle: AppTheme.formLabelStyle,
                hintText: 'T.ex. Veckohandling',
                hintStyle: AppTheme.inputHintStyle,
                border: const OutlineInputBorder(),
              ),
              style: AppTheme.bodyStyle,
              autofocus: true,
            ),
            AppTheme.mediumGap,
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Beskrivning (valfri)',
                labelStyle: AppTheme.formLabelStyle,
                hintText: 'Beskriv vad listan är till för',
                hintStyle: AppTheme.inputHintStyle,
                border: const OutlineInputBorder(),
              ),
              style: AppTheme.bodyStyle,
              maxLines: 2,
            ),
            AppTheme.mediumGap,
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  AppTheme.infoIcon(context),
                  AppTheme.smallHorizontalGap,
                  Expanded(
                    child: Text(
                      'Listan skapas som personlig. Du kan dela den med vänner senare.',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle,
            child: Text('Skapa', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listnamn krävs',
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight)),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      final success = await viewModel.createPersonalList(name);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lista "$name" skapad!',
                  style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight)),
              backgroundColor: AppTheme.successColor,
            ),
          );

          setState(() {
            _selectedListId = viewModel.activeList?.id;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kunde inte skapa lista: ${viewModel.error ?? "Okänt fel"}',
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleListAction(
    String action,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    switch (action) {
      case 'rename':
        await _showRenameDialog(list, viewModel);
        break;
      case 'export':
        await _exportList(list, viewModel);
        break;
      case 'delete':
        await _showDeleteDialog(list, viewModel);
        break;
    }
  }

  Future<void> _showRenameDialog(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final nameController = TextEditingController(text: list.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Byt namn på lista', style: AppTheme.sectionTitleStyle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nytt namn',
            labelStyle: AppTheme.formLabelStyle,
            border: const OutlineInputBorder(),
          ),
          style: AppTheme.bodyStyle,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: AppTheme.primaryButtonStyle,
            child: Text('Spara', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != list.name && mounted) {
      final success = await viewModel.renameActiveList(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista omdöpt till "$result"'
                  : 'Kunde inte byta namn: ${viewModel.error ?? "Okänt fel"}',
              style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportList(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final exportText = viewModel.exportListAsText();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lista exporterad! ${exportText.length} tecken',
          style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _showDeleteDialog(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            AppTheme.smallHorizontalGap,
            Text('Ta bort lista', style: AppTheme.sectionTitleStyle),
          ],
        ),
        content: Text(
          'Är du säker på att du vill ta bort "${list.name}"?\n\n'
          'Denna åtgärd kan inte ångras och alla ${list.totalItems} artiklar försvinner.',
          style: AppTheme.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('Ta bort', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await viewModel.deleteActiveList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista "${list.name}" borttagen'
                  : 'Kunde inte ta bort lista: ${viewModel.error ?? "Okänt fel"}',
              style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );

        if (success) {
          setState(() {
            _selectedListId = viewModel.activeList?.id;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
