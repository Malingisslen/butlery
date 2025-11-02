# Audit Logging - GDPR Article 30

Comprehensive guide to implementing audit trail and records of processing activities using FirebaseAuditRepository for GDPR Article 30 compliance.

## Overview

**GDPR Article 30** requires maintaining records of all data processing activities:
- **Complete audit trail** - Log all sensitive operations
- **7-year retention** - Legal compliance requirement
- **Tamper-proof** - Immutable audit records
- **Queryable** - Filter by user, action, resource, time range
- **Anonymization-safe** - Support for user deletion while preserving audit trail

**Implementation**: FirebaseAuditRepository with Firestore persistence

## FirebaseAuditRepository

**Location**: `lib/repositories/firebase/firebase_audit_repository.dart`

**Purpose**: Persistent audit logging for GDPR compliance and security monitoring

### Key Methods

```dart
class FirebaseAuditRepository {
  // Log a new audit event
  Future<void> logAuditEvent(AuditEvent event);

  // Get audit trail for specific user
  Future<List<AuditEvent>> getAuditTrail(String userId);

  // Query audit logs with filters
  Future<List<AuditEvent>> queryAuditLogs({
    String? userId,
    AuditAction? action,
    String? resourceType,
    DateTime? startDate,
    DateTime? endDate,
  });

  // Anonymize audit logs (for Article 17 - right to erasure)
  Future<void> anonymizeUserLogs(String userId);

  // Delete old audit logs (retention policy)
  Future<void> deleteLogsOlderThan(Duration retention);
}
```

### AuditEvent Model

```dart
class AuditEvent {
  final String id;
  final String userId;  // Can be anonymized as 'DELETED_USER'
  final AuditAction action;
  final String resourceType;  // 'recipe', 'menu', 'user_data', etc.
  final String? resourceId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;  // Additional context

  AuditEvent({
    required this.id,
    required this.userId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.timestamp,
    this.metadata,
  });
}
```

### AuditAction Enum

```dart
enum AuditAction {
  // Account lifecycle
  accountCreated,
  accountDeleted,
  accountDeletionInitiated,
  accountDeletionFailed,

  // Consent management (Article 7)
  consentGranted,
  consentRevoked,
  consentUpdated,

  // Data access (Article 15)
  dataExport,
  dataExportFailed,

  // Authentication & security
  loginSuccess,
  loginFailed,
  logoutSuccess,
  passwordChanged,
  emailChanged,

  // Data operations
  recipeCreated,
  recipeUpdated,
  recipeDeleted,
  recipeShared,

  menuCreated,
  menuUpdated,
  menuDeleted,

  // Social operations
  friendRequestSent,
  friendRequestAccepted,
  friendRemoved,

  // Sensitive operations
  permissionDenied,
  unauthorizedAccess,
  securityViolation,
}
```

### Firestore Structure

```
auditLogs/{auditId}
  ├─ userId: "user-123" (or "DELETED_USER" after anonymization)
  ├─ action: "account_deleted"
  ├─ resourceType: "user_account"
  ├─ resourceId: "user-123"
  ├─ timestamp: Timestamp(2025-01-31T10:00:00Z)
  └─ metadata: {
       "ip": "192.168.1.1",
       "userAgent": "Mozilla/5.0...",
       "reason": "User requested deletion"
     }
```

**Indexes** (for efficient querying):
- `userId` + `timestamp` (descending)
- `action` + `timestamp` (descending)
- `resourceType` + `timestamp` (descending)

## Usage Patterns

### Pattern 1: Log Account Deletion

```dart
Future<void> deleteAccount(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  try {
    // Log deletion initiated
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: userId,
      action: AuditAction.accountDeletionInitiated,
      resourceType: 'user_account',
      resourceId: userId,
      timestamp: DateTime.now(),
      metadata: {
        'reason': 'User requested deletion',
        'initiatedBy': userId,
      },
    ));

    // Perform deletion operations...
    await _deleteUserData(userId);
    await _deleteFromAuth(userId);

    // Log deletion complete (with anonymized userId)
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: 'DELETED_$userId',  // Anonymized
      action: AuditAction.accountDeleted,
      resourceType: 'user_account',
      resourceId: 'DELETED_$userId',
      timestamp: DateTime.now(),
    ));
  } catch (e) {
    // Log deletion failed
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: userId,
      action: AuditAction.accountDeletionFailed,
      resourceType: 'user_account',
      resourceId: userId,
      timestamp: DateTime.now(),
      metadata: {'error': e.toString()},
    ));
    rethrow;
  }
}
```

