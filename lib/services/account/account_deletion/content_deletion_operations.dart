import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

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

      final unifiedSnapshot = await _firestore
          .collection(FirestoreCollections.recipes)
          .where('userId', isEqualTo: userId)
          .get();

      final allDocs = [
        ...recipesSnapshot.docs,
        ...unifiedSnapshot.docs,
      ];

      await batchDeleteDocs(_firestore, allDocs);
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

      await batchDeleteDocs(_firestore, menusSnapshot.docs);
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

      await batchDeleteDocs(_firestore, listsSnapshot.docs);
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
          .collection(FirestoreCollections.userPersonalTags)
          .get();

      await batchDeleteDocs(_firestore, tagsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${tagsSnapshot.docs.length} personal tags');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tags', e);
      return false;
    }
  }

  /// Delete cook snaps (GDPR Article 17 - Right to Erasure)
  Future<bool> deleteCookSnaps(String userId) async {
    try {
      final snapsSnapshot = await _firestore
          .collection(FirestoreCollections.cookSnaps)
          .where('userId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, snapsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${snapsSnapshot.docs.length} cook snaps');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete cook snaps', e);
      return false;
    }
  }

  /// Delete activity events (GDPR Article 17 - Right to Erasure)
  Future<bool> deleteActivityEvents(String userId) async {
    try {
      final eventsSnapshot = await _firestore
          .collection(FirestoreCollections.activityEvents)
          .where('actorId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, eventsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${eventsSnapshot.docs.length} activity events');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete activity events', e);
      return false;
    }
  }

  /// Delete weekly menu plans (BUT-211, GDPR Article 17 - Right to Erasure).
  /// Doc IDs are prefixed with `{userId}_` so a range query gives us only
  /// this user's plans without an additional Firestore index.
  Future<bool> deleteWeeklyMenuPlans(String userId) async {
    try {
      final plansSnapshot = await _firestore
          .collection(FirestoreCollections.weeklyMenuPlans)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
          .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
          .get();

      await batchDeleteDocs(_firestore, plansSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${plansSnapshot.docs.length} weekly menu plans');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete weekly menu plans', e);
      return false;
    }
  }

  /// Delete pantry items (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePantryItems(String userId) async {
    try {
      final pantrySnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.pantry)
          .get();

      await batchDeleteDocs(_firestore, pantrySnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${pantrySnapshot.docs.length} pantry items');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete pantry items', e);
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

      await batchDeleteDocs(_firestore, groupsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${groupsSnapshot.docs.length} personal tag groups');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tag groups', e);
      return false;
    }
  }
}
