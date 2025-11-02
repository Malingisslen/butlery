# GDPR Compliance Patterns

Comprehensive guide to GDPR compliance implementation in Butlery - Articles 7, 15, 17, 30 patterns and workflows.

## Overview

Butlery is **production-ready for EU market** with comprehensive GDPR compliance:
- **Article 7**: Explicit consent management (ConsentService)
- **Article 15**: Right of access / data portability (DataExportService)
- **Article 17**: Right to erasure / right to be forgotten (AccountDeletionService)
- **Article 30**: Records of processing activities (AuditRepository)

**Status**: ✅ Phase 1 Complete (Jan 2025) - All services implemented and tested

## When This Skill Activates

Auto-activates when you:
- Implement consent management features
- Handle user data export requests
- Implement account deletion workflows
- Add audit logging for compliance
- Work with GDPR-related services

## Quick Reference

### Article 7: Consent Management

```dart
// User gives/revokes consent
final consentService = ServiceLocator.get<ConsentService>();

// Check if user has consented
final hasConsented = await consentService.hasConsent(
  userId,
  ConsentType.dataProcessing,
);

// Request consent
await consentService.requestConsent(
  userId,
  ConsentType.marketing,
  version: '1.0',
);

// Revoke consent
await consentService.revokeConsent(
  userId,
  ConsentType.analytics,
);
```

### Article 15: Data Export

```dart
// Export all user data
final exportService = ServiceLocator.get<DataExportService>();

final exportData = await exportService.exportUserData(userId);
// Returns: { recipes: [...], menus: [...], preferences: {...} }

// Download as JSON file
final jsonString = await exportService.exportAsJson(userId);
```

### Article 17: Account Deletion

```dart
// Delete user account and all data
final deletionService = ServiceLocator.get<AccountDeletionService>();

await deletionService.deleteAccount(userId);
// Deletes: user profile, recipes, menus, lists, social data, etc.
```

### Article 30: Audit Logging

```dart
// Log security-sensitive operations
final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

await auditRepo.logAuditEvent(AuditEvent(
  userId: currentUserId,
  action: AuditAction.dataExport,
  resourceType: 'user_data',
  resourceId: userId,
  timestamp: DateTime.now(),
  metadata: {'format': 'JSON', 'size_kb': 150},
));
```

## GDPR Articles Overview

### Article 7: Explicit Consent

**Requirement**: Users must give explicit, informed consent for data processing

**Implementation**:
- ConsentService manages consent types
- Opt-in only (no pre-checked boxes)
- Version tracking (update privacy policy → re-consent)
- Granular controls (data processing, marketing, analytics)

**Firestore Structure**:
```
users/{userId}/consent/{consentType}
  - type: "data_processing" | "marketing" | "analytics"
  - granted: true/false
  - version: "1.0"
  - timestamp: Timestamp
```

### Article 15: Right of Access

**Requirement**: Users can request copy of all their data

**Implementation**:
- DataExportService generates complete data export
- JSON format with all user content
- Self-service from settings
- Includes: recipes, menus, lists, preferences, social data

**Export Structure**:
```json
{
  "user": { "id": "...", "email": "...", "displayName": "..." },
  "recipes": [{ "id": "...", "title": "...", "ingredients": [...] }],
  "menus": [...],
  "shoppingLists": [...],
  "preferences": {...},
  "exportDate": "2025-01-31T10:00:00Z"
}
```

### Article 17: Right to Erasure

**Requirement**: Users can request deletion of all their data

**Implementation**:
- AccountDeletionService with cascading deletion
- Deletes across all collections
- Audit trail of deletion
- Soft delete (anonymize) vs hard delete options

**Collections Deleted**:
- User profile, settings, consent records
- Personal recipes, menus, shopping lists
- Social data (friend requests, comments, ratings)
- Messaging data, notifications
- Audit logs (retained for legal compliance)

### Article 30: Records of Processing

**Requirement**: Maintain audit trail of data processing activities

**Implementation**:
- FirebaseAuditRepository with persistent logging
- Tracks security-sensitive operations
- Retention policy (7 years for legal compliance)
- Query capabilities for regulatory review

**Audit Events**:
- Account creation/deletion
- Data export requests
- Consent granted/revoked
- Permission changes
- Security events

## GDPR Services

### 1. ConsentService

