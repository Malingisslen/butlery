// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/unified/unified_shopping_list.dart';

/// Repository for handling shopping lists stored in Firestore.
class FirebaseShoppingRepository {
  FirebaseShoppingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _personalListsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('unified_shopping_lists');

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      _firestore.collection('unified_shared_shopping_lists');

  /// Create or update a personal list for the current user.
  Future<void> savePersonalList(UnifiedShoppingList list) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _personalListsRef(uid).doc(list.id).set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Create or update a collaborative list.
  Future<void> saveCollaborativeList(UnifiedShoppingList list) async {
    await _sharedListsRef.doc(list.id).set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Delete a personal list.
  Future<void> deletePersonalList(String listId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _personalListsRef(uid).doc(listId).delete();
  }

  /// Delete a collaborative list.
  Future<void> deleteCollaborativeList(String listId) async {
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _personalListsRef(uid)
        .snapshots()
        .map((snap) => snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
  }

  /// Fetch collaborative lists where the current user is a member.
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _sharedListsRef
        .where('memberPermissions.$uid', isNotEqualTo: null)
        .snapshots()
        .map((snap) => snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
  }
}

