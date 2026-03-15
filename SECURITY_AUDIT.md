# Security Audit — Butlery Flutter/Firebase Codebase

**Date**: 2026-03-15
**Scope**: Full STRIDE-based threat model and OWASP-style security sweep
**Architecture**: Flutter thick client → Firebase (Firestore, Auth, Storage, Cloud Functions)

---

## Summary Dashboard

| Severity | Total | Fixed | Deferred | No Action |
|----------|-------|-------|----------|-----------|
| Critical | 0 | 0 | 0 | 0 |
| High | 4 | 4 | 0 | 0 |
| Medium | 13 | 9 | 4 | 0 |
| Low | 11 | 7 | 3 | 1 |
| Info | 5 | 1 | 1 | 3 |
| **Total** | **33** | **21** | **8** | **4** |

**Remediation date**: 2026-03-15

---

## Threat Model — STRIDE Analysis

### Assets

| Asset | Sensitivity | Storage |
|-------|-------------|---------|
| User recipes | High (personal IP) | `users/{uid}/recipes` |
| Personal data (email, avatar, settings) | High (PII/GDPR) | `users/{uid}`, `public_profiles` |
| Social graph (friends, groups) | Medium | `users/{uid}/friends`, `friendCategories` |
| Shared content (recipes, menus, shopping lists) | Medium | `shared_recipes`, `shared_menus`, `shared_shopping_lists` |
| Auth tokens / session state | Critical | Firebase Auth (SDK-managed) |
| Allergen/dietary data | High (health-critical) | `users/{uid}/recipes` → `core.tagResult` |
| Feedback submissions | Low–Medium | `feedback` collection + Storage |
| OCR API keys | High | ~~Hardcoded in Dart source~~ → Build-time environment variable |

### Trust Boundaries

| Boundary | Description |
|----------|-------------|
| **Client ↔ Firestore Rules** | Primary defense surface. All authorization enforced here. |
| **Client ↔ Storage Rules** | File upload/download authorization. |
| **Client ↔ Cloud Functions** | Server-side logic (notifications, cleanup). |
| **Cloud Functions ↔ Firestore** | Admin SDK — bypasses rules, trusted. |

### STRIDE Per Boundary

| Threat | Client ↔ Firestore | Client ↔ Storage | Client ↔ Functions |
|--------|--------------------|--------------------|---------------------|
| **Spoofing** | Mitigated: `request.auth.uid` on every rule | Mitigated: auth check on all paths | Mitigated: `context.auth` required |
| **Tampering** | **HIGH**: Several collections allow field overwrites beyond intent (see P1-01, P1-02, P1-05) | LOW: metadata.uploadedBy validated | LOW: Input sanitized in notification payloads |
| **Repudiation** | LOW: Audit logs are client-writable (P1-13) | N/A | LOW: Full UIDs in function logs (P5-03) |
| **Info Disclosure** | MEDIUM: Comments/ratings readable by all auth users (P1-09); public_profiles expose email (P4-04) | LOW: Shared images publicly readable (P1-12) | LOW: UIDs in logs |
| **DoS** | MEDIUM: `globalRecipeCache` unconstrained create (P1-04); no message length limits (P3-02) | LOW: 10MB upload limit enforced | Mitigated: Rate limiting on social operations |
| **Elevation of Privilege** | **HIGH**: Collaborators can overwrite `ownerId` (P1-01); members can self-join groups (P1-03) | MEDIUM: Any auth user can upload to any shared recipe path (P1-06) | MEDIUM: Conversation-based auth is bypassable (P5-01) |

---

## Findings

### Pass 1 — Firestore & Storage Rules

#### P1-01 | HIGH | Realtime Collab Docs: Collaborators Can Overwrite `ownerId`

**Status: FIXED** — `affectedKeys` restriction added for non-owners.

**Location**: `firestore.rules:1027-1030`
**STRIDE**: Elevation of Privilege

**Description**: The `unified_shared_shopping_lists` update rule allows any collaborator to modify all fields, including `ownerId` and `collaborators`. A collaborator can take ownership of the document or add/remove other collaborators.

**Proof**:
```javascript
// firestore.rules:1026-1030
// Can update if you're a collaborator (for real-time collaboration)
allow update: if isAuthenticated() && (
  request.auth.uid == resource.data.ownerId ||
  request.auth.uid in resource.data.collaborators
);
```

No `affectedKeys()` constraint prevents collaborators from modifying ownership fields.

**Recommended Fix**: Add field restriction for non-owners:
```javascript
allow update: if isAuthenticated() && (
  request.auth.uid == resource.data.ownerId ||
  (request.auth.uid in resource.data.collaborators
   && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['ownerId', 'collaborators', 'createdAt']))
);
```

---

#### P1-02 | HIGH | Shared Shopping Lists: Members Can Overwrite `sharedByUserId`

**Status: FIXED** — `affectedKeys` restriction added for members.

**Location**: `firestore.rules:624-627`
**STRIDE**: Elevation of Privilege

