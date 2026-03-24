/// Test helpers for FakeFirebaseFirestore FieldValue limitations.
///
/// When TestServiceLocator is initialized, it registers real Firebase platform
/// bindings that conflict with FakeFirebaseFirestore's MockFieldValuePlatform.
/// This causes FieldValue.serverTimestamp(), FieldValue.increment(), etc. to
/// throw 'MethodChannelFieldValue is not a subtype of MockFieldValuePlatform'.
///
/// These helpers provide workarounds:
/// - For serverTimestamp: inject TestTimestampProvider into repositories
/// - For increment/arrayUnion/arrayRemove: use these read-modify-write helpers
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers that work around FakeFirebaseFirestore's FieldValue limitations
/// when TestServiceLocator has registered real Firebase platform bindings.
class FakeFirebaseHelpers {
  FakeFirebaseHelpers._();

  /// Increment a numeric field on a document using read-modify-write.
  ///
  /// Use this instead of calling production methods that use
  /// FieldValue.increment() internally.
  static Future<void> incrementField(
    DocumentReference doc,
    String field,
    num value,
  ) async {
    final snapshot = await doc.get();
    final data = snapshot.data() as Map<String, dynamic>?;
    final current = (data?[field] ?? 0) as num;
    await doc.update({field: current + value});
  }

  /// Union elements into an array field using read-modify-write.
  ///
  /// Use this instead of calling production methods that use
  /// FieldValue.arrayUnion() internally.
  static Future<void> arrayUnionField(
    DocumentReference doc,
    String field,
    List<dynamic> elements,
  ) async {
    final snapshot = await doc.get();
    final data = snapshot.data() as Map<String, dynamic>?;
    final current = List<dynamic>.from(data?[field] ?? []);
    for (final element in elements) {
      if (!current.contains(element)) {
        current.add(element);
      }
    }
    await doc.update({field: current});
  }

  /// Remove elements from an array field using read-modify-write.
  ///
  /// Use this instead of calling production methods that use
  /// FieldValue.arrayRemove() internally.
  static Future<void> arrayRemoveField(
    DocumentReference doc,
    String field,
    List<dynamic> elements,
  ) async {
    final snapshot = await doc.get();
    final data = snapshot.data() as Map<String, dynamic>?;
    final current = List<dynamic>.from(data?[field] ?? []);
    current.removeWhere((item) => elements.contains(item));
    await doc.update({field: current});
  }

  /// Set a document with server timestamp fields replaced by Timestamp.now().
  ///
  /// Use this instead of calling production methods whose toFirestore()
  /// embeds FieldValue.serverTimestamp() directly.
  static Future<void> setWithTimestamp(
    DocumentReference doc,
    Map<String, dynamic> data, {
    List<String> timestampFields = const [
      'timestamp',
      'createdAt',
      'updatedAt'
    ],
  }) async {
    final cleanData = Map<String, dynamic>.from(data);
    for (final field in timestampFields) {
      if (cleanData.containsKey(field)) {
        cleanData[field] = Timestamp.now();
      }
    }
    await doc.set(cleanData);
  }

  /// Add a document with server timestamp fields replaced by Timestamp.now().
  static Future<DocumentReference> addWithTimestamp(
    CollectionReference collection,
    Map<String, dynamic> data, {
    List<String> timestampFields = const [
      'timestamp',
      'createdAt',
      'updatedAt'
    ],
  }) async {
    final cleanData = Map<String, dynamic>.from(data);
    for (final field in timestampFields) {
      if (cleanData.containsKey(field)) {
        cleanData[field] = Timestamp.now();
      }
    }
    return collection.add(cleanData);
  }
}
