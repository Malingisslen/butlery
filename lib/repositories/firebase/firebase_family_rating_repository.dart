import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// Firestore implementation of [FamilyRatingRepository].
///
/// Top-level `family_ratings` collection. Access gated by household membership
/// (delegates to [HouseholdRepository.isMember]). Persistence enforces the 1–5
/// stars invariant at the data boundary (create/update/createBatch), and update
/// validates against the STORED household and forbids re-parenting a rating into
/// another household. Firestore rules are the authoritative isolation layer.
class FirebaseFamilyRatingRepository
    extends BaseFirebaseRepository<FamilyRating>
    implements FamilyRatingRepository {
  final HouseholdRepository _householdRepository;

  FirebaseFamilyRatingRepository({
    required HouseholdRepository householdRepository,
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : _householdRepository = householdRepository;

  @override
  String get collectionName => FirestoreCollections.familyRatings;

  @override
  FamilyRating fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FamilyRating.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(FamilyRating entity) => entity.toFirestore();

  @override
  String getId(FamilyRating entity) => entity.id;

  /// Stars-range invariant enforced at the data boundary (defense-in-depth
  /// beneath any service/UI validation). Throws [SecurityViolationException]
  /// so an out-of-range write can never land regardless of caller.
  void _assertValidStars(FamilyRating rating) {
    if (!rating.hasValidStars) {
      throw SecurityViolationException(
        'Family rating stars must be between 1 and 5',
        details: 'stars=${rating.stars}',
      );
    }
  }

  @override
  Future<FamilyRating> create(FamilyRating entity) async {
    _assertValidStars(entity);
    return super.create(entity);
  }

  @override
  Future<void> update(FamilyRating entity) async {
    _assertValidStars(entity);
    return super.update(entity);
  }

  /// The base `createBatch` writes directly via `batch.set`, bypassing the
  /// [create] override — re-apply the stars guard so a bulk write can't persist
  /// an out-of-range rating.
  @override
  Future<void> createBatch(List<FamilyRating> entities) async {
    for (final entity in entities) {
      _assertValidStars(entity);
    }
    return super.createBatch(entities);
  }

  @override
  Future<bool> validateCreatePermission(
    String userId,
    FamilyRating entity,
  ) async {
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    FamilyRating? entity,
  ) async {
    if (entity == null) return true; // delegated to Firestore rules
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    FamilyRating entity,
  ) async {
    // Check the STORED household and forbid re-parenting (mirrors the diner
    // profile repo) — no hijacking a rating into another household.
    final doc = await collection.doc(resourceId).get();
    if (!doc.exists) return false;
    final stored = fromFirestore(doc);
    if (entity.householdId != stored.householdId) return false;
    return _householdRepository.isMember(stored.householdId, userId);
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    final doc = await collection.doc(resourceId).get();
    if (!doc.exists) return false;
    final rating = fromFirestore(doc);
    return _householdRepository.isMember(rating.householdId, userId);
  }

  @override
  Future<List<FamilyRating>> getForRecipe(
    String householdId,
    String recipeId,
  ) async {
    if (!await _isCallerMember(householdId)) return [];
    final snap = await collection
        .where('householdId', isEqualTo: householdId)
        .where('recipeId', isEqualTo: recipeId)
        .get();
    return snap.docs.map(fromFirestore).toList();
  }

  @override
  Future<List<FamilyRating>> getForHousehold(String householdId) async {
    if (!await _isCallerMember(householdId)) return [];
    final snap = await collection
        .where('householdId', isEqualTo: householdId)
        .get();
    return snap.docs.map(fromFirestore).toList();
  }

  Future<bool> _isCallerMember(String householdId) async {
    final userId = requireCurrentUserId();
    final isMember = await _householdRepository.isMember(householdId, userId);
    if (!isMember) {
      AppLogger.warning(
        '$collectionName query denied: ${userId.maskedUserId} is not a member '
        'of the requested household',
      );
    }
    return isMember;
  }
}