**Description**: The `shared_shopping_lists` update rule allows any member in `sharedToUserIds` to modify all document fields, including `sharedByUserId` and `sharedToUserIds`. A member can claim ownership or manipulate the member list.

**Proof**:
```javascript
// firestore.rules:623-627
// Can update if you're in the sharedToUserIds (for real-time collaboration)
allow update: if isAuthenticated() && (
  request.auth.uid == resource.data.sharedByUserId ||
  request.auth.uid in resource.data.sharedToUserIds
);
```

Compare with `shared_recipes` (firestore.rules:352-356) which correctly restricts member updates:
```javascript
allow update: if isAuthenticated() && (
  request.auth.uid == resource.data.sharedByUserId ||
  (exists(.../members/$(request.auth.uid))
   && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['sharedByUserId', 'originalRecipeId', 'sharedAt']))
);
```

**Recommended Fix**: Apply the same `affectedKeys()` restriction as `shared_recipes`.

---

#### P1-03 | MEDIUM | Friend Categories: Any Auth User Can Self-Join Groups

**Status: FIXED** — Replaced post-update data check with pending invitation check.

**Location**: `firestore.rules:204-207`
**STRIDE**: Elevation of Privilege

**Description**: The `friendCategories` update rule allows any authenticated user to add themselves to a group's `friendUserIds` array, even if they are not already a member or invited. The rule only checks that the caller is in the *post-update* data, not the *pre-update* data.

**Proof**:
```javascript
// firestore.rules:203-207
// Allow updating if adding yourself OR already a member
allow update: if isAuthenticated() && (
  isInList('friendUserIds') ||
  request.auth.uid in request.resource.data.friendUserIds
);
```

The second condition (`request.resource.data.friendUserIds`) checks the *incoming* data — an attacker simply includes their UID in the update payload.

**Recommended Fix**: Require existing membership OR a pending invitation:
```javascript
allow update: if isAuthenticated() && (
  isInList('friendUserIds') ||
  request.auth.uid in resource.data.get('pendingInviteUserIds', [])
);
```

---

#### P1-04 | MEDIUM | Global Recipe Cache: Unconstrained Create

**Status: FIXED** — Required fields, ownership validation, and rate limit added.

**Location**: `firestore.rules:1447-1452`
**STRIDE**: Denial of Service / Tampering

**Description**: Any authenticated user can create documents in `globalRecipeCache` with no field validation or size limits. This enables cache poisoning (storing malicious or misleading recipe data) and storage abuse.

**Proof**:
```javascript
// firestore.rules:1447-1452
match /globalRecipeCache/{docId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated();
  // ...
}
```

No `hasRequiredFields()`, no content validation, no rate limiting.

**Recommended Fix**: Add required fields validation and rate limiting:
```javascript
allow create: if isAuthenticated()
  && hasRequiredFields(['url', 'title', 'createdBy', 'createdAt'])
  && request.resource.data.createdBy == request.auth.uid
  && rateLimitWrite('globalRecipeCache', 30);
```

---

#### P1-05 | MEDIUM | Conversations: Participants Can Force-Add Users

**Status: FIXED** — `participantIds` and `createdAt` modification restricted via `affectedKeys`.

**Location**: `firestore.rules:968-969`
**STRIDE**: Elevation of Privilege / Tampering

**Description**: The `conversations` update rule allows any participant to modify `participantIds` without restriction. A participant can add arbitrary user IDs to the conversation, giving those users access to message history and enabling notification abuse (see P5-01).

**Proof**:
```javascript
// firestore.rules:968-969
// Can update if you're a participant
allow update: if isAuthenticated() && request.auth.uid in resource.data.participantIds;
```

No field restriction prevents modifying `participantIds` or `createdAt`.

**Recommended Fix**: Restrict non-creator updates to exclude `participantIds`:
```javascript
allow update: if isAuthenticated() && request.auth.uid in resource.data.participantIds
  && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['participantIds', 'createdAt']);
```

---

#### P1-06 | MEDIUM | Storage: Any Auth User Can Upload to Shared Recipe Paths

**Status: DEFERRED** — Storage rules cannot access Firestore to verify recipe ownership. `metadata.uploadedBy` check prevents overwrites. Accepted as beta risk.

**Location**: `storage.rules:34-43`
**STRIDE**: Tampering

**Description**: Any authenticated user can create files under `/shared/recipes/{recipeId}/` for any `recipeId`, as long as they set `metadata.uploadedBy` to their own UID. This allows uploading unwanted images to another user's shared recipe.

**Proof**:
```javascript
// storage.rules:40-43
allow create: if request.auth != null
  && request.resource.metadata.uploadedBy == request.auth.uid
  && isValidImage()
  && isWithinSizeLimit(10);
```

The rule validates the uploader's identity and file format but does not verify the user has any relationship to the recipe.

**Recommended Fix**: Add a Firestore lookup to verify the uploader is the recipe owner or a member. Alternatively, scope uploads to the user's own path and copy on share.

