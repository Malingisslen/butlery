/// Firebase repository for persistent audit logging (GDPR Article 30 compliance).
/// This repository manages the secure storage and retrieval of audit logs in Firestore,
/// providing the persistent audit trail required for GDPR compliance. Audit logs record
/// all permission checks and security events throughout the application.
/// **GDPR Compliance:**
/// - Article 30: Records of Processing Activities (CRITICAL requirement)
/// - Article 15: Right of Access by the Data Subject
/// - Article 17: Right to Erasure (audit logs exempt per legal requirement)
/// **Security Model:**
/// - Users CAN write their own audit logs (via authenticated requests)
/// - Users CANNOT read their own audit logs (prevents tampering detection)
/// - Only admins can read audit logs (via backend/admin tools)
/// - Audit logs are immutable once created
/// **Design Principles:**
/// - Fail gracefully: Audit logging failures do NOT break application operations
/// - Write-only for users: Prevents users from knowing what's being audited
/// - Async fire-and-forget: Doesn't block application performance
/// - Comprehensive context: Captures all relevant security metadata

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/audit_log.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for persistent audit log storage and retrieval.
/// Manages the complete lifecycle of audit logs from creation through retrieval,
/// with special handling for GDPR compliance and security monitoring requirements.
class FirebaseAuditRepository {
  final FirebaseFirestore _firestore;

