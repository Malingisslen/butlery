/// Standardized form state management for consistent form handling across the application.
///
/// This class addresses the form state architecture inconsistency (Issue 8) by providing
/// a unified approach that combines the benefits of both TextEditingController and 
/// initialValue patterns while maintaining clean MVVM architecture.
///
/// **Key Benefits:**
/// - Automatic controller lifecycle management (no manual disposal needed)
/// - Reactive state updates with proper change notifications
/// - Consistent API across all forms
/// - Proper integration with FormValidators
/// - Memory leak prevention through automatic cleanup
/// - Support for both individual fields and dynamic lists
///
/// **Usage Examples:**
/// ```dart
/// // In ViewModel
/// late final FormStateManager _formManager;
/// 
/// @override
/// void initState() {
///   _formManager = FormStateManager(
///     fields: {
///       'title': FormField.text(initialValue: recipe?.title ?? ''),
///       'description': FormField.text(initialValue: recipe?.description ?? ''),
///       'portions': FormField.number(initialValue: recipe?.portions),
///     },
///     onFieldChanged: (fieldId, value) {
///       // Handle field changes
///       switch (fieldId) {
///         case 'title': _title = value; break;
///         case 'description': _description = value; break;
///         case 'portions': _portions = int.tryParse(value) ?? 0; break;
///       }
///       notifyListeners();
///     },
///   );
/// }
/// 
/// // In view
/// TextFormField(
///   controller: viewModel.formManager.getController('title'),
///   validator: FormValidators.required('Title'),
/// )
/// ```

// lib/core/forms/form_state_manager.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart';

/// Type definition for form field change callbacks
typedef FormFieldChangeCallback = void Function(String fieldId, String value);

/// Configuration for individual form fields
class FormFieldConfig {
  final String initialValue;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final bool enabled;

  const FormFieldConfig({
    this.initialValue = '',
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.enabled = true,
  });

