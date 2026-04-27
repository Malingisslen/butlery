/// Firebase implementation of AcquisitionRepository.
///
/// Stores BUT-612 acquisition attribution at:
///   users/{userId}/acquisition/current
///
/// Mirrors the consent-repository layout (single fixed-id doc inside a
/// per-user subcollection) so security rules can target a stable path.
///
/// First-write-wins: [setAcquisitionIfAbsent] checks for an existing doc
/// before writing. The Firestore rule additionally forbids client updates,
/// providing a server-side safety net even if the client check is skipped.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';

class FirebaseAcquisitionRepository
    extends BaseFirebaseRepository<AcquisitionAttribution>
    implements AcquisitionRepository {
  static const String _usersCollection = FirestoreCollections.users;
  static const String _acquisitionSubcollection = 'acquisition';
  static const String _currentDocId = 'current';

  FirebaseAcquisitionRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => _acquisitionSubcollection;

  @override
  AcquisitionAttribution fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AcquisitionAttribution.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(AcquisitionAttribution entity) {
    return entity.toFirestore();
  }

  @override
  String getId(AcquisitionAttribution entity) => _currentDocId;

  // Self-only access: an acquisition record belongs to a single user. The
  // userId is implicit in the document path (users/{uid}/acquisition/current),
  // so permission checks reduce to "is the caller that user".

  @override
  Future<bool> validateCreatePermission(
    String userId,
    AcquisitionAttribution entity,
  ) async {
    return userId == requireCurrentUserId();
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    AcquisitionAttribution? entity,
  ) async {
    return userId == requireCurrentUserId();
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    AcquisitionAttribution entity,
  ) async {
    // First-write-wins: updates are not allowed at the repository layer.
    // The Firestore rule also blocks client-side updates.
    return false;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Acquisition is server-/admin-managed once written; no client deletes.
    return false;
  }

  @override
  Future<AcquisitionAttribution?> getAcquisition(String userId) async {
    try {
      final caller = requireCurrentUserId();
      if (caller != userId) {
        throw PermissionDeniedException(
          'User $caller cannot read acquisition for $userId',
        );
      }
      final doc = await firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_acquisitionSubcollection)
          .doc(_currentDocId)
          .get();
      if (!doc.exists) return null;
      return AcquisitionAttribution.fromFirestore(doc);
    } catch (e) {
      if (e is PermissionDeniedException || e is AuthenticationException) {
        rethrow;
      }
      AppLogger.warning(
        'Failed to read acquisition for ${userId.maskedUserId}: $e',
      );
      return null;
    }
  }

  @override
  Future<bool> setAcquisitionIfAbsent(
    String userId,
    AcquisitionAttribution attribution,
  ) async {
    try {
      final caller = requireCurrentUserId();
      if (caller != userId) {
        throw PermissionDeniedException(
          'User $caller cannot write acquisition for $userId',
        );
      }

      final ref = firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_acquisitionSubcollection)
          .doc(_currentDocId);

      // Client-side dedupe: skip if a doc already exists. The Firestore rule
      // additionally blocks updates, so even a racing client cannot overwrite.
      final existing = await ref.get();
      if (existing.exists) {
        AppLogger.debug(
          'Acquisition already set for ${userId.maskedUserId}; skipping',
        );
        return false;
      }

      await ref.set(attribution.toFirestore());
      AppLogger.info(
        'Recorded acquisition for ${userId.maskedUserId} '
        '(source=${attribution.source})',
      );
      return true;
    } catch (e) {
      if (e is PermissionDeniedException || e is AuthenticationException) {
        rethrow;
      }
      AppLogger.warning(
        'Failed to write acquisition for ${userId.maskedUserId}: $e',
      );
      return false;
    }
  }
}
