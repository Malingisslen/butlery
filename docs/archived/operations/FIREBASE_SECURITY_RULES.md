# Firebase Security Rules Documentation

## Overview
This document explains the Firebase Security Rules implemented for the Butlery app. These rules ensure that data is properly secured and users can only access data they're authorized to see.

## Security Principles

1. **Authentication Required**: All operations require user authentication
2. **User Data Isolation**: Users can only access their own private data
3. **Explicit Sharing**: Shared content requires explicit permissions
4. **Least Privilege**: Users get minimum necessary access
5. **Input Validation**: Required fields and data types are enforced

## Rule Structure

### 🔐 Private User Data (`/users/{userId}/`)
**Access**: Only the owner can read/write

- **recipes**: User's personal recipes
- **recipe_summaries**: Lightweight recipe metadata
- **friends**: User's friend list
- **friend_categories**: Friend groups/categories
- **connection_tests**: App initialization tests

### 👥 Public Profiles (`/user_profiles/{userId}`)
**Read**: Any authenticated user  
**Write**: Only profile owner

Required fields for creation:
- `displayName`
- `createdAt`
- `updatedAt`
- `isSearchable` (boolean)

### 🤝 Friend Requests (`/friend_requests/{requestId}`)
**Read**: Sender or recipient  
**Create**: Sender only (must set status='pending')  
**Update**: Recipient only (to accept/reject)  
**Delete**: Sender or recipient

Required fields:
- `fromUserId`
- `toUserId`
- `status`
- `sentAt`

### 💌 Group Invitations (`/group_invitations/{invitationId}`)
**Read**: Sender or recipient  
**Create**: Sender only  
**Update**: Recipient only  
**Delete**: Sender or recipient

### 🍳 Shared Recipes (`/shared_recipes/{shareId}`)
**Read**: Owner or anyone in `sharedWith` list  
**Create/Update**: Owner only  
**Delete**: Owner or shared recipients (to remove from their list)

### 📅 Shared Menus (`/shared_menus/{menuId}`)
**Read**: Owner or anyone in `sharedWith` list  
**Write**: Owner only

### 🛒 Shared Shopping Lists (`/shared_shopping_lists/{listId}`)
**Read**: Owner or collaborators  
**Create**: Owner (must include self in collaborators)  
**Update**: Owner or any collaborator (real-time collaboration)  
**Delete**: Owner only

### 💬 Recipe Comments (`/recipe_comments/{commentId}`)
**Read**: Any authenticated user  
**Create**: Authenticated users (max 1000 chars)  
**Update/Delete**: Comment author only

### 📚 Butlery Archive (`/butlery_archive/`)
**Read**: Any authenticated user  
**Write**: Blocked (admin-only via server)

## Security Features

### Helper Functions
- `isAuthenticated()`: Checks if user is logged in
- `isOwner(userId)`: Verifies user owns the resource
- `isDocumentOwner()`: Checks document ownership
- `isInList(field)`: Checks if user is in a list field
- `hasRequiredFields(fields)`: Validates required fields exist

### Data Validation
- Comment length: 1-1000 characters
- Required fields enforced on document creation
- Status values restricted to valid options
- Boolean type checking for flags

### Default Deny
Any path not explicitly defined is denied access by default.

## Testing Security Rules

### Firebase Emulator
```bash
firebase emulators:start --only firestore
```

### Example Test Cases
```javascript
// Test: User can only read their own recipes
const myRecipe = db.collection('users').doc('myUserId').collection('recipes').doc('recipe1');
await firebase.assertSucceeds(myRecipe.get());

const otherRecipe = db.collection('users').doc('otherUserId').collection('recipes').doc('recipe1');
await firebase.assertFails(otherRecipe.get());
```

## Deployment

⚠️ **IMPORTANT**: Do NOT deploy these rules to production until:
1. A comprehensive test system has been implemented (Priority 4.1 in todo.md)
2. All security rules have been thoroughly tested in the Firebase Emulator
3. Integration tests verify that all app features work with the rules
4. Permission checks in repositories (Priority 1.1.3) are implemented

### Testing First (Required)
```bash
# Start Firebase Emulator for testing
firebase emulators:start --only firestore

# Run security rules tests (after test system is built)
npm test -- --testPathPattern=security
```

### Deploy Rules (After Testing)
```bash
firebase deploy --only firestore:rules
```

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### Deploy Both
```bash
firebase deploy --only firestore
```

## Important Notes

1. **API Keys**: Ensure Firebase API keys are restricted in the Firebase Console
2. **App Check**: Enable Firebase App Check for additional security
3. **Monitoring**: Use Firebase Console to monitor rule violations
4. **Testing**: Always test rules in emulator before deploying
5. **Updates**: Review and update rules when adding new features

## Common Patterns

### User-Scoped Data
```javascript
match /users/{userId}/collection/{docId} {
  allow read, write: if request.auth.uid == userId;
}
```

### Shared Resources
```javascript
allow read: if request.auth.uid in resource.data.sharedWith;
```

### Status-Based Access
```javascript
allow update: if request.auth.uid == resource.data.recipientId
  && request.resource.data.status in ['accepted', 'rejected'];
```

## Security Checklist

- [ ] All paths have explicit rules
- [ ] Authentication required for all operations
- [ ] User data properly isolated
- [ ] Shared data has permission checks
- [ ] Input validation on writes
- [ ] No admin operations exposed
- [ ] Default deny rule in place
- [ ] Indexes created for all queries
- [ ] Rules tested in emulator
- [ ] API keys restricted in console