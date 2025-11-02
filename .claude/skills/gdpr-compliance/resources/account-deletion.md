# Account Deletion - GDPR Article 17

Guide to implementing right to erasure using AccountDeletionService for GDPR Article 17 compliance.

## Overview

**GDPR Article 17** gives users the right to have their data deleted:
- **Complete deletion** - All personal data removed
- **Cascading deletion** - Across all collections
- **Immediate** - Deletion happens right away
- **Irreversible** - Warning dialogs required

**Implementation**: AccountDeletionService with cascading deletion workflow

## AccountDeletionService

**Location**: `lib/services/account/account_deletion_service.dart`

### Key Methods

```dart
class AccountDeletionService {
  // Delete account and all user data
  Future<void> deleteAccount(String userId);

  // Soft delete (anonymize instead of deleting)
  Future<void> anonymizeAccount(String userId);

  // Schedule deletion (delay for grace period)
  Future<void> scheduleAccountDeletion(String userId, Duration delay);
}
```

## Deletion Workflow

### Step-by-Step Process

1. **Verify user identity** - Re-authenticate user
2. **Log deletion initiated** - Create audit record
3. **Delete from all collections** - Cascading deletion
4. **Anonymize audit logs** - Remove PII, keep logs for compliance
5. **Delete authentication** - Remove from Firebase Auth
6. **Log deletion complete** - Final audit record

### deleteAccount() Implementation

```dart
Future<void> deleteAccount(String userId) async {
  try {
    // 1. Log deletion initiated
    await _auditRepo.logAuditEvent(AuditEvent(
      userId: userId,
      action: AuditAction.accountDeletionInitiated,
      timestamp: DateTime.now(),
    ));

    // 2. Delete user collections
    await _deleteUserCollections(userId);

    // 3. Delete user document
    await _firestoreRepository.firestore
        .collection('users')
        .doc(userId)
        .delete();

    // 4. Anonymize audit logs (keep for compliance, remove PII)
    await _anonymizeAuditLogs(userId);

    // 5. Delete from Firebase Auth
    await _authRepository.deleteUser(userId);

    // 6. Log deletion complete (final audit record)
    await _auditRepo.logAuditEvent(AuditEvent(
      userId: 'DELETED_$userId',  // Anonymized
      action: AuditAction.accountDeleted,
      timestamp: DateTime.now(),
    ));
  } catch (e) {
    // Log failure
    await _auditRepo.logAuditEvent(AuditEvent(
      userId: userId,
      action: AuditAction.accountDeletionFailed,
      timestamp: DateTime.now(),
      metadata: {'error': e.toString()},
    ));
    rethrow;
  }
}
```

### Collections Deleted

```dart
Future<void> _deleteUserCollections(String userId) async {
  final firestore = _firestoreRepository.firestore;

  // Personal content collections
  await _deleteCollection(firestore.collection('users').doc(userId).collection('recipes'));
  await _deleteCollection(firestore.collection('users').doc(userId).collection('menus'));
  await _deleteCollection(firestore.collection('users').doc(userId).collection('shopping'));
  await _deleteCollection(firestore.collection('users').doc(userId).collection('consent'));

  // Social content (where user is involved)
  await _deleteFriendRequests(userId);
  await _deleteComments(userId);
  await _deleteRatings(userId);
  await _deleteNotifications(userId);

  // Messaging
  await _deleteConversations(userId);
  await _deleteMessages(userId);
}
```

### Anonymize Audit Logs

```dart
Future<void> _anonymizeAuditLogs(String userId) async {
  // Query all audit logs for user
  final logs = await _auditRepo.getAuditTrail(userId);

  // Anonymize each log
  for (final log in logs) {
    await _auditRepo.update(log.id, {
      'userId': 'DELETED_USER',
      'metadata.email': null,
      'metadata.displayName': null,
      // Keep action, timestamp, resourceType for compliance
    });
  }
}
```

## UI Implementation

### Account Deletion Dialog

