// lib/core/form/form_fields_manager.dart

import 'package:flutter/material.dart';

/// Hanterar TextEditingControllers för dynamiska formulärfält
///
/// Denna klass tar hand om:
/// - Skapande och borttagning av controllers
/// - Synkronisering mellan controllers och data
/// - Korrekt dispose av controllers
/// - Memory management
class FormFieldsManager {
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _values = [];
  final Function(int, String)? onValueChanged;

  FormFieldsManager({this.onValueChanged});

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
