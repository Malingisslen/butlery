import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// Firestore implementation of [HouseholdRepository].
///
/// Top-level `households` collection (NOT user-scoped). Access is gated by
/// membership: a member can read; only an admin can change its name or
/// delete it, and an admin or edit member can change a nutrition food
/// choice. Permission checks for update/delete
/// read the CURRENT document — never the caller-supplied new state — so a
/// caller cannot grant themselves admin by submitting an elevated entity.
/// Firestore rules are the authoritative second layer (see firestore.rules).
class FirebaseHouseholdRepository extends BaseFirebaseRepository<Household>
    implements HouseholdRepository {
  /// 50 is a generous ceiling that also caps
  /// the read fan-out if the data is ever malformed.
  static const int _maxHouseholdsPerUser = 50;

  FirebaseHouseholdRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
    FirebaseFunctions? functions,
  }) : _injectedFunctions = functions;

  /// Resolved lazily so constructing the repository never calls
  /// `FirebaseFunctions.instanceFor`, which throws in unit tests that do not
  /// initialise Firebase; only [joinGroupHousehold] needs it.
  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions? _functionsCache;
  FirebaseFunctions get _functions => _functionsCache ??=
      (_injectedFunctions ??
      FirebaseFunctions.instanceFor(region: 'europe-west1'));

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
  Future<Household?> getActiveForUser(String userId) async =>
      Household.pickActive(await getForUser(userId), userId);

  @override
  Future<Household> ensureForUser(String userId) async {
    final existing = await getActiveForUser(userId);
    if (existing != null) return existing;
    AppLogger.info('Creating first household for ${userId.maskedUserId}');
    return create(Household.create(creatorId: userId));
  }

  @override
  Future<String> joinGroupHousehold({
    required String ownerId,
    required String groupId,
  }) async {
    final result = await _functions
        .httpsCallable('joinGroupHousehold')
        .call<Map<String, dynamic>>(<String, dynamic>{
          'ownerId': ownerId,
          'groupId': groupId,
        });
    return result.data['householdId'] as String;
  }

  /// Mirrors `firestore.rules`: the same key shape, a positive id, and one
  /// key per write named in `nutritionChoiceKey`.
  static final RegExp _choiceKeyShape = RegExp(r'^[a-zåäö0-9_]{1,60}$');

  @override
  Future<void> setNutritionFoodChoice({
    required String householdId,
    required String key,
    required int? foodId,
  }) async {
    if (!_choiceKeyShape.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'not a nutrition choice key');
    }
    if (foodId != null && foodId <= 0) {
      throw ArgumentError.value(foodId, 'foodId', 'must be positive');
    }
    final userId = requireCurrentUserId();
    final current = await _loadRaw(householdId);
    final allowed = current != null && current.canEdit(userId);
    await logPermissionCheck(
      userId: userId,
      resource: 'Household/$householdId/nutritionFoodChoices',
      operation: 'update',
      granted: allowed,
      auditRepository: auditRepository,
    );
    if (!allowed) {
      throw StateError('Not allowed to change this household');
    }
    await collection.doc(householdId).update({
      FieldPath(['nutritionFoodChoices', key]): foodId ?? FieldValue.delete(),
      'nutritionChoiceKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> isMember(String householdId, String userId) async {
    // Defense-in-depth: only answer membership questions about the caller.
    if (requireCurrentUserId() != userId) return false;
    final household = await _loadRaw(householdId);
    return household?.isMember(userId) ?? false;
  }
}