  /// Create audit repository with optional Firestore instance (for testing)
  FirebaseAuditRepository([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to the audit_logs collection
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.auditLogs);

  /// Log a permission check to persistent storage.
  /// This is a fire-and-forget operation - failures are logged but don't throw.
  /// Application operations should NEVER fail due to audit logging issues.
  /// **Usage:**
  /// ```dart
  /// await auditRepository.logPermissionCheck(
  ///   userId: 'user123',
  ///   operation: 'read',
  ///   resourceType: 'recipe',
  ///   resourceId: 'recipe456',
  ///   granted: true,
  ///   metadata: {'ip': '192.168.1.1', 'app_version': '1.0.0'},
  /// );
  /// ```
  /// **Parameters:**
  /// - [userId]: User performing the operation
  /// - [operation]: Type of operation (read, write, delete, create)
  /// - [resourceType]: Type of resource (recipe, user, shopping_list, etc.)
  /// - [resourceId]: Specific resource ID (null for bulk operations)
  /// - [granted]: Whether permission was granted or denied
  /// - [metadata]: Additional context (IP, device, app version, etc.)
  Future<void> logPermissionCheck({
    required String userId,
    required String operation,
    required String resourceType,
    String? resourceId,
    required bool granted,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Create audit log entry
      final auditLog = AuditLog(
        id: '', // Firestore will generate ID
        userId: userId,
        operation: operation,
        resourceType: resourceType,
        resourceId: resourceId,
        granted: granted,
        timestamp: clock.now(), // Will be overwritten by server timestamp
        metadata: metadata,
      );

      // Write to Firestore (fire-and-forget)
      await _collection.add(auditLog.toFirestore());

      // Success - log locally for development visibility
      AppLogger.debug(
        '📝 Audit log persisted: $operation on $resourceType${resourceId != null ? "/$resourceId" : ""} - ${granted ? "GRANTED" : "DENIED"}',
      );
    } catch (e) {
      // CRITICAL: Audit logging failure must NOT break app operations
      // Log the error but don't throw - continue with normal operation
      AppLogger.error(
        '⚠️ Failed to write audit log (non-blocking): $e',
      );
      // Note: We don't rethrow - audit logging is best-effort
    }
  }

  /// Log a tag result modification for GDPR Article 30 compliance.
  /// Health-related data (allergens, dietary status) requires audit trail.
  /// This is a fire-and-forget operation - failures are logged but don't throw.
  /// **GDPR Article 30:** Records of Processing Activities
  /// Allergen/dietary data is health-sensitive and requires tracking.
  /// **Usage:**
  /// ```dart
  /// await auditRepository.logTagModification(
  ///   userId: 'user123',
  ///   recipeId: 'recipe456',
  ///   previousTags: oldTagResult?.toFirestore(),
  ///   newTags: newTagResult.toFirestore(),
  ///   source: 'auto_tagging',
  /// );
  /// ```
  /// **Parameters:**
  /// - [userId]: Owner of the recipe
  /// - [recipeId]: Recipe whose tags were modified
  /// - [previousTags]: Previous tag result (null if first tagging)
  /// - [newTags]: New tag result
  /// - [source]: Source of modification (auto_tagging, manual_retag, import)
  Future<void> logTagModification({
    required String userId,
    required String recipeId,
    Map<String, dynamic>? previousTags,
    required Map<String, dynamic> newTags,
    required String source,
  }) async {
    try {
      final auditLog = AuditLog(
        id: '',
        userId: userId,
        operation: 'tag_modified',
        resourceType: 'recipe',
        resourceId: recipeId,
        granted: true,
        timestamp: clock.now(),
        metadata: {
          'source': source,
          'previousAllergenStatus': previousTags?['allergenStatus'],
          'newAllergenStatus': newTags['allergenStatus'],
          'previousDietaryStatus': previousTags?['dietaryStatus'],
          'newDietaryStatus': newTags['dietaryStatus'],
          'previousCoverage': previousTags?['coverage'],
          'newCoverage': newTags['coverage'],
          'wasFirstTagging': previousTags == null,
        },
      );

      await _collection.add(auditLog.toFirestore());

      AppLogger.debug(
        '📝 Tag modification audit logged for recipe $recipeId (source: $source)',
      );
    } catch (e) {
      // Audit logging failure must NOT break tag operations
      AppLogger.error(
        '⚠️ Failed to log tag modification (non-blocking): $e',
      );
    }
  }

  /// Retrieve audit logs for a specific user (admin/GDPR request only).
  /// This method is for GDPR data subject access requests and admin monitoring.
  /// Regular users CANNOT call this method - enforced by Firebase Security Rules.
  /// **GDPR Article 15:** Right of Access by the Data Subject
  /// Users can request their audit logs via GDPR data export.
  /// **Usage:**
  /// ```dart
  /// // GDPR data request
  /// final logs = await auditRepository.getUserAuditLogs('user123');
  /// ```
  /// **Parameters:**
  /// - [userId]: User ID to retrieve logs for
  /// - [limit]: Maximum number of logs to retrieve (default 1000)
  /// - [startAfter]: Start after this timestamp (for pagination)
  /// **Returns:** List of audit logs, newest first
  Future<List<AuditLog>> getUserAuditLogs(
    String userId, {
    int limit = 1000,
    DateTime? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter)]);
      }

      final snapshot = await query.get();

      final logs = snapshot.docs
          .map((doc) => AuditLog.fromFirestore(doc))
          .toList();

      AppLogger.info(
        '📊 Retrieved ${logs.length} audit logs for user ${userId.maskedUserId}',
      );

      return logs;
    } catch (e) {
      AppLogger.error(
        'Failed to retrieve audit logs for user ${userId.maskedUserId}: $e',
      );
      rethrow; // This is an admin operation, so throwing is appropriate
    }
  }

  /// Retrieve audit logs for a specific resource (admin monitoring only).
  /// Used for security monitoring and forensic investigation.
  /// Shows all access attempts (granted and denied) for a specific resource.
  /// **Usage:**
  /// ```dart
  /// // Check who accessed a recipe
  /// final logs = await auditRepository.getResourceAuditLogs(
  ///   resourceType: 'recipe',
  ///   resourceId: 'recipe456',
  /// );
  /// ```
  Future<List<AuditLog>> getResourceAuditLogs({
    required String resourceType,
    String? resourceId,
    int limit = 1000,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('resourceType', isEqualTo: resourceType)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (resourceId != null) {
        query = query.where('resourceId', isEqualTo: resourceId);
      }

      final snapshot = await query.get();

      final logs = snapshot.docs
          .map((doc) => AuditLog.fromFirestore(doc))
          .toList();

      AppLogger.info(
        '📊 Retrieved ${logs.length} audit logs for $resourceType${resourceId != null ? "/$resourceId" : ""}',
      );

      return logs;
    } catch (e) {
      AppLogger.error(
        'Failed to retrieve audit logs for $resourceType${resourceId != null ? "/$resourceId" : ""}: $e',
      );
      rethrow;
    }
  }

  /// Get denied access attempts for security monitoring.
  /// Returns all permission denials within a time window.
  /// Useful for detecting unauthorized access attempts and security threats.
  /// **Usage:**
  /// ```dart
  /// // Check for unauthorized access in last 24 hours
  /// final denials = await auditRepository.getDeniedAccessAttempts(
  ///   since: DateTime.now().subtract(Duration(days: 1)),
  /// );
  /// ```
  Future<List<AuditLog>> getDeniedAccessAttempts({
    DateTime? since,
    int limit = 1000,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('granted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (since != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }

      final snapshot = await query.get();

      final logs = snapshot.docs
          .map((doc) => AuditLog.fromFirestore(doc))
          .toList();

      AppLogger.info(
        '🚨 Retrieved ${logs.length} denied access attempts${since != null ? " since $since" : ""}',
      );

      return logs;
    } catch (e) {
      AppLogger.error('Failed to retrieve denied access attempts: $e');
      rethrow;
    }
  }

  /// Get audit log statistics for a user.
  /// Returns summary statistics including total operations, denied attempts, etc.
  /// Useful for GDPR reports and user activity summaries.
  /// **Usage:**
  /// ```dart
  /// final stats = await auditRepository.getUserAuditStats('user123');
  /// print('Total operations: ${stats['total']}');
  /// print('Denied attempts: ${stats['denied']}');
  /// ```
  Future<Map<String, int>> getUserAuditStats(String userId) async {
    try {
      final logs = await getUserAuditLogs(userId);

      final stats = {
        'total': logs.length,
        'granted': logs.where((log) => log.granted).length,
        'denied': logs.where((log) => !log.granted).length,
        'reads': logs.where((log) => log.operation == 'read').length,
        'writes': logs
            .where(
              (log) => log.operation == 'write' || log.operation == 'update',
            )
            .length,
        'deletes': logs.where((log) => log.operation == 'delete').length,
        'creates': logs.where((log) => log.operation == 'create').length,
      };

      return stats;
    } catch (e) {
      AppLogger.error(
        'Failed to get audit stats for user ${userId.maskedUserId}: $e',
      );
      rethrow;
    }
  }
}
