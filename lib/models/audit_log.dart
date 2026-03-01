/// Audit log entry for GDPR compliance and security monitoring.
/// Represents a single audit log entry recording a permission check or security event.
/// These logs are persisted to Firestore to satisfy GDPR Article 30 (Records of Processing)
/// requirements, enabling data subject access requests and security auditing.
/// **GDPR Compliance:**
/// - Article 30: Records of Processing Activities
/// - Article 15: Right of Access by the Data Subject
/// - Article 17: Right to Erasure (audit logs retained per legal requirements)
/// **Security Use Cases:**
/// - Permission check auditing (granted and denied)
/// - Unauthorized access detection
/// - User activity monitoring
/// - Compliance reporting
/// - Forensic investigation
/// **Privacy Notes:**
/// - Audit logs are write-only for users (prevents tampering)
/// - Only admins can read audit logs
/// - Users can request their audit logs via GDPR data export
/// - Logs are NOT deletable (legal requirement for audit trail)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Immutable audit log entry for security and compliance tracking.
/// Each audit log records a single permission check or security event with
/// complete context including user, resource, operation, outcome, and metadata.
class AuditLog {
  /// Unique identifier for this audit log entry
  final String id;

  /// User ID who performed the operation
  final String userId;

  /// Operation performed (e.g., 'read', 'write', 'delete', 'create')
  final String operation;

  /// Type of resource accessed (e.g., 'recipe', 'user', 'shopping_list', 'message')
  final String resourceType;

  /// Specific resource identifier (null for bulk operations like readAll)
  final String? resourceId;

  /// Whether permission was granted (true) or denied (false)
  final bool granted;

  /// When this permission check occurred (server timestamp)
  final DateTime timestamp;

  /// Additional context (IP address, device info, app version, etc.)
  final Map<String, dynamic>? metadata;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.operation,
    required this.resourceType,
    this.resourceId,
    required this.granted,
    required this.timestamp,
    this.metadata,
  });

  /// Create AuditLog from Firestore document
  factory AuditLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AuditLog(
      id: doc.id,
      userId: SerializationUtils.safeString(data, 'userId'),
      operation: SerializationUtils.safeString(data, 'operation'),
      resourceType: SerializationUtils.safeString(data, 'resourceType'),
      resourceId: SerializationUtils.safeNullableString(data, 'resourceId'),
      granted: SerializationUtils.safeBool(data, 'granted'),
      timestamp:
          SerializationUtils.safeDateTime(data, 'timestamp') ?? DateTime.now(),
      metadata: SerializationUtils.safeNullableMap(data, 'metadata'),
    );
  }

  /// Convert AuditLog to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'operation': operation,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'granted': granted,
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }

  /// Convert to JSON for GDPR data export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'operation': operation,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'granted': granted,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON (for GDPR data import/testing)
  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: SerializationUtils.safeString(json, 'id'),
      userId: SerializationUtils.safeString(json, 'userId'),
      operation: SerializationUtils.safeString(json, 'operation'),
      resourceType: SerializationUtils.safeString(json, 'resourceType'),
      resourceId: SerializationUtils.safeNullableString(json, 'resourceId'),
      granted: SerializationUtils.safeBool(json, 'granted'),
      timestamp:
          SerializationUtils.safeDateTime(json, 'timestamp') ?? DateTime.now(),
      metadata: SerializationUtils.safeNullableMap(json, 'metadata'),
    );
  }

  @override
  String toString() {
    return 'AuditLog(userId: $userId, operation: $operation, resource: $resourceType${resourceId != null ? "/$resourceId" : ""}, granted: $granted, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuditLog &&
        other.id == id &&
        other.userId == userId &&
        other.operation == operation &&
        other.resourceType == resourceType &&
        other.resourceId == resourceId &&
        other.granted == granted &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      operation,
      resourceType,
      resourceId,
      granted,
      timestamp,
    );
  }
}
