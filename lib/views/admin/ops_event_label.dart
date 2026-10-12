import 'package:butlery/l10n/app_localizations.dart';

/// The ops-log event name a person can read: the known cleanup jobs by their
/// Swedish name, any other type as its own words.
String opsEventLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'notification_cleanup':
      return l10n.adminOpsEventNotificationCleanup;
    case 'ingredient_cleanup':
      return l10n.adminOpsEventIngredientCleanup;
    case 'system_events_cleanup':
      return l10n.adminOpsEventSystemEventsCleanup;
    case 'cleanup_expired_social_requests':
      return l10n.adminOpsEventSocialRequestsCleanup;
    case 'audit_log_cleanup':
      return l10n.adminOpsEventAuditLogCleanup;
    case 'deletion_audit_log_cleanup':
      return l10n.adminOpsEventDeletionAuditLogCleanup;
  }
  final words = type
      .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .toLowerCase();
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}
