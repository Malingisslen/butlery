import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for GDPR consent management (Article 7: Conditions for consent).
/// This repository handles persistent storage and retrieval of user consent
/// with comprehensive security validation and audit logging to ensure GDPR compliance.
/// **GDPR Compliance:**
/// - Article 7: Conditions for Consent (CRITICAL requirement)
/// - Article 4(11): Definition of consent
/// - Article 13: Information to be provided where personal data are collected
/// **Security Model:**
/// - Users can only read/write their own consent
/// - All consent operations are audit logged
/// - Consent version tracking for policy changes
/// - Device information tracking for audit trails
/// **Data Structure:**
/// ```
/// users/{userId}/consent/current
/// ```
class FirebaseConsentRepository extends BaseFirebaseRepository<UserConsent> {
  static const String _collectionPath = FirestoreCollections.users;
  static const String _consentSubcollection = FirestoreCollections.userConsent;
  static const String _currentConsentDoc = 'current';

  // Local reference to audit repository for custom methods
  final FirebaseAuditRepository? _localAuditRepository;

  FirebaseConsentRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  }) : _localAuditRepository = auditRepository;
  @override
  String get collectionName => _consentSubcollection;

  @override
  UserConsent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserConsent.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(UserConsent entity) {
    return entity.toFirestore();
  }

  @override
  String getId(UserConsent entity) {
    // Consent uses fixed "current" document ID
    return _currentConsentDoc;
  }

  // Users can only access their own consent data (self-access only)

  @override
  Future<bool> validateCreatePermission(
    String userId,
    UserConsent entity,
  ) async {
    // User can only create consent for themselves
    return userId == entity.userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    UserConsent? entity,
  ) async {
    // User can only read their own consent
    if (entity != null) {
      return userId == entity.userId;
    }
    // If entity not provided, check if resourceId matches userId (for subcollection pattern)
    return true; // Will be validated in getUserConsent method
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    UserConsent entity,
  ) async {
    // User can only update their own consent
    return userId == entity.userId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // User can only delete their own consent
    // resourceId in this case is the userId from the subcollection path
    return true; // Will be validated in deleteConsent method
  }

  /// Validate user is accessing their own consent
  Future<void> _validateSelfAccess(String userId, String operation) async {
    await validateSelfOperation(
      currentUserId: requireCurrentUserId(),
      targetUserId: userId,
      operation: operation,
    );
  }

  /// Get user's consent
  /// Returns null if no consent exists or user is not authenticated.
  /// **Security:** Users can only read their own consent
  Future<UserConsent?> getUserConsent(String userId) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'read');

      final doc = await firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .get();

      if (!doc.exists) {
        AppLogger.debug('No consent found for user ${userId.maskedUserId}');
        return null;
      }

      final consent = UserConsent.fromFirestore(doc);
      AppLogger.info(
        '✅ Retrieved consent for user ${userId.maskedUserId} (version: ${consent.consentVersion})',
      );
      return consent;
    } catch (e) {
      _rethrowSecurityExceptions(e);
      AppLogger.error(
        'Failed to get user consent for ${userId.maskedUserId}: $e',
      );
      return null;
    }
  }

  /// Save or update user consent
  /// **Security:** Users can only write their own consent
  /// **Audit:** All consent changes are logged for GDPR compliance
  Future<bool> saveConsent(String userId, UserConsent consent) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'write');

      // Validate consent belongs to the correct user
      if (consent.userId != userId) {
        AppLogger.error(
          'Consent userId mismatch: expected ${userId.maskedUserId}, got ${consent.userId.maskedUserId}',
        );
        return false;
      }

      await firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .set(consent.toFirestore());

      // Additional audit log for consent changes (GDPR requirement)
      await _localAuditRepository?.logPermissionCheck(
        userId: userId,
        operation: 'consent_updated',
        resourceType: 'user_consent',
        resourceId: userId,
        granted: true,
        metadata: {
          'consentVersion': consent.consentVersion,
          'purposes': consent.purposes.toMap(),
          'timestamp': clock.now().toUtc().toIso8601String(),
        },
      );

      AppLogger.success(
        '✅ Consent saved for user ${userId.maskedUserId} (version: ${consent.consentVersion})',
      );
      return true;
    } catch (e) {
      _rethrowSecurityExceptions(e);
      AppLogger.error('Failed to save consent for ${userId.maskedUserId}: $e');
      return false;
    }
  }

  /// Delete user consent
  /// **GDPR:** This supports Article 17 (Right to Erasure)
  /// **Security:** Users can only delete their own consent
  Future<bool> deleteConsent(String userId) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'delete');

      await firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .delete();

      // Audit log for consent deletion
      await _localAuditRepository?.logPermissionCheck(
        userId: userId,
        // `consent_revoked`, NOT a fourth spelling. `CONSENT_OPERATIONS` in
        // functions/src/audit_logs/purge-expired.ts is exhaustive by
        // enumeration: an unlisted `consent_*` operation falls to the 180-day
        // general bucket instead of the 730-day consent one, and the Art. 7(1)
        // trail is purged at six months without a sound.
        //
        // `consent_deleted` reached that state on 2026-06-28 (BUT-1404), when
        // the purge stopped matching by `startsWith('consent_')` and switched
        // to the enumeration, which left the token out. It DID reach
        // production before that: `ProfileDeletionOperations` called this
        // method from BUT-498 (2026-04-27) until BUT-788 (2026-05-22) moved
        // deletion to the Cloud Function cascade. Those rows are still short
        // of the 180-day cutoff, so listing `consent_deleted` as a legacy
        // token saves them rather than recovering a loss; this rename protects
        // future rows. There is no live caller now.
        operation: 'consent_revoked',
        resourceType: 'user_consent',
        resourceId: userId,
        granted: true,
        metadata: {'timestamp': clock.now().toUtc().toIso8601String()},
      );

      AppLogger.success('✅ Consent deleted for user ${userId.maskedUserId}');
      return true;
    } catch (e) {
      _rethrowSecurityExceptions(e);
      AppLogger.error(
        'Failed to delete consent for ${userId.maskedUserId}: $e',
      );
      return false;
    }
  }

  /// Get consent history for a user (for GDPR audit trail)
  /// **Security:** Users can only access their own consent history
  /// **GDPR:** Article 15 (Right of Access)
  Future<List<UserConsent>> getConsentHistory(
    String userId, {
    int limit = 10,
  }) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'read');

      final snapshot = await firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      final history = snapshot.docs
          .map((doc) => UserConsent.fromFirestore(doc))
          .toList();

      AppLogger.info(
        'Retrieved ${history.length} consent history entries for user ${userId.maskedUserId}',
      );
      return history;
    } catch (e) {
      _rethrowSecurityExceptions(e);
      AppLogger.error(
        'Failed to get consent history for ${userId.maskedUserId}: $e',
      );
      return [];
    }
  }

  /// Rethrows security exceptions that must propagate to callers.
  Never? _rethrowSecurityExceptions(Object e) {
    if (e is PermissionDeniedException || e is AuthenticationException) throw e;
    return null;
  }
}
