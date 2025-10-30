import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Repository for GDPR consent management (Article 7: Conditions for consent).
///
/// This repository handles persistent storage and retrieval of user consent
/// with comprehensive security validation and audit logging to ensure GDPR compliance.
///
/// **GDPR Compliance:**
/// - Article 7: Conditions for Consent (CRITICAL requirement)
/// - Article 4(11): Definition of consent
/// - Article 13: Information to be provided where personal data are collected
///
/// **Security Model:**
/// - Users can only read/write their own consent
/// - All consent operations are audit logged
/// - Consent version tracking for policy changes
/// - Device information tracking for audit trails
///
/// **Data Structure:**
/// ```
/// users/{userId}/consent/current
/// ```
class FirebaseConsentRepository with PermissionValidationMixin {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final FirebaseAuditRepository? _auditRepository;

  static const String _collectionPath = 'users';
  static const String _consentSubcollection = 'consent';
  static const String _currentConsentDoc = 'current';

  FirebaseConsentRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository,
        _auditRepository = auditRepository;

  /// Get current authenticated user ID
  String? _getCurrentUserId() {
    return _authRepository.currentUser?.uid;
  }

  /// Validate user is accessing their own consent
  Future<void> _validateSelfAccess(String userId, String operation) async {
    final currentUserId = _getCurrentUserId();

    if (currentUserId == null) {
      await logPermissionCheck(
        userId: 'anonymous',
        resource: 'consent/$userId',
        operation: operation,
        granted: false,
        auditRepository: _auditRepository,
      );
      throw PermissionDeniedException(
        'User must be authenticated',
        resource: 'consent',
        operation: operation,
      );
    }

    if (currentUserId != userId) {
      await logPermissionCheck(
        userId: currentUserId,
        resource: 'consent/$userId',
        operation: operation,
        granted: false,
        details: 'User attempted to access another user\'s consent',
        auditRepository: _auditRepository,
      );
      throw PermissionDeniedException(
        'Users can only access their own consent',
        resource: 'consent',
        operation: operation,
        userId: currentUserId,
      );
    }

    // Log successful permission check
    await logPermissionCheck(
      userId: currentUserId,
      resource: 'consent/$userId',
      operation: operation,
      granted: true,
      auditRepository: _auditRepository,
    );
  }

  /// Get user's consent
  ///
  /// Returns null if no consent exists or user is not authenticated.
  ///
  /// **Security:** Users can only read their own consent
  Future<UserConsent?> getUserConsent(String userId) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'read');

      final doc = await _firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .get();

      if (!doc.exists) {
        AppLogger.debug('No consent found for user $userId');
        return null;
      }

      final consent = UserConsent.fromFirestore(doc);
      AppLogger.info('✅ Retrieved consent for user $userId (version: ${consent.consentVersion})');
      return consent;
    } catch (e) {
      if (e is PermissionDeniedException) {
        rethrow;
      }
      AppLogger.error('Failed to get user consent for $userId: $e');
      return null;
    }
  }

  /// Save or update user consent
  ///
  /// **Security:** Users can only write their own consent
  /// **Audit:** All consent changes are logged for GDPR compliance
  Future<bool> saveConsent(String userId, UserConsent consent) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'write');

      // Validate consent belongs to the correct user
      if (consent.userId != userId) {
        AppLogger.error('Consent userId mismatch: expected $userId, got ${consent.userId}');
        return false;
      }

      await _firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .set(consent.toFirestore());

      // Additional audit log for consent changes (GDPR requirement)
      await _auditRepository?.logPermissionCheck(
        userId: userId,
        operation: 'consent_updated',
        resourceType: 'user_consent',
        resourceId: userId,
        granted: true,
        metadata: {
          'consentVersion': consent.consentVersion,
          'purposes': consent.purposes.toMap(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      AppLogger.success('✅ Consent saved for user $userId (version: ${consent.consentVersion})');
      return true;
    } catch (e) {
      if (e is PermissionDeniedException) {
        rethrow;
      }
      AppLogger.error('Failed to save consent for $userId: $e');
      return false;
    }
  }

  /// Delete user consent
  ///
  /// **GDPR:** This supports Article 17 (Right to Erasure)
  /// **Security:** Users can only delete their own consent
  Future<bool> deleteConsent(String userId) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'delete');

      await _firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .doc(_currentConsentDoc)
          .delete();

      // Audit log for consent deletion
      await _auditRepository?.logPermissionCheck(
        userId: userId,
        operation: 'consent_deleted',
        resourceType: 'user_consent',
        resourceId: userId,
        granted: true,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      AppLogger.success('✅ Consent deleted for user $userId');
      return true;
    } catch (e) {
      if (e is PermissionDeniedException) {
        rethrow;
      }
      AppLogger.error('Failed to delete consent for $userId: $e');
      return false;
    }
  }

  /// Get consent history for a user (for GDPR audit trail)
  ///
  /// **Security:** Users can only access their own consent history
  /// **GDPR:** Article 15 (Right of Access)
  Future<List<UserConsent>> getConsentHistory(String userId, {int limit = 10}) async {
    try {
      // Validate permission
      await _validateSelfAccess(userId, 'read');

      final snapshot = await _firestore
          .collection(_collectionPath)
          .doc(userId)
          .collection(_consentSubcollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      final history = snapshot.docs
          .map((doc) => UserConsent.fromFirestore(doc))
          .toList();

      AppLogger.info('Retrieved ${history.length} consent history entries for user $userId');
      return history;
    } catch (e) {
      if (e is PermissionDeniedException) {
        rethrow;
      }
      AppLogger.error('Failed to get consent history for $userId: $e');
      return [];
    }
  }
}