---

#### P1-07 | MEDIUM | friendsCount: Manipulable by Any Auth User (Accepted Risk)

**Location**: `firestore.rules:255-264`
**STRIDE**: Tampering

**Description**: Any authenticated user can increment or decrement another user's `friendsCount` by ±1. While rate-limited to one update per 5 seconds, there is no verification that a friendship actually exists. Documented as an accepted tradeoff due to Firestore transaction timing constraints.

**Proof**:
```javascript
// firestore.rules:255-264
allow update: if isOwner(userId) || (
  isAuthenticated() &&
  request.resource.data.diff(resource.data).affectedKeys().hasOnly(['friendsCount']) &&
  (request.resource.data.friendsCount == resource.data.get('friendsCount', 0) + 1 ||
   request.resource.data.friendsCount == resource.data.get('friendsCount', 0) - 1) &&
  rateLimitWrite('friendsCount', 5)
);
```

**Status**: Accepted risk — documented in rules comments (S2 note).

---

#### P1-08 | LOW | Friend Requests: Update Allows Field Mutation Beyond Status

**Status: FIXED** — `affectedKeys().hasOnly(['status', 'respondedAt'])` constraint added.

**Location**: `firestore.rules:288-290`
**STRIDE**: Tampering

**Description**: The `friend_requests` update rule validates that the new `status` is `'accepted'` or `'rejected'` but does not restrict which other fields can be modified. A recipient could alter `fromUserId`, `toUserId`, or `sentAt` in the same update.

**Proof**:
```javascript
// firestore.rules:288-290
allow update: if isAuthenticated()
  && request.auth.uid == resource.data.toUserId
  && request.resource.data.status in ['accepted', 'rejected'];
```

Missing: `&& request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'respondedAt'])`

**Recommended Fix**: Add `affectedKeys().hasOnly(['status', 'respondedAt'])` constraint.

---

#### P1-09 | LOW | Comments/Ratings: Readable by All Authenticated Users

**Location**: `firestore.rules:905-910`, `firestore.rules:1358-1360`, `firestore.rules:1382-1384`
**STRIDE**: Information Disclosure

**Description**: `recipe_comments`, `menu_ratings`, and `menu_comments` are readable by any authenticated user, not just recipe/menu owners or shared members. Access control for these is enforced client-side only.

**Proof**:
```javascript
// firestore.rules:905-906
match /recipe_comments/{commentId} {
  // S3 tradeoff: Comments are readable by any authenticated user.
```

**Status**: Documented tradeoff (S3) — server-side recipe ownership lookup from just a recipeId is not feasible in rules. Client-side filtering + blocked user filtering mitigate practical impact.

---

#### P1-10 | LOW | Menu Activity: Any Auth User Can Create Entries

**Status: FIXED** — `userId` field required and validated against `request.auth.uid`.

**Location**: `firestore.rules:1431-1437`
**STRIDE**: Tampering / Repudiation

**Description**: Any authenticated user can create activity log entries for any menu, with only `menuId` and `timestamp` required. There is no validation that the user is a menu collaborator.

**Proof**:
```javascript
// firestore.rules:1435-1437
allow create: if isAuthenticated()
  && hasRequiredFields(['menuId', 'timestamp']);
```

**Recommended Fix**: Add a `userId` field requirement and validate `request.resource.data.userId == request.auth.uid`.

---

#### P1-11 | LOW | Shopping Lists Delete: ownerId-Missing Fallback

**Status: FIXED** — `get()` fallback removed, strict `resource.data.ownerId` access.

**Location**: `firestore.rules:1082-1083`
**STRIDE**: Elevation of Privilege

**Description**: The `shoppingLists` delete rule falls back to allowing deletion if `ownerId` is missing from the document, using `resource.data.get('ownerId', request.auth.uid)` which defaults to the caller's UID — always passing the check.

**Proof**:
```javascript
// firestore.rules:1082-1083
allow delete: if isAuthenticated()
  && (request.auth.uid == resource.data.get('ownerId', request.auth.uid));
```

Any authenticated user can delete shopping lists that lack an `ownerId` field.

**Recommended Fix**: Use strict field access without fallback:
```javascript
allow delete: if isAuthenticated()
  && request.auth.uid == resource.data.ownerId;
```

---

#### P1-12 | LOW | Shared Recipe Images: Publicly Readable

**Status: FIXED** — Read access now requires `request.auth != null`.

**Location**: `storage.rules:35`
**STRIDE**: Information Disclosure

**Description**: Files under `/shared/recipes/{recipeId}/` are readable without any authentication (`allow read: if true`). Anyone with a direct URL can access shared recipe images.

**Proof**:
```javascript
// storage.rules:34-35
match /shared/recipes/{recipeId}/{allPaths=**} {
  allow read: if true; // Public read access for shared content
```

**Impact**: Low — recipe images are not sensitive PII. However, enumeration of recipe IDs could expose user activity.

