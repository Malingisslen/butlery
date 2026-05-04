/// Serialization utilities for safe data transformation

import 'package:clock/clock.dart';

class SerializationUtils {
  SerializationUtils._(); // Private constructor - utility class

  // Safe field extraction
  static String safeString(Map<String, dynamic> map, String key,
      {String defaultValue = ''}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  static String? safeNullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int safeInt(Map<String, dynamic> map, String key,
      {int defaultValue = 0}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    return parsed ?? defaultValue;
  }

  static int? safeNullableInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double safeDouble(Map<String, dynamic> map, String key,
      {double defaultValue = 0.0}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? defaultValue;
  }

  static double? safeNullableDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool safeBool(Map<String, dynamic> map, String key,
      {bool defaultValue = false}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) return value != 0;
    return defaultValue;
  }

  static bool? safeNullableBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) return value != 0;
    return null;
  }

  // Date/time serialization

  /// Parse a raw dynamic value to DateTime.
  /// Handles: DateTime, String (ISO), int (epoch millis), Timestamp (duck-typed),
  /// Map with seconds/nanoseconds keys (Firestore raw + JS SDK _seconds variant).
  static DateTime? parseDateTimeValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);

    // Firebase Timestamp (duck-typed to avoid cloud_firestore import)
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    // Raw Firestore Map {seconds, nanoseconds} or JS SDK {_seconds, _nanoseconds}
    if (value is Map) {
      final seconds = value['seconds'] as int? ?? value['_seconds'] as int?;
      if (seconds != null) {
        final nanos =
            value['nanoseconds'] as int? ?? value['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanos ~/ 1000000);
      }
    }

    return null;
  }

  /// Non-nullable variant — falls back to [defaultValue] or DateTime.now().
  static DateTime parseRequiredDateTimeValue(dynamic value,
      {DateTime? defaultValue}) {
    return parseDateTimeValue(value) ?? defaultValue ?? clock.now();
  }

  static DateTime? safeDateTime(Map<String, dynamic> map, String key) {
    return parseDateTimeValue(map[key]);
  }

  static DateTime safeRequiredDateTime(Map<String, dynamic> map, String key,
      {DateTime? defaultValue}) {
    return parseDateTimeValue(map[key]) ?? defaultValue ?? clock.now();
  }

  static dynamic serializeDateTime(DateTime? dateTime) {
    return dateTime?.toIso8601String();
  }

  // List serialization
  static List<T> safeList<T>(
      Map<String, dynamic> map, String key, T Function(dynamic) converter,
      {List<T>? defaultValue}) {
    final value = map[key];
    if (value == null) return defaultValue ?? <T>[];
    if (value is! List) return defaultValue ?? <T>[];

    final result = <T>[];
    for (final item in value) {
      try {
        result.add(converter(item));
      } catch (e) {
        // Skip invalid items
        continue;
      }
    }
    return result;
  }

  static List<String> safeStringList(Map<String, dynamic> map, String key,
      {List<String>? defaultValue}) {
    return safeList<String>(map, key, (item) => item.toString(),
        defaultValue: defaultValue);
  }

  /// Parses a map of string keys to string lists, e.g. emoji reactions.
  /// Returns null when the field is absent or not a map.
  static Map<String, List<String>>? safeStringListMap(
      Map<String, dynamic> map, String key) {
    final raw = map[key];
    if (raw == null || raw is! Map<String, dynamic>) return null;
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      if (entry.value is List) {
        result[entry.key] = List<String>.from(entry.value as List);
      }
    }
    return result;
  }

  static List<T> safeObjectList<T>(Map<String, dynamic> map, String key,
      T Function(Map<String, dynamic>) fromJson,
      {List<T>? defaultValue}) {
    return safeList<T>(
      map,
      key,
      (item) {
        if (item is Map<String, dynamic>) {
          return fromJson(item);
        } else if (item is Map) {
          return fromJson(Map<String, dynamic>.from(item));
        }
        throw ArgumentError('Invalid object format');
      },
      defaultValue: defaultValue,
    );
  }

  static List<dynamic>? serializeList<T>(
      List<T>? list, dynamic Function(T) toJson) {
    if (list == null) return null;
    return list.map(toJson).toList();
  }

  static List<String>? serializeStringList(List<String>? list) {
    return list;
  }

  // Map serialization
  static Map<String, dynamic> safeMap(Map<String, dynamic> map, String key,
      {Map<String, dynamic>? defaultValue}) {
    final value = map[key];
    if (value == null) return defaultValue ?? <String, dynamic>{};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return defaultValue ?? <String, dynamic>{};
  }

  static Map<String, dynamic>? safeNullableMap(
      Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // Nested object serialization
  static T? safeNestedObject<T>(Map<String, dynamic> map, String key,
      T Function(Map<String, dynamic>) fromJson) {
    final value = map[key];
    if (value == null) return null;

    Map<String, dynamic> objectMap;
    if (value is Map<String, dynamic>) {
      objectMap = value;
    } else if (value is Map) {
      objectMap = Map<String, dynamic>.from(value);
    } else {
      return null;
    }

    try {
      return fromJson(objectMap);
    } catch (e) {
      return null;
    }
  }

  static T safeRequiredNestedObject<T>(Map<String, dynamic> map, String key,
      T Function(Map<String, dynamic>) fromJson, T defaultValue) {
    return safeNestedObject(map, key, fromJson) ?? defaultValue;
  }

  static Map<String, dynamic>? serializeNestedObject<T>(
      T? object, Map<String, dynamic> Function(T) toJson) {
    return object != null ? toJson(object) : null;
  }

  // Enum serialization
  static T safeEnum<T>(Map<String, dynamic> map, String key, List<T> values,
      T defaultValue, String Function(T) enumToString) {
    final value = map[key];
    if (value == null) return defaultValue;

    final stringValue = value.toString();
    try {
      return values.firstWhere((e) => enumToString(e) == stringValue);
    } catch (e) {
      return defaultValue;
    }
  }

  /// Safe enum lookup by name with fallback — O(1) via .byName().
  static T safeEnumByName<T extends Enum>(
      List<T> values, String name, T defaultValue) {
    try {
      return values.byName(name);
    } catch (_) {
      return defaultValue;
    }
  }

  static T? safeNullableEnum<T>(Map<String, dynamic> map, String key,
      List<T> values, String Function(T) enumToString) {
    final value = map[key];
    if (value == null) return null;

    final stringValue = value.toString();
    try {
      return values.firstWhere((e) => enumToString(e) == stringValue);
    } catch (e) {
      return null;
    }
  }

  static String? serializeEnum<T>(
      T? enumValue, String Function(T) enumToString) {
    return enumValue != null ? enumToString(enumValue) : null;
  }

  // Validation & cleanup utilities
  static Map<String, dynamic> cleanMap(Map<String, dynamic> map) {
    final cleaned = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value != null) {
        cleaned[entry.key] = entry.value;
      }
    }
    return cleaned;
  }

  static bool hasRequiredFields(
      Map<String, dynamic> map, List<String> requiredFields) {
    for (final field in requiredFields) {
      if (!map.containsKey(field) || map[field] == null) {
        return false;
      }
    }
    return true;
  }

  static List<String> getMissingFields(
      Map<String, dynamic> map, List<String> requiredFields) {
    final missing = <String>[];
    for (final field in requiredFields) {
      if (!map.containsKey(field) || map[field] == null) {
        missing.add(field);
      }
    }
    return missing;
  }

  // Type conversion utilities
  static T? convertTo<T>(dynamic value) {
    if (value == null) return null;
    if (value is T) return value;

    // String conversions
    if (T == String) return value.toString() as T;

    // Numeric conversions
    if (T == int) {
      if (value is num) return value.toInt() as T;
      if (value is String) return int.tryParse(value) as T?;
    }

    if (T == double) {
      if (value is num) return value.toDouble() as T;
      if (value is String) return double.tryParse(value) as T?;
    }

    // Boolean conversions
    if (T == bool) {
      if (value is bool) return value as T;
      if (value is String) {
        return (value.toLowerCase() == 'true' || value == '1') as T;
      }
      if (value is num) return (value != 0) as T;
    }

    return null;
  }

  /// Safely parses a map with int keys from Firestore (which stores keys as strings).
  /// Returns null when the field is absent or not a map.
  static Map<int, int>? safeIntKeyIntMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! Map) return null;
    final result = <int, int>{};
    for (final entry in value.entries) {
      final k = int.tryParse(entry.key.toString());
      if (k != null && entry.value is num) {
        result[k] = (entry.value as num).toInt();
      }
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, T> convertMapValues<T>(
      Map<String, dynamic> map, T Function(dynamic) converter) {
    final result = <String, T>{};
    for (final entry in map.entries) {
      try {
        result[entry.key] = converter(entry.value);
      } catch (e) {
        // Skip invalid conversions
        continue;
      }
    }
    return result;
  }
}

