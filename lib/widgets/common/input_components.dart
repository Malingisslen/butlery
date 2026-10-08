import 'package:flutter/material.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';

// The three modules this facade imports directly. More in `common/input/`
// are pulled in BY these three, so BUT-1859's reachability audit has to follow
// the imports rather than the directory listing.
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';

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
  /// [structuredIngredients] (BUT-444) enables amount-based scaling from
  /// `Recipe.structuredIngredients` instead of string re-parsing.
  /// [initialPortions] (BUT-1322) pre-selects a target (household default);
  /// [originalPortions] stays the scaling base.
  static Widget portionScaler({
    required int originalPortions,
    required List<String> originalIngredients,
    List<RecipeIngredient>? structuredIngredients,
    required Function(int newPortions, List<String> scaledIngredients)
    onPortionChanged,
    int minPortions = 1,
    int maxPortions = 20,
    int? initialPortions,
  }) {
    return PortionScaler(
      originalPortions: originalPortions,
      originalIngredients: originalIngredients,
      structuredIngredients: structuredIngredients,
      onPortionChanged: onPortionChanged,
      minPortions: minPortions,
      maxPortions: maxPortions,
      initialPortions: initialPortions,
    );
  }

  /// Creates a debounced checkbox to prevent spam interactions.
  static Widget debouncedCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    Color? activeColor,
    Duration debounceDuration = DebouncedCheckbox.defaultDebounce,
  }) {
    return DebouncedCheckbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      debounceDuration: debounceDuration,
    );
  }
}
