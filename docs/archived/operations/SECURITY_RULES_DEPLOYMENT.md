# Firebase Security Rules Deployment Guide

## Overview

This guide covers testing and deploying Firebase Security Rules for the Butlery application. The security rules enforce the same permission validation patterns implemented in the application-layer repositories.

## Security Rules Architecture

### Application-Layer Security (Dart/Flutter)
- **BaseFirebaseRepository** with `PermissionValidationMixin`
- **10 Repository implementations** with permission validation methods
- **FirebaseAuditRepository** for GDPR Article 30 compliance logging
- **Persistent audit logging** with fire-and-forget pattern

### Firebase Security Rules (Cloud)
- **Firestore Rules**: 30+ collection patterns covering all data access
- **Storage Rules**: User-scoped file access with path validation
- **Defense in depth**: Both application and cloud-level security

## Collections Covered

### Core User Data
- `users/{userId}` - Private user data (self-access only)
- `public_profiles/{userId}` - Public profiles (read: all, write: owner)
- `users/{userId}/consent/{consentDoc}` - GDPR consent (self-access)

### Social Features
- `friend_requests/{requestId}` - Friend request management
- `group_invitations/{invitationId}` - Group invitation system
- `conversations/{conversationId}` - Messaging (participant-only)
- `messages/{messageId}` - Top-level messages (sender permissions)

### Recipe & Menu Sharing
- `shared_recipes/{shareId}` - Recipe sharing
- `shared_menus/{menuId}` - Menu sharing with collaboration
- `recipe_comments/{commentId}` - Threaded comments
- `recipe_ratings/{ratingId}` - 5-star rating system
- `menu_ratings/{menuId}/ratings/{ratingId}` - Menu ratings
- `menu_comments/{menuId}/comments/{commentId}` - Menu comments
- `menu_templates/{templateId}` - Reusable menu templates
- `menu_activity/{menuId}/activities/{activityId}` - Collaboration logs

### Shopping Lists
- `shoppingLists/{listId}` - Personal shopping lists
- `sharedShoppingLists/{listId}` - Shared shopping lists
- `unified_shared_shopping_lists/{listId}` - Unified collaborative lists

### Realtime Collaboration
- `realtime_recipes/{recipeId}` - Real-time recipe editing
- `realtime_recipes/{recipeId}/presence/{userId}` - Presence tracking

### Notifications
- `user_notifications/{notificationId}` - Push notifications (self-access)
- `user_fcm_tokens/{userId}` - FCM tokens (self-access)
- `user_notification_preferences/{userId}` - Notification settings (self-access)

### GDPR Compliance
- `audit_logs/{logId}` - Immutable audit trail (Article 30)
- `users/{userId}/consent/{consentDoc}` - Consent management (Article 7)

## Testing Security Rules

### 1. Local Testing with Firebase Emulator

#### Start Emulator
```bash
firebase emulators:start
```

This starts:
- Firestore Emulator: `localhost:8080`
- Storage Emulator: `localhost:9199`
- Auth Emulator: `localhost:9099`
- Emulator UI: `localhost:4000`

#### Run Integration Tests
```bash
flutter test test/integration/security_rules_test.dart
```

### 2. Manual Testing Checklist

#### Recipe Ratings Security
```dart
// ✅ SHOULD SUCCEED: User rating their own recipe
await ratingsRepo.rateRecipe(
  recipeId: recipeId,
  userId: currentUserId,
  rating: 4.5,
);

// ❌ SHOULD FAIL: User rating as another user
await ratingsRepo.rateRecipe(
  recipeId: recipeId,
  userId: otherUserId, // Permission denied
  rating: 4.5,
);
```

#### Notification Security
```dart
// ✅ SHOULD SUCCEED: User reading their own notifications
final myNotifications = await notificationRepo.getUserNotifications(currentUserId);

// ❌ SHOULD FAIL: User reading another user's notifications
final otherNotifications = await notificationRepo.getUserNotifications(otherUserId); // Permission denied
```

