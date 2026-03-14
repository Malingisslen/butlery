import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstraction for server timestamp generation.
///
/// Production code uses [ServerTimestampProvider] which returns
/// `FieldValue.serverTimestamp()`. Tests inject [TestTimestampProvider]
/// which returns a real `Timestamp`, avoiding the FakeFirebaseFirestore
/// limitation where FieldValue sentinels are unsupported.
abstract class TimestampProvider {
  /// Returns a value suitable for Firestore timestamp fields.
  ///
  /// In production: `FieldValue.serverTimestamp()` (sentinel).
  /// In tests: `Timestamp.fromDate(DateTime.now())` (concrete value).
  Object serverTimestamp();
}

/// Production implementation that uses Firestore server timestamps.
class ServerTimestampProvider implements TimestampProvider {
  const ServerTimestampProvider();

  @override
  Object serverTimestamp() => FieldValue.serverTimestamp();
}

/// Test implementation that returns a concrete Timestamp.
///
/// Use this when creating repositories with FakeFirebaseFirestore,
/// which does not support FieldValue sentinel values.
class TestTimestampProvider implements TimestampProvider {
  const TestTimestampProvider();

  @override
  Object serverTimestamp() => Timestamp.fromDate(DateTime.now());
}