**Purpose**: Manage user consent for data processing

**Location**: `lib/services/account/consent_service.dart`

**Key Methods**:
```dart
Future<bool> hasConsent(String userId, ConsentType type);
Future<void> requestConsent(String userId, ConsentType type, String version);
Future<void> revokeConsent(String userId, ConsentType type);
Future<Map<ConsentType, ConsentRecord>> getAllConsents(String userId);
```

**Consent Types**:
- `ConsentType.dataProcessing` - Basic app functionality
- `ConsentType.marketing` - Marketing communications
- `ConsentType.analytics` - Usage analytics

**Firestore Integration**:
- Stores in: `users/{userId}/consent/{consentType}`
- Version tracking for privacy policy updates
- Timestamp for audit trail

### 2. DataExportService

**Purpose**: Export all user data (GDPR Article 15)

**Location**: `lib/services/account/data_export_service.dart`

**Key Methods**:
```dart
Future<Map<String, dynamic>> exportUserData(String userId);
Future<String> exportAsJson(String userId);
Future<File> exportAsFile(String userId);
```

**Data Included**:
- User profile (email, displayName, settings)
- Recipes (personal + shared)
- Menus
- Shopping lists
- Preferences and settings
- Social data (friends, ratings, comments)

**Self-Service**:
- Available in user settings
- One-click export
- Downloads as JSON file

### 3. AccountDeletionService

**Purpose**: Delete user account and all data (GDPR Article 17)

**Location**: `lib/services/account/account_deletion_service.dart`

**Key Methods**:
```dart
Future<void> deleteAccount(String userId);
Future<void> softDeleteAccount(String userId); // Anonymize instead
Future<void> scheduleAccountDeletion(String userId, Duration delay);
```

**Deletion Workflow**:
1. Verify user identity
2. Create audit record (deletion initiated)
3. Delete from all collections (cascading)
4. Anonymize audit logs (keep for compliance, remove PII)
5. Delete authentication
6. Create final audit record (deletion complete)

**Collections Deleted**:
- `users/{userId}` - User profile
- `users/{userId}/recipes` - Personal recipes
- `users/{userId}/menus` - Personal menus
- `users/{userId}/shopping` - Shopping lists
- `users/{userId}/consent` - Consent records
- `friendRequests` - Where userId involved
- `comments` - User's comments
- `ratings` - User's ratings
- `notifications/{userId}` - User notifications

### 4. FirebaseAuditRepository

**Purpose**: Audit logging for compliance (GDPR Article 30)

**Location**: `lib/repositories/firebase/firebase_audit_repository.dart`

**Key Methods**:
```dart
Future<void> logAuditEvent(AuditEvent event);
Future<List<AuditEvent>> getAuditTrail(String userId);
Future<List<AuditEvent>> getAuditsByAction(AuditAction action);
```

**Audit Actions**:
- `AuditAction.accountCreated`
- `AuditAction.accountDeleted`
- `AuditAction.dataExport`
- `AuditAction.consentGranted`
- `AuditAction.consentRevoked`
- `AuditAction.permissionChanged`

**Firestore Structure**:
```
auditLogs/{auditId}
  - userId: string
  - action: AuditAction
  - resourceType: string
  - resourceId: string
  - timestamp: Timestamp
  - metadata: Map<String, dynamic>
```

## GDPR Workflows

### Workflow 1: User Consent on First Launch

```dart
// 1. Check if user has given consent
final consentService = ServiceLocator.get<ConsentService>();
final hasConsented = await consentService.hasConsent(
  userId,
  ConsentType.dataProcessing,
);

// 2. If not consented, show consent dialog
if (!hasConsented) {
  final granted = await showConsentDialog(context);

  if (granted) {
    await consentService.requestConsent(
      userId,
      ConsentType.dataProcessing,
      version: '1.0',
    );
  } else {
    // User must consent to use app
    Navigator.pushReplacementNamed(context, '/consent-required');
  }
}
```

### Workflow 2: Privacy Policy Update (Re-Consent)

```dart
// 1. Check if user has consented to latest version
final currentVersion = '2.0';
final consent = await consentService.getConsent(
  userId,
  ConsentType.dataProcessing,
);

// 2. If old version, request re-consent
if (consent?.version != currentVersion) {
  final reConsented = await showPrivacyPolicyUpdate(context);

  if (reConsented) {
    await consentService.requestConsent(
      userId,
      ConsentType.dataProcessing,
      version: currentVersion,
    );
  }
}
```

