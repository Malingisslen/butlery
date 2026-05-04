/// Extension methods providing convenient default values for nullable types.

/// String null-coalescing extensions.

import 'package:clock/clock.dart';

extension StringDefaults on String? {
  /// Returns the string or empty string if null.
  String orEmpty() => this ?? '';

  /// Returns the string or provided default if null.
  String orDefault(String defaultValue) => this ?? defaultValue;

  /// Returns the string trimmed, or empty string if null.
  String orEmptyTrimmed() => this?.trim() ?? '';

  /// Returns true if string is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if string is not null and not empty.
  bool get hasValue => this != null && this!.isNotEmpty;

  /// Returns true if string is null, empty, or contains only whitespace.
  bool get isNullOrWhitespace => this == null || this!.trim().isEmpty;
}

/// List null-coalescing extensions.
extension ListDefaults<T> on List<T>? {
  /// Returns the list or empty list if null.
  List<T> orEmpty() => this ?? <T>[];

  /// Returns the list length or 0 if null.
  int get safeLength => this?.length ?? 0;

  /// Returns true if list is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if list is not null and not empty.
  bool get hasItems => this != null && this!.isNotEmpty;

  /// Returns the first element or null if list is null or empty.
  T? get firstOrNull => this != null && this!.isNotEmpty ? this!.first : null;

  /// Returns the last element or null if list is null or empty.
  T? get lastOrNull => this != null && this!.isNotEmpty ? this!.last : null;
}

/// Map null-coalescing extensions.
extension MapDefaults<K, V> on Map<K, V>? {
  /// Returns the map or empty map if null.
  Map<K, V> orEmpty() => this ?? <K, V>{};

  /// Returns the map size or 0 if null.
  int get safeLength => this?.length ?? 0;

  /// Returns true if map is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if map is not null and not empty.
  bool get hasEntries => this != null && this!.isNotEmpty;
}

/// DateTime null-coalescing extensions.
extension DateTimeDefaults on DateTime? {
  /// Returns the datetime or current time if null.
  DateTime orNow() => this ?? clock.now();

  /// Returns the datetime or provided default if null.
  DateTime orDefault(DateTime defaultValue) => this ?? defaultValue;

  /// Returns true if datetime is null.
  bool get isNull => this == null;

  /// Returns true if datetime is not null.
  bool get hasValue => this != null;

  /// Returns ISO8601 string or empty string if null.
  String toIso8601OrEmpty() => this?.toIso8601String() ?? '';
}

/// Int null-coalescing extensions.
extension IntDefaults on int? {
  /// Returns the int value or 0 if null.
  int orZero() => this ?? 0;

  /// Returns the int value or provided default if null.
  int orDefault(int defaultValue) => this ?? defaultValue;

  /// Returns true if value is null or zero.
  bool get isNullOrZero => this == null || this == 0;

  /// Returns true if value is not null and greater than zero.
  bool get isPositive => this != null && this! > 0;
}

/// Double null-coalescing extensions.
extension DoubleDefaults on double? {
  /// Returns the double value or 0.0 if null.
  double orZero() => this ?? 0.0;

  /// Returns the double value or provided default if null.
  double orDefault(double defaultValue) => this ?? defaultValue;

  /// Returns true if value is null or zero.
  bool get isNullOrZero => this == null || this == 0.0;

  /// Returns true if value is not null and greater than zero.
  bool get isPositive => this != null && this! > 0.0;
}

/// Bool null-coalescing extensions.
extension BoolDefaults on bool? {
  /// Returns the bool value or false if null.
  bool orFalse() => this ?? false;

  /// Returns the bool value or true if null.
  bool orTrue() => this ?? true;

  /// Returns the bool value or provided default if null.
  bool orDefault(bool defaultValue) => this ?? defaultValue;
}
