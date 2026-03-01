import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles deletion of user content (recipes, menus, shopping lists).
class ContentDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ContentDeletionOps';

  ContentDeletionOperations(this._firestore);

  Future<bool> deleteRecipes(String userId) async {
    try {
      final recipesSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.recipes)
          .get();

      final batch = _firestore.batch();
      for (final doc in recipesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final unifiedSnapshot = await _firestore
          .collection(FirestoreCollections.recipes)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in unifiedSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete recipes', e);
      return false;
    }
  }

  Future<bool> deleteMenus(String userId) async {
    try {
      final menusSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.menus)
          .get();

      final batch = _firestore.batch();
      for (final doc in menusSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete menus', e);
      return false;
    }
  }

  Future<bool> deleteShoppingLists(String userId) async {
    try {
      final listsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userShoppingLists)
          .get();

      final batch = _firestore.batch();
      for (final doc in listsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete shopping lists', e);
      return false;
    }
  }

  /// Delete personal tags (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePersonalTags(String userId) async {
    try {
      final tagsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userPersonalTagIds)
          .get();

      await _deleteInBatches(tagsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${tagsSnapshot.docs.length} personal tags');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tags', e);
      return false;
    }
  }

  /// Delete personal tag groups (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePersonalTagGroups(String userId) async {
    try {
      final groupsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userPersonalTagGroups)
          .get();

      await _deleteInBatches(groupsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${groupsSnapshot.docs.length} personal tag groups');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tag groups', e);
      return false;
    }
  }

  /// Helper to delete documents in batches of 500 (Firestore limit)
  Future<void> _deleteInBatches(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    const batchLimit = 500;
    for (var i = 0; i < docs.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = docs.skip(i).take(batchLimit);
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
