// lib/services/account/export/preferences_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

/// Handles export of user preferences: settings, notifications.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501 (closed): All direct Firestore reads route through
/// [FirebaseDataExportRepository] which enforces `validateOwnership`.
class PreferencesExportManager {
  final FirebaseDataExportRepository? _exportRepo;
  static const String _logTag = 'PreferencesExportManager';

  PreferencesExportManager({
    FirebaseDataExportRepository? dataExportRepository,
  }) : _exportRepo = dataExportRepository;

  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  /// Export user preferences and settings
  Future<Map<String, dynamic>> exportPreferences(String userId) async {
    try {
      final prefs = await _exports.exportSettingsPreferences(userId);
      return {
        'preferences': sanitizeForJson(prefs ?? {}),
        'preferences_exist': prefs != null,
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

      final entries = await _exports.exportUserNotifications(userId);

      for (final entry in entries) {
        final data = entry['data'] as Map<String, dynamic>;
        notifications.add({
          'notification_id': entry['id'],
          'type': data['type'] ?? 'unknown',
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'created_at':
              data['createdAt']?.toDate()?.toIso8601String() ?? 'unknown',
          'read_at': data['readAt']?.toDate()?.toIso8601String(),
          'is_read': data['isRead'] ?? false,
          'data': sanitizeForJson(data['data']),
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
      final prefs = await _exports.exportNotificationPreferences(userId);
      final fcmData = await _exports.exportFcmTokensTopLevel(userId);

      String? fcmTokenUpdatedAt;
      if (fcmData != null && fcmData['updatedAt'] != null) {
        final updatedAt = fcmData['updatedAt'];
        if (updatedAt is Timestamp) {
          fcmTokenUpdatedAt = updatedAt.toDate().toIso8601String();
        }
      }

      return {
        'preferences': prefs != null ? sanitizeForJson(prefs) : null,
        'preferences_exist': prefs != null,
        'fcm_token_registered': fcmData != null,
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

  /// Export FCM token metadata (token value redacted for security)
  Future<Map<String, dynamic>> exportFcmTokens(String userId) async {
    try {
      final tokens = await _exports.exportFcmTokensSubcollection(userId);

      return {
        'tokens': tokens.map((data) {
          final sanitized = sanitizeForJson(data) as Map<String, dynamic>;
          if (sanitized.containsKey('token') && sanitized['token'] is String) {
            final token = sanitized['token'] as String;
            sanitized['token'] =
                '${token.substring(0, 10.clamp(0, token.length))}...[redacted]';
          }
          return sanitized;
        }).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export FCM tokens', e);
      return {'error': e.toString()};
    }
  }

  /// Export shopping category preferences and list category orders
  Future<Map<String, dynamic>> exportCategoryPreferences(String userId) async {
    try {
      final catPrefs = await _exports.exportCategoryPreferences(userId);
      final listOrders = await _exports.exportListCategoryOrders(userId);

      return {
        'category_preferences': catPrefs.map(sanitizeForJson).toList(),
        'list_category_orders': listOrders.map(sanitizeForJson).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export category preferences', e);
      return {'error': e.toString()};
    }
  }
}