### Pattern 2: Log Consent Changes

```dart
Future<void> requestConsent(String userId, ConsentType type) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  // Update consent in database
  await _consentRepo.grantConsent(userId, type);

  // Log audit event
  await auditRepo.logAuditEvent(AuditEvent(
    id: Uuid().v4(),
    userId: userId,
    action: AuditAction.consentGranted,
    resourceType: 'consent',
    resourceId: type.toString(),
    timestamp: DateTime.now(),
    metadata: {
      'consentType': type.toString(),
      'version': '1.0',
    },
  ));
}

Future<void> revokeConsent(String userId, ConsentType type) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  await _consentRepo.revokeConsent(userId, type);

  await auditRepo.logAuditEvent(AuditEvent(
    id: Uuid().v4(),
    userId: userId,
    action: AuditAction.consentRevoked,
    resourceType: 'consent',
    resourceId: type.toString(),
    timestamp: DateTime.now(),
    metadata: {'consentType': type.toString()},
  ));
}
```

### Pattern 3: Log Data Export

```dart
Future<String> exportUserData(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  try {
    // Generate export
    final jsonData = await _generateExport(userId);

    // Log successful export
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: userId,
      action: AuditAction.dataExport,
      resourceType: 'user_data',
      resourceId: userId,
      timestamp: DateTime.now(),
      metadata: {
        'format': 'json',
        'size': jsonData.length,
      },
    ));

    return jsonData;
  } catch (e) {
    // Log failed export
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: userId,
      action: AuditAction.dataExportFailed,
      resourceType: 'user_data',
      resourceId: userId,
      timestamp: DateTime.now(),
      metadata: {'error': e.toString()},
    ));
    rethrow;
  }
}
```

### Pattern 4: Log Security Events

```dart
Future<void> checkPermission(String userId, String operation) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  final hasPermission = await _permissionService.hasPermission(userId, operation);

  if (!hasPermission) {
    // Log permission denied
    await auditRepo.logAuditEvent(AuditEvent(
      id: Uuid().v4(),
      userId: userId,
      action: AuditAction.permissionDenied,
      resourceType: 'permission',
      timestamp: DateTime.now(),
      metadata: {
        'operation': operation,
        'reason': 'User lacks required permission',
      },
    ));

    throw PermissionDeniedException(operation);
  }
}

Future<void> detectUnauthorizedAccess(String userId, String resourceId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  await auditRepo.logAuditEvent(AuditEvent(
    id: Uuid().v4(),
    userId: userId,
    action: AuditAction.unauthorizedAccess,
    resourceType: 'security',
    resourceId: resourceId,
    timestamp: DateTime.now(),
    metadata: {
      'attemptedResource': resourceId,
      'severity': 'high',
    },
  ));
}
```

## Querying Audit Trail

### Get User's Complete Audit Trail

```dart
Future<List<AuditEvent>> getUserAuditTrail(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  // Get all audit events for user (sorted by timestamp descending)
  final events = await auditRepo.getAuditTrail(userId);

  return events;
}
```

### Query by Action Type

```dart
Future<List<AuditEvent>> getConsentChanges(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  final events = await auditRepo.queryAuditLogs(
    userId: userId,
    action: AuditAction.consentGranted,
  );

  return events;
}
```

### Query by Time Range

```dart
Future<List<AuditEvent>> getRecentActivity(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

  final events = await auditRepo.queryAuditLogs(
    userId: userId,
    startDate: thirtyDaysAgo,
  );

  return events;
}
```

### Query Security Events

```dart
Future<List<AuditEvent>> getSecurityEvents() async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  final events = await auditRepo.queryAuditLogs(
    action: AuditAction.unauthorizedAccess,
  );

  return events;
}
```

## Anonymization Support

### Anonymize User Logs (Article 17)

