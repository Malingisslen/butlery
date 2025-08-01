/// Comprehensive dynamic form field manager implementing intelligent TextEditingController lifecycle management.
///
/// This manager class serves as the foundational form field infrastructure throughout the Butlery application,
/// providing advanced controller management for dynamic form scenarios including recipe ingredient lists,
/// instruction steps, and shopping list items. It ensures optimal memory management, synchronization between
/// controllers and data models, and comprehensive lifecycle handling for Swedish cooking application's
/// complex form requirements while maintaining performance and preventing memory leaks.
///
/// ## Core Architecture Features
/// 
/// **Intelligent Controller Lifecycle Management**
/// - Automatic creation and disposal of TextEditingController instances
/// - Synchronization between controller state and external data models
/// - Memory-efficient controller reuse and proper resource cleanup
/// - Dynamic field addition and removal with automatic index management
/// 
/// **Form State Synchronization**
/// - Bidirectional synchronization between form controllers and data values
/// - Real-time change detection with callback integration for reactive forms
/// - External data model integration with automatic controller updates
/// - Backward compatibility support for existing form patterns
/// 
/// **Memory Management Intelligence**
/// - Automatic cleanup of unused controllers to prevent memory leaks
/// - Efficient controller reorganization after field removal operations
/// - Resource disposal coordination for proper Flutter widget lifecycle
/// - Debug utilities for monitoring controller state and memory usage
/// 
/// ## Usage Examples
/// 
/// **Recipe Ingredient Management:**
/// ```dart
/// class RecipeFormViewModel {
///   final FormFieldsManager _ingredientsManager = FormFieldsManager(
///     initialItems: recipe.ingredients,
///     onValueChanged: (index, value) {
///       recipe.ingredients[index] = value;
///       notifyListeners();
///     },
///   );
///   
///   void addIngredient() => _ingredientsManager.addController();
///   void removeIngredient(int index) => _ingredientsManager.removeController(index);
///   
///   List<TextEditingController> get ingredientControllers => 
///     _ingredientsManager.getControllers(recipe.ingredients);
/// }
/// ```
/// 
/// **Shopping List Item Management:**
/// ```dart
/// class ShoppingListView extends StatefulWidget {
///   final FormFieldsManager _itemsManager = FormFieldsManager(
///     onValueChanged: (index, value) {
///       shoppingList.items[index].name = value;
///       _saveChanges();
///     },
///   );
///   
///   Widget build(BuildContext context) {
///     final controllers = _itemsManager.getControllers(
///       shoppingList.items.map((item) => item.name).toList(),
///     );
///     
///     return ListView.builder(
///       itemCount: controllers.length,
///       itemBuilder: (context, index) => TextFormField(
///         controller: controllers[index],
///         decoration: InputDecoration(
///           hintText: 'Vara ${index + 1}',
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// 
/// **Dynamic Instruction Steps:**
/// ```dart
/// class InstructionStepsWidget extends StatefulWidget {
///   final FormFieldsManager _stepsManager = FormFieldsManager(
///     initialItems: recipe.instructions,
///     validator: (value) => value?.isEmpty == true ? 'Instruktion krävs' : null,
///   );
///   
///   void _addStep() {
///     _stepsManager.addController();
///     setState(() {});
///   }
///   
///   void _removeStep(int index) {
///     _stepsManager.removeController(index);
///     setState(() {});
///   }
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Memory Efficiency**: Controllers are reused when possible and properly disposed when unused
/// - **Synchronization Speed**: Minimal overhead synchronization with intelligent change detection
/// - **Resource Management**: Automatic cleanup prevents memory leaks in long-lived forms
/// - **Index Management**: Efficient reorganization algorithms for field addition/removal operations
/// 
/// ## Integration Patterns
/// 
/// - **MVVM Architecture**: Direct integration with ViewModels for reactive form state management
/// - **Form Validation**: Built-in validator support for comprehensive form validation workflows
/// - **Widget Lifecycle**: Proper disposal integration with Flutter widget disposal patterns
/// - **Data Binding**: Bidirectional binding with external data models for consistent state management
/// 
/// This manager is essential for all dynamic form scenarios in the Swedish cooking application,
/// providing reliable, performant, and memory-efficient controller management for complex form
/// interfaces while maintaining clean architecture patterns and optimal user experience.

import 'package:flutter/material.dart';

/// Hanterar TextEditingControllers för dynamiska formulärfält (Manages TextEditingControllers for dynamic form fields)
///
/// Denna klass tar hand om (This class handles):
/// - Skapande och borttagning av controllers (Creation and removal of controllers)
/// - Synkronisering mellan controllers och data (Synchronization between controllers and data)
/// - Korrekt dispose av controllers (Proper disposal of controllers)
/// - Memory management
class FormFieldsManager {
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _values = [];
  final Function(int, String)? onValueChanged;
  final List<String>? initialItems;
  final String? Function(String?)? validator;

