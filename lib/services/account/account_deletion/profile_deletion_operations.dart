import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Handles deletion of user profile data (user profile, public profile, preferences, notifications).
class ProfileDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ProfileDeletionOps';

  ProfileDeletionOperations(this._firestore);

  Future<bool> deleteUserProfile(String userId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user profile', e);
      return false;
    }
  }

  Future<bool> deletePublicProfile(String userId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete public profile', e);
      return false;
    }
  }

  Future<bool> deleteUserPreferences(String userId) async {
    try {
      final prefsDoc = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userSettings)
          .doc('preferences');

      await prefsDoc.delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete preferences', e);
      return false;
    }
  }

  Future<bool> deleteFcmTokens(String userId) async {
    try {
      final tokens = await _firestore
          .collection(FirestoreCollections.userFcmTokens)
          .where('userId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, tokens.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete FCM tokens', e);
      return false;
    }
  }

  Future<bool> deleteNotificationPreferences(String userId) async {
    try {
      final prefs = await _firestore
          .collection(FirestoreCollections.userNotificationPreferences)
          .doc(userId)
          .get();

      if (prefs.exists) {
        await prefs.reference.delete();
      }
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete notification preferences', e);
      return false;
    }
  }

  Future<bool> deleteNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection(FirestoreCollections.userNotifications)
          .where('userId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, notifications.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete notifications', e);
      return false;
    }
  }

  /// Delete orphaned user subcollections (Firestore doesn't cascade-delete).
  Future<bool> deleteUserSubcollections(String userId) async {
    try {
      final userDoc =
          _firestore.collection(FirestoreCollections.users).doc(userId);
      final subcollections = [
        FirestoreCollections.userConversationMemberships,
        FirestoreCollections.userRateLimits,
        FirestoreCollections.userSharedMenus,
        FirestoreCollections.userSharedShoppingLists,
      ];

      for (final sub in subcollections) {
        final docs = await userDoc.collection(sub).get();
        await batchDeleteDocs(_firestore, docs.docs);
      }
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete user subcollections', e);
      return false;
    }
  }

  /// Delete notification history, batch records, and analytics data.
  Future<bool> deleteNotificationAnalytics(String userId) async {
    try {
      final userIdCollections = [
        FirestoreCollections.notificationHistory,
        FirestoreCollections.notificationBatches,
        FirestoreCollections.notificationEngagement,
      ];
      for (final collection in userIdCollections) {
        final docs = await _firestore
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .get();
        await batchDeleteDocs(_firestore, docs.docs);
      }

      // notification_delivery uses senderId and targetUserId
      for (final field in ['senderId', 'targetUserId']) {
        final docs = await _firestore
            .collection(FirestoreCollections.notificationDelivery)
            .where(field, isEqualTo: userId)
            .get();
        await batchDeleteDocs(_firestore, docs.docs);
      }

      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete notification analytics', e);
      return false;
    }
  }

  /// Delete consent subcollection under user document.
  Future<bool> deleteConsentRecords(String userId) async {
    try {
      final consents = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userConsent)
          .get();

      await batchDeleteDocs(_firestore, consents.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete consent records', e);
      return false;
    }
  }
}
