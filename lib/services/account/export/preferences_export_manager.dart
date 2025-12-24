// lib/services/account/export/preferences_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles export of user preferences: settings, notifications.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
class PreferencesExportManager {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'PreferencesExportManager';

  PreferencesExportManager({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Export user preferences and settings
  Future<Map<String, dynamic>> exportPreferences(String userId) async {
    try {
      final prefsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences')
          .get();

      return {
        'preferences': prefsDoc.data() ?? {},
        'preferences_exist': prefsDoc.exists,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export preferences', e);
      return {'error': e.toString()};
    }
  }

  /// Export user notifications
  /// Includes all notifications received by the user for transparency.
  Future<Map<String, dynamic>> exportNotifications(String userId) async {
    try {
      final notifications = <Map<String, dynamic>>[];

      // Get all user notifications
      final notificationsSnapshot = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(500) // Limit to last 500 notifications
          .get();

      for (final doc in notificationsSnapshot.docs) {
        final data = doc.data();
        notifications.add({
          'notification_id': doc.id,
          'type': data['type'] ?? 'unknown',
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'created_at':
              data['createdAt']?.toDate()?.toIso8601String() ?? 'unknown',
          'read_at': data['readAt']?.toDate()?.toIso8601String(),
          'is_read': data['isRead'] ?? false,
          'data': data['data'],
        });
      }

      return {
        'total_count': notifications.length,
        'notifications': notifications,
        'note': 'Limited to last 500 notifications for export size',
        'summary': {
          'unread_count':
              notifications.where((n) => n['is_read'] == false).length,
          'read_count': notifications.where((n) => n['is_read'] == true).length,
          'notification_types': _summarizeNotificationTypes(notifications),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export notifications', e);
      return {
        'error': e.toString(),
        'note': 'Notifications may not be available',
      };
    }
  }

  /// Summarize notification types
  Map<String, int> _summarizeNotificationTypes(
      List<Map<String, dynamic>> notifications) {
    final typeCounts = <String, int>{};
    for (final notification in notifications) {
      final type = notification['type'] as String;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    return typeCounts;
  }

  /// Export notification preferences
  /// User's notification settings and preferences.
  Future<Map<String, dynamic>> exportNotificationPreferences(
      String userId) async {
    try {
      // Get notification preferences
      final prefsDoc = await _firestore
          .collection('user_notification_preferences')
          .doc(userId)
          .get();

      // Get FCM token (if exists)
      final fcmDoc =
          await _firestore.collection('user_fcm_tokens').doc(userId).get();

      String? fcmTokenUpdatedAt;
      if (fcmDoc.exists) {
        final fcmData = fcmDoc.data();
        if (fcmData != null && fcmData['updatedAt'] != null) {
          final updatedAt = fcmData['updatedAt'];
          if (updatedAt is Timestamp) {
            fcmTokenUpdatedAt = updatedAt.toDate().toIso8601String();
          }
        }
      }

      return {
        'preferences': prefsDoc.exists ? prefsDoc.data() : null,
        'preferences_exist': prefsDoc.exists,
        'fcm_token_registered': fcmDoc.exists,
        'fcm_token_updated_at': fcmTokenUpdatedAt,
        'note': 'FCM token is not included for security reasons',
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export notification preferences', e);
      return {
        'error': e.toString(),
        'note': 'Notification preferences may not be available',
      };
    }
  }
}