When a user deletes their account, audit logs must be preserved for legal compliance but anonymized to remove PII:

```dart
Future<void> anonymizeUserLogs(String userId) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  // Query all logs for user
  final logs = await auditRepo.getAuditTrail(userId);

  // Anonymize each log
  for (final log in logs) {
    await auditRepo.update(log.id, {
      'userId': 'DELETED_USER',
      'metadata.email': null,
      'metadata.displayName': null,
      'metadata.ip': null,  // Remove PII
      'metadata.userAgent': null,  // Remove PII
      // Keep: action, timestamp, resourceType (for compliance)
    });
  }
}
```

**Preserved for compliance**:
- Action performed
- Timestamp
- Resource type
- Anonymized user ID

**Removed (PII)**:
- Email
- Display name
- IP address
- User agent

## Retention Policy

GDPR requires audit logs for **7 years** for legal compliance:

```dart
Future<void> enforceRetentionPolicy() async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  // Delete logs older than 7 years
  await auditRepo.deleteLogsOlderThan(Duration(days: 365 * 7));
}

// Run as scheduled job (e.g., monthly)
void scheduleRetentionPolicyEnforcement() {
  Timer.periodic(Duration(days: 30), (_) async {
    await enforceRetentionPolicy();
  });
}
```

## UI Components

### Audit Trail View (Admin)

```dart
class AuditTrailView extends StatefulWidget {
  final String userId;

  const AuditTrailView({required this.userId});

  @override
  _AuditTrailViewState createState() => _AuditTrailViewState();
}

class _AuditTrailViewState extends State<AuditTrailView> {
  late final FirebaseAuditRepository _auditRepo;
  List<AuditEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _auditRepo = ServiceLocator.get<FirebaseAuditRepository>();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    setState(() => _isLoading = true);

    try {
      final events = await _auditRepo.getAuditTrail(widget.userId);
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      showError('Failed to load audit trail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audit Trail')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return ListTile(
                  leading: _buildActionIcon(event.action),
                  title: Text(_formatAction(event.action)),
                  subtitle: Text(
                    '${event.resourceType} - ${_formatTimestamp(event.timestamp)}',
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.info_outline),
                    onPressed: () => _showEventDetails(event),
                  ),
                );
              },
            ),
    );
  }

  Icon _buildActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.accountDeleted:
        return Icon(Icons.delete_forever, color: Colors.red);
      case AuditAction.consentGranted:
        return Icon(Icons.check_circle, color: Colors.green);
      case AuditAction.dataExport:
        return Icon(Icons.download, color: Colors.blue);
      case AuditAction.unauthorizedAccess:
        return Icon(Icons.warning, color: Colors.orange);
      default:
        return Icon(Icons.info);
    }
  }

  String _formatAction(AuditAction action) {
    return action.toString().split('.').last.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        ).trim();
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _showEventDetails(AuditEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Audit Event Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Action', _formatAction(event.action)),
              _buildDetailRow('User ID', event.userId),
              _buildDetailRow('Resource', event.resourceType),
              if (event.resourceId != null)
                _buildDetailRow('Resource ID', event.resourceId!),
              _buildDetailRow('Timestamp', event.timestamp.toIso8601String()),
              if (event.metadata != null && event.metadata!.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...event.metadata!.entries.map(
                  (e) => _buildDetailRow('  ${e.key}', e.value.toString()),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
```

## Testing Audit Logging

