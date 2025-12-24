import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles deletion of user content (recipes, menus, shopping lists).
class ContentDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ContentDeletionOps';

  ContentDeletionOperations(this._firestore);

  Future<bool> deleteRecipes(String userId) async {
    try {
      final recipesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .get();

      final batch = _firestore.batch();
      for (final doc in recipesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final unifiedSnapshot = await _firestore
          .collection('recipes')
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
          .collection('users')
          .doc(userId)
          .collection('menus')
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
          .collection('users')
          .doc(userId)
          .collection('shopping_lists')
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
}