/// Extension methods for Map&lt;String, dynamic&gt; serialization
extension MapSerializationExtensions on Map<String, dynamic> {
  String safeString(String key, {String defaultValue = ''}) =>
      SerializationUtils.safeString(this, key, defaultValue: defaultValue);

  String? safeNullableString(String key) =>
      SerializationUtils.safeNullableString(this, key);

  int safeInt(String key, {int defaultValue = 0}) =>
      SerializationUtils.safeInt(this, key, defaultValue: defaultValue);

  int? safeNullableInt(String key) =>
      SerializationUtils.safeNullableInt(this, key);

  double safeDouble(String key, {double defaultValue = 0.0}) =>
      SerializationUtils.safeDouble(this, key, defaultValue: defaultValue);

  double? safeNullableDouble(String key) =>
      SerializationUtils.safeNullableDouble(this, key);

  bool safeBool(String key, {bool defaultValue = false}) =>
      SerializationUtils.safeBool(this, key, defaultValue: defaultValue);

  bool? safeNullableBool(String key) =>
      SerializationUtils.safeNullableBool(this, key);

  DateTime? safeDateTime(String key) =>
      SerializationUtils.safeDateTime(this, key);

  List<String> safeStringList(String key, {List<String>? defaultValue}) =>
      SerializationUtils.safeStringList(this, key, defaultValue: defaultValue);

