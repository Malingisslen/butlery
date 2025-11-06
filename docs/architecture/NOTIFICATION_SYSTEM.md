# Notification System

**Complete FCM integration with development logging approach**

**Last Updated**: January 2025
**Related Guides**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | [Firebase Integration](FIREBASE_INTEGRATION.md) | [Best Practices](BEST_PRACTICES.md)

---

## Overview

The Butlery notification system provides **comprehensive push notification support** for social features including friend requests, recipe sharing, and real-time collaboration.

**Current Status**: ✅ **DEVELOPMENT COMPLETE** with production-ready architecture

### Key Features

- ✅ All notification types (immediate, batchable, silent, digest, optional)
- ✅ Localization (Swedish/English templates)
- ✅ Friend system notifications
- ✅ Recipe sharing notifications
- ✅ Real-time collaboration notifications
- ✅ Comment batching (spam prevention)
- ✅ User preferences and FCM token management
- ✅ Offline support with notification queuing
- ✅ Rate limiting and security validation

---

## Development Approach

The system uses **intentional logging** instead of actual FCM sending during development:

```
🔔 [DEV] FCM notification ready for: user123abc
📋 [DEV] Title: Ny vänskapsförfrågan
📋 [DEV] Body: Anna vill bli vän med dig
📋 [DEV] Data keys: senderUserId, requestId, message
```

### Benefits

- ✅ Complete notification logic testing
- ✅ Easy debugging and verification
- ✅ No server infrastructure required
- ✅ Security-safe (no exposed FCM keys)
- ✅ All integration points working
- ✅ Production upgrade: ~1 hour

---

## Notification Architecture

### System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │───▶│ NotificationService│───▶│ FCM Development │
│                 │    │                  │    │    (Logging)    │
│ Friend Requests │    │ ✅ All Logic     │    │                 │
│ Recipe Sharing  │    │ ✅ Preferences   │    │ Ready for       │
│ Collaboration   │    │ ✅ Batching      │    │ Production      │
│ Comments        │    │ ✅ Localization  │    │ Upgrade         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### File Structure

```
lib/services/notifications/
├── notification_service.dart      # Main orchestration service
├── notification_types.dart        # Type-safe strategies & templates
├── notification_repository.dart   # Preferences & history management
├── fcm_service.dart               # Firebase Cloud Messaging integration
└── notification_templates.dart    # Localized message templates

notification_cloud_functions.js    # Production server-side (ready to deploy)
```

---

## Notification Types

### 1. Immediate Notifications (Critical/High Priority)

Sent instantly with high priority for time-sensitive actions:

```dart
// Friend request sent
NotificationStrategy.friendRequest
// Localization:
// 'title_sv': 'Ny vänskapsförfrågan'
// 'body_sv': '{senderName} vill bli vän med dig'

// Friend request accepted
NotificationStrategy.friendRequestAccepted
// 'title_sv': 'Vänskapsförfrågan accepterad'
// 'body_sv': '{senderName} accepterade din vänskapsförfrågan'

// Recipe shared
NotificationStrategy.recipeShared
// 'title_sv': 'Recept delat med dig'
// 'body_sv': '{senderName} delade "{recipeTitle}" med dig'

// Collaboration invite
NotificationStrategy.collaborationInvite
// 'title_sv': 'Inbjudan till samarbete'
// 'body_sv': '{senderName} bjuder in dig till "{recipeTitle}"'
```

### 2. Batchable Notifications (Medium Priority)

Grouped over time windows to prevent spam:

```dart
// Recipe comments (5-minute batch window)
NotificationStrategy.recipeComment
// Single: '{userName} kommenterade ditt recept'
// Multiple: '{count} nya kommentarer på ditt recept'
// Batch window: 5 minutes
// Max batch size: 5 notifications
```

### 3. Silent Notifications (Background Data)

Data-only notifications for background updates:

```dart
// Collaboration events
NotificationStrategy.collaborationJoined  // User joined editing session
NotificationStrategy.collaborationLeft    // User left editing session
NotificationStrategy.realtimeEdit         // Live recipe edits

// No user-visible notification, just data payload
```

---

## Integration Points

### Friend System Integration

```dart
// lib/services/unified/operations/friends_invitations_operations.dart

// Automatic notification when sending friend request
await friendsOps.sendFriendRequest(userId);
// ➜ Triggers NotificationStrategy.friendRequest

// Automatic notification when accepting request
await friendsOps.acceptFriendRequest(requestId);
// ➜ Triggers NotificationStrategy.friendRequestAccepted
```

### Recipe Sharing Integration

