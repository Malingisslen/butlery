/// Test mode configuration for repositories
/// 
/// Provides a way to configure repositories to work in test mode
/// where FieldValue operations are replaced with test-safe alternatives.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Global test mode configuration
class TestModeConfig {
  TestModeConfig._();
  
  static bool _isTestMode = false;
  static bool _useTestFieldValues = false;
  
  /// Check if running in test mode
  static bool get isTestMode => _isTestMode;
  
  /// Check if should use test field values
  static bool get useTestFieldValues => _useTestFieldValues;
  
  /// Enable test mode
  static void enableTestMode({bool useTestFieldValues = true}) {
    _isTestMode = true;
    _useTestFieldValues = useTestFieldValues;
  }
  
  /// Disable test mode
  static void disableTestMode() {
    _isTestMode = false;
    _useTestFieldValues = false;
  }
  
  /// Get server timestamp (returns FieldValue or DateTime based on mode)
  static dynamic serverTimestamp() {
    if (_useTestFieldValues) {
      return DateTime.now();
    }
    return FieldValue.serverTimestamp();
  }
  
  /// Get array union (returns FieldValue or List based on mode)
  static dynamic arrayUnion(List<dynamic> elements) {
    if (_useTestFieldValues) {
      return elements; // In test mode, just return the elements
    }
    return FieldValue.arrayUnion(elements);
  }
  
  /// Get array remove (returns FieldValue or List based on mode)
  static dynamic arrayRemove(List<dynamic> elements) {
    if (_useTestFieldValues) {
      return elements; // In test mode, just return the elements
    }
    return FieldValue.arrayRemove(elements);
  }
  
  /// Get increment value (returns FieldValue or number based on mode)
  static dynamic increment(num n) {
    if (_useTestFieldValues) {
      return n; // In test mode, just return the increment value
    }
    return FieldValue.increment(n);
  }
  
  /// Get delete field value
  static dynamic delete() {
    if (_useTestFieldValues) {
      return null; // In test mode, use null
    }
    return FieldValue.delete();
  }
  
  /// Apply increment to a value in test mode
  static num applyIncrement(num currentValue, dynamic incrementValue) {
    if (_useTestFieldValues && incrementValue is num) {
      return currentValue + incrementValue;
    }
    // In production mode, Firestore handles this
    return currentValue;
  }
  
  /// Apply array union in test mode
  static List<T> applyArrayUnion<T>(List<T> current, dynamic unionValue) {
    if (_useTestFieldValues && unionValue is List) {
      final result = List<T>.from(current);
      for (final item in unionValue) {
        if (item is T && !result.contains(item)) {
          result.add(item);
        }
      }
      return result;
    }
    // In production mode, Firestore handles this
    return current;
  }
  
  /// Apply array remove in test mode
  static List<T> applyArrayRemove<T>(List<T> current, dynamic removeValue) {
    if (_useTestFieldValues && removeValue is List) {
      final result = List<T>.from(current);
      result.removeWhere((item) => removeValue.contains(item));
      return result;
    }
    // In production mode, Firestore handles this
    return current;
  }
}

/// Mixin for repositories to support test mode
mixin TestModeMixin {
  /// Get server timestamp based on test mode
  dynamic getServerTimestamp() => TestModeConfig.serverTimestamp();
  
  /// Get array union based on test mode
  dynamic getArrayUnion(List<dynamic> elements) => TestModeConfig.arrayUnion(elements);
  
  /// Get array remove based on test mode
  dynamic getArrayRemove(List<dynamic> elements) => TestModeConfig.arrayRemove(elements);
  
  /// Get increment based on test mode
  dynamic getIncrement(num n) => TestModeConfig.increment(n);
  
  /// Get delete based on test mode
  dynamic getDelete() => TestModeConfig.delete();
  
  /// Check if in test mode
  bool get isTestMode => TestModeConfig.isTestMode;
  
  /// Handle field value in test mode
  dynamic handleFieldValue(dynamic value, dynamic testValue) {
    if (TestModeConfig.useTestFieldValues) {
      return testValue;
    }
    return value;
  }
}