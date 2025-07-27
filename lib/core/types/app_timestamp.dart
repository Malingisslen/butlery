// lib/core/types/app_timestamp.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain-agnostic timestamp abstraction that wraps platform-specific implementations
/// 
/// This abstraction allows models to be independent of Firebase Timestamp while
/// still supporting efficient serialization to/from Firestore.
class AppTimestamp {
  final DateTime _dateTime;

  const AppTimestamp._(this._dateTime);

  /// Create AppTimestamp from DateTime
  factory AppTimestamp.fromDateTime(DateTime dateTime) => 
      AppTimestamp._(dateTime);

  /// Create AppTimestamp from current time
  factory AppTimestamp.now() => 
      AppTimestamp._(DateTime.now());

  /// Create AppTimestamp from Firestore Timestamp (repository layer only)
  factory AppTimestamp.fromFirestore(Timestamp timestamp) => 
      AppTimestamp._(timestamp.toDate());

  /// Create AppTimestamp from milliseconds since epoch
  factory AppTimestamp.fromMilliseconds(int milliseconds) => 
      AppTimestamp._(DateTime.fromMillisecondsSinceEpoch(milliseconds));

  /// Create AppTimestamp from ISO string
  factory AppTimestamp.fromIsoString(String isoString) => 
      AppTimestamp._(DateTime.parse(isoString));

  /// Get underlying DateTime
  DateTime get dateTime => _dateTime;

  /// Convert to Firestore Timestamp (repository layer only)
  Timestamp toFirestore() => Timestamp.fromDate(_dateTime);

  /// Convert to milliseconds since epoch
  int toMilliseconds() => _dateTime.millisecondsSinceEpoch;

  /// Convert to ISO string
  String toIsoString() => _dateTime.toIso8601String();

  /// Convenience getters
  int get year => _dateTime.year;
  int get month => _dateTime.month;
  int get day => _dateTime.day;
  int get hour => _dateTime.hour;
  int get minute => _dateTime.minute;
  int get second => _dateTime.second;

  /// Comparison operators
  bool isBefore(AppTimestamp other) => _dateTime.isBefore(other._dateTime);
  bool isAfter(AppTimestamp other) => _dateTime.isAfter(other._dateTime);
  bool isAtSameMomentAs(AppTimestamp other) => _dateTime.isAtSameMomentAs(other._dateTime);

  /// Duration operations
  AppTimestamp add(Duration duration) => 
      AppTimestamp._(_dateTime.add(duration));
  
  AppTimestamp subtract(Duration duration) => 
      AppTimestamp._(_dateTime.subtract(duration));

  Duration difference(AppTimestamp other) => 
      _dateTime.difference(other._dateTime);

  /// Equality and hash
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppTimestamp && other._dateTime == _dateTime;
  }

  @override
  int get hashCode => _dateTime.hashCode;

  @override
  String toString() => _dateTime.toString();

  /// JSON serialization support
  Map<String, dynamic> toJson() => {
    'timestamp': _dateTime.millisecondsSinceEpoch,
  };

  /// JSON deserialization support
  factory AppTimestamp.fromJson(Map<String, dynamic> json) => 
      AppTimestamp.fromMilliseconds(json['timestamp'] as int);
}