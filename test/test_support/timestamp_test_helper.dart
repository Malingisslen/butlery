/// Timestamp test helper for handling DateTime and Timestamp conversions
///
/// Provides utilities for consistent timestamp handling in tests,
/// addressing issues with Firestore Timestamp vs DateTime comparisons.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for timestamp operations in tests
class TimestampTestHelper {
  TimestampTestHelper._();

  /// Convert any timestamp value to DateTime
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('Failed to parse date string: $value');
        return null;
      }
    }
    return null;
  }

  /// Convert DateTime to Timestamp
  static Timestamp toTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }

  /// Convert any value to Timestamp
  static Timestamp? toTimestampSafe(dynamic value) {
    final dateTime = toDateTime(value);
    return dateTime != null ? Timestamp.fromDate(dateTime) : null;
  }

  /// Compare two timestamp values with tolerance
  static bool areTimestampsEqual(
    dynamic timestamp1,
    dynamic timestamp2, {
    Duration tolerance = const Duration(seconds: 1),
  }) {
    final dt1 = toDateTime(timestamp1);
    final dt2 = toDateTime(timestamp2);

    if (dt1 == null || dt2 == null) return false;

    final difference = dt1.difference(dt2).abs();
    return difference <= tolerance;
  }

  /// Check if timestamp is recent (within tolerance)
  ///
  /// Uses [clock.now()] by default so `fakeAsync` / `withClock` can control
  /// the reference time. Pass [now] to override explicitly.
  static bool isRecent(
    dynamic timestamp, {
    Duration tolerance = const Duration(seconds: 5),
    DateTime? now,
  }) {
    final dt = toDateTime(timestamp);
    if (dt == null) return false;

    final reference = now ?? clock.now();
    final difference = reference.difference(dt).abs();
    return difference <= tolerance;
  }

  /// Create a test timestamp
  ///
  /// Uses [clock.now()] by default so `fakeAsync` / `withClock` can control
  /// the reference time. Pass [now] to override explicitly.
  static Timestamp createTestTimestamp({
    DateTime? dateTime,
    Duration? ago,
    Duration? fromNow,
    DateTime? now,
  }) {
    DateTime dt;

    if (dateTime != null) {
      dt = dateTime;
    } else {
      final reference = now ?? clock.now();
      if (ago != null) {
        dt = reference.subtract(ago);
      } else if (fromNow != null) {
        dt = reference.add(fromNow);
      } else {
        dt = reference;
      }
    }

    return Timestamp.fromDate(dt);
  }

  /// Create a server timestamp placeholder for tests
  /// This mimics FieldValue.serverTimestamp() behavior.
  ///
  /// Uses [clock.now()] so `fakeAsync` / `withClock` can control time.
  static dynamic serverTimestamp() {
    return Timestamp.fromDate(clock.now());
  }

  /// Convert Firestore data with timestamps to DateTime
  static Map<String, dynamic> convertTimestampsToDateTime(
    Map<String, dynamic> data,
  ) {
    final converted = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate();
      } else if (value is Map<String, dynamic>) {
        converted[key] = convertTimestampsToDateTime(value);
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Timestamp) return item.toDate();
          if (item is Map<String, dynamic>) {
            return convertTimestampsToDateTime(item);
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });

    return converted;
  }

  /// Convert DateTime values to Timestamps for Firestore
  static Map<String, dynamic> convertDateTimeToTimestamps(
    Map<String, dynamic> data,
  ) {
    final converted = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is DateTime) {
        converted[key] = Timestamp.fromDate(value);
      } else if (value is Map<String, dynamic>) {
        converted[key] = convertDateTimeToTimestamps(value);
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is DateTime) return Timestamp.fromDate(item);
          if (item is Map<String, dynamic>) {
            return convertDateTimeToTimestamps(item);
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });

    return converted;
  }

  /// Normalize timestamp for comparison (remove microseconds)
  ///
  /// Fallback for null input uses [clock.now()]; override via [now].
  static DateTime normalizeTimestamp(dynamic timestamp, {DateTime? now}) {
    final dt = toDateTime(timestamp);
    if (dt == null) return now ?? clock.now();

    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      0, // Remove milliseconds
      0, // Remove microseconds
    );
  }

  /// Create a range of timestamps for testing
  ///
  /// Uses [clock.now()] as default start so `fakeAsync` / `withClock`
  /// can control the reference time.
  static List<Timestamp> createTimestampRange({
    required int count,
    DateTime? start,
    Duration interval = const Duration(minutes: 1),
  }) {
    final startTime = start ?? clock.now();
    final timestamps = <Timestamp>[];

    for (int i = 0; i < count; i++) {
      final time = startTime.add(interval * i);
      timestamps.add(Timestamp.fromDate(time));
    }

    return timestamps;
  }

  /// Format timestamp for debugging
  static String formatTimestamp(dynamic timestamp) {
    final dt = toDateTime(timestamp);
    if (dt == null) return 'null';

    return dt.toIso8601String();
  }

  /// Check if value is a valid timestamp
  static bool isValidTimestamp(dynamic value) {
    return toDateTime(value) != null;
  }

  /// Get milliseconds since epoch from any timestamp value
  static int? toMilliseconds(dynamic timestamp) {
    final dt = toDateTime(timestamp);
    return dt?.millisecondsSinceEpoch;
  }

  /// Create test data with proper timestamps
  static Map<String, dynamic> createTestDataWithTimestamps({
    required Map<String, dynamic> data,
    List<String>? timestampFields,
  }) {
    final fields = timestampFields ?? ['createdAt', 'updatedAt', 'timestamp'];
    final result = Map<String, dynamic>.from(data);

    for (final field in fields) {
      if (!result.containsKey(field) || result[field] == null) {
        result[field] = Timestamp.fromDate(clock.now());
      } else if (result[field] is DateTime) {
        result[field] = Timestamp.fromDate(result[field] as DateTime);
      }
    }

    return result;
  }
}