**Recommended Fix**: Require authentication: `allow read: if request.auth != null;`

---

#### P1-13 | LOW | Audit Logs: Client-Writable

**Location**: `firestore.rules:1323-1333`
**STRIDE**: Repudiation

**Description**: Users can create their own audit log entries. While scoped to their own `userId`, this means audit logs cannot be fully trusted for compliance purposes — a user could create misleading entries or flood the collection.

**Proof**:
```javascript
// firestore.rules:1331-1333
allow create: if isAuthenticated()
  && request.auth.uid == request.resource.data.userId
  && hasRequiredFields(['userId', 'operation', 'resourceType', 'timestamp']);
```

**Status: FIXED** — Rate limiting (`rateLimitWrite('audit_logs', 2)`) added to prevent flooding. Note: still acceptable for beta; true GDPR Article 30 compliance should use server-side-only writes.

---

### Pass 2 — Auth Flows & Access Control

#### P2-01 | HIGH | Batch Operations Skip Per-Entity Permission Validation

**Status: FIXED** — Per-entity `validateCreatePermission`/`validateUpdatePermission`/`validateDeletePermission` added to `createBatch`, `updateBatch`, `deleteBatch`.

**Location**: `lib/repositories/firebase/base_firebase_repository.dart:247-262`
**STRIDE**: Elevation of Privilege

**Description**: The `createBatch()` method in `BaseFirebaseRepository` only calls `requireCurrentUserId()` (authentication check) but skips `validateCreatePermission()` for each entity. Compare with the single-entity `create()` method (line 84-113) which validates permissions per entity.

**Proof**:
```dart
// base_firebase_repository.dart:247-262
Future<void> createBatch(List<T> entities) async {
  try {
    requireCurrentUserId();  // Auth only — no per-entity permission check
    final ref = getCollectionRef();
    final batch = _firestore.batch();

    for (final entity in entities) {
      batch.set(ref.doc(getId(entity)), toFirestore(entity));  // Direct write
    }

    await batch.commit();
  }
}
```

The same issue affects `updateBatch()` (line 402-418) and `deleteBatch()` (line 420-437) in the `BatchOperationsFirebaseRepository` mixin.

**Recommended Fix**: Call `validateCreatePermission()` / `validateUpdatePermission()` / `validateDeletePermission()` for each entity before adding to the batch. Note: Firestore security rules still enforce server-side, but client-side validation provides defense in depth and consistent error handling.

---

#### P2-02 | MEDIUM | addMember() No Client-Side Ownership Check

**Status: FIXED** — Ownership check via `read()` + `isCreatedBy()` added before member addition.

**Location**: `lib/repositories/firebase/base_shared_content_repository.dart:341-375`
**STRIDE**: Elevation of Privilege

**Description**: The `addMember()` method does not validate that the caller is the content owner before adding a member. Any code path that reaches `addMember()` can add members to any shared content document.

**Proof**:
```dart
// base_shared_content_repository.dart:341-375
Future<void> addMember(
  String contentId,
  String userId, {
  required String addedBy,
  // ...
}) async {
  try {
    final member = SharedContentMember(/* ... */);
    await getCollectionRef()
        .doc(contentId)
        .collection(FirestoreCollections.members)
        .doc(userId)
        .set(member.toFirestore());
    // No ownership check
  }
}
```

**Mitigating factor**: Firestore rules for `members` subcollections do enforce that only the owner can create member documents (e.g., `firestore.rules:648-650`). This is a defense-in-depth gap, not an exploitable bypass.

**Recommended Fix**: Add ownership validation before the Firestore write:
```dart
final content = await read(contentId);
if (content == null || !isCreatedBy(content, requireCurrentUserId())) {
  throw PermissionDeniedException('Only the owner can add members');
}
```

---

#### P2-03 | MEDIUM | deleteAllBlocksForUser() No Ownership Validation

**Status: FIXED** — `requireCurrentUserId()` ownership validation added.

**Location**: `lib/repositories/firebase/firebase_block_repository.dart:103-121`
**STRIDE**: Elevation of Privilege

**Description**: `deleteAllBlocksForUser()` accepts any `userId` parameter and deletes all block records involving that user (both as blocker and blocked) without verifying the caller is the user being deleted or an admin.

**Proof**:
```dart
// firebase_block_repository.dart:103-121
Future<void> deleteAllBlocksForUser(String userId) async {
  // No ownership check — deletes blocks for ANY userId passed
  final asBlocker = await collection.where('blockerId', isEqualTo: userId).get();
  final asBlocked = await collection.where('blockedId', isEqualTo: userId).get();

  final batch = firestore.batch();
  for (final doc in [...asBlocker.docs, ...asBlocked.docs]) {
    batch.delete(doc.reference);
  }
  // ...
}
```

**Mitigating factor**: Only called from `AccountDeletionService` which validates the caller. But the method is public and could be called from other paths.

