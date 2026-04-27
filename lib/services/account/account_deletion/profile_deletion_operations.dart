import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Handles deletion of user profile data (user profile, public profile, preferences, notifications).
class ProfileDeletionOperations {
  final FirebaseFirestore _firestore;
  final NotificationsRepository _notificationsRepo;
  final NotificationHistoryRepository _notificationHistoryRepo;
  final NotificationBatchRepository _notificationBatchRepo;
  final DeviceRepository _deviceRepo;
  static const String _logTag = 'ProfileDeletionOps';

  ProfileDeletionOperations(
    this._firestore, {
    required NotificationsRepository notificationsRepository,
    required NotificationHistoryRepository notificationHistoryRepository,
    required NotificationBatchRepository notificationBatchRepository,
    required DeviceRepository deviceRepository,
  })  : _notificationsRepo = notificationsRepository,
        _notificationHistoryRepo = notificationHistoryRepository,
        _notificationBatchRepo = notificationBatchRepository,
        _deviceRepo = deviceRepository;

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
      await _deviceRepo.deleteAllByUser(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete FCM tokens', e);
      return false;
    }
  }

  Future<bool> deleteNotificationPreferences(String userId) async {
    try {
      return await _notificationsRepo.deletePreferencesForUser(userId);
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete notification preferences', e);
      return false;
    }
  }

  Future<bool> deleteNotifications(String userId) async {
    try {
      await _notificationsRepo.deleteAllByUser(userId);
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
  ///
  /// `notification_history` and `notification_batches` go through their
  /// repos (single-collection scrub with `validateOwnership`).
  /// `notification_engagement` and `notification_delivery` stay direct —
  /// the engagement collection has no repo, and `notification_delivery`
  /// needs a multi-field query (senderId OR targetUserId) that doesn't
  /// fit the single-collection-by-userId repo shape.
  Future<bool> deleteNotificationAnalytics(String userId) async {
    try {
      await _notificationHistoryRepo.deleteAllByUser(userId);
      await _notificationBatchRepo.deleteAllByUser(userId);

      final engagement = await _firestore
          .collection(FirestoreCollections.notificationEngagement)
          .where('userId', isEqualTo: userId)
          .get();
      await batchDeleteDocs(_firestore, engagement.docs);

      // notification_delivery uses senderId and targetUserId — multi-field
      // query that doesn't fit the single-collection-by-userId repo shape.
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