### Workflow 3: User Requests Data Export

```dart
// 1. User clicks "Export My Data" in settings
final exportService = ServiceLocator.get<DataExportService>();

// 2. Show loading indicator
showLoadingDialog(context, 'Preparing your data export...');

// 3. Generate export
final jsonString = await exportService.exportAsJson(userId);

// 4. Create file and download
final file = await exportService.saveToFile(jsonString, 'my_data.json');

// 5. Share/download file
await Share.shareFiles([file.path], text: 'My Butlery Data');

// 6. Log audit event
await auditRepo.logAuditEvent(AuditEvent(
  userId: userId,
  action: AuditAction.dataExport,
  resourceType: 'user_data',
  timestamp: DateTime.now(),
));
```

### Workflow 4: User Deletes Account

```dart
// 1. User clicks "Delete Account" in settings
// 2. Show confirmation dialog (serious warning)
final confirmed = await showAccountDeletionDialog(context);

if (!confirmed) return;

// 3. Verify user identity (re-authenticate)
final verified = await reAuthenticateUser(context);

if (!verified) {
  showError('Authentication required to delete account');
  return;
}

// 4. Delete account
final deletionService = ServiceLocator.get<AccountDeletionService>();
showLoadingDialog(context, 'Deleting your account...');

try {
  await deletionService.deleteAccount(userId);

  // 5. Sign out and navigate to welcome screen
  await authService.signOut();
  Navigator.pushReplacementNamed(context, '/welcome');

  showSnackbar('Your account has been deleted');
} catch (e) {
  showError('Failed to delete account: $e');
}
```

## Firestore Security Rules

### Consent Collection Rules

```javascript
// User can only read/write their own consent
match /users/{userId}/consent/{consentId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Audit Logs Rules

```javascript
// Users can read their own audit logs, admin can read all
match /auditLogs/{auditId} {
  allow read: if request.auth != null &&
              (request.auth.uid == resource.data.userId ||
               request.auth.token.admin == true);

  // Only server/functions can write audit logs
  allow write: if request.auth.token.admin == true;
}
```

### Data Export Rules

```javascript
// User data is protected - only owner can access
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;

  match /recipes/{recipeId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }

  match /menus/{menuId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
}
```

## User-Facing Features

### Settings > Privacy

**Consent Management**:
- View current consent status
- Revoke consent (with warning)
- View privacy policy

**Data Export**:
- "Download My Data" button
- Generates JSON file with all data
- Self-service (no support needed)

**Account Deletion**:
- "Delete Account" button
- Confirmation dialog with warning
- Re-authentication required
- Immediate deletion

### UI Components

**Consent Dialog** (`lib/views/account/consent_dialog.dart`):
```dart
class ConsentDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Data Processing Consent'),
      content: Column([
        Text('We need your consent to process your data...'),
        PrivacyPolicyLink(),
        // Checkboxes for different consent types
        ConsentCheckbox(type: ConsentType.dataProcessing, required: true),
        ConsentCheckbox(type: ConsentType.marketing, required: false),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Decline'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Accept'),
        ),
      ],
    );
  }
}
```

**Account Deletion Dialog** (`lib/views/account/account_deletion_dialog.dart`):
```dart
class AccountDeletionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete Account?'),
      content: Column([
        Icon(Icons.warning, color: Colors.red, size: 64),
        SizedBox(height: 16),
        Text('This action cannot be undone!'),
        Text('All your data will be permanently deleted:'),
        BulletList([
          'All recipes and menus',
          'Shopping lists',
          'Social connections',
          'Comments and ratings',
        ]),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Delete Forever'),
        ),
      ],
    );
  }
}
```

## Testing GDPR Compliance

### Testing ConsentService

```dart
test('user can grant consent', () async {
  await consentService.requestConsent(
    testUserId,
    ConsentType.dataProcessing,
    version: '1.0',
  );

  final hasConsent = await consentService.hasConsent(
    testUserId,
    ConsentType.dataProcessing,
  );

  expect(hasConsent, isTrue);
});

