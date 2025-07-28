// lib/widgets/common/input_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import all input modules
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';
import 'package:butlery/widgets/common/input/shopping_list_selector.dart';

/// Unified Input Components API
///
/// This class provides a unified API for all input-related widgets:
/// - Instruction editor with dynamic step management
/// - Portion scaler with unit conversion
/// - Debounced checkbox for spam prevention
/// - Shopping item dialog for item management
/// - Shopping list selector for list operations
///
/// MIGRATION GUIDE:
/// ```dart
/// // Before:
/// import '../widgets/instruction_editor.dart';
/// InstructionEditor(initialInstructions: instructions)
///
/// // After:
/// import '../widgets/common/input_components.dart';
/// InputComponents.instructionEditor(initialInstructions: instructions)
/// ```
class InputComponents {
  // ===== INSTRUCTION EDITOR =====

  /// Dynamic instruction editor with Enter-key support for new steps
  static Widget instructionEditor({
    required List<String> initialInstructions,
    ValueChanged<List<String>>? onChanged,
  }) {
    return InstructionEditor(
      initialInstructions: initialInstructions,
      onChanged: onChanged,
    );
  }

  // ===== PORTION SCALER =====

  /// Smart portion scaler with ingredient scaling and unit conversion
  static Widget portionScaler({
    required int originalPortions,
    required List<String> originalIngredients,
    required Function(int newPortions, List<String> scaledIngredients)
        onPortionChanged,
    int minPortions = 1,
    int maxPortions = 20,
  }) {
    return PortionScaler(
      originalPortions: originalPortions,
      originalIngredients: originalIngredients,
      onPortionChanged: onPortionChanged,
      minPortions: minPortions,
      maxPortions: maxPortions,
    );
  }

  // ===== DEBOUNCED CHECKBOX =====

  /// Checkbox with debounce functionality to prevent spam clicking
  static Widget debouncedCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    Color? activeColor,
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    return DebouncedCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      debounceDuration: debounceDuration,
    );
  }

  // ===== SHOPPING ITEM DIALOG =====

  /// Dialog for adding/editing unified shopping items
  static Future<UnifiedShoppingItem?> showShoppingItemDialog(
    BuildContext context, {
    UnifiedShoppingItem? initialItem,
  }) {
    return showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => AddUnifiedShoppingItemDialog(
        initialItem: initialItem,
      ),
    );
  }

  // ===== SHOPPING LIST SELECTOR =====

  /// Bottom sheet for shopping list selection and management
  static Future<void> showListSelector(
    BuildContext context, {
    VoidCallback? onListSelected,
    Map<String, List<Recipe>>? menu,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ShoppingListSelector(
        onListSelected: onListSelected,
        menu: menu,
      ),
    );
  }
}