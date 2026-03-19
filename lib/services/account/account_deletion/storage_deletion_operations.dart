import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/base/base_storage_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

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

  /// Delete all realtime recipes owned by the user (Firestore cleanup)
  /// **Note:** This is Firestore (not Storage), so it doesn't use BaseStorageRepository methods
  Future<bool> deleteRealtimeRecipes(String userId) async {
    try {
      final realtimeRecipes = await _firestore
          .collection(FirestoreCollections.realtimeRecipes)
          .where('ownerId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in realtimeRecipes.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete realtime recipes', e);
      return false;
    }
  }

  /// Delete all realtime menus owned by the user (Firestore cleanup)
  Future<bool> deleteRealtimeMenus(String userId) async {
    try {
      final realtimeMenus = await _firestore
          .collection(FirestoreCollections.realtimeMenus)
          .where('ownerId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in realtimeMenus.docs) {
        batch.delete(doc.reference);
      }
      if (realtimeMenus.docs.isNotEmpty) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete realtime menus', e);
      return false;
    }
  }

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