  Map<String, dynamic> safeMap(String key,
          {Map<String, dynamic>? defaultValue}) =>
      SerializationUtils.safeMap(this, key, defaultValue: defaultValue);

  T? safeNestedObject<T>(
          String key, T Function(Map<String, dynamic>) fromJson) =>
      SerializationUtils.safeNestedObject(this, key, fromJson);

  bool hasRequiredFields(List<String> requiredFields) =>
      SerializationUtils.hasRequiredFields(this, requiredFields);

  List<String> getMissingFields(List<String> requiredFields) =>
      SerializationUtils.getMissingFields(this, requiredFields);

  Map<String, dynamic> cleaned() => SerializationUtils.cleanMap(this);
}

/// Base serializable interface
abstract class Serializable {
  Map<String, dynamic> toJson();
  List<String> get requiredFields => [];
  bool get isValid => true;
}

/// Serialization mixin
mixin SerializationMixin implements Serializable {
  Map<String, dynamic> toCleanJson() {
    return SerializationUtils.cleanMap(toJson());
  }

  Map<String, dynamic> toValidatedJson() {
    if (!isValid) {
      throw StateError('Cannot serialize invalid object');
    }
    return toJson();
  }

  String toJsonString() {
    // Note: Would typically use dart:convert's jsonEncode here
    // This is a placeholder for the pattern
    return toJson().toString();
  }
}