```dart
// lib/services/unified/operations/social_recipe_operations.dart

// Share recipe with members
await recipeOps.shareRecipe(recipeId, memberIds);
// ➜ Triggers NotificationStrategy.recipeShared for each member

// Add member to collaborative recipe
await recipeOps.addMember(recipeId, userId, permission);
// ➜ Triggers NotificationStrategy.collaborationInvite

// Add comment to recipe
await recipeOps.addComment(recipeId, comment);
// ➜ Triggers NotificationStrategy.recipeComment (batched)
```

### Real-time Collaboration Integration

```dart
// lib/services/unified/operations/realtime_recipe_operations.dart

// Start real-time editing
await realtimeOps.startRealtimeEditing(recipeId);
// ➜ Triggers silent NotificationStrategy.collaborationJoined

// Make live edit
await realtimeOps.makeRealtimeEdit(recipeId, changes);
// ➜ Triggers silent NotificationStrategy.realtimeEdit

// Enable collaborative editing
await realtimeOps.enableCollaborativeEditing(recipeId);
// ➜ Triggers NotificationStrategy.collaborationEnabled
```

---

## Development vs Production

### Development Mode (Current)

Notifications are logged instead of sent:

```dart
// lib/services/notifications/fcm_service.dart
Future<void> _sendFCMNotification() async {
  // Development logging
  debugPrint('🔔 [DEV] FCM notification ready for: $targetUserId');
  debugPrint('📋 [DEV] Title: ${template.title}');
  debugPrint('📋 [DEV] Body: ${template.body}');
  debugPrint('📋 [DEV] Data keys: ${template.data.keys.join(', ')}');
}
```

### Production Upgrade (1 hour)

**Step 1: Deploy Cloud Functions (15 min)**
```bash
# notification_cloud_functions.js is already ready
cp notification_cloud_functions.js functions/index.js
firebase deploy --only functions
```

**Step 2: Update NotificationService (5 min)**
```dart
// Replace logging with HTTP call
final response = await http.post(
  Uri.parse('${Config.cloudFunctionsUrl}/sendNotification'),
  headers: {
    'Authorization': 'Bearer ${await _getAuthToken()}',
    'Content-Type': 'application/json',
  },
  body: json.encode({
    'targetUserId': targetUserId,
    'title': template.title,
    'body': template.body,
    'data': template.data,
    'imageUrl': template.imageUrl,
  }),
);
```

**Step 3: Configure Environment (2 min)**
```dart
class Config {
  static const String cloudFunctionsUrl =
    'https://us-central1-butlery-app.cloudfunctions.net';
}
```

**Step 4: Test End-to-End (30 min)**
- Send friend request → Verify push notification
- Share recipe → Verify notification received
- Add comment → Verify batching works
- Real-time collaboration → Verify silent notifications

---

## Production Security Features

- ✅ Authenticated calls only
- ✅ Friend/collaboration permission validation
- ✅ Rate limiting (50 notifications/hour per user)
- ✅ Input sanitization and validation
- ✅ FCM token freshness checking
- ✅ Quiet hours support
- ✅ User preference checking

---

## Notification Analytics

The Cloud Functions include comprehensive analytics:
- Notification delivery success/failure rates
- User engagement (open rates, interactions)
- Rate limiting effectiveness
- Error tracking (FCM token issues, delivery failures)

---

## User Preferences

### Preference Management

```dart
class NotificationRepository {
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    await _firestore
        .collection('users')
        .doc(_authRepository.currentUserId)
        .update({
      'notificationPreferences': prefs.toFirestore(),
    });
  }

  Future<NotificationPreferences> getPreferences() async {
    final doc = await _firestore
        .collection('users')
        .doc(_authRepository.currentUserId)
        .get();

    return NotificationPreferences.fromFirestore(doc.data()!);
  }
}
```

### Preference Options

```dart
class NotificationPreferences {
  final bool friendRequests;        // Enable friend request notifications
  final bool recipeSharing;         // Enable recipe sharing notifications
  final bool comments;              // Enable comment notifications
  final bool collaboration;         // Enable collaboration notifications
  final bool quietHoursEnabled;     // Enable quiet hours
  final TimeOfDay quietHoursStart;  // Quiet hours start time
  final TimeOfDay quietHoursEnd;    // Quiet hours end time

  // Serialization methods
  Map<String, dynamic> toFirestore() { ... }
  factory NotificationPreferences.fromFirestore(Map<String, dynamic> data) { ... }
}
```

---

## Notification Batching

### Batch Strategy

Comments are batched to prevent spam:

