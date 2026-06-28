import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// Firestore implementation of [HouseholdRepository].
///
/// Top-level `households` collection (NOT user-scoped). Access is gated by
/// membership: a member can read; only an admin can update the household
/// (membership/name changes) or delete it. Permission checks for update/delete
/// read the CURRENT document — never the caller-supplied new state — so a
/// caller cannot grant themselves admin by submitting an elevated entity.
/// Firestore rules are the authoritative second layer (see firestore.rules).
class FirebaseHouseholdRepository extends BaseFirebaseRepository<Household>
    implements HouseholdRepository {
  /// A user belongs to ~1 household; 50 is a generous ceiling that also caps
  /// the read fan-out if the data is ever malformed.
  static const int _maxHouseholdsPerUser = 50;

  FirebaseHouseholdRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.households;

  @override
  Household fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Household.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(Household entity) => entity.toFirestore();

  @override
  String getId(Household entity) => entity.id;

  /// Loads the stored household without running read-permission validation —
  /// used internally by update/delete permission checks to inspect the
  /// authoritative current state.
  Future<Household?> _loadRaw(String id) async {
    final doc = await collection.doc(id).get();
    if (!doc.exists) return null;
    return fromFirestore(doc);
  }

  @override
  Future<bool> validateCreatePermission(String userId, Household entity) async {
    // You can only create a household you are a member of.
    return entity.isMember(userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    Household? entity,
  ) async {
    // The base read() fetches the doc first, so a null entity only reaches
    // here when the doc genuinely doesn't exist — nothing to protect. Firestore
    // rules are the authoritative isolation layer.
    if (entity == null) return true;
    return entity.isMember(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    Household entity,
  ) async {
    // Check the CURRENT doc, not the submitted entity — prevents self-elevation.
    final current = await _loadRaw(resourceId);
    if (current == null) return false;
    return current.canAdmin(userId);
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    final current = await _loadRaw(resourceId);
    if (current == null) return false;
    return current.canAdmin(userId);
  }

  @override
  Future<List<Household>> getForUser(String userId) async {
    // A caller may only list their OWN households.
    final callerId = requireCurrentUserId();
    if (callerId != userId) {
      AppLogger.warning(
        'getForUser denied: ${callerId.maskedUserId} requested '
        '${userId.maskedUserId}',
      );
      return [];
    }
    final snap = await collection
        .where('memberUserIds', arrayContains: userId)
        .limit(_maxHouseholdsPerUser)
        .get();
    return snap.docs.map(fromFirestore).toList();
  }

  @override
  Future<Household> ensureForUser(String userId) async {
    final existing = await getForUser(userId);
    if (existing.isNotEmpty) return existing.first;
    AppLogger.info('Creating first household for ${userId.maskedUserId}');
    return create(Household.create(creatorId: userId));
  }

  @override
  Future<bool> isMember(String householdId, String userId) async {
    // Defense-in-depth: only answer membership questions about the caller.
    if (requireCurrentUserId() != userId) return false;
    final household = await _loadRaw(householdId);
    return household?.isMember(userId) ?? false;
  }
}