test('user can revoke consent', () async {
  await consentService.requestConsent(testUserId, ConsentType.marketing);
  await consentService.revokeConsent(testUserId, ConsentType.marketing);

  final hasConsent = await consentService.hasConsent(
    testUserId,
    ConsentType.marketing,
  );

  expect(hasConsent, isFalse);
});
```

### Testing DataExportService

```dart
test('export includes all user data', () async {
  // Create test data
  await seedUserData(testUserId);

  // Export
  final exportData = await exportService.exportUserData(testUserId);

  // Verify all data included
  expect(exportData['user'], isNotNull);
  expect(exportData['recipes'], isA<List>());
  expect(exportData['menus'], isA<List>());
  expect(exportData['preferences'], isA<Map>());
});

test('export generates valid JSON', () async {
  final jsonString = await exportService.exportAsJson(testUserId);

  // Verify valid JSON
  expect(() => jsonDecode(jsonString), returnsNormally);

  final data = jsonDecode(jsonString);
  expect(data['exportDate'], isNotNull);
});
```

### Testing AccountDeletionService

```dart
test('deleteAccount removes all user data', () async {
  // Create test data
  await seedUserData(testUserId);

  // Delete account
  await deletionService.deleteAccount(testUserId);

  // Verify all data deleted
  final userData = await getUserData(testUserId);
  expect(userData, isNull);

  final recipes = await getRecipes(testUserId);
  expect(recipes, isEmpty);

  final menus = await getMenus(testUserId);
  expect(menus, isEmpty);
});

test('deleteAccount logs audit event', () async {
  await deletionService.deleteAccount(testUserId);

  final auditEvents = await auditRepo.getAuditTrail(testUserId);
  final deletionEvent = auditEvents.firstWhere(
    (e) => e.action == AuditAction.accountDeleted,
  );

  expect(deletionEvent, isNotNull);
});
```

## Resource Files

Detailed documentation for each GDPR article:

1. **[consent-management.md](resources/consent-management.md)** - Article 7
   - ConsentService patterns
   - Consent types and versions
   - UI components for consent
   - Testing consent workflows

2. **[data-export.md](resources/data-export.md)** - Article 15
   - DataExportService patterns
   - Export format and structure
   - Self-service export workflow
   - Testing data completeness

3. **[account-deletion.md](resources/account-deletion.md)** - Article 17
   - AccountDeletionService patterns
   - Cascading deletion workflow
   - Soft delete vs hard delete
   - Testing deletion completeness

4. **[audit-logging.md](resources/audit-logging.md)** - Article 30
   - FirebaseAuditRepository patterns
   - Audit event types
   - Retention policies
   - Querying audit trail

## Compliance Checklist

### Article 7 (Consent)
- ✅ Explicit consent required before data processing
- ✅ Opt-in only (no pre-checked boxes)
- ✅ Granular controls (separate consent types)
- ✅ Consent version tracking
- ✅ Easy withdrawal of consent
- ✅ Consent records stored in Firestore

### Article 15 (Right of Access)
- ✅ Self-service data export in settings
- ✅ Complete user data included
- ✅ Machine-readable format (JSON)
- ✅ Export available immediately
- ✅ Audit logging of export requests

### Article 17 (Right to Erasure)
- ✅ Self-service account deletion
- ✅ Cascading deletion across all collections
- ✅ Confirmation dialog with warnings
- ✅ Re-authentication required
- ✅ Audit logging of deletions
- ✅ Immediate deletion (not delayed)

### Article 30 (Records of Processing)
- ✅ Audit repository with persistent logging
- ✅ Security events tracked
- ✅ Retention policy (7 years)
- ✅ Query capabilities
- ✅ Anonymization of deleted user logs

## Related Skills

**Complementary Skills**:
- 🏗️ **[butlery-architecture](../butlery-architecture/SKILL.md)** - For overall MVVM architecture and service patterns
- 🗄️ **[firebase-repository-patterns](../firebase-repository-patterns/SKILL.md)** - For audit logging patterns in repositories
- 🔧 **[dependency-injection-patterns](../dependency-injection-patterns/SKILL.md)** - For service access patterns
- 📋 **[testing-patterns](../testing-patterns/SKILL.md)** - For testing GDPR compliance features

---

**Skill Version**: 1.0
**Last Updated**: 2025-01-31
**Status**: Week 4 of Claude Code infrastructure system
**Compliance**: ✅ Production-ready for EU market (Phase 1 complete)