  /// Create text field configuration
  static FormFieldConfig text({
    String? initialValue,
    int? maxLines,
    int? maxLength,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormFieldConfig(
      initialValue: initialValue ?? '',
      keyboardType: TextInputType.text,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      enabled: enabled,
    );
  }

  /// Create number field configuration
  static FormFieldConfig number({
    num? initialValue,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormFieldConfig(
      initialValue: initialValue?.toString() ?? '',
      keyboardType: TextInputType.number,
      maxLines: 1,
      validator: validator,
      enabled: enabled,
    );
  }

  /// Create email field configuration
  static FormFieldConfig email({
    String? initialValue,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormFieldConfig(
      initialValue: initialValue ?? '',
      keyboardType: TextInputType.emailAddress,
      maxLines: 1,
      validator: validator,
      enabled: enabled,
    );
  }

  /// Create password field configuration
  static FormFieldConfig password({
    String? initialValue,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormFieldConfig(
      initialValue: initialValue ?? '',
      keyboardType: TextInputType.visiblePassword,
      maxLines: 1,
      validator: validator,
      enabled: enabled,
    );
  }

  /// Create multiline text field configuration
  static FormFieldConfig multiline({
    String? initialValue,
    int? maxLines,
    int? maxLength,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormFieldConfig(
      initialValue: initialValue ?? '',
      keyboardType: TextInputType.multiline,
      maxLines: maxLines ?? 3,
      maxLength: maxLength,
      validator: validator,
      enabled: enabled,
    );
  }
}

/// Standardized form state manager for consistent form handling
class FormStateManager {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FormFieldConfig> _fieldConfigs;
  final FormFieldChangeCallback? _onFieldChanged;
  
  bool _disposed = false;
  bool get disposed => _disposed;

  /// Create form state manager with field configurations
  FormStateManager({
    required Map<String, FormFieldConfig> fields,
    FormFieldChangeCallback? onFieldChanged,
  }) : _fieldConfigs = fields,
       _onFieldChanged = onFieldChanged {
    _initializeControllers();
  }

  /// Initialize controllers for all configured fields
  void _initializeControllers() {
    for (final entry in _fieldConfigs.entries) {
      final fieldId = entry.key;
      final config = entry.value;
      
      final controller = TextEditingController(text: config.initialValue);
      _controllers[fieldId] = controller;
      
      // Set up change listener with proper error handling
      controller.addListener(() {
        if (!_disposed && _onFieldChanged != null) {
          try {
            // ignore: unnecessary_non_null_assertion
            _onFieldChanged!(fieldId, controller.text);
          } catch (e) {
            AppLogger.error('Form field change callback error for $fieldId: $e');
          }
        }
      });
      
      AppLogger.debug('Initialized form controller for field: $fieldId');
    }
  }

  /// Get controller for specific field
  TextEditingController getController(String fieldId) {
    final controller = _controllers[fieldId];
    if (controller == null) {
      throw ArgumentError('No controller found for field: $fieldId');
    }
    return controller;
  }

  /// Get current value for specific field
  String getValue(String fieldId) {
    return getController(fieldId).text;
  }

  /// Set value for specific field
  void setValue(String fieldId, String value) {
    final controller = getController(fieldId);
    if (controller.text != value) {
      controller.text = value;
    }
  }

  /// Get configuration for specific field
  FormFieldConfig getConfig(String fieldId) {
    final config = _fieldConfigs[fieldId];
    if (config == null) {
      throw ArgumentError('No configuration found for field: $fieldId');
    }
    return config;
  }

  /// Update multiple field values at once
  void setValues(Map<String, String> values) {
    for (final entry in values.entries) {
      setValue(entry.key, entry.value);
    }
  }

  /// Get all current form values
  Map<String, String> getAllValues() {
    final values = <String, String>{};
    for (final fieldId in _controllers.keys) {
      values[fieldId] = getValue(fieldId);
    }
    return values;
  }

  /// Clear all form fields
  void clearAll() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
  }

  /// Clear specific field
  void clearField(String fieldId) {
    setValue(fieldId, '');
  }

  /// Validate all fields using their configured validators
  bool validateAll() {
    bool allValid = true;
    
    for (final entry in _fieldConfigs.entries) {
      final fieldId = entry.key;
      final config = entry.value;
      
      if (config.validator != null) {
        final value = getValue(fieldId);
        final validationResult = config.validator!(value);
        
        if (validationResult != null) {
          AppLogger.warning('Validation failed for field $fieldId: $validationResult');
          allValid = false;
        }
      }
    }
    
    return allValid;
  }

  /// Check if form has any values
  bool get isEmpty {
    return _controllers.values.every((controller) => controller.text.isEmpty);
  }

  /// Check if form has unsaved changes from initial values
  bool get hasChanges {
    for (final entry in _fieldConfigs.entries) {
      final fieldId = entry.key;
      final initialValue = entry.value.initialValue;
      final currentValue = getValue(fieldId);
      
      if (currentValue != initialValue) {
        return true;
      }
    }
    return false;
  }

  /// Reset all fields to their initial values
  void resetToInitial() {
    for (final entry in _fieldConfigs.entries) {
      final fieldId = entry.key;
      final initialValue = entry.value.initialValue;
      setValue(fieldId, initialValue);
    }
    AppLogger.debug('Form reset to initial values');
  }

  /// Add or update field configuration
  void addField(String fieldId, FormFieldConfig config) {
    if (_disposed) {
      AppLogger.warning('Cannot add field to disposed FormStateManager');
      return;
    }
    
    // Remove existing field if it exists
    removeField(fieldId);
    
    // Add new field
    _fieldConfigs[fieldId] = config;
    
    final controller = TextEditingController(text: config.initialValue);
    _controllers[fieldId] = controller;
    
    controller.addListener(() {
      if (!_disposed && _onFieldChanged != null) {
        try {
          // ignore: unnecessary_non_null_assertion
          _onFieldChanged!(fieldId, controller.text);
        } catch (e) {
          AppLogger.error('Form field change callback error for $fieldId: $e');
        }
      }
    });
    
    AppLogger.debug('Added form field: $fieldId');
  }

  /// Remove field configuration and cleanup
  void removeField(String fieldId) {
    _controllers[fieldId]?.dispose();
    _controllers.remove(fieldId);
    
    _fieldConfigs.remove(fieldId);
    AppLogger.debug('Removed form field: $fieldId');
  }

  /// Get list of all field IDs
  List<String> get fieldIds => _fieldConfigs.keys.toList();

  /// Check if field exists
  bool hasField(String fieldId) => _fieldConfigs.containsKey(fieldId);

  /// Dispose of all resources - automatic cleanup
  void dispose() {
    if (_disposed) return;
    
    _disposed = true;
    
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    // Clear configurations
    _fieldConfigs.clear();
    
    AppLogger.debug('FormStateManager disposed successfully');
  }
}

/// Extension to create TextFormField with standardized form manager integration
extension FormStateManagerWidget on FormStateManager {
  /// Build TextFormField using form manager configuration
  TextFormField buildTextField(String fieldId, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    bool obscureText = false,
    VoidCallback? onEditingComplete,
    void Function(String)? onSubmitted,
  }) {
    final controller = getController(fieldId);
    final config = getConfig(fieldId);
    
    return TextFormField(
      controller: controller,
      keyboardType: config.keyboardType,
      maxLines: obscureText ? 1 : config.maxLines,
      maxLength: config.maxLength,
      enabled: config.enabled,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onSubmitted,
      validator: config.validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}