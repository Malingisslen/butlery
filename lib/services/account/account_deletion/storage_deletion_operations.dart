import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/base/base_storage_repository.dart';

/// Handles deletion of storage and cached data (Firebase Storage, realtime recipes, offline cache).
/// **Architecture:** Extends BaseStorageRepository for proper repository pattern and GDPR compliance
/// **Security:** Uses BaseStorageRepository security validation and audit logging
/// **GDPR:** Article 17 - Right to Erasure (comprehensive user data deletion)
class StorageDeletionOperations extends BaseStorageRepository {
  final OfflineService _offlineService;
  final PresenceService _presenceService;
  final CollaborativeRecipeRepository _collaborativeRecipeRepo;
  static const String _logTag = 'StorageDeletionOps';

  StorageDeletionOperations({
    required OfflineService offlineService,
    required PresenceService presenceService,
    required CollaborativeRecipeRepository collaborativeRecipeRepository,
    super.storage,
    required super.authRepository,
    super.auditRepository,
  })  : _offlineService = offlineService,
        _presenceService = presenceService,
        _collaborativeRecipeRepo = collaborativeRecipeRepository;

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
      // Report failure honestly — the caller's _runDeletionStep adds this to
      // failedCollections and the audit log records gdprCompliant: false
      return false;
    }
  }

  Future<bool> deleteRealtimeRecipes(String userId) async {
    try {
      await _collaborativeRecipeRepo.deleteAllByUser(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete realtime_recipes', e);
      return false;
    }
  }

  /// Delete presence document for the user. Delegates to [PresenceService]
  /// which owns the `presence/{uid}` collection — keeps this deletion path
  /// consistent with how presence is read/written elsewhere (BUT-498).
  Future<bool> deletePresence(String userId) =>
      _presenceService.deleteUserPresence(userId);

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
