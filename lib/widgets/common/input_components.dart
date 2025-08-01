/// Comprehensive input components facade providing unified access to specialized form and interaction widgets.
///
/// This facade implements a centralized API for all input-related widgets throughout the application,
/// providing consistent interface patterns for form elements, user interactions, and data entry
/// components. It delegates to specialized input modules while maintaining backward compatibility
/// and providing a single entry point for all input-related functionality.
///
/// **Architecture Integration:**
/// - Implements Facade Pattern for unified access to specialized input modules
/// - Provides consistent API for form components across the application
/// - Integrates with validation systems and form state management
/// - Supports responsive design patterns for various screen sizes
/// - Maintains backward compatibility for seamless migration paths
///
/// **Input Component Categories:**
/// - **Text Input**: Instruction editors, dynamic text management, and rich text support
/// - **Numeric Input**: Portion scalers, unit conversion, and mathematical operations
/// - **Selection Input**: Checkboxes, radio buttons, and multi-selection interfaces
/// - **Dialog Input**: Modal dialogs for complex data entry and item management
/// - **List Management**: Shopping list selectors and bulk operation interfaces
///
/// **Key Features:**
/// - Debounced input handling to prevent spam and improve performance
/// - Dynamic content management with real-time updates
/// - Unit conversion and mathematical operations for cooking measurements
/// - Modal dialog integration for complex data entry scenarios
/// - Responsive design support for various screen sizes and orientations
///
/// **Usage Examples:**
/// ```dart
/// // Dynamic instruction editor
/// InputComponents.instructionEditor(
///   initialInstructions: recipe.instructions,
///   onChanged: (instructions) => recipe.updateInstructions(instructions),
/// );
///
/// // Portion scaler with unit conversion
/// InputComponents.portionScaler(
///   originalPortions: 4,
///   originalIngredients: recipe.ingredients,
///   onPortionChanged: (portions, scaledIngredients) => updateRecipe(portions, scaledIngredients),
/// );
///
/// // Shopping item dialog
/// final item = await InputComponents.showShoppingItemDialog(context);
/// ```

// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/material.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import all input modules
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';
import 'package:butlery/widgets/common/input/shopping_list_selector.dart';

/// Comprehensive input components facade implementing unified API for specialized form and interaction widgets.
///
/// This class serves as the central access point for all input-related functionality throughout
/// the application, providing consistent interface patterns and delegating to specialized modules
/// for optimal performance and maintainability. It supports dynamic content management, validation,
/// and responsive design patterns.
///
/// **Component Architecture:**
/// - **Modular Design**: Each input type is handled by a focused specialized module
/// - **Consistent API**: Unified method signatures and parameter patterns across all components
/// - **Performance Optimization**: Debounced operations and efficient state management
/// - **Validation Integration**: Built-in support for form validation and error handling
/// - **Responsive Support**: Adaptive layouts for various screen sizes and orientations
///
/// **Migration Support:**
/// This facade maintains full backward compatibility while providing improved organization
/// and performance through the delegation pattern to specialized input modules.
class InputComponents {
  // ===== INSTRUCTION EDITOR =====

  /// Creates a dynamic instruction editor widget with intelligent step management and real-time editing capabilities.
  ///
  /// This method provides access to the InstructionEditor module, offering sophisticated text editing
  /// functionality specifically designed for recipe instructions with support for dynamic step addition,
  /// Enter-key navigation, and real-time content validation. The editor automatically manages step
  /// numbering and provides intuitive keyboard navigation for enhanced user experience.
  ///
  /// [initialInstructions] The starting list of instruction steps to populate the editor
  /// [onChanged] Callback triggered when instructions are modified, providing updated instruction list
  ///
  /// Returns configured InstructionEditor widget with dynamic step management
  ///
  /// **Features:**
  /// - Dynamic step addition with Enter-key support
  /// - Automatic step numbering and reordering
  /// - Real-time content validation and formatting
  /// - Intuitive keyboard navigation between steps
  /// - Support for step deletion and reordering
  ///
  /// **Usage Example:**
  /// ```dart
  /// InputComponents.instructionEditor(
  ///   initialInstructions: ['Förvärm ugnen till 200°C', 'Blanda ingredienserna'],
  ///   onChanged: (updatedInstructions) => recipe.updateInstructions(updatedInstructions),
  /// );
  /// ```
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

