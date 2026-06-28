import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// Firestore implementation of [DinerProfileRepository].
///
/// Top-level `diner_profiles` collection. Access is gated by household
/// membership (delegated to [HouseholdRepository.isMember]). Persistence
/// (create/update) additionally enforces the GDPR consent invariants at the
/// data boundary, so no code path can store a minor's profile without guardian
/// consent or allergen (Art. 9) data without explicit allergen consent —
/// defense-in-depth beneath the service/UI consent flow. Firestore rules are
/// the authoritative isolation layer.
class FirebaseDinerProfileRepository
    extends BaseFirebaseRepository<DinerProfile>
    implements DinerProfileRepository {
  final HouseholdRepository _householdRepository;

  FirebaseDinerProfileRepository({
    required HouseholdRepository householdRepository,
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : _householdRepository = householdRepository;

  @override
  String get collectionName => FirestoreCollections.dinerProfiles;

  @override
  DinerProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      DinerProfile.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(DinerProfile entity) => entity.toFirestore();

  @override
  String getId(DinerProfile entity) => entity.id;

  /// GDPR consent invariants enforced before any persistence. Throws
  /// [SecurityViolationException] so a non-compliant write can never land.
  void _assertConsentCompliant(DinerProfile profile) {
    if (profile.isMinor && profile.guardianConsent == null) {
      throw SecurityViolationException(
        'A minor diner profile requires guardian consent',
        details: 'ageBand=${profile.ageBand.name}',
      );
    }
    final hasAllergenData =
        profile.allergenPreferences?.hasAnyPreferences ?? false;
    if (hasAllergenData && !profile.hasAllergenConsent) {
      throw SecurityViolationException(
        'Storing diner allergen data requires explicit guardian allergen '
        'consent (GDPR Art. 9)',
        details: 'profile=${profile.id}',
      );
    }
  }

  @override
  Future<DinerProfile> create(DinerProfile entity) async {
    _assertConsentCompliant(entity);
    return super.create(entity);
  }

  @override
  Future<void> update(DinerProfile entity) async {
    _assertConsentCompliant(entity);
    return super.update(entity);
  }

  /// The base `createBatch` writes directly via `batch.set`, bypassing the
  /// [create] override — so the consent guard must be re-applied here, or a
  /// bulk write could persist a minor's profile (or allergen data) without
  /// consent. (`updateBatch`/`deleteBatch` live on a mixin this repo does NOT
  /// apply and are therefore unreachable; if that mixin is ever added, override
  /// `updateBatch` here too.)
  @override
  Future<void> createBatch(List<DinerProfile> entities) async {
    for (final entity in entities) {
      _assertConsentCompliant(entity);
    }
    return super.createBatch(entities);
  }

  @override
  Future<bool> validateCreatePermission(
    String userId,
    DinerProfile entity,
  ) async {
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    DinerProfile? entity,
  ) async {
    if (entity == null) return true; // delegated to Firestore rules
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    DinerProfile entity,
  ) async {
    // Check the STORED household, not the submitted payload, and forbid
    // re-parenting — otherwise a member of household B could hijack a child's
    // profile out of household A by re-tagging its householdId.
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
    final profile = fromFirestore(doc);
    return _householdRepository.isMember(profile.householdId, userId);
  }

  @override
  Future<List<DinerProfile>> getByHousehold(String householdId) async {
    final userId = requireCurrentUserId();
    if (!await _householdRepository.isMember(householdId, userId)) {
      AppLogger.warning(
        'getByHousehold denied: ${userId.maskedUserId} is not a member of '
        'the requested household',
      );
      return [];
    }
    final snap = await collection
        .where('householdId', isEqualTo: householdId)
        .get();
    return snap.docs.map(fromFirestore).toList();
  }
}