**Recommended Fix**: Add `requireCurrentUserId()` check:
```dart
Future<void> deleteAllBlocksForUser(String userId) async {
  final uid = requireCurrentUserId();
  if (uid != userId) {
    throw PermissionDeniedException('Can only delete own block records');
  }
  // ...
}
```

---

#### P2-04 | LOW | Auth Null-Suppression Cache Window

**Location**: `lib/repositories/firebase/firebase_auth_repository.dart:41-74`
**STRIDE**: Spoofing

**Description**: The auth repository caches the last known user and suppresses Firebase's initial `null` emission to prevent false sign-outs during app initialization. During this brief window, the cached UID is used for operations even though Firebase reports no authenticated user.

**Proof**:
```dart
// firebase_auth_repository.dart:72-74
if (_ignoreInitialNull && firebaseUser == null && _cachedUser != null) {
  // BLOCKING Firebase NULL emission - preserving cached user
```

**Status: DEFERRED** — By design. Millisecond window, fails at Firestore rules anyway.

**Impact**: Extremely brief window (milliseconds). Firebase Auth SDK handles token refresh independently. The risk is theoretical — if the user's account were deleted server-side during this exact window, operations would use a stale UID (but would fail at Firestore rules).

---

### Pass 3 — Input Validation & Injection

#### P3-01 | HIGH | OCR API Key Hardcoded in Dart Source

**Status: FIXED** — Key moved to `const String.fromEnvironment('OCR_SPACE_API_KEY')`.

**Location**: `lib/services/ocr_extraction_service.dart:202`
**STRIDE**: Information Disclosure

**Description**: The OCR.space API key is hardcoded as a string literal in the Dart source code. Anyone who decompiles the APK/IPA or inspects the web build can extract this key and use the OCR quota.

**Proof**:
```dart
// ocr_extraction_service.dart:200-202
String get _ocrApiKey {
  if (_testOcrApiKey != null) return _testOcrApiKey;
  return 'K86932882588957';
}
```

Contrast with the Google Vision key (line 209-211) which correctly uses `String.fromEnvironment()`.

**Recommended Fix**: Move to environment variable or Firebase Remote Config:
```dart
String get _ocrApiKey {
  if (_testOcrApiKey != null) return _testOcrApiKey;
  return const String.fromEnvironment('OCR_SPACE_API_KEY');
}
```

---

#### P3-02 | MEDIUM | Message Content: No Firestore Length Enforcement

**Status: FIXED** — Content type check and 5000-char length limit added to both create and update rules.

**Location**: `firestore.rules:985-988`
**STRIDE**: Denial of Service

**Description**: The `messages` collection create rule requires `content` as a field but does not enforce a maximum length. A malicious user could write arbitrarily large messages, consuming storage and bandwidth.

**Proof**:
```javascript
// firestore.rules:985-988
allow create: if isAuthenticated()
  && request.auth.uid == request.resource.data.senderId
  && hasRequiredFields(['senderId', 'conversationId', 'content', 'sentAt'])
  && rateLimitWrite('messages', 5);
```

No `request.resource.data.content.size() <= 5000` or similar constraint.

**Recommended Fix**: Add length validation:
```javascript
&& request.resource.data.content is string
&& request.resource.data.content.size() <= 5000
```

---

#### P3-03 | MEDIUM | Feedback Form: No Length Limits

**Status: FIXED** — `maxLength: 2000` (description) and `maxLength: 100` (email) added.

**Location**: `lib/widgets/common/feedback_form_dialog.dart:106-116`
**STRIDE**: Denial of Service

**Description**: The feedback description and email `TextField` widgets have no `maxLength` property. Combined with no server-side length validation, users could submit extremely large feedback entries.

**Proof**:
```dart
// feedback_form_dialog.dart:106-116
TextField(
  controller: _descriptionController,
  maxLines: 5,
  minLines: 3,
  decoration: InputDecoration(
    hintText: context.l10n.feedbackDescriptionHint,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
    ),
  ),
  // No maxLength property
),
```

**Recommended Fix**: Add `maxLength: 2000` to the description field and `maxLength: 100` to the email field. Also add Firestore rules for the `feedback` collection with size limits.

---

#### P3-04 | MEDIUM | Recipe Free-Text: Not Sanitized Before Firestore Write

**Status: FIXED** — `HtmlSanitizer.sanitizeText()` applied to title, description; `sanitizeUrl()` to sourceUrl in `FirebaseRecipeRepository` create/update.

**Location**: Recipe model / repository layer
**STRIDE**: Tampering

**Description**: Recipe fields like `title`, `instructions`, and `notes` are written to Firestore without sanitization. While Flutter's `Text` widget does not render HTML (eliminating XSS), the data could be consumed by future web views, export features, or third-party integrations that do render HTML.

**Impact**: No current exploitation path due to Flutter's Text widget rendering. This is a defense-in-depth recommendation for future-proofing.

**Recommended Fix**: Sanitize HTML entities on write or implement a sanitization layer in the repository base class.

