import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Stores user category preferences and per-list category orders.
///
/// **Data shape (multi-document repo):**
/// - `users/{uid}/category_preferences/shopping` — single doc per user with
///   the user's preferred ordering of categories.
/// - `users/{uid}/list_category_orders/{listId}` — one doc per shopping list
///   with the per-list category override.
/// - `category_overrides/{normalizedItemName}` — global aggregated overrides
///   (writable by all authenticated users; read by Cloud Functions for
///   crowd-sourced learning).
///
/// **Why it extends `BaseFirebaseRepository<Object>`:** this repo owns three
/// distinct document shapes, so the `Repository<T>` CRUD contract doesn't
/// apply. It uses the base class as an *infrastructure shell* to gain the
/// `firestore` getter, `requireCurrentUserId()`, and `logPermissionCheck()`
/// helpers — same gateway pattern as [FirebaseDataExportRepository]. The
/// four `validate*Permission` methods and `fromFirestore`/`toFirestore`/
/// `getId` throw because the base class's generic CRUD is never invoked
/// against this repo (callers use the typed methods on
/// [CategoryPreferencesRepository]).
class FirebaseCategoryPreferencesRepository
    extends BaseFirebaseRepository<Object>
    implements CategoryPreferencesRepository {
  FirebaseCategoryPreferencesRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.categoryPreferences;

  // The Repository<Object> abstractions below are unused — this gateway
  // owns three document shapes, none of which is a single CRUD entity. They
  // throw to make accidental use loud.
  @override
  Object fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      throw UnsupportedError(
        'FirebaseCategoryPreferencesRepository: use typed accessors',
      );

  @override
  Map<String, dynamic> toFirestore(Object entity) => throw UnsupportedError(
    'FirebaseCategoryPreferencesRepository: use typed accessors',
  );

  @override
  String getId(Object entity) => throw UnsupportedError(
    'FirebaseCategoryPreferencesRepository: use typed accessors',
  );

  // The four permission hooks below would bypass per-method ownership checks
  // if the base class's generic CRUD ever called them. Throw so a stray call
  // surfaces immediately rather than silently allowing/denying.
  @override
  Future<bool> validateCreatePermission(String userId, Object entity) async =>
      throw UnsupportedError(
        'FirebaseCategoryPreferencesRepository: use typed accessors',
      );

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    Object? entity,
  ) async => throw UnsupportedError(
    'FirebaseCategoryPreferencesRepository: use typed accessors',
  );

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    Object entity,
  ) async => throw UnsupportedError(
    'FirebaseCategoryPreferencesRepository: use typed accessors',
  );

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => throw UnsupportedError(
    'FirebaseCategoryPreferencesRepository: use typed accessors',
  );

  DocumentReference<Map<String, dynamic>> _prefsDoc(String userId) {
    return firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.categoryPreferences)
        .doc('shopping');
  }

  DocumentReference<Map<String, dynamic>> _listOrderDoc(
    String userId,
    String listId,
  ) {
    return firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.listCategoryOrders)
        .doc(listId);
  }

  DocumentReference<Map<String, dynamic>> _globalOverrideDoc(String itemName) {
    return firestore
        .collection(FirestoreCollections.categoryOverrides)
        .doc(CategoryPreferences.normalizeItemName(itemName));
  }

  /// Emit an audit-log entry for an owner-scoped operation. Ownership is
  /// **structural** — the doc path is `users/{requireCurrentUserId()}/...`,
  /// so a request can only ever reach the user's own doc, and Firestore
  /// security rules enforce the same constraint at the wire layer. The
  /// `granted: true` reflects "structural ownership held by construction,"
  /// not a runtime check on this layer.
  Future<void> _logSelfAccess({
    required String userId,
    required String resource,
    required String operation,
  }) async {
    await logPermissionCheck(
      userId: userId,
      resource: resource,
      operation: operation,
      granted: true,
    );
  }

  @override
  Future<CategoryPreferences?> getPreferences() async {
    try {
      final userId = requireCurrentUserId();
      await _logSelfAccess(
        userId: userId,
        resource: 'CategoryPreferences/$userId/shopping',
        operation: 'read',
      );
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
      final userId = requireCurrentUserId();
      await _logSelfAccess(
        userId: userId,
        resource: 'CategoryPreferences/$userId/shopping',
        operation: 'update',
      );
      await _prefsDoc(userId).set(prefs.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('Failed to save category preferences: $e', st);
      rethrow;
    }
  }

  @override
  Future<ListCategoryOrder?> getListCategoryOrder(String listId) async {
    try {
      final userId = requireCurrentUserId();
      await _logSelfAccess(
        userId: userId,
        resource: 'ListCategoryOrder/$userId/$listId',
        operation: 'read',
      );
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
      final userId = requireCurrentUserId();
      await _logSelfAccess(
        userId: userId,
        resource: 'ListCategoryOrder/$userId/${order.listId}',
        operation: 'update',
      );
      await _listOrderDoc(
        userId,
        order.listId,
      ).set(order.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('Failed to save list category order: $e', st);
      rethrow;
    }
  }

  @override
  Future<void> deleteListCategoryOrder(String listId) async {
    try {
      final userId = requireCurrentUserId();
      await _logSelfAccess(
        userId: userId,
        resource: 'ListCategoryOrder/$userId/$listId',
        operation: 'delete',
      );
      await _listOrderDoc(userId, listId).delete();
    } catch (e, st) {
      AppLogger.error('Failed to delete list category order: $e', st);
      rethrow;
    }
  }

  @override
  Future<void> recordGlobalOverride(String itemName, String category) async {
    try {
      // Global aggregation collection — auth required (rules) but no
      // ownership check (every authenticated user contributes to the same
      // shared signal). Best-effort: failures must NOT break the user flow.
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
