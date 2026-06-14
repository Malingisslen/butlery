/// Root user-document deletion for the GDPR erasure cascade (BUT-734).
///
/// [FirebaseUserRepository] is keyed on the `public_profiles` collection — its
/// inherited `collection` getter points there. The root user document lives in a
/// *different* collection, `users/{uid}`, so deleting it must bypass the
/// `collection` getter and reference `firestore.collection(users)` explicitly.
/// That deliberate bypass is the reason this lives in its own documented mixin:
/// it is the one deletion path in the repository that does NOT operate on the
/// repository's own collection, so isolating it keeps that intent obvious and
/// prevents a future reader from "fixing" it to use `collection`.
///
/// This mixin requires the host to be a [BaseFirebaseRepository] of
/// [UserProfile] so it inherits `firestore`, `requireCurrentUserId()`, and
/// `validateOwnership()` (from `PermissionValidationMixin`). Companion path
/// `deletePublicProfile` intentionally stays on the repository itself because
/// it operates on the inherited `public_profiles` collection.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

mixin UserRootDeletionMixin on BaseFirebaseRepository<UserProfile> {
  /// Delete the root `users/{userId}` document as part of the GDPR erasure
  /// cascade. Caller must own the document.
  ///
  /// Bypasses the inherited `collection` getter (which points at
  /// `public_profiles`) because the root user doc lives in `users/{userId}`.
  Future<bool> deleteUserRootDoc(String userId) async {
    // GDPR cascade: caller must own this user document.
    final currentUser = requireCurrentUserId();
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: userId,
      resourceType: FirestoreCollections.users,
    );
    // The `collection` getter points at `public_profiles` (collectionName).
    // Root user doc lives in `users/{userId}` — explicit reference here.
    await firestore.collection(FirestoreCollections.users).doc(userId).delete();
    AppLogger.info('Deleted users/$userId');
    // GDPR Article 17 erasure must leave an audit entry on the SUCCESS path —
    // validateOwnership only logs on deny. Mirror the granted:true logging that
    // every other mutating method in this repository does, and forward
    // auditRepository so the entry PERSISTS to the Art.30 trail (BUT-1286), not
    // just the console.
    logPermissionCheck(
      userId: currentUser,
      resource: 'user_root_doc/$userId',
      operation: 'delete',
      granted: true,
      auditRepository: auditRepository,
    );
    return true;
  }
}