---

#### P3-05 | LOW | OCR Extracted Text: Not Sanitized

**Status: FIXED** — `HtmlSanitizer.sanitizeText()` applied to all three OCR provider output paths.

**Location**: `lib/services/ocr_extraction_service.dart:333-347`
**STRIDE**: Tampering

**Description**: Text extracted by OCR providers is returned directly without sanitization. If this text is later displayed in a context that renders HTML (e.g., web export), it could contain injected content.

**Impact**: No current exploitation path — OCR output is displayed via Flutter `Text` widgets. Informational for future web features.

---

#### P3-06 | LOW | Deep Link Message: Not Length-Bounded

**Location**: Deep link handling (URL import flow)
**STRIDE**: Denial of Service

**Description**: Deep link payloads (e.g., shared recipe URLs) are not validated for length before processing. An extremely long URL could cause excessive memory allocation during parsing.

**Status: DEFERRED** — Minimal risk. Platform URL length limits and HTTP client provide natural bounds.

**Impact**: Low — the HTTP client and URL parsing libraries impose practical limits.

---

### Pass 4 — Secrets & Data Exposure

#### P4-01 | MEDIUM | Firebase API Keys Committed to Git

**Status: DEFERRED** — Google Cloud Console action (configure API key restrictions). Not code-fixable.

**Location**: `lib/firebase_options.dart:35`
**STRIDE**: Information Disclosure

**Description**: Firebase API keys for all platforms (web, Android, iOS, macOS, Windows) are committed to the repository in `firebase_options.dart`. While Firebase API keys are designed to be public (security is enforced by Firestore/Storage rules), exposing them increases the attack surface for quota abuse and makes it easier to target the project.

**Proof**:
```dart
// firebase_options.dart:34-42
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyAZV38BdC1VBes0N-oiLdk1yi5xS_xKZ8g',
  appId: '1:976357691692:web:3e70520a0ac19514e4dc89',
  messagingSenderId: '976357691692',
  projectId: 'butlery-app-1',
  // ...
);
```

**Status**: Standard FlutterFire CLI output. Firebase documents that these keys are safe to include in client apps. However, consider restricting API keys in Google Cloud Console (HTTP referrer restrictions for web, app restrictions for mobile).

**Recommended Fix**: Configure API key restrictions in Google Cloud Console → Credentials.

---

#### P4-02 | MEDIUM | All Environments Point to Same Firebase Project

**Status: DEFERRED** — Infrastructure change. Separate Firebase projects for dev/staging/prod needed. Out of code scope.

**Location**: `lib/firebase_options.dart`
**STRIDE**: Tampering

**Description**: All platform configurations (web, Android, iOS, macOS, Windows) use the same Firebase project (`butlery-app-1`). There is no separate staging/dev project, meaning development and testing activity hits the production database.

**Impact**: Development errors could corrupt production data. Test accounts and debug data may pollute production collections.

**Recommended Fix**: Create separate Firebase projects for dev/staging/production. Use `--dart-define` or flavor-based configuration to switch between them.

---

#### P4-03 | MEDIUM | GDPR: Feedback Not Deleted on Account Deletion

**Status: FIXED** — `cleanupFeedback()` added to `onUserDeleted`, including Firestore batch deletion and Storage file cleanup.

**Location**: `functions/src/cleanup/on-user-deleted.ts`
**STRIDE**: Information Disclosure (GDPR non-compliance)

**Description**: The `onUserDeleted` Cloud Function cleans up social data (friendships, friend requests, group memberships, public profiles) but does not delete the user's feedback submissions from the `feedback` collection or feedback screenshots from Storage (`/feedback/{userId}/`).

**Proof**: The cleanup function handles 5 data categories:
```typescript
// on-user-deleted.ts:57-72
results.friendsRemoved = await cleanupReverseFriendships(userId);
results.friendRequestsCleaned = await cleanupFriendRequests(userId);
results.groupMembershipsRemoved = await cleanupGroupMemberships(userId);
results.friendCountsUpdated = await updateFriendCounts(userId);
await db.collection("public_profiles").doc(userId).delete();
// No feedback cleanup
```

Additionally, `AccountDeletionService` in the Dart client does not reference feedback data:
```bash
$ grep -r "feedback" lib/services/account/account_deletion_service.dart
# No matches
```

**Recommended Fix**: Add feedback cleanup to `onUserDeleted`:
```typescript
// Delete feedback documents
const feedbackDocs = await db.collection('feedback').where('userId', '==', userId).get();
// batch delete...

// Delete feedback screenshots from Storage
await admin.storage().bucket().deleteFiles({ prefix: `feedback/${userId}/` });
```

---

#### P4-04 | LOW | Public Profiles: Emails Readable by All Authenticated Users

**Status: DEFERRED** — Low beta impact. Requires friend-search redesign (Cloud Function query).

**Location**: `firestore.rules:239-241`
**STRIDE**: Information Disclosure