/// Extension for DateTime operations in tests
extension DateTimeTestExtensions on DateTime {
  /// Convert to Firestore Timestamp
  Timestamp get asTimestamp => Timestamp.fromDate(this);

  /// Check if this DateTime is recent
  bool isRecent({Duration tolerance = const Duration(seconds: 5)}) {
    return TimestampTestHelper.isRecent(this, tolerance: tolerance);
  }

  /// Normalize for comparison (remove microseconds)
  DateTime get normalized => TimestampTestHelper.normalizeTimestamp(this);

  /// Compare with another timestamp with tolerance
  bool isCloseTo(
    dynamic other, {
    Duration tolerance = const Duration(seconds: 1),
  }) {
    return TimestampTestHelper.areTimestampsEqual(
      this,
      other,
      tolerance: tolerance,
    );
  }
}

/// Extension for Timestamp operations in tests
extension TimestampTestExtensions on Timestamp {
  /// Check if this Timestamp is recent
  bool isRecent({Duration tolerance = const Duration(seconds: 5)}) {
    return TimestampTestHelper.isRecent(this, tolerance: tolerance);
  }

  /// Normalize for comparison
  DateTime get normalized => TimestampTestHelper.normalizeTimestamp(this);

  /// Compare with another timestamp with tolerance
  bool isCloseTo(
    dynamic other, {
    Duration tolerance = const Duration(seconds: 1),
  }) {
    return TimestampTestHelper.areTimestampsEqual(
      this,
      other,
      tolerance: tolerance,
    );
  }

  /// Format for debugging
  String get formatted => TimestampTestHelper.formatTimestamp(this);
}

/// Test matcher for timestamp comparisons
class TimestampMatcher extends Matcher {
  final dynamic expected;
  final Duration tolerance;

  const TimestampMatcher(
    this.expected, {
    this.tolerance = const Duration(seconds: 1),
  });

  @override
  bool matches(dynamic item, Map matchState) {
    return TimestampTestHelper.areTimestampsEqual(
      item,
      expected,
      tolerance: tolerance,
    );
  }

  @override
  Description describe(Description description) {
    final dt = TimestampTestHelper.toDateTime(expected);
    return description.add('timestamp close to ${dt?.toIso8601String()}');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final dt = TimestampTestHelper.toDateTime(item);
    return mismatchDescription.add(
      'was ${dt?.toIso8601String()} (difference > $tolerance)',
    );
  }
}

/// Helper function to create timestamp matcher
Matcher isCloseToTimestamp(
  dynamic expected, {
  Duration tolerance = const Duration(seconds: 1),
}) {
  return TimestampMatcher(expected, tolerance: tolerance);
}

/// Matcher for recent timestamps
class RecentTimestampMatcher extends Matcher {
  final Duration tolerance;

  const RecentTimestampMatcher({
    this.tolerance = const Duration(seconds: 5),
  });

  @override
  bool matches(dynamic item, Map matchState) {
    return TimestampTestHelper.isRecent(item, tolerance: tolerance);
  }

  @override
  Description describe(Description description) {
    return description.add('recent timestamp (within $tolerance)');
  }
}

/// Helper function to check if timestamp is recent
const Matcher isRecentTimestamp = RecentTimestampMatcher();
