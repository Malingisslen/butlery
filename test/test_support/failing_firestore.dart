import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Firestore whose every read fails the way a missing index does. The
/// installed fake_cloud_firestore has no failure injection, so this Fake stands
/// in; it throws on the first call a repository makes, which is all a
/// "failure propagates" test needs.
class FailingFirestore extends Fake implements FirebaseFirestore {
  static FirebaseException get failure => FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
  );

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw failure;

  @override
  Query<Map<String, dynamic>> collectionGroup(String collectionId) =>
      throw failure;
}

Matcher get throwsFirestoreFailure => throwsA(
  isA<FirebaseException>().having((e) => e.code, 'code', 'failed-precondition'),
);