**Description**: The `public_profiles` collection is fully readable by any authenticated user, and the create rule requires an `email` field. This exposes user email addresses to all other users in the app.

**Proof**:
```javascript
// firestore.rules:239-241
match /public_profiles/{userId} {
  allow read: if isAuthenticated();
```

```javascript
// firestore.rules:244-246
allow create: if isOwner(userId)
  && hasRequiredFields(['displayName', 'email'])
  && request.resource.data.isSearchable is bool;
```

**Impact**: Low for beta with trusted users. Should be addressed before public launch.

**Recommended Fix**: Either remove `email` from public profiles (query via Cloud Function for friend requests) or add field-level access control via a separate `private_profile` subcollection.

---

#### P4-05 | LOW | SECURITY.md: Claims Don't Match Reality

**Status: FIXED** — Fictional claims replaced with actual security measures in SECURITY.md.

**Location**: `SECURITY.md:44-49`
**STRIDE**: N/A (Documentation accuracy)

**Description**: The `SECURITY.md` file claims several security measures that are not implemented:

| Claim | Reality |
|-------|---------|
| "End-to-end encryption for sensitive data" | No E2E encryption — data is encrypted at rest by Firebase (standard) |
| "Secure local storage with encryption" | Standard SharedPreferences / Firestore SDK cache (not encrypted) |
| "SSL certificate pinning" | No pinning library in `pubspec.yaml`, no pinning code in codebase |
| "Multi-factor authentication support" | Not implemented |
| "Biometric authentication options" | Explicitly deleted per beta decisions |
| "Root/jailbreak detection" | No detection library or code |

**Recommended Fix**: Update `SECURITY.md` to accurately reflect current security posture.

---

### Pass 5 — Cloud Functions & API Security

#### P5-01 | MEDIUM | sendNotification: Conversation-Based Auth Is Bypassable

**Status: FIXED** — Replaced conversation-based auth with friendship + friend-request check in both `sendNotification` and `sendNotificationBatch`.

**Location**: `functions/src/notifications/send-notification.ts:102-122`
**STRIDE**: Elevation of Privilege

**Description**: The `sendNotification` function validates that the caller shares a conversation with the target user. However, the Firestore `conversations` create rule (firestore.rules:964-966) allows any authenticated user to create a conversation that includes any other user's ID in `participantIds`. An attacker can:
1. Create a conversation with `participantIds: [attackerUid, victimUid]`
2. Call `sendNotification` targeting `victimUid` — authorization passes because they share a conversation

**Proof**:
```javascript
// send-notification.ts:102-122
if (callerUid !== targetUserId) {
  const conversations = await admin.firestore()
    .collection("conversations")
    .where("participantIds", "array-contains", callerUid)
    .get();

  const isAuthorized = conversations.docs.some((doc) => {
    const participants = doc.data().participantIds as string[];
    return participants?.includes(targetUserId);
  });
  // ...
}
```

```javascript
// firestore.rules:963-966
allow create: if isAuthenticated()
  && request.auth.uid in request.resource.data.participantIds
  && hasRequiredFields(['participantIds', 'createdAt']);
```

**Recommended Fix**: Validate that the conversation was created by mutual consent (e.g., require both participants to have accepted a friend request) or use a friendship check instead of conversation check.

---

#### P5-02 | MEDIUM | SSRF Risk in URL Import if Proxied Server-Side

**Location**: Cloud Functions (URL import/recipe scraping)
**STRIDE**: Tampering

**Description**: If a Cloud Function fetches user-supplied URLs to import recipes, internal network resources could be targeted (SSRF). The current OCR Cloud Function has SSRF protection, but any future URL-fetching function should apply the same protections.

**Status: DEFERRED** — Currently mitigated by OCR Cloud Function SSRF protection. Forward-looking recommendation.

**Impact**: Currently mitigated — the OCR Cloud Function validates URLs. This is a forward-looking recommendation.

---

#### P5-03 | LOW | Full UIDs in Cloud Function Logs

**Location**: `functions/src/notifications/send-notification.ts:159`, `functions/src/cleanup/on-user-deleted.ts:31`
**STRIDE**: Information Disclosure

**Description**: Cloud Function logs include full Firebase UIDs. While logs are access-controlled via Google Cloud IAM, UIDs in logs could be useful to an attacker who gains log access.

**Proof**:
```typescript
// send-notification.ts:158-160
functions.logger.info(
  `Sending notification to ${tokens.length} device(s) for user ${targetUserId}`
);
```

```typescript
// on-user-deleted.ts:31
functions.logger.info(`User deleted: ${userId}. Starting social cleanup.`);
```

**Status: DEFERRED** — Standard practice. Access-controlled via Google Cloud IAM.

**Impact**: Low — requires Google Cloud console access. Standard Firebase practice.

---

#### P5-04 | INFO | print() Statements in Production Code

**Location**: Dart source (documentation comments only)
**STRIDE**: N/A

