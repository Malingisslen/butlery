// lib/services/account/export/compliance_export_manager.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// Handles export of GDPR compliance data: audit logs, consent records.
/// Implements Article 7 (Consent), Article 15 (Right of Access), and
/// Article 30 (Records of Processing).
///
/// BUT-501 (closed): consent reads route through
/// [FirebaseDataExportRepository].
///
/// BUT-770: audit logs are admin-only at the rules layer (BUT-424 tampering-
/// detection invariant). This manager now calls the `exportAuditLogs`
/// Cloud Function (Admin SDK, region europe-west1) which can read the
/// collection on the user's behalf. Pages until the CF reports `nextCursor:
/// null` so the bundle includes the full actor history rather than a
/// recent-1000 snapshot.
class ComplianceExportManager {
  final FirebaseDataExportRepository? _exportRepo;
  final FirebaseFunctions _functions;
  static const String _logTag = 'ComplianceExportManager';
  // BUT-770: cap total entries we'll page through to avoid runaway exports
  // for power users with multi-year history. 50,000 covers ~5 years of
  // typical activity; anything beyond is still a real GDPR concern but
  // can be served via an admin-tools manual export.
  static const int _maxAuditLogPages = 10;

  ComplianceExportManager({
    FirebaseDataExportRepository? dataExportRepository,
    FirebaseFunctions? functions,
  })  : _exportRepo = dataExportRepository,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  /// Export audit logs for GDPR Article 15 (Right of Access) +
  /// Article 30 (Records of Processing) compliance.
  ///
  /// BUT-770: routes through the `exportAuditLogs` Cloud Function so the
  /// admin-only `audit_logs` collection is reachable for the data subject
  /// without breaking BUT-424's tampering-detection invariant (the rule
  /// still denies direct user-side reads). Pages via the CF's `nextCursor`
  /// to capture the full actor history, capped at [_maxAuditLogPages] to
  /// avoid runaway exports.
  Future<Map<String, dynamic>> exportAuditLogs(String userId) async {
    try {
      final auditLogs = <Map<String, dynamic>>[];
      final callable = _functions.httpsCallable(
        'exportAuditLogs',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      String? cursor;
      var pages = 0;
      while (true) {
        if (pages >= _maxAuditLogPages) {
          app_logger.AppLogger.warning(
              '[$_logTag] Audit-log export hit page cap; further entries omitted');
          break;
        }
        final result = await callable.call<Map<dynamic, dynamic>>(
            cursor != null ? <String, dynamic>{'before': cursor} : null);
        final data = Map<String, dynamic>.from(result.data);
        final rows =
            (data['rows'] as List?)?.cast<Map<dynamic, dynamic>>() ?? const [];
        for (final row in rows) {
          final r = Map<String, dynamic>.from(row);
          auditLogs.add({
            'audit_log_id': r['id'],
            'timestamp': r['timestamp'] ?? 'unknown',
            'operation': r['operation'] ?? 'unknown',
            'resource_type': r['resourceType'] ?? 'unknown',
            'resource_id': r['resourceId'],
            'granted': r['granted'] ?? false,
            'metadata': sanitizeForJson(r['metadata']),
          });
        }
        cursor = data['nextCursor'] as String?;
        pages++;
        if (cursor == null) break;
      }

      return {
        'total_count': auditLogs.length,
        'audit_logs': auditLogs,
        'note': pages >= _maxAuditLogPages
            ? 'Capped at $_maxAuditLogPages pages (~50,000 entries); contact support for older history'
            : 'Full actor history exported via server-side admin export',
        'gdpr_article':
            'Article 15 - Right of Access; Article 30 - Records of Processing',
        'summary': {
          'total_granted':
              auditLogs.where((log) => log['granted'] == true).length,
          'total_denied':
              auditLogs.where((log) => log['granted'] == false).length,
          'operations': _summarizeOperations(auditLogs),
          'resource_types': _summarizeResourceTypes(auditLogs),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export audit logs', e);
      return {
        'error': e.toString(),
        'note': 'Audit logs could not be exported via the server-side endpoint',
      };
    }
  }

  /// Summarize operations from audit logs
  Map<String, int> _summarizeOperations(List<Map<String, dynamic>> auditLogs) {
    final operationCounts = <String, int>{};
    for (final log in auditLogs) {
      final operation = log['operation'] as String;
      operationCounts[operation] = (operationCounts[operation] ?? 0) + 1;
    }
    return operationCounts;
  }

  /// Summarize resource types from audit logs
  Map<String, int> _summarizeResourceTypes(
      List<Map<String, dynamic>> auditLogs) {
    final resourceCounts = <String, int>{};
    for (final log in auditLogs) {
      final resourceType = log['resource_type'] as String;
      resourceCounts[resourceType] = (resourceCounts[resourceType] ?? 0) + 1;
    }
    return resourceCounts;
  }

  /// Export consent records for GDPR Article 7 compliance
  Future<Map<String, dynamic>> exportConsentRecords(String userId) async {
    try {
      final consentRecords = <Map<String, dynamic>>[];
      final consentLimit =
          ExportPaginationHelper.getLimitForType('consent_records');

      final history = await _exports.exportConsentHistory(
        userId,
        maxDocuments: consentLimit,
      );
      for (final entry in history) {
        final data = entry['data'] as Map<String, dynamic>;
        consentRecords.add({
          'consent_id': entry['id'],
          'consent_version': data['consentVersion'] ?? 'unknown',
          'timestamp':
              data['timestamp']?.toDate()?.toIso8601String() ?? 'unknown',
          'purposes': data['purposes'] ?? {},
          'ip_address': data['ipAddress'],
          'user_agent': data['userAgent'],
        });
      }

      final currentConsentData = await _exports.exportCurrentConsent(userId);

      return {
        'total_consent_records': consentRecords.length,
        'consent_history': consentRecords,
        'current_consent': currentConsentData != null
            ? sanitizeForJson(currentConsentData)
            : null,
        'gdpr_article': 'Article 7 - Conditions for Consent',
        'note': 'Complete history of consent decisions and purposes',
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export consent records', e);
      return {
        'error': e.toString(),
        'note': 'Consent records may not be available',
      };
    }
  }
}