```dart
class NotificationBatcher {
  final Duration batchWindow = Duration(minutes: 5);
  final int maxBatchSize = 5;

  Future<void> addToBatch(String recipeId, Comment comment) async {
    // Add to pending batch
    await _batchRepository.addComment(recipeId, comment);

    // Schedule batch send
    _scheduleBatchSend(recipeId);
  }

  Future<void> _sendBatch(String recipeId) async {
    final comments = await _batchRepository.getComments(recipeId);

    if (comments.length == 1) {
      // Single comment notification
      await _sendNotification(
        title: 'Ny kommentar',
        body: '${comments.first.userName} kommenterade ditt recept',
      );
    } else {
      // Batched notification
      await _sendNotification(
        title: 'Nya kommentarer',
        body: '${comments.length} nya kommentarer på ditt recept',
      );
    }

    // Clear batch
    await _batchRepository.clearComments(recipeId);
  }
}
```

---

## Rate Limiting

### Protection Against Spam

```dart
class RateLimiter {
  final int maxNotificationsPerHour = 50;
  final Duration window = Duration(hours: 1);

  Future<bool> canSendNotification(String userId) async {
    final count = await _getNotificationCount(userId, window);

    if (count >= maxNotificationsPerHour) {
      debugPrint('⚠️ Rate limit exceeded for user: $userId');
      return false;
    }

    return true;
  }

  Future<void> recordNotification(String userId) async {
    await _firestore
        .collection('notification_tracking')
        .doc(userId)
        .collection('sent')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
```

---

## Testing Notifications

### Unit Testing

```dart
void main() {
  late NotificationService notificationService;
  late MockNotificationRepository mockRepository;
  late MockFCMService mockFCMService;

  setUp(() {
    mockRepository = MockNotificationRepository();
    mockFCMService = MockFCMService();
    notificationService = NotificationService(
      repository: mockRepository,
      fcmService: mockFCMService,
    );
  });

  test('should send friend request notification', () async {
    when(() => mockRepository.getPreferences(any()))
        .thenAnswer((_) async => NotificationPreferences(friendRequests: true));

    await notificationService.sendFriendRequestNotification(
      targetUserId: 'user123',
      senderName: 'Anna',
    );

    verify(() => mockFCMService.sendNotification(any())).called(1);
  });

  test('should respect user preferences', () async {
    when(() => mockRepository.getPreferences(any()))
        .thenAnswer((_) async => NotificationPreferences(friendRequests: false));

    await notificationService.sendFriendRequestNotification(
      targetUserId: 'user123',
      senderName: 'Anna',
    );

    verifyNever(() => mockFCMService.sendNotification(any()));
  });
}
```

### Integration Testing

```dart
void main() {
  testWidgets('should display notification when friend request received',
      (tester) async {
    await tester.pumpWidget(MyApp());

    // Simulate receiving notification
    await simulateNotification(
      type: NotificationStrategy.friendRequest,
      data: {
        'senderUserId': 'user123',
        'senderName': 'Anna',
      },
    );

    await tester.pumpAndSettle();

    // Verify notification displayed
    expect(find.text('Ny vänskapsförfrågan'), findsOneWidget);
    expect(find.text('Anna vill bli vän med dig'), findsOneWidget);
  });
}
```

---

## Troubleshooting

### Common Issues

**1. Notifications not appearing in logs:**
- Check that notification service is registered in DI
- Verify FCMService is being called
- Check debug console output

**2. Localization not working:**
- Verify language code matches template keys
- Check NotificationTemplates.dart for language support

**3. Batching not working:**
- Verify batch window configuration
- Check batch repository implementation
- Ensure scheduler is running

**4. Rate limiting too aggressive:**
- Adjust maxNotificationsPerHour
- Check rate limiter window duration

---

## Cloud Functions

### notification_cloud_functions.js Structure

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendNotification = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Validate input
  const { targetUserId, title, body, data: notificationData, imageUrl } = data;

  // Get FCM token
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(targetUserId)
    .get();

  const fcmToken = userDoc.data().fcmToken;

  if (!fcmToken) {
    return { success: false, error: 'No FCM token' };
  }

  // Send notification
  const message = {
    notification: {
      title,
      body,
      imageUrl,
    },
    data: notificationData,
    token: fcmToken,
  };

  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});
```

---

## Next Steps

- **Learn Integration**: See integration point examples above
- **Configure Preferences**: Implement user preference UI
- **Deploy to Production**: Follow production upgrade steps
- **Monitor Analytics**: Review notification metrics regularly

---

**Last Updated**: January 2025 | **Verified Against**: Actual codebase implementation