**Description**: Grep for `print(` found references only in documentation comments and the `AppLogger` module which uses `developer.log()` instead of `print()`. No actual `print()` calls in production code paths. This is a positive finding.

---

#### P5-05 | INFO | WRITE_EXTERNAL_STORAGE: Deprecated Permission

**Status: FIXED** — Scoped with `android:maxSdkVersion="28"`.

**Location**: `android/app/src/main/AndroidManifest.xml:9`
**STRIDE**: N/A

**Description**: The Android manifest requests `WRITE_EXTERNAL_STORAGE`, which is deprecated on Android 10+ (API 29+) and ignored on Android 11+ (API 30+). It has no security impact but should be cleaned up.

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**Recommended Fix**: Remove if `minSdkVersion` >= 29, or scope with `android:maxSdkVersion="28"`.

---

#### P5-06 | INFO | No Certificate Pinning Despite SECURITY.md Claim

**Location**: `SECURITY.md:46`, `pubspec.yaml`
**STRIDE**: N/A

**Description**: SECURITY.md claims "SSL certificate pinning for API communications" but no certificate pinning library exists in `pubspec.yaml` and no pinning implementation was found in the codebase. All network traffic uses Firebase SDK defaults (standard TLS, no pinning).

**Status: DEFERRED** — Covered by P4-05 fix (SECURITY.md no longer claims certificate pinning).

**Impact**: Informational — Firebase SDK traffic to Google servers has strong TLS. Pinning would protect against MITM on custom API calls (e.g., OCR.space). Not critical for beta.

---

#### P5-07 | INFO | Crashlytics UID Sanitization (Positive)

**Description**: Noted for completeness — the codebase sanitizes UIDs before sending to Crashlytics. This is a positive security practice.

---

#### P5-08 | INFO | No XSS Surface (Positive)

**Description**: All user-generated content is rendered through Flutter's `Text` widget, which does not interpret HTML or JavaScript. There is no XSS attack surface in the current Flutter application.

---

## Positive Findings

The following security practices are well-implemented:

1. **Default-deny catch-all in Firestore rules** (`firestore.rules:1505`): `allow read, write: if false;` catches any paths not explicitly allowed.

2. **Authentication enforced on every accessible path**: Every Firestore and Storage rule checks `isAuthenticated()` (except the intentionally public shared recipe images).

3. **Block system rules well-constructed**: Uses composite-key documents (`{blockerId}_{blockedId}`) for O(1) lookups, immutable records (no update allowed), and blocker-only delete. Block checks integrated into friend request and group invitation creation.

4. **PII scrubbing before LLM calls**: Personal data is sanitized before being sent to external AI services.

5. **SSRF protection in Cloud Functions OCR**: URL validation prevents internal network resource access.

6. **Crashlytics UID sanitization**: User identifiers are scrubbed from crash reports.

7. **Server-side rate limiting on social operations**: `rateLimitWrite()` function applied to friend requests (10s), group invitations (10s), messages (5s), and friendsCount updates (5s).

8. **No XSS surface**: Flutter's `Text` widget rendering eliminates cross-site scripting as an attack vector.

9. **HTTPS enforced on all platforms**: Firebase SDK enforces TLS for all communication.

10. **Backup disabled on Android**: `android:allowBackup="false"` prevents adb backup of app data.

11. **TagResult validation** (allergen safety): Comprehensive Firestore rule validation (`isValidTagResult()`, `_isValidTriStateMap()`) prevents client-side tampering with allergen status data, which is health-critical.

12. **User-defined ingredient validation** (`_isValidUserIngredient()`): Prevents injection of malicious ingredient properties including status escalation, path traversal via ID, and storage abuse via unbounded arrays.

---

## Remediation Summary

**Fixed (21 findings)**: P1-01, P1-02, P1-03, P1-04, P1-05, P1-08, P1-10, P1-11, P1-12, P1-13, P2-01, P2-02, P2-03, P3-01, P3-02, P3-03, P3-04, P3-05, P4-03, P4-05, P5-01, P5-05

**Deferred (8 findings)**:
- **P1-06**: Storage rules can't access Firestore (platform limitation)
- **P1-07**: Accepted risk — friendsCount ±1 manipulation, rate-limited
- **P1-09**: Accepted tradeoff (S3) — comments/ratings readability
- **P2-04**: By design — auth null-suppression window is milliseconds
- **P3-06**: Minimal risk — deep link URL length bounded by platform
- **P4-01**: Google Cloud Console action — configure API key restrictions
- **P4-02**: Infrastructure change — separate Firebase projects for environments
- **P4-04**: Low beta impact — public_profiles email exposure, requires redesign
- **P5-02**: Already mitigated — OCR Cloud Function has SSRF protection
- **P5-03**: Standard practice — UIDs in Cloud Function logs, access-controlled via IAM
- **P5-06**: Covered by P4-05 — SECURITY.md update removes false claim

**No Action Required (4 findings)**: P5-04, P5-07, P5-08 (positive findings), P3-06 (accepted)
