// lib/services/account/export/compliance_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles export of GDPR compliance data: audit logs, consent records.
/// Implements Article 7 (Consent) and Article 30 (Records of Processing).
///
/// BUT-501 (closed): consent reads route through
/// [FirebaseDataExportRepository]. The audit_logs read remains on direct
/// Firestore — by design — because BUT-424 documented that the
/// `audit_logs` rule branch denies user-side reads (the collection is
/// admin-only), so this method is currently a "best effort, expect to
/// catch and report 'unavailable'" path. A Cloud Function exporter is
/// the proper long-term fix; tracked under the BUT-424 follow-up.
class ComplianceExportManager {
  final FirebaseFirestore _firestore;
  final FirebaseDataExportRepository? _exportRepo;
  static const String _logTag = 'ComplianceExportManager';

  ComplianceExportManager({
    required FirebaseFirestore firestore,
    FirebaseDataExportRepository? dataExportRepository,
  })  : _firestore = firestore,
        _exportRepo = dataExportRepository;

  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  /// Export audit logs for GDPR Article 30 compliance.
  ///
  /// **BUT-424 known limitation:** the `audit_logs` collection is admin-only
  /// at the rules layer. This method attempts the read but expects deny
  /// for non-admin callers; the response then carries the error and a
  /// note. A Cloud Function exporter (admin-credentialed) is the proper
  /// fix and is tracked separately.
  Future<Map<String, dynamic>> exportAuditLogs(String userId) async {
    try {
      final auditLogs = <Map<String, dynamic>>[];

      // Direct Firestore read — see class docstring for rationale.
      // Caller (DataExportService) has already verified the auth uid IS
      // userId, so the rules-layer deny is the only failure mode.
      final auditSnapshot = await _firestore
          .collection(FirestoreCollections.auditLogs)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();

      for (final doc in auditSnapshot.docs) {
        final data = doc.data();
        auditLogs.add({
          'audit_log_id': doc.id,
          'timestamp':
              ((data['timestamp']?.toDate()?.toIso8601String()) ?? 'unknown'),
          'operation': ((data['operation']) ?? 'unknown'),
          'resource_type': ((data['resourceType']) ?? 'unknown'),
          'resource_id': data['resourceId'],
          'granted': ((data['granted']) ?? false),
          'metadata': sanitizeForJson(data['metadata']),
        });
      }

      return {
        'total_count': auditLogs.length,
        'audit_logs': auditLogs,
        'note': 'Limited to last 1000 audit entries for export size',
        'gdpr_article': 'Article 30 - Records of Processing Activities',
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
        'note': 'Audit logs may not be available or accessible',
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
