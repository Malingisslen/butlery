// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/unified/unified_shopping_item.dart';
import '../interfaces/shopping_repository.dart';
import 'base_firebase_repository.dart';

/// Repository for handling shopping lists stored in Firestore.
///
/// Refactored to extend BaseFirebaseRepository with UserScopedFirebaseRepository mixin,
/// eliminating 50+ lines of duplicate CRUD code and authentication checks.
class FirebaseShoppingRepository
    extends BaseFirebaseRepository<UnifiedShoppingList>
    with UserScopedFirebaseRepository<UnifiedShoppingList>
    implements ShoppingRepository {
  String? _activeListId;

  FirebaseShoppingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'unified_shopping_lists';

  @override
  UnifiedShoppingList fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      UnifiedShoppingList.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(UnifiedShoppingList entity) =>
      entity.toFirestore();

  @override
  String getId(UnifiedShoppingList entity) => entity.id;

  // ===== SHARED COLLECTIONS ACCESS =====

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      FirebaseFirestore.instance.collection('unified_shared_shopping_lists');

  // ===== ENHANCED BASE CLASS METHODS =====

  @override
  Future<List<UnifiedShoppingList>> readAll() async {
    // Override to add ordering and combine personal + shared lists
    try {
      final personalLists = await readAllSafe();
      // TODO: Add shared lists when implemented
      return personalLists;
    } catch (e) {
      return await readAllSafe();
    }
  }

  // ===== SPECIALIZED SHOPPING LIST OPERATIONS =====

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
    final uid = requireCurrentUserId();
    await getUserCollection(uid)
        .doc(listId)
        .collection('items')
        .doc(item.id)
        .set(item.toFirestore());
  }

  @override
  Future<void> removeItem(String listId, String itemId) async {
    final uid = requireCurrentUserId();
    await getUserCollection(uid)
        .doc(listId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  /// Create or update a personal list for the current user.
  /// Uses base class create/update methods for consistency.
  Future<void> savePersonalList(UnifiedShoppingList list) async {
    try {
      await update(list);
    } catch (e) {
      // If update fails (e.g., document doesn't exist), create it
      await create(list);
    }
  }

  /// Create or update a collaborative list.
  Future<void> saveCollaborativeList(UnifiedShoppingList list) async {
    await _sharedListsRef
        .doc(list.id)
        .set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Delete a personal list.
  /// Uses base class delete method for consistency.
  Future<void> deletePersonalList(String listId) async {
    await delete(listId);
  }

  /// Delete a collaborative list.
  Future<void> deleteCollaborativeList(String listId) async {
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  /// Uses base class stream methods for consistency.
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    try {
      final uid = requireCurrentUserId();
      return getUserCollection(uid)
          .snapshots()
          .map((snap) => snap.docs.map(fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  /// Fetch collaborative lists where the current user is a member.
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() {
    try {
      final uid = requireCurrentUserId();
      return _sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .snapshots()
          .map((snap) =>
              snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }
}
