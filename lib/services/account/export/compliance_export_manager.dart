// lib/services/account/export/compliance_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles export of GDPR compliance data: audit logs, consent records.
/// Implements Article 7 (Consent) and Article 30 (Records of Processing).
class ComplianceExportManager {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ComplianceExportManager';

  ComplianceExportManager({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Export audit logs for GDPR Article 30 compliance
  /// Provides complete audit trail of all permission checks and data
  /// processing activities performed on behalf of the user.
  Future<Map<String, dynamic>> exportAuditLogs(String userId) async {
    try {
      final auditLogs = <Map<String, dynamic>>[];

      // Get all audit logs for this user
      final auditSnapshot = await _firestore
          .collection(FirestoreCollections.auditLogs)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1000) // Limit to last 1000 audit entries
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
          'metadata': data['metadata'],
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
  /// Provides complete history of user consent decisions and purposes.
  Future<Map<String, dynamic>> exportConsentRecords(String userId) async {
    try {
      final consentRecords = <Map<String, dynamic>>[];
      final consentLimit =
          ExportPaginationHelper.getLimitForType('consent_records');

      // Get consent records from user's subcollection (limited)
      final consentSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userConsent)
          .orderBy('timestamp', descending: true)
          .limit(consentLimit)
          .get();

      for (final doc in consentSnapshot.docs) {
        final data = doc.data();
        consentRecords.add({
          'consent_id': doc.id,
          'consent_version': data['consentVersion'] ?? 'unknown',
          'timestamp':
              data['timestamp']?.toDate()?.toIso8601String() ?? 'unknown',
          'purposes': data['purposes'] ?? {},
          'ip_address': data['ipAddress'],
          'user_agent': data['userAgent'],
        });
      }

      // Get current consent status
      final currentConsentDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userConsent)
          .doc('current')
          .get();

      return {
        'total_consent_records': consentRecords.length,
        'consent_history': consentRecords,
        'current_consent':
            currentConsentDoc.exists ? currentConsentDoc.data() : null,
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
