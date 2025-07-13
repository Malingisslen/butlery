import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository that wraps all Firestore operations used in the app.
///
/// Services should depend on this class instead of directly using
/// [FirebaseFirestore] to make it easier to mock and to keep all
/// Firestore access in a single place.
class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Expose the raw [FirebaseFirestore] instance for low level use cases.
  FirebaseFirestore get firestore => _firestore;

  /// Stream for connectivity checks.
  Stream<QuerySnapshot<Map<String, dynamic>>> connectivityStream() {
    return _firestore.collection('connectivity_test').limit(1).snapshots();
  }

  /// Document reference for realtime resources.
  DocumentReference<Map<String, dynamic>> realtimeResourceDoc(String id) {
    return _firestore.collection('realtime_resources').doc(id);
  }

  /// Generic helpers for document operations.
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
      DocumentReference<Map<String, dynamic>> ref) {
    return ref.get();
  }

  Future<void> setDocument(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) {
    return ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteDocument(DocumentReference<Map<String, dynamic>> ref) {
    return ref.delete();
  }

  /// Collection with a user's recipes.
  CollectionReference<Map<String, dynamic>> userRecipesCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  /// Low level access for generic collections.
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  /// Low level access for generic documents.
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return _firestore.doc(path);
  }
}
