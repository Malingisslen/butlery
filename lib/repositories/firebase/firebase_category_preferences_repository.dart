import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

class FirebaseCategoryPreferencesRepository
    with PermissionValidationMixin
    implements CategoryPreferencesRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  FirebaseCategoryPreferencesRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository;

  String _requireUserId() {
    final uid = _authRepository.currentUserId;
    if (uid == null) throw StateError('User not authenticated');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _prefsDoc(String userId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.categoryPreferences)
        .doc('shopping');
  }

  DocumentReference<Map<String, dynamic>> _listOrderDoc(
    String userId,
    String listId,
  ) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.listCategoryOrders)
        .doc(listId);
  }

  DocumentReference<Map<String, dynamic>> _globalOverrideDoc(String itemName) {
    return _firestore
        .collection(FirestoreCollections.categoryOverrides)
        .doc(CategoryPreferences.normalizeItemName(itemName));
  }

  @override
  Future<CategoryPreferences?> getPreferences() async {
    try {
      final userId = _requireUserId();
      final snap = await _prefsDoc(userId).get();
      if (!snap.exists || snap.data() == null) return null;
      return CategoryPreferences.fromFirestore(snap.data()!);
    } catch (e, st) {
      AppLogger.error('Failed to get category preferences: $e', st);
      return null;
    }
  }

  @override
  Future<void> savePreferences(CategoryPreferences prefs) async {
    try {
      final userId = _requireUserId();
      await _prefsDoc(userId).set(prefs.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('Failed to save category preferences: $e', st);
      rethrow;
    }
  }

  @override
  Future<ListCategoryOrder?> getListCategoryOrder(String listId) async {
    try {
      final userId = _requireUserId();
      final snap = await _listOrderDoc(userId, listId).get();
      if (!snap.exists || snap.data() == null) return null;
      return ListCategoryOrder.fromFirestore(listId, snap.data()!);
    } catch (e, st) {
      AppLogger.error('Failed to get list category order: $e', st);
      return null;
    }
  }

  @override
  Future<void> saveListCategoryOrder(ListCategoryOrder order) async {
    try {
      final userId = _requireUserId();
      await _listOrderDoc(userId, order.listId)
          .set(order.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('Failed to save list category order: $e', st);
      rethrow;
    }
  }

  @override
  Future<void> deleteListCategoryOrder(String listId) async {
    try {
      final userId = _requireUserId();
      await _listOrderDoc(userId, listId).delete();
    } catch (e, st) {
      AppLogger.error('Failed to delete list category order: $e', st);
      rethrow;
    }
  }

  @override
  Future<void> recordGlobalOverride(String itemName, String category) async {
    try {
      final normalized = CategoryPreferences.normalizeItemName(itemName);
      await _globalOverrideDoc(normalized).set({
        'overrides': {category: FieldValue.increment(1)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      // Non-blocking: global tracking failure should not break the user flow
      AppLogger.error('Failed to record global category override: $e', st);
    }
  }
}
