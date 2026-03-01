import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles deletion of user profile data (user profile, public profile, preferences, activity feed).
class ProfileDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ProfileDeletionOps';

  ProfileDeletionOperations(this._firestore);

  Future<bool> deleteUserProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user profile', e);
      return false;
    }
  }

  Future<bool> deletePublicProfile(String userId) async {
    try {
      await _firestore.collection('public_profiles').doc(userId).delete();
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
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences');

      await prefsDoc.delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete preferences', e);
      return false;
    }
  }

  Future<bool> deleteActivityFeed(String userId) async {
    try {
      final activities = await _firestore
          .collection('activity_feed')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in activities.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete activity feed', e);
      return false;
    }
  }

  /// Delete FCM tokens stored for push notifications.
  Future<bool> deleteFcmTokens(String userId) async {
    try {
      final tokens = await _firestore
          .collection('user_fcm_tokens')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in tokens.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete FCM tokens', e);
      return false;
    }
  }

  /// Delete notification preferences subcollection.
  Future<bool> deleteNotificationPreferences(String userId) async {
    try {
      final prefs = await _firestore
          .collection('user_notification_preferences')
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

  /// Delete user notifications.
  Future<bool> deleteNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete notifications', e);
      return false;
    }
  }

  /// Delete consent subcollection under user document.
  Future<bool> deleteConsentRecords(String userId) async {
    try {
      final consents = await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent')
          .get();

      final batch = _firestore.batch();
      for (final doc in consents.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete consent records', e);
      return false;
    }
  }
}
