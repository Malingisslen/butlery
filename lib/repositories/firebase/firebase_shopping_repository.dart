// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/unified/unified_shopping_item.dart';
import '../interfaces/shopping_repository.dart';

/// Repository for handling shopping lists stored in Firestore.
class FirebaseShoppingRepository implements ShoppingRepository {
  FirebaseShoppingRepository({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository();

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  String? _activeListId;

  CollectionReference<Map<String, dynamic>> _personalListsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('unified_shopping_lists');

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      _firestore.collection('unified_shared_shopping_lists');

  @override
  Future<UnifiedShoppingList> create(UnifiedShoppingList list) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw Exception('No authenticated user');
    await _personalListsRef(uid).doc(list.id).set(list.toFirestore());
    return list;
  }

  @override
  Future<UnifiedShoppingList?> read(String id) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return null;
    final doc = await _personalListsRef(uid).doc(id).get();
    if (!doc.exists) return null;
    return UnifiedShoppingList.fromFirestore(doc);
  }

  @override
  Future<List<UnifiedShoppingList>> readAll() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return [];
    final snap = await _personalListsRef(uid).get();
    return snap.docs.map(UnifiedShoppingList.fromFirestore).toList();
  }

  @override
  Future<void> update(UnifiedShoppingList list) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw Exception('No authenticated user');
    await _personalListsRef(uid).doc(list.id).update(list.toFirestore());
  }

  @override
  Future<void> delete(String id) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw Exception('No authenticated user');
    await _personalListsRef(uid).doc(id).delete();
  }

  @override
  Future<void> setActiveList(String listId) async {
    _activeListId = listId;
  }

  @override
  Future<UnifiedShoppingList?> getActiveList() async {
    if (_activeListId == null) return null;
    return read(_activeListId!);
  }

  @override
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw Exception('No authenticated user');
    await _personalListsRef(uid)
        .doc(listId)
        .collection('items')
        .doc(item.id)
        .set(item.toFirestore());
  }

  @override
  Future<void> removeItem(String listId, String itemId) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw Exception('No authenticated user');
    await _personalListsRef(uid)
        .doc(listId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  /// Create or update a personal list for the current user.
  Future<void> savePersonalList(UnifiedShoppingList list) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    await _personalListsRef(uid).doc(list.id).set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Create or update a collaborative list.
  Future<void> saveCollaborativeList(UnifiedShoppingList list) async {
    await _sharedListsRef.doc(list.id).set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Delete a personal list.
  Future<void> deletePersonalList(String listId) async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    await _personalListsRef(uid).doc(listId).delete();
  }

  /// Delete a collaborative list.
  Future<void> deleteCollaborativeList(String listId) async {
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      return const Stream.empty();
    }
    return _personalListsRef(uid)
        .snapshots()
        .map((snap) => snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
  }

  /// Fetch collaborative lists where the current user is a member.
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() {
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      return const Stream.empty();
    }
    return _sharedListsRef
        .where('memberPermissions.$uid', isNotEqualTo: null)
        .snapshots()
        .map((snap) => snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
  }
}