#### Audit Log Security
```dart
// ✅ SHOULD SUCCEED: User reading their own audit logs
final myLogs = await auditRepo.getUserAuditLogs(currentUserId);

// ❌ SHOULD FAIL: Attempting to delete audit logs
await auditRepo.deleteAuditLog(logId); // Permission denied (immutable)
```

### 3. Firestore Rules Unit Tests (Optional)

Create `test/firestore_rules/rules_test.js`:

```javascript
const firebase = require('@firebase/rules-unit-testing');
const fs = require('fs');

const PROJECT_ID = 'butlery-test';
const RULES = fs.readFileSync('firestore.rules', 'utf8');

describe('Firestore Security Rules', () => {
  beforeAll(async () => {
    await firebase.loadFirestoreRules({
      projectId: PROJECT_ID,
      rules: RULES,
    });
  });

  afterAll(async () => {
    await firebase.clearFirestoreData({ projectId: PROJECT_ID });
  });

  test('Users can only read their own notifications', async () => {
    const db = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: { uid: 'user1' },
    }).firestore();

    // Should succeed
    await firebase.assertSucceeds(
      db.collection('user_notifications')
        .where('userId', '==', 'user1')
        .get()
    );

    // Should fail
    await firebase.assertFails(
      db.collection('user_notifications')
        .where('userId', '==', 'user2')
        .get()
    );
  });
});
```

Run with:
```bash
npm test -- test/firestore_rules/rules_test.js
```

## Deployment Process

### Prerequisites

