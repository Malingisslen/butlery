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

  // BUT-1760: logs the real exception and returns the section's failure
  // envelope. Every section here used to return `{'error': e.toString()}`.
  //
  // A stable authored sentence, never `e.toString()`: a raw Firestore /
  // permission string carries another user's uid (a notification counterparty
  // lands in composite doc ids), a `create_composite` index URL embedding field
  // paths and the project id, and internal collection paths — into an Art. 15
  // artifact the data subject may forward to a supervisory authority. The
  // exception itself stays in `AppLogger.error`, so support loses nothing.
  //
  // `error_code` is not decoration: `DataExportService` names the failing
  // section in `export_metadata.warnings` from it, and a precise token says
  // WHICH read failed rather than "something did". Same convention as
  // `social_export_manager.dart`, `shared_shopping_list_export.dart` and
  // `family_export_manager.dart`.
  Map<String, dynamic> _failed(String section, String code, Object e) {
    app_logger.AppLogger.error('[$_logTag] Failed to export $section', e);
    return {'error': 'Could not export $section.', 'error_code': code};
  }

  /// Export user preferences and settings
  Future<Map<String, dynamic>> exportPreferences(String userId) async {
    try {
      final prefs = await _exports.exportSettingsPreferences(userId);
      return {
        'preferences': sanitizeForJson(prefs ?? {}),
        'preferences_exist': prefs != null,
      };
    } catch (e) {
      return _failed('preferences', 'preferences-export-failed', e);
    }
  }

  /// BUT-1957: the `users/{userId}/notifications` subcollection.
  ///
  /// A SEPARATE section from [exportNotifications], which reads the top-level
  /// `user_notifications`. The two collections are one word apart in name and
  /// were never the same rows: these are written by the win-back job
  /// (`detect-lapsed-users.ts`) and the weekly activity digest
  /// (`send-activity-digest.ts`), and until BUT-1957 nothing erased them and
  /// nothing exported them either.
  ///
  /// Fields are passed through rather than projected.
  ///
  /// This comment first said no other person appears in these rows. That is
  /// FALSE, and the `firebase-backend-security` gate measured it: the win-back
  /// copy resolver's highest-priority signal builds
  /// `"<namn> delade ett recept med dig"` from another user's
  /// `sharedByDisplayName` (`functions/src/analytics/winback-context.ts`,
  /// `contextKey == 'ctx_friend_share'`), and that text is stored verbatim in
  /// `message` and `bodyShown`. `firstName()` splits on the first whitespace,
  /// so "Anna Andersson" ships as "Anna" — but it falls back to the WHOLE
  /// trimmed name when there is none, so a single-token display name is
  /// exported in full.
  /// The digest rows are clean — counts of the requester's OWN activity
  /// (a comment they authored may sit on someone else's recipe) and nothing
  /// else.
  ///
  /// The name is KEPT. It sits inside a push notification the
  /// requester already received and read on their own device, so the export
  /// discloses nothing they have not already been shown, and redacting it would
  /// hand them a falsified copy of their own record. Reasoned here on its own
  /// facts — NOT carried over from the conversations decision, which governs a
  /// different collection; `.claude/rules/accepted-deviations.md` records that
  /// arguing across collections by analogy is the error it exists to document.
  /// Chosen conservatively without asking Malin; STRIPPING it is hers to decide.
  Future<Map<String, dynamic>> exportDeliveredNotifications(
    String userId,
  ) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'delivered_notifications',
      );
      final page = await ExportPaginationHelper.fetchCapped(
        type: 'delivered_notifications',
        fetch: (max) =>
            _exports.exportDeliveredNotifications(userId, maxDocuments: max),
      );

      final rows = <Map<String, dynamic>>[];
      for (final entry in page.items) {
        final data = entry['data'] as Map<String, dynamic>;
        // Spread FIRST, id LAST: a document field literally named
        // `notification_id` would otherwise overwrite the document id, and this
        // section passes fields through unprojected, so it cannot rule that out.
        rows.add({
          ...sanitizeForJson(data) as Map<String, dynamic>,
          'notification_id': entry['id'],
        });
      }

      return {
        'total_count': rows.length,
        'notifications': rows,
        if (page.truncated) 'truncated': true,
        if (page.truncated)
          'note': 'Limited to the $limit most recent notifications',
        'data_minimisation':
            'Notification text is reproduced verbatim, exactly as it was shown '
            'to you. A reminder about a shared recipe therefore contains the '
            'name of the person who shared it.',
      };
    } catch (e) {
      return _failed(
        'delivered notifications',
        'delivered-notifications-export-failed',
        e,
      );
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
      final page = await ExportPaginationHelper.fetchCapped(
        type: 'user_notifications',
        fetch: (max) =>
            _exports.exportUserNotifications(userId, maxDocuments: max),
      );
      final truncated = page.truncated;

      for (final entry in page.items) {
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
      return {
        ..._failed('notifications', 'notifications-export-failed', e),
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
      return {
        ..._failed(
          'notification preferences',
          'notification-preferences-export-failed',
          e,
        ),
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
      return _failed('FCM tokens', 'fcm-tokens-export-failed', e);
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
      return _failed(
        'category preferences',
        'category-preferences-export-failed',
        e,
      );
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
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'notification_history',
        fetch: (max) =>
            _exports.exportNotificationHistory(userId, maxDocuments: max),
      );
      return {
        'notification_history': entries.items
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.truncated) 'truncated': true,
        if (entries.truncated)
          'note': 'Limited to the $limit most recent records',
      };
    } catch (e) {
      return _failed(
        'notification history',
        'notification-history-export-failed',
        e,
      );
    }
  }

  /// BUT-1450: Export notification_batches (userId-scoped).
  Future<Map<String, dynamic>> exportNotificationBatches(String userId) async {
    try {
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'notification_batches',
        fetch: (max) =>
            _exports.exportNotificationBatches(userId, maxDocuments: max),
      );
      return {
        'notification_batches': entries.items
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      return _failed(
        'notification batches',
        'notification-batches-export-failed',
        e,
      );
    }
  }

  /// BUT-1450: Export notification_engagement (userId-scoped open/click events).
  Future<Map<String, dynamic>> exportNotificationEngagement(
    String userId,
  ) async {
    try {
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'notification_engagement',
        fetch: (max) =>
            _exports.exportNotificationEngagement(userId, maxDocuments: max),
      );
      return {
        'notification_engagement': entries.items
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      return _failed(
        'notification engagement',
        'notification-engagement-export-failed',
        e,
      );
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
      // Each leg carries the cap independently, so each gets its own N+1 probe
      // and the section is truncated when EITHER leg clipped (BUT-1662).
      final sent = await ExportPaginationHelper.fetchCapped(
        type: 'notification_delivery',
        fetch: (max) =>
            _exports.exportNotificationDeliverySent(userId, maxDocuments: max),
      );
      final received = await ExportPaginationHelper.fetchCapped(
        type: 'notification_delivery',
        fetch: (max) => _exports.exportNotificationDeliveryReceived(
          userId,
          maxDocuments: max,
        ),
      );
      // De-dupe by doc id — a self-targeted notification can match both queries.
      final byId = <String, Map<String, dynamic>>{};
      for (final e in [...sent.items, ...received.items]) {
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
        if (sent.truncated || received.truncated) 'truncated': true,
      };
    } catch (e) {
      return _failed(
        'notification delivery',
        'notification-delivery-export-failed',
        e,
      );
    }
  }
}
