// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import all input modules
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';
import 'package:butlery/widgets/common/input/shopping_list_selector.dart';

/// Facade for input components. Delegates to specialized input modules.
class InputComponents {
  /// Creates a dynamic instruction editor with step management.
  static Widget instructionEditor({
    required List<String> initialInstructions,
    ValueChanged<List<String>>? onChanged,
  }) {
    return InstructionEditor(
      initialInstructions: initialInstructions,
      onChanged: onChanged,
    );
  }

  /// Creates a portion scaler with automatic ingredient scaling.
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

  /// Creates a debounced checkbox to prevent spam interactions.
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

  /// Displays a modal dialog for creating or editing shopping items.
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

  /// Displays a bottom sheet for shopping list selection with menu integration.
  static Future<void> showListSelector(
    BuildContext context, {
    VoidCallback? onListSelected,
    Map<String, List<Recipe>>? menu,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => ShoppingListSelector(
        onListSelected: onListSelected,
        menu: menu,
      ),
    );
  }
}