  /// Creates an intelligent portion scaler widget with automatic ingredient scaling and unit conversion.
  ///
  /// This method provides access to the PortionScaler module, offering sophisticated mathematical
  /// operations for scaling recipe ingredients based on desired portion counts. It includes intelligent
  /// unit conversion, fraction handling, and maintains ingredient ratio consistency for accurate
  /// cooking measurements across different serving sizes.
  ///
  /// [originalPortions] The original number of portions the recipe serves
  /// [originalIngredients] List of original ingredient measurements to scale
  /// [onPortionChanged] Callback providing scaled portions and ingredient list when changes occur
  /// [minPortions] Minimum allowed portion count (defaults to 1)
  /// [maxPortions] Maximum allowed portion count (defaults to 20)
  ///
  /// Returns configured PortionScaler widget with intelligent scaling capabilities
  ///
  /// **Mathematical Features:**
  /// - Proportional ingredient scaling with ratio preservation
  /// - Intelligent unit conversion (metric/imperial support)
  /// - Fraction and decimal handling for accurate measurements
  /// - Range validation to prevent unrealistic portion counts
  /// - Real-time calculation updates with immediate feedback
  ///
  /// **Usage Example:**
  /// ```dart
  /// InputComponents.portionScaler(
  ///   originalPortions: 4,
  ///   originalIngredients: ['2 dl mjöl', '3 ägg', '5 dl mjölk'],
  ///   onPortionChanged: (newPortions, scaledIngredients) => updateRecipe(newPortions, scaledIngredients),
  ///   minPortions: 1,
  ///   maxPortions: 12,
  /// );
  /// ```
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

  /// Creates a performance-optimized checkbox widget with debounce functionality to prevent spam interactions.
  ///
  /// This method provides access to the DebouncedCheckbox module, offering enhanced checkbox functionality
  /// with built-in debouncing to prevent rapid-fire state changes that could impact performance or cause
  /// unintended behavior. It maintains standard checkbox appearance while adding intelligent interaction
  /// management for improved user experience and system stability.
  ///
  /// [value] Current checkbox state (checked/unchecked)
  /// [onChanged] Callback triggered after debounce period when state changes
  /// [activeColor] Custom color for checked state appearance
  /// [debounceDuration] Time delay for debouncing rapid interactions (defaults to 300ms)
  ///
  /// Returns configured DebouncedCheckbox widget with spam prevention
  ///
  /// **Performance Features:**
  /// - Debounced state changes to prevent rapid-fire updates
  /// - Optimized for collaborative environments with multiple users
  /// - Maintains responsive feel while preventing system overload
  /// - Configurable debounce timing for different use cases
  /// - Standard Material Design checkbox appearance
  ///
  /// **Usage Example:**
  /// ```dart
  /// InputComponents.debouncedCheckbox(
  ///   value: shoppingItem.isCompleted,
  ///   onChanged: (checked) => updateItemStatus(shoppingItem.id, checked),
  ///   activeColor: Colors.green,
  ///   debounceDuration: Duration(milliseconds: 500),
  /// );
  /// ```
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

  /// Displays a modal dialog for creating or editing unified shopping items with comprehensive form validation.
  ///
  /// This method provides access to the shopping item dialog functionality, offering a full-featured
  /// modal interface for managing shopping list items with support for categories, quantities, units,
  /// and metadata. The dialog includes intelligent form validation, auto-completion, and integration
  /// with the unified shopping system for consistent data management across collaborative features.
  ///
  /// [context] Build context for dialog display and theming
  /// [initialItem] Optional existing item for editing mode (null for creation mode)
  ///
  /// Returns Future<UnifiedShoppingItem?> containing the created/edited item or null if cancelled
  ///
  /// **Form Features:**
  /// - Comprehensive item information capture (name, quantity, unit, category)
  /// - Intelligent auto-completion based on usage history
  /// - Form validation with real-time error feedback
  /// - Support for custom categories and units
  /// - Integration with unified shopping item model
  ///
  /// **Modes:**
  /// - **Creation Mode**: Fresh item creation with empty form
  /// - **Editing Mode**: Pre-populated form for existing item modification
  ///
  /// **Usage Example:**
  /// ```dart
  /// final newItem = await InputComponents.showShoppingItemDialog(
  ///   context,
  ///   initialItem: existingItem, // null for new item
  /// );
  /// if (newItem != null) shoppingList.addItem(newItem);
  /// ```
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

  /// Displays a modal bottom sheet for shopping list selection and management with menu integration support.
  ///
  /// This method provides access to the shopping list selector functionality, offering an intuitive
  /// bottom sheet interface for choosing shopping lists, creating new lists, and managing list operations.
  /// It includes integration with weekly menu systems for automatic shopping list generation and supports
  /// collaborative list selection for shared shopping scenarios.
  ///
  /// [context] Build context for bottom sheet display and theming
  /// [onListSelected] Callback triggered when a shopping list is selected
  /// [menu] Optional weekly menu for automatic shopping list generation from recipes
  ///
  /// Returns Future<void> completing when the bottom sheet is dismissed
  ///
  /// **Selection Features:**
  /// - Visual list preview with item counts and collaboration status
  /// - Quick list creation with menu integration
  /// - Search and filtering for large list collections
  /// - Collaborative list indicators and member information
  /// - Recent lists and favorites for quick access
  ///
  /// **Menu Integration:**
  /// - Automatic shopping list generation from weekly menu recipes
  /// - Ingredient consolidation and duplicate removal
  /// - Smart categorization based on recipe ingredients
  ///
  /// **Usage Example:**
  /// ```dart
  /// await InputComponents.showListSelector(
  ///   context,
  ///   onListSelected: () => navigateToShoppingList(),
  ///   menu: weeklyMenu, // for auto-generation features
  /// );
  /// ```
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
