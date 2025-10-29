import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles deletion of storage and cached data (Firebase Storage, realtime recipes, offline cache).
class StorageDeletionOperations {
  final FirebaseFirestore _firestore;
  final OfflineService _offlineService;
  static const String _logTag = 'StorageDeletionOps';

  StorageDeletionOperations(this._firestore, this._offlineService);

  Future<bool> deleteUserStorageFiles(String userId) async {
    try {
      final storage = FirebaseStorage.instance;
      final userRef = storage.ref('users/$userId');

      final ListResult result = await userRef.listAll();

      for (final fileRef in result.items) {
        try {
          await fileRef.delete();
          app_logger.AppLogger.debug('[$_logTag] Deleted storage file: ${fileRef.fullPath}');
        } catch (e) {
          app_logger.AppLogger.warning('[$_logTag] Failed to delete storage file ${fileRef.fullPath}: $e');
        }
      }

      for (final prefix in result.prefixes) {
        await _deleteStorageDirectory(prefix);
      }

      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user storage files', e);
      return true;
    }
  }

  Future<void> _deleteStorageDirectory(Reference dirRef) async {
    try {
      final ListResult result = await dirRef.listAll();

      for (final fileRef in result.items) {
        try {
          await fileRef.delete();
        } catch (e) {
          app_logger.AppLogger.warning('[$_logTag] Failed to delete ${fileRef.fullPath}: $e');
        }
      }

      for (final prefix in result.prefixes) {
        await _deleteStorageDirectory(prefix);
      }
    } catch (e) {
      app_logger.AppLogger.warning('[$_logTag] Failed to delete directory ${dirRef.fullPath}: $e');
    }
  }

  Future<bool> deleteRealtimeRecipes(String userId) async {
    try {
      final realtimeRecipes = await _firestore
          .collection('realtime_recipes')
          .where('ownerId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in realtimeRecipes.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete realtime recipes', e);
      return false;
    }
  }

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