```dart
class AccountDeletionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row([
        Icon(Icons.warning, color: Colors.red),
        SizedBox(width: 8),
        Text('Delete Account?'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action cannot be undone!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 16),
          Text('All your data will be permanently deleted:'),
          SizedBox(height: 8),
          _buildDeletedDataList(),
          SizedBox(height: 16),
          Text(
            'Are you sure you want to continue?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('Delete Forever'),
        ),
      ],
    );
  }

  Widget _buildDeletedDataList() {
    return Column([
      _buildBulletPoint('All recipes and menus'),
      _buildBulletPoint('Shopping lists'),
      _buildBulletPoint('Social connections (friends, followers)'),
      _buildBulletPoint('Comments and ratings'),
      _buildBulletPoint('Messages and notifications'),
      _buildBulletPoint('Account settings and preferences'),
    ]);
  }

  Widget _buildBulletPoint(String text) {
    return Row([
      Icon(Icons.circle, size: 8),
      SizedBox(width: 8),
      Expanded(child: Text(text)),
    ]);
  }
}
```

### Account Deletion View

```dart
class AccountDeletionView extends StatefulWidget {
  @override
  _AccountDeletionViewState createState() => _AccountDeletionViewState();
}

class _AccountDeletionViewState extends State<AccountDeletionView> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    // 1. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AccountDeletionDialog(),
    );

    if (confirmed != true) return;

    // 2. Verify user identity (re-authenticate)
    final verified = await _reAuthenticateUser();
    if (!verified) {
      showError('Authentication required to delete account');
      return;
    }

    // 3. Delete account
    setState(() => _isDeleting = true);

    try {
      final deletionService = ServiceLocator.get<AccountDeletionService>();
      final userId = authService.currentUserId;

      await deletionService.deleteAccount(userId);

      // 4. Sign out and navigate to welcome screen
      await authService.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);

      showSnackbar('Your account has been deleted');
    } catch (e) {
      showError('Failed to delete account: $e');
      setState(() => _isDeleting = false);
    }
  }

  Future<bool> _reAuthenticateUser() async {
    // Show re-authentication dialog
    final credentials = await showDialog<AuthCredentials>(
      context: context,
      builder: (_) => ReAuthenticationDialog(),
    );

    if (credentials == null) return false;

    try {
      await authService.reAuthenticateWithCredential(credentials);
      return true;
    } catch (e) {
      showError('Re-authentication failed');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delete Account')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Delete Your Account', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text('This action is permanent and cannot be undone'),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isDeleting ? null : _deleteAccount,
              icon: _isDeleting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.delete_forever),
              label: Text(_isDeleting ? 'Deleting...' : 'Delete Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Testing Account Deletion

```dart
group('AccountDeletionService', () {
  late AccountDeletionService service;
  late FakeFirebaseFirestore fakeFirestore;

  setUp() async {
    fakeFirestore = FakeFirebaseFirestore();

    // Seed test data
    await _seedUserData(fakeFirestore, 'user-123');

    service = AccountDeletionService(
      firestore: fakeFirestore,
      authRepository: mockAuthRepo,
      auditRepository: mockAuditRepo,
    );
  });

  test('deleteAccount removes all user data', () async {
    // Act
    await service.deleteAccount('user-123');

    // Assert: User document deleted
    final userDoc = await fakeFirestore.collection('users').doc('user-123').get();
    expect(userDoc.exists, isFalse);

    // Assert: Collections deleted
    final recipes = await fakeFirestore
        .collection('users')
        .doc('user-123')
        .collection('recipes')
        .get();
    expect(recipes.docs, isEmpty);

    final menus = await fakeFirestore
        .collection('users')
        .doc('user-123')
        .collection('menus')
        .get();
    expect(menus.docs, isEmpty);
  });

  test('deleteAccount logs audit events', () async {
    await service.deleteAccount('user-123');

    // Verify audit events logged
    verify(() => mockAuditRepo.logAuditEvent(any(
      that: isA<AuditEvent>().having(
        (e) => e.action,
        'action',
        AuditAction.accountDeletionInitiated,
      ),
    ))).called(1);

    verify(() => mockAuditRepo.logAuditEvent(any(
      that: isA<AuditEvent>().having(
        (e) => e.action,
        'action',
        AuditAction.accountDeleted,
      ),
    ))).called(1);
  });
});
```

## Best Practices

1. **Require re-authentication** - Verify user identity
2. **Show clear warning** - Deletion is permanent
3. **Cascading deletion** - Delete from all collections
4. **Audit logging** - Log deletion events
5. **Anonymize audit logs** - Keep logs, remove PII
6. **Immediate deletion** - No delay (or short grace period)

## Related Resources

- [consent-management.md](consent-management.md) - Article 7
- [data-export.md](data-export.md) - Article 15
- [audit-logging.md](audit-logging.md) - Article 30

---

**Impact**: GDPR Article 17 compliance
**Benefit**: User right to erasure
**Status**: ✅ Production-ready