```dart
group('FirebaseAuditRepository', () {
  late FirebaseAuditRepository repository;
  late FakeFirebaseFirestore fakeFirestore;

  setUp() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirebaseAuditRepository(firestore: fakeFirestore);
  });

  test('logAuditEvent creates audit record', () async {
    final event = AuditEvent(
      id: 'audit-123',
      userId: 'user-123',
      action: AuditAction.accountDeleted,
      resourceType: 'user_account',
      resourceId: 'user-123',
      timestamp: DateTime.now(),
    );

    await repository.logAuditEvent(event);

    final doc = await fakeFirestore
        .collection('auditLogs')
        .doc('audit-123')
        .get();

    expect(doc.exists, isTrue);
    expect(doc.data()?['userId'], 'user-123');
    expect(doc.data()?['action'], 'account_deleted');
  });

  test('getAuditTrail returns user events', () async {
    // Seed audit events
    await repository.logAuditEvent(AuditEvent(
      id: 'audit-1',
      userId: 'user-123',
      action: AuditAction.consentGranted,
      resourceType: 'consent',
      timestamp: DateTime.now(),
    ));
    await repository.logAuditEvent(AuditEvent(
      id: 'audit-2',
      userId: 'user-123',
      action: AuditAction.dataExport,
      resourceType: 'user_data',
      timestamp: DateTime.now(),
    ));

    final events = await repository.getAuditTrail('user-123');

    expect(events.length, 2);
    expect(events[0].userId, 'user-123');
  });

  test('queryAuditLogs filters by action', () async {
    await repository.logAuditEvent(AuditEvent(
      id: 'audit-1',
      userId: 'user-123',
      action: AuditAction.consentGranted,
      resourceType: 'consent',
      timestamp: DateTime.now(),
    ));
    await repository.logAuditEvent(AuditEvent(
      id: 'audit-2',
      userId: 'user-123',
      action: AuditAction.dataExport,
      resourceType: 'user_data',
      timestamp: DateTime.now(),
    ));

    final events = await repository.queryAuditLogs(
      action: AuditAction.consentGranted,
    );

    expect(events.length, 1);
    expect(events[0].action, AuditAction.consentGranted);
  });

  test('anonymizeUserLogs removes PII', () async {
    final event = AuditEvent(
      id: 'audit-123',
      userId: 'user-123',
      action: AuditAction.accountDeleted,
      resourceType: 'user_account',
      timestamp: DateTime.now(),
      metadata: {
        'email': 'user@example.com',
        'displayName': 'John Doe',
        'ip': '192.168.1.1',
      },
    );

    await repository.logAuditEvent(event);
    await repository.anonymizeUserLogs('user-123');

    final doc = await fakeFirestore
        .collection('auditLogs')
        .doc('audit-123')
        .get();

    expect(doc.data()?['userId'], 'DELETED_USER');
    expect(doc.data()?['metadata']?['email'], isNull);
    expect(doc.data()?['metadata']?['displayName'], isNull);
    expect(doc.data()?['metadata']?['ip'], isNull);
  });

  test('deleteLogsOlderThan removes old logs', () async {
    final oldEvent = AuditEvent(
      id: 'audit-old',
      userId: 'user-123',
      action: AuditAction.accountCreated,
      resourceType: 'user_account',
      timestamp: DateTime.now().subtract(Duration(days: 365 * 8)), // 8 years old
    );
    final recentEvent = AuditEvent(
      id: 'audit-recent',
      userId: 'user-123',
      action: AuditAction.dataExport,
      resourceType: 'user_data',
      timestamp: DateTime.now(),
    );

    await repository.logAuditEvent(oldEvent);
    await repository.logAuditEvent(recentEvent);

    await repository.deleteLogsOlderThan(Duration(days: 365 * 7)); // 7 years

    final oldDoc = await fakeFirestore.collection('auditLogs').doc('audit-old').get();
    final recentDoc = await fakeFirestore.collection('auditLogs').doc('audit-recent').get();

    expect(oldDoc.exists, isFalse);  // Should be deleted
    expect(recentDoc.exists, isTrue);  // Should remain
  });
});
```

## Best Practices

1. **Log all sensitive operations** - Account changes, consent, data access
2. **Include context in metadata** - IP, user agent, reason for action
3. **Preserve audit trail** - Even after account deletion (anonymized)
4. **7-year retention** - Legal compliance requirement
5. **Queryable structure** - Efficient indexes for filtering
6. **Immutable records** - Never update/delete audit events (except retention policy)
7. **Anonymization support** - Remove PII while preserving compliance data

## Related Resources

- [consent-management.md](consent-management.md) - Article 7 compliance
- [data-export.md](data-export.md) - Article 15 compliance
- [account-deletion.md](account-deletion.md) - Article 17 compliance

---

**Impact**: GDPR Article 30 compliance
**Benefit**: Complete audit trail for regulatory compliance
**Status**: ✅ Production-ready
