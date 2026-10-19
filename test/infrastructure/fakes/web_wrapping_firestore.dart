import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart' show Fake;

/// What the web plugin hands back when a transaction fails: a plain error
/// that is not a Firebase type and does not name the error inside it.
class WebJsErrorStandIn implements Exception {
  @override
  String toString() => 'WebJsErrorStandIn';
}

/// [inner] with `runTransaction` failing as the web plugin does: whatever
/// the handler throws comes out as [WebJsErrorStandIn]. Only the members the
/// repositories under test call are forwarded.
class WebWrappingFirestore extends Fake implements FirebaseFirestore {
  WebWrappingFirestore(this.inner);

  final FakeFirebaseFirestore inner;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      inner.collection(path);

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => inner.doc(path);

  @override
  WriteBatch batch() => inner.batch();

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    try {
      return await inner.runTransaction(handler, timeout: timeout);
    } catch (_) {
      throw WebJsErrorStandIn();
    }
  }
}
