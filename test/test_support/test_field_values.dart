/// Test-safe FieldValue operations for FakeFirebaseFirestore
/// 
/// This provides alternatives to Firebase FieldValue operations that work
/// correctly with FakeFirebaseFirestore and prevent type mismatch errors.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Test-safe alternatives to FieldValue operations
/// 
/// Use these instead of FieldValue.* in tests to avoid type mismatches
/// with FakeFirebaseFirestore's MockFieldValuePlatform.
class TestFieldValues {
  TestFieldValues._();
  
  /// Get server timestamp (returns current DateTime)
  /// 
  /// Use this instead of FieldValue.serverTimestamp() in tests
  static DateTime serverTimestamp() => DateTime.now();
  
  /// Array union operation (manually adds items)
  /// 
  /// Use this to add items to an array field
  static List<T> arrayUnion<T>(List<T> current, List<T> itemsToAdd) {
    final result = List<T>.from(current);
    for (final item in itemsToAdd) {
      if (!result.contains(item)) {
        result.add(item);
      }
    }
    return result;
  }
  
  /// Array remove operation (manually removes items)
  /// 
  /// Use this to remove items from an array field
  static List<T> arrayRemove<T>(List<T> current, List<T> itemsToRemove) {
    final result = List<T>.from(current);
    result.removeWhere((item) => itemsToRemove.contains(item));
    return result;
  }
  
  /// Increment operation (manually increments a number)
  /// 
  /// Use this instead of FieldValue.increment() in tests
  static num increment(num current, num incrementBy) {
    return current + incrementBy;
  }
  
  /// Delete field operation (returns null)
  /// 
  /// Use this instead of FieldValue.delete() in tests
  static Null deleteField() => null;
  
  /// Convert Timestamp to DateTime safely
  /// 
  /// Handles both Timestamp and DateTime inputs
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    // Try to parse as DateTime string
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Convert DateTime to Timestamp safely
  /// 
  /// Returns DateTime directly as FakeFirebaseFirestore handles it
  static dynamic toTimestamp(DateTime? dateTime) {
    if (dateTime == null) return null;
    // For FakeFirebaseFirestore, just return DateTime
    // It will handle the conversion internally
    return dateTime;
  }
  
  /// Apply field value operations to a document data map
  /// 
  /// This simulates FieldValue operations for test data
  static Map<String, dynamic> applyFieldValues(
    Map<String, dynamic> data, {
    List<String>? serverTimestampFields,
    Map<String, List<dynamic>>? arrayUnionFields,
    Map<String, List<dynamic>>? arrayRemoveFields,
    Map<String, num>? incrementFields,
    List<String>? deleteFields,
  }) {
    final result = Map<String, dynamic>.from(data);
    
    // Apply server timestamps
    if (serverTimestampFields != null) {
      for (final field in serverTimestampFields) {
        result[field] = serverTimestamp();
      }
    }
    
    // Apply array unions
    if (arrayUnionFields != null) {
      arrayUnionFields.forEach((field, itemsToAdd) {
        final current = List<dynamic>.from(result[field] ?? []);
        result[field] = arrayUnion(current, itemsToAdd);
      });
    }
    
    // Apply array removes
    if (arrayRemoveFields != null) {
      arrayRemoveFields.forEach((field, itemsToRemove) {
        final current = List<dynamic>.from(result[field] ?? []);
        result[field] = arrayRemove(current, itemsToRemove);
      });
    }
    
    // Apply increments
    if (incrementFields != null) {
      incrementFields.forEach((field, incrementBy) {
        final current = (result[field] ?? 0) as num;
        result[field] = increment(current, incrementBy);
      });
    }
    
    // Apply deletes
    if (deleteFields != null) {
      for (final field in deleteFields) {
        result.remove(field);
      }
    }
    
    return result;
  }
}

/// Extension methods for easier test data manipulation
extension TestFieldValueExtensions on Map<String, dynamic> {
  /// Add server timestamp to specified fields
  Map<String, dynamic> withServerTimestamp(List<String> fields) {
    return TestFieldValues.applyFieldValues(
      this,
      serverTimestampFields: fields,
    );
  }
  
  /// Add items to array fields
  Map<String, dynamic> withArrayUnion(Map<String, List<dynamic>> fields) {
    return TestFieldValues.applyFieldValues(
      this,
      arrayUnionFields: fields,
    );
  }
  
  /// Remove items from array fields
  Map<String, dynamic> withArrayRemove(Map<String, List<dynamic>> fields) {
    return TestFieldValues.applyFieldValues(
      this,
      arrayRemoveFields: fields,
    );
  }
  
  /// Increment numeric fields
  Map<String, dynamic> withIncrement(Map<String, num> fields) {
    return TestFieldValues.applyFieldValues(
      this,
      incrementFields: fields,
    );
  }
  
  /// Delete specified fields
  Map<String, dynamic> withoutFields(List<String> fields) {
    return TestFieldValues.applyFieldValues(
      this,
      deleteFields: fields,
    );
  }
}

/// Helper for creating test documents with proper timestamps
class TestDocument {
  /// Create a document with creation and update timestamps
  static Map<String, dynamic> create({
    required Map<String, dynamic> data,
    bool includeTimestamps = true,
  }) {
    if (includeTimestamps) {
      return {
        ...data,
        'createdAt': TestFieldValues.serverTimestamp(),
        'updatedAt': TestFieldValues.serverTimestamp(),
      };
    }
    return data;
  }
  
  /// Update a document with new update timestamp
  static Map<String, dynamic> update({
    required Map<String, dynamic> data,
    required Map<String, dynamic> updates,
    bool updateTimestamp = true,
  }) {
    final result = {...data, ...updates};
    if (updateTimestamp) {
      result['updatedAt'] = TestFieldValues.serverTimestamp();
    }
    return result;
  }
}