import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';

/// Firestore implementation of [HouseholdAllergenShareRepository].
///
/// Top-level `household_allergen_shares` collection, one document per member
/// per household, id `{householdId}_{userId}`.
///
/// Three access rules, and they are deliberately different:
/// - **read** — membership of the named household. Membership is re-derived on
///   every read, so removing someone cuts their access with no cleanup step.
/// - **create / update** — ownership AND membership. A share is a statement
///   about oneself, so no member may write another's, and nobody may point a
///   share at a household they do not belong to (which would disclose their
///   allergens to strangers).
/// - **delete** — ownership ONLY, with no membership conjunct. Requiring
///   membership would leave a member who has been removed from the household
///   unable to erase their own Art. 9 data while the household keeps reading
///   it. Do not "harmonise" this with the two above, and do not copy the
///   membership-gated delete `diner_profiles` uses.
///
/// Firestore rules are the authoritative isolation layer; these checks are the
/// client-side first line and the audit trail.
///
/// **Inert until the rules commit lands.** `firestore.rules` has no match block
/// for this collection yet, so the catch-all `match /{document=**}` denies every
/// read and write here in production. Every caller — the household aggregate's
/// read and the settings row's grant/withdraw — sits behind
/// `enable_household_allergen_sharing` (OFF), so nothing reaches Firestore yet.
/// Do not read the sentence above as describing a live control until the block
/// and its emulator tests exist.
class FirebaseHouseholdAllergenShareRepository
    extends BaseFirebaseRepository<HouseholdAllergenShare>
    implements HouseholdAllergenShareRepository {
  final HouseholdRepository _householdRepository;

  FirebaseHouseholdAllergenShareRepository({
    required HouseholdRepository householdRepository,
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : _householdRepository = householdRepository;

  @override
  String get collectionName => FirestoreCollections.householdAllergenShares;

  /// The document id is authoritative: it is what the Firestore rules derive
  /// ownership from, so a body that disagrees with its own path is refused
  /// rather than trusted. Without this the rules and this class would judge the
  /// same document by different fields.
  @override
  HouseholdAllergenShare fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final share = HouseholdAllergenShare.fromMap(doc.id, doc.data()!);
    if (share.id != doc.id) {
      throw FormatException(
        'Allergen share body disagrees with its path',
        doc.id,
      );
    }
    return share;
  }

  @override
  Map<String, dynamic> toFirestore(HouseholdAllergenShare entity) =>
      entity.toFirestore();

  @override
  String getId(HouseholdAllergenShare entity) => entity.id;

  /// A write that is not a self-declaration under a valid consent must never
  /// land, whatever the caller believes it is doing (GDPR Art. 9(2)(a)).
  void _assertSelfDeclaredWithConsent(
    String userId,
    HouseholdAllergenShare share, {
    bool isGrant = false,
  }) {
    if (share.userId != userId) {
      throw SecurityViolationException(
        'A household allergen share may only be written by the member it '
        'describes',
        details: 'share=${share.userId.maskedUserId}',
      );
    }
    if (!share.isValidConsent) {
      throw SecurityViolationException(
        'Storing a household allergen share requires explicit consent '
        '(GDPR Art. 9)',
        details: 'household=${share.householdId}',
      );
    }
    // A grant is given under the wording the member actually read. A stale
    // client offering an older version would otherwise re-date the record
    // under text nobody was shown.
    if (isGrant &&
        share.consentVersion != HouseholdAllergenShare.currentConsentVersion) {
      throw SecurityViolationException(
        'A consent grant must carry the current consent version',
        details: 'offered=${share.consentVersion}',
      );
    }
  }

  /// A grant writes a NEW consent record. `super.create` is an unconditional
  /// `set()` on a deterministic id, so without the existence check a second
  /// create silently re-dates and re-versions the Art. 7(1) evidence — a
  /// save-flow with create-or-set semantics would do it on every preference
  /// edit. Editing goes through [update], which carries the stored record
  /// forward; a genuine re-grant follows a [revoke], which deletes.
  Future<void> _assertNotAlreadyShared(HouseholdAllergenShare entity) async {
    // Read directly rather than through the base `exists()`, which SWALLOWS a
    // failed read and answers false — offline, or one transient `unavailable`,
    // would wave the grant through and overwrite the record this guard exists
    // to protect. A read that fails must abort the grant, not approve it.
    final doc = await collection.doc(entity.id).get();
    if (doc.exists) {
      // A conflict, not an authorization failure: the caller should edit
      // instead, and the error copy must not say "not allowed".
      throw ValidationException(
        'A share already exists at ${entity.id}; edit it with update()',
      );
    }
  }

  @override
  Future<HouseholdAllergenShare> create(HouseholdAllergenShare entity) async {
    _assertSelfDeclaredWithConsent(
      requireCurrentUserId(),
      entity,
      isGrant: true,
    );
    await _assertNotAlreadyShared(entity);
    return super.create(entity);
  }

  /// Full-document overwrite, not the inherited merge-`update()`. A member who
  /// removes an allergen must see it GONE from the household's view; a merge
  /// would leave the old value in place and keep filtering on a preference they
  /// have retracted.
  @override
  Future<void> update(HouseholdAllergenShare entity) async {
    final userId = requireCurrentUserId();
    _assertSelfDeclaredWithConsent(userId, entity);

    final doc = await collection.doc(entity.id).get();
    if (!doc.exists) {
      throw PermissionDeniedException(
        'No allergen share to update at ${entity.id}',
      );
    }
    final stored = fromFirestore(doc);
    // Fresh Art. 9 data must not land under a record that is not a consent.
    // The payload's consent is discarded below in favour of this one, so if
    // THIS one is not valid, there is nothing lawful to write under.
    if (!stored.isValidConsent) {
      throw PermissionDeniedException(
        'The stored share at ${entity.id} carries no valid consent; grant it '
        'again rather than editing it',
      );
    }

    final canUpdate =
        stored.userId == userId &&
        entity.householdId == stored.householdId &&
        await _householdRepository.isMember(stored.householdId, userId);
    await logPermissionCheck(
      userId: userId,
      // Spelled like the base class's `'${T}/id'`, so one query over
      // audit_logs finds a share's whole history instead of half of it.
      resource: 'HouseholdAllergenShare/${entity.id}',
      operation: 'update',
      granted: canUpdate,
      auditRepository: auditRepository,
    );
    if (!canUpdate) {
      throw PermissionDeniedException(
        'User $userId does not have permission to update allergen share '
        '${entity.id}',
      );
    }

    // The STORED consent record is carried forward, never the payload's. An
    // ordinary "I edited my allergies" write must not re-date the consent or
    // silently move it to another wording version — that record is the Art.
    // 7(1) evidence, and a stale client would otherwise undo a version bump.
    // Granting consent again goes through revoke() then create(): in Firestore
    // terms a `set()` over an existing document is an UPDATE, so a re-grant
    // here would collide with the consent-immutability rule.
    await collection
        .doc(entity.id)
        .set(entity.withStoredConsent(stored).toFirestore());
  }

  /// The base `createBatch` writes through `batch.set` and never reaches
  /// [create], so the consent guard is re-applied here.
  @override
  Future<void> createBatch(List<HouseholdAllergenShare> entities) async {
    final userId = requireCurrentUserId();
    for (final entity in entities) {
      _assertSelfDeclaredWithConsent(userId, entity, isGrant: true);
      await _assertNotAlreadyShared(entity);
    }
    return super.createBatch(entities);
  }

  @override
  Future<bool> validateCreatePermission(
    String userId,
    HouseholdAllergenShare entity,
  ) async {
    if (entity.userId != userId) return false;
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    HouseholdAllergenShare? entity,
  ) async {
    if (entity == null) return true; // delegated to Firestore rules
    return _householdRepository.isMember(entity.householdId, userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    HouseholdAllergenShare entity,
  ) async {
    // Read the STORED household rather than the payload: otherwise a member
    // could re-point their existing share at another household and disclose
    // their allergens there. A share that does not exist yet is a create.
    final doc = await collection.doc(resourceId).get();
    if (!doc.exists) return false;
    final stored = fromFirestore(doc);
    if (stored.userId != userId) return false;
    if (entity.householdId != stored.householdId) return false;
    return _householdRepository.isMember(stored.householdId, userId);
  }

  /// Erasure is decided from the PATH, deliberately, and never from the stored
  /// body. Reading the body would run [fromFirestore]'s identity check, which
  /// THROWS on a corrupt or forged row — so the one document a member most
  /// needs to be able to delete would be the one they could not. A fail-loud
  /// read is protective; a fail-loud erasure is an Art. 17 defect. The id is
  /// `{householdId}_{userId}` and neither half contains '_', so the suffix
  /// binds the document to its owner exactly. It also keeps withdrawal
  /// idempotent for an absent document, and costs no read.
  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => resourceId.endsWith('_$userId');

  @override
  Future<List<HouseholdAllergenShare>> getByHousehold(
    String householdId,
  ) async {
    final userId = requireCurrentUserId();

    // Membership first, and on its own: a non-member cannot read the household
    // document at all, so deriving their answer from that read would turn "you
    // are not in this household" into the unavailability case below.
    if (!await _householdRepository.isMember(householdId, userId)) {
      AppLogger.warning(
        'getByHousehold denied: ${userId.maskedUserId} is not a member of the '
        'requested household',
      );
      return [];
    }

    // Whoever is on the roster RIGHT NOW. A share left behind by someone who
    // has left must stop filtering this household's menu the moment they
    // leave — the membership rule cuts their READ access, not the visibility
    // of what they already wrote.
    final household = await _householdRepository.read(householdId);
    if (household == null) {
      // NOT an empty roster, and reachable only as an anomaly: `isMember` just
      // read this document successfully. Silently returning [] here would read
      // downstream as "nobody shared", dropping every real declaration without
      // anyone knowing. Fail loud so the aggregate CAN report itself degraded
      // — since BUT-1693's service slice it does so only when someone other
      // than the caller is on the roster, because a household of one had no
      // share to miss.
      // NOT a StateError: this cluster uses StateError as ordinary control
      // flow for `firstWhere` (HouseholdService.getHousehold), so spelling an
      // anomaly that way invites a caller to swallow it as "no household".
      throw const RepositoryException(
        'Household roster became unreadable between the membership check and '
        'the roster read; allergen shares cannot be attributed',
        code: 'household-roster-unavailable',
      );
    }
    final currentMembers = household.memberUserIds.toSet();

    final snap = await collection
        .where('householdId', isEqualTo: householdId)
        .get();
    // Equality-only filter, so the automatic single-field index covers it.

    final shares = <HouseholdAllergenShare>[];
    for (final doc in snap.docs) {
      // Per document, because one malformed or forged row must not take the
      // whole household's shares down with it — that would silently return
      // "nobody shared" and look exactly like a healthy empty household.
      final HouseholdAllergenShare share;
      try {
        share = fromFirestore(doc);
      } on FormatException catch (e) {
        AppLogger.warning('Skipping unusable allergen share ${doc.id}: $e');
        // A body that disagrees with its path is the forgery shape, not a
        // parse hiccup — it belongs in the audit trail, not only in a
        // device-local log line nobody will ever read.
        await logPermissionCheck(
          userId: userId,
          resource: 'HouseholdAllergenShare/${doc.id}',
          operation: 'read',
          granted: false,
          auditRepository: auditRepository,
        );
        continue;
      }
      if (!share.isValidConsent) continue;
      if (!currentMembers.contains(share.userId)) {
        AppLogger.warning(
          'Skipping allergen share ${doc.id}: its member is no longer on the '
          'household roster',
        );
        continue;
      }
      shares.add(share);
    }
    return shares;
  }

  /// Deliberately fails LOUD where [getByHousehold] skips. One bad row among
  /// many must not take a household's shares down with it; but a forged or
  /// corrupt row of your OWN has no honest fallback — answering `null` would
  /// read as "you have not shared", turning a broken document into a silent
  /// opt-out of your own allergen list.
  @override
  Future<HouseholdAllergenShare?> getOwn(String householdId) async {
    final userId = requireCurrentUserId();
    final doc = await collection
        .doc(HouseholdAllergenShare.documentId(householdId, userId))
        .get();
    if (!doc.exists) return null;
    final share = fromFirestore(doc);
    return share.isValidConsent ? share : null;
  }

  @override
  Future<void> revoke(String householdId) async {
    final userId = requireCurrentUserId();
    await delete(HouseholdAllergenShare.documentId(householdId, userId));
  }

  /// The inherited single-document reads are consent-blind: they would hand a
  /// caller a share whose `consentGranted` is false, which this class's own
  /// contract says must be treated exactly like no share at all. Filtered here
  /// rather than fenced, because reading one share by id is legitimate — it is
  /// believing a withdrawn one that is not.
  @override
  Future<HouseholdAllergenShare?> read(String id) async =>
      _onlyConsented(await super.read(id));

  @override
  Future<HouseholdAllergenShare?> readCacheFirst(String id) async =>
      _onlyConsented(await super.readCacheFirst(id));

  HouseholdAllergenShare? _onlyConsented(HouseholdAllergenShare? share) =>
      (share != null && share.isValidConsent) ? share : null;

  /// The inherited whole-collection reads do NOT honour this collection's
  /// contract: they skip the consent filter and the roster check, `watchAll`
  /// performs no permission check at all, and both would sweep every
  /// household's Art. 9 data with one household read per document. Rules deny
  /// them in production; refusing here means a caller finds out at the call
  /// site rather than at runtime on someone's phone.
  @override
  Future<List<HouseholdAllergenShare>> readAll() => throw UnsupportedError(
    'Allergen shares are household-scoped: use getByHousehold or getOwn',
  );

  @override
  Stream<List<HouseholdAllergenShare>> watchAll({
    String? orderBy,
    bool descending = false,
  }) => throw UnsupportedError(
    'Allergen shares are household-scoped: use getByHousehold or getOwn',
  );
}
