// lib/services/account/export/preferences_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

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

      final limit = ExportPaginationHelper.getLimitForType(
        'user_notifications',
      );
      // Fetch one past the cap so "exactly `limit` present" is distinguishable
      // from "more than `limit`, some omitted". Keying `truncated` off
      // `length >= limit` would falsely flag a complete export of exactly
      // `limit` notifications as truncated — a wrong completeness claim on a
      // GDPR data-portability export (BUT-1562).
      final entries = await _exports.exportUserNotifications(
        userId,
        maxDocuments: limit + 1,
      );
      final truncated = entries.length > limit;
      final included = truncated ? entries.take(limit) : entries;

      for (final entry in included) {
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
        if (truncated) 'truncated': true,
        if (truncated)
          'note': 'Limited to the $limit most recent notifications',
        'summary': {
          'unread_count': notifications
              .where((n) => n['is_read'] == false)
              .length,
          'read_count': notifications.where((n) => n['is_read'] == true).length,
          'notification_types': _summarizeNotificationTypes(notifications),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export notifications',
        e,
      );
      return {
        'error': e.toString(),
        'note': 'Notifications may not be available',
      };
    }
  }

  /// Summarize notification types
  Map<String, int> _summarizeNotificationTypes(
    List<Map<String, dynamic>> notifications,
  ) {
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
    String userId,
  ) async {
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
        '[$_logTag] Failed to export notification preferences',
        e,
      );
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
        '[$_logTag] Failed to export category preferences',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1450: Export notification-history records (notifications the user
  /// received, with the title/body they saw). The deletion cascade erases
  /// these, so Art. 15 requires the export to include them.
  Future<Map<String, dynamic>> exportNotificationHistory(String userId) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'notification_history',
      );
      final entries = await _exports.exportNotificationHistory(
        userId,
        maxDocuments: limit,
      );
      return {
        'notification_history': entries
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.length >= limit) 'truncated': true,
        if (entries.length >= limit)
          'note': 'Limited to the $limit most recent records',
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export notification history',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1450: Export notification_batches (userId-scoped).
  Future<Map<String, dynamic>> exportNotificationBatches(String userId) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'notification_batches',
      );
      final entries = await _exports.exportNotificationBatches(
        userId,
        maxDocuments: limit,
      );
      return {
        'notification_batches': entries
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.length >= limit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export notification batches',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1450: Export notification_engagement (userId-scoped open/click events).
  Future<Map<String, dynamic>> exportNotificationEngagement(
    String userId,
  ) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'notification_engagement',
      );
      final entries = await _exports.exportNotificationEngagement(
        userId,
        maxDocuments: limit,
      );
      return {
        'notification_engagement': entries
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.length >= limit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export notification engagement',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1450: Export notification_delivery — the union of records where the
  /// user is the SENDER and where the user is the TARGET (two queries; Firestore
  /// has no cross-field OR), de-duplicated by doc id. The counterparty is stored
  /// only as a UID and is exported AS-IS (not anonymised) per the Art. 15(4)
  /// include-the-counterparty decision: the right of access reflects what the
  /// user's data actually is, and the human-readable notification is in
  /// notification_history (joined via notificationId). See
  /// `.claude/rules/accepted-deviations.md`.
  Future<Map<String, dynamic>> exportNotificationDelivery(
    String userId,
  ) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'notification_delivery',
      );
      final sent = await _exports.exportNotificationDeliverySent(
        userId,
        maxDocuments: limit,
      );
      final received = await _exports.exportNotificationDeliveryReceived(
        userId,
        maxDocuments: limit,
      );
      // De-dupe by doc id — a self-targeted notification can match both queries.
      final byId = <String, Map<String, dynamic>>{};
      for (final e in [...sent, ...received]) {
        byId[e['id'] as String] = {
          'id': e['id'],
          'data': sanitizeForJson(e['data']),
        };
      }
      final merged = byId.values.toList();
      return {
        'notification_delivery': merged,
        'total_count': merged.length,
        'sent_count': sent.length,
        'received_count': received.length,
        if (sent.length >= limit || received.length >= limit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export notification delivery',
        e,
      );
      return {'error': e.toString()};
    }
  }
}