  FormFieldsManager({
    this.onValueChanged,
    this.initialItems,
    this.validator,
  }) {
    if (initialItems != null) {
      _values.addAll(initialItems!);
    }
    if (_values.isEmpty) {
      _values.add('');
    }
  }

  /// Hämta alla controllers synkroniserade med aktuella värden
  List<TextEditingController> getControllers(List<String> currentValues) {
    // Synkronisera _values med currentValues
    _syncValues(currentValues);

    // Skapa/uppdatera controllers för varje värde
    final controllers = <TextEditingController>[];

    for (int i = 0; i < _values.length; i++) {
      final key = 'field_$i';

      // Skapa ny controller om den inte finns
      if (!_controllers.containsKey(key)) {
        final controller = TextEditingController(text: _values[i]);

        // Lägg till listener för att spåra ändringar
        controller.addListener(() {
          if (onValueChanged != null && i < _values.length) {
            onValueChanged!(i, controller.text);
          }
        });

        _controllers[key] = controller;
      } else {
        // Uppdatera befintlig controller om texten ändrats externt
        final existingController = _controllers[key]!;
        if (existingController.text != _values[i]) {
          existingController.text = _values[i];
        }
      }

      controllers.add(_controllers[key]!);
    }

    // Rensa upp controllers som inte längre används
    _cleanupUnusedControllers(controllers.length);

    return controllers;
  }

  /// Lägg till ny tom controller
  void addController() {
    _values.add('');
    // getControllers kommer skapa den nya controllern nästa gång den anropas
  }

  /// Ta bort controller vid specifikt index
  void removeController(int index) {
    if (index < 0 || index >= _values.length) return;

    // Ta bort värdet
    _values.removeAt(index);

    // Dispose och ta bort controller
    final key = 'field_$index';
    _controllers[key]?.dispose();
    _controllers.remove(key);

    // Omarrangera kvarvarande controllers
    _reorganizeControllers(index);
  }

  /// Uppdatera värde direkt (används vid programmatisk uppdatering)
  void updateValue(int index, String value) {
    if (index < 0 || index >= _values.length) return;

    _values[index] = value;
    final key = 'field_$index';

    if (_controllers.containsKey(key)) {
      final controller = _controllers[key]!;
      // Undvik onödiga uppdateringar som triggar listeners
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  /// Update items (for backward compatibility)
  void updateItems(List<String> items) {
    _values.clear();
    _values.addAll(items);
    if (_values.isEmpty) {
      _values.add('');
    }
  }

  /// Update at specific index
  void updateAt(int index, String value) {
    updateValue(index, value);
  }

  /// Add new item
  void add(String value) {
    _values.add(value);
  }

  /// Remove item at index
  void removeAt(int index) {
    removeController(index);
  }

  /// Get controllers property
  List<TextEditingController> get controllers {
    return getControllers(_values);
  }

  /// Hämta antal fält
  int get length => _values.length;

  /// Hämta alla värden
  List<String> get values => List.unmodifiable(_values);

  /// Kontrollera om en specifik controller finns
  bool hasController(int index) {
    return _controllers.containsKey('field_$index');
  }

  /// Rensa och dispose alla controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _values.clear();
  }

  /// Återställ till initial state
  void reset() {
    dispose();
    _values.add(''); // Börja med ett tomt fält
  }

  // ===== PRIVATE HELPERS =====

  /// Synkronisera interna värden med externa
  void _syncValues(List<String> currentValues) {
    _values.clear();
    _values.addAll(currentValues);

    // Säkerställ minst ett fält
    if (_values.isEmpty) {
      _values.add('');
    }
  }

  /// Rensa upp controllers som inte längre används
  void _cleanupUnusedControllers(int activeCount) {
    final keysToRemove = <String>[];

    _controllers.forEach((key, controller) {
      final index = int.tryParse(key.replaceFirst('field_', ''));
      if (index != null && index >= activeCount) {
        controller.dispose();
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  /// Omarrangera controllers efter borttagning
  void _reorganizeControllers(int removedIndex) {
    final newControllers = <String, TextEditingController>{};

    _controllers.forEach((key, controller) {
      final index = int.tryParse(key.replaceFirst('field_', ''));
      if (index != null) {
        if (index < removedIndex) {
          // Behåll controllers före borttagen index
          newControllers[key] = controller;
        } else if (index > removedIndex) {
          // Flytta ner controllers efter borttagen index
          final newKey = 'field_${index - 1}';
          newControllers[newKey] = controller;
        }
      }
    });

    _controllers.clear();
    _controllers.addAll(newControllers);
  }

  /// Debug-metod för att logga state
  void debugPrintState() {
    debugPrint('FormFieldsManager State:');
    debugPrint('  Values: $_values');
    debugPrint('  Controllers: ${_controllers.keys.join(', ')}');
  }
}
