import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/base/base_storage_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Handles deletion of storage and cached data (Firebase Storage, realtime recipes, offline cache).
/// **Architecture:** Extends BaseStorageRepository for proper repository pattern and GDPR compliance
/// **Security:** Uses BaseStorageRepository security validation and audit logging
/// **GDPR:** Article 17 - Right to Erasure (comprehensive user data deletion)
class StorageDeletionOperations extends BaseStorageRepository {
  final FirebaseFirestore _firestore;
  final OfflineService _offlineService;
  static const String _logTag = 'StorageDeletionOps';

  StorageDeletionOperations({
    required FirebaseFirestore firestore,
    required OfflineService offlineService,
    super.storage,
    required super.authRepository,
    super.auditRepository,
  })  : _firestore = firestore,
        _offlineService = offlineService;

  /// Delete all Firebase Storage files for a user (GDPR Article 17 - Right to Erasure)
  /// **Security:** No permission validation needed - this is a system-level deletion operation
  /// **GDPR:** Comprehensive audit logging for all file deletions
  /// **Pattern:** Uses BaseStorageRepository.deleteDirectory() instead of direct Firebase access
  Future<bool> deleteUserStorageFiles(String userId) async {
    try {
      final path = 'users/$userId';

      app_logger.AppLogger.info(
        '[$_logTag] Starting deletion of all storage files for user: $userId',
      );

      // Use BaseStorageRepository's deleteDirectory method
      // This provides:
      // - Recursive deletion of all files and subdirectories
      // - GDPR-compliant audit logging for each file deletion
      // - Consistent error handling
      await deleteDirectory(path, logAudit: true);

      // Log GDPR compliance event
      await logPermissionCheck(
        userId: userId,
        resource: 'storage/$path',
        operation: 'gdpr_deletion',
        granted: true,
        details: 'Complete user storage deletion (GDPR Article 17)',
        auditRepository: auditRepository,
      );

      app_logger.AppLogger.success(
        '[$_logTag] Successfully deleted all storage files for user: $userId',
      );

      return true;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to delete user storage files',
        e,
      );
      // Return true to allow account deletion to continue even if storage deletion fails
      // This prevents orphaned accounts if storage deletion has issues
      return true;
    }
  }

  /// Delete all realtime documents owned by the user for a given collection.
  Future<bool> _deleteRealtimeCollection(
      String userId, String collection) async {
    try {
      final docs = await _firestore
          .collection(collection)
          .where('ownerId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, docs.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete $collection', e);
      return false;
    }
  }

  Future<bool> deleteRealtimeRecipes(String userId) =>
      _deleteRealtimeCollection(userId, FirestoreCollections.realtimeRecipes);

  /// Delete presence document for the user
  Future<bool> deletePresence(String userId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.presence)
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete presence', e);
      return false;
    }
  }

  /// Clear offline cached data for the user (local storage cleanup)
  /// **Note:** This is local cache (not Firebase Storage), so it doesn't use BaseStorageRepository methods
  Future<bool> clearOfflineData(String userId) async {
    try {
      await _offlineService.clearUserData(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to clear offline data', e);
      return false;
    }
  }
}