1. **Install Firebase CLI** (if not installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Verify Project**:
   ```bash
   firebase use
   ```
   Should show: `butlery-app-1`

### Deployment Options

#### Option 1: Use Deployment Script (Recommended)
```bash
scripts\deploy_security_rules.bat
```

The script will:
1. Verify Firebase CLI is installed
2. Confirm you're logged in
3. Show current project
4. Ask for confirmation
5. Deploy Firestore rules
6. Deploy Storage rules
7. Provide verification instructions

#### Option 2: Manual Deployment

**Deploy Both Firestore and Storage Rules:**
```bash
firebase deploy --only firestore:rules,storage:rules
```

**Deploy Only Firestore Rules:**
```bash
firebase deploy --only firestore:rules
```

**Deploy Only Storage Rules:**
```bash
firebase deploy --only storage:rules
```

### Deployment Verification

#### 1. Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `butlery-app-1`
3. Navigate to **Firestore Database** → **Rules**
4. Verify rules match `firestore.rules` file
5. Navigate to **Storage** → **Rules**
6. Verify rules match `storage.rules` file

#### 2. Check Rule Deployment Timestamp
```bash
firebase firestore:rules:get
```

#### 3. Integration Testing
Run the full test suite against production:
```bash
flutter test --dart-define=USE_PRODUCTION=true
```

## Security Rules Summary

### Key Patterns

1. **Authentication Required**
   - All operations require `isAuthenticated()` (request.auth != null)

2. **Self-Access Pattern**
   - Users can only access their own data (notifications, preferences, tokens)
   - Enforced with: `request.auth.uid == userId`

3. **Ownership Pattern**
   - Resource owners have full CRUD permissions
   - Enforced with: `request.auth.uid == resource.data.ownerId`

4. **Participant Pattern**
   - Shared resources accessible to participants/collaborators
   - Enforced with: `request.auth.uid in resource.data.participantIds`

5. **Immutable Audit Pattern**
   - Audit logs and activity logs are write-once, no updates/deletes
   - Enforced with: `allow update, delete: if false`

6. **Field Validation Pattern**
   - Required fields enforced: `hasRequiredFields(['field1', 'field2'])`
   - Value ranges validated: `request.resource.data.rating >= 1 && <= 5`

### GDPR Compliance

✅ **Article 7 (Consent)**: `users/{userId}/consent/{consentDoc}` collection
✅ **Article 15 (Right of Access)**: Users can read their own audit logs
✅ **Article 17 (Right to Erasure)**: Users can delete their own data
✅ **Article 30 (Records of Processing)**: Immutable audit_logs collection

## Rollback Procedure

If rules cause issues in production:

### 1. Quick Rollback (Firebase Console)
1. Go to Firebase Console → Firestore → Rules
2. Click "Version History"
3. Select previous working version
4. Click "Publish"

### 2. Git Rollback
```bash
# Revert to previous version
git log firestore.rules
git checkout <previous-commit-hash> firestore.rules

# Deploy old rules
firebase deploy --only firestore:rules
```

### 3. Emergency Open Rules (Last Resort)
```javascript
// ONLY FOR EMERGENCY DEBUGGING
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

**⚠️ WARNING**: Never use open rules in production long-term!

## Troubleshooting

### Issue: "Permission Denied" Errors

**Diagnosis:**
```bash
# Check Firestore logs
firebase functions:log

# Enable debug logging in app
flutter run --dart-define=LOG_LEVEL=debug
```

**Common Causes:**
1. Rules not deployed: Run `firebase deploy --only firestore:rules`
2. User not authenticated: Check `authRepository.currentUser`
3. Field mismatch: Verify data structure matches rules expectations
4. Array checks: Ensure arrays exist before checking containment

### Issue: Rules Deployment Fails

**Diagnosis:**
```bash
firebase deploy --only firestore:rules --debug
```

**Common Causes:**
1. Syntax error in rules file
2. Not logged in: Run `firebase login`
3. Wrong project: Run `firebase use butlery-app-1`
4. Network issues: Check internet connection

### Issue: Rules Work in Emulator but Not Production

**Diagnosis:**
1. Verify deployment: Check Firebase Console
2. Compare timestamps: `firebase firestore:rules:get`
3. Clear app cache: Uninstall and reinstall app

## Maintenance

### Regular Security Audits

**Monthly Review:**
- Review `audit_logs` for suspicious patterns
- Check for permission denied errors in Firebase logs
- Verify new features have corresponding rules

**After Major Features:**
- Update rules for new collections
- Test permission scenarios
- Deploy and verify

### Adding New Collections

1. **Add to `firestore.rules`**:
   ```javascript
   match /new_collection/{docId} {
     allow read: if isAuthenticated() && <condition>;
     allow create: if isAuthenticated() && <condition>;
     allow update: if isAuthenticated() && <condition>;
     allow delete: if isAuthenticated() && <condition>;
   }
   ```

2. **Add repository permission validation**:
   ```dart
   @override
   Future<bool> validateReadPermission(...) async {
     // Implement matching logic
   }
   ```

3. **Test locally with emulator**
4. **Deploy to production**

## Quick Reference

### Security Principles

1. **Authentication Required**: All operations require user authentication
2. **User Data Isolation**: Users can only access their own private data
3. **Explicit Sharing**: Shared content requires explicit permissions
4. **Least Privilege**: Users get minimum necessary access
5. **Input Validation**: Required fields and data types are enforced

### Helper Functions

- `isAuthenticated()`: Checks if user is logged in (request.auth != null)
- `isOwner(userId)`: Verifies user owns the resource (request.auth.uid == userId)
- `isDocumentOwner()`: Checks document ownership via resource.data
- `isInList(field)`: Checks if user is in a list field (e.g., sharedWith, participants)
- `hasRequiredFields(fields)`: Validates required fields exist in document

### Security Checklist

Before deploying to production, verify:

- [ ] All paths have explicit rules
- [ ] Authentication required for all operations
- [ ] User data properly isolated
- [ ] Shared data has permission checks
- [ ] Input validation on writes
- [ ] No admin operations exposed
- [ ] Default deny rule in place
- [ ] Indexes created for all queries
- [ ] Rules tested in emulator
- [ ] API keys restricted in Firebase Console

## Support

For issues with security rules deployment:
1. Check Firebase Console logs
2. Review `docs/audit/REMEDIATION_ACTION_PLAN.md`
3. Check application-layer security in repositories
4. Consult Firebase Security Rules documentation

---

**Last Updated**: January 30, 2025
**Rules Version**: Phase 1 Security Remediation (Complete)
**Maintainer**: Development Team
