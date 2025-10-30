# FCM Production Deployment Guide

## Overview

This guide covers deploying Firebase Cloud Functions for production push notifications in the Butlery messaging system.

## Current Status

The messaging infrastructure is **95% complete** with all client-side features implemented:
- ✅ Real-time messaging with Firestore
- ✅ Message delivery and read receipts
- ✅ Typing indicators with presence tracking
- ✅ Reply threading with swipe gestures
- ✅ Image sharing with fullscreen viewer
- ✅ Group conversations with admin controls
- ✅ Conversation organization (pin/archive/mute)
- ⚠️ **Push notifications currently use development logging approach**

## What's Missing

To enable production push notifications, you need to:
1. Deploy Firebase Cloud Functions to trigger on new messages
2. Update NotificationService to send actual FCM tokens
3. Handle FCM token registration on app startup

## Architecture

```
New Message → Firestore → Cloud Function → FCM → User Device
```

## Cloud Functions Setup

### 1. Initialize Firebase Functions

```bash
cd c:\Butlery\butlery
firebase init functions
```

Select:
- JavaScript or TypeScript (recommend TypeScript)
- Install dependencies with npm

### 2. Cloud Function Code

Create `functions/src/index.ts`:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Trigger on new message creation
 * Sends FCM notification to conversation participants
 */
export const onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const conversationId = context.params.conversationId;

    try {
      // Get conversation to find participants
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.error('Conversation not found:', conversationId);
        return;
      }

      const conversation = conversationDoc.data();
      const participants = conversation?.participantIds || [];
      const senderId = message.senderId;

      // Get participants excluding sender
      const recipientIds = participants.filter((id: string) => id !== senderId);

      if (recipientIds.length === 0) {
        console.log('No recipients to notify');
        return;
      }

      // Get FCM tokens for recipients
      const tokensSnapshot = await admin.firestore()
        .collection('fcmTokens')
        .where('userId', 'in', recipientIds)
        .get();

      const tokens: string[] = [];
      const mutedUsers: string[] = [];

      for (const doc of tokensSnapshot.docs) {
        const tokenData = doc.data();
        const userId = tokenData.userId;

        // Check if user has muted this conversation
        const settingsDoc = await admin.firestore()
          .collection('conversations')
          .doc(conversationId)
          .collection('userSettings')
          .doc(userId)
          .get();

        const settings = settingsDoc.data();
        if (settings?.isMuted) {
          mutedUsers.push(userId);
          continue;
        }

        tokens.push(tokenData.token);
      }

      if (tokens.length === 0) {
        console.log('No valid FCM tokens found or all users muted');
        return;
      }

      // Prepare notification payload
      const senderName = message.senderDisplayName || 'Någon';
      let notificationBody = '';

      switch (message.type) {
        case 'text':
          notificationBody = message.content;
          break;
        case 'image':
          notificationBody = '📷 Skickade en bild';
          break;
        case 'recipeShare':
          notificationBody = '🍳 Delade ett recept';
          break;
        case 'menuShare':
          notificationBody = '📋 Delade en meny';
          break;
        default:
          notificationBody = 'Nytt meddelande';
      }

      // Get conversation title
      const conversationTitle = conversation?.isGroup
        ? (conversation?.title || 'Gruppchatt')
        : senderName;

      // Send notification
      const payload = {
        notification: {
          title: conversationTitle,
          body: `${senderName}: ${notificationBody}`,
          sound: 'default',
        },
        data: {
          conversationId: conversationId,
          messageId: snapshot.id,
          senderId: senderId,
          type: 'new_message',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'messages',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`Sent ${response.successCount} notifications, ${response.failureCount} failures`);

      // Clean up invalid tokens
      const failedTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
          console.error('Failed to send to token:', tokens[idx], resp.error);
        }
      });

      // Remove invalid tokens from database
      if (failedTokens.length > 0) {
        const batch = admin.firestore().batch();
        const invalidTokensSnapshot = await admin.firestore()
          .collection('fcmTokens')
          .where('token', 'in', failedTokens)
          .get();

        invalidTokensSnapshot.docs.forEach(doc => {
          batch.delete(doc.reference);
        });

        await batch.commit();
        console.log(`Removed ${failedTokens.length} invalid FCM tokens`);
      }

    } catch (error) {
      console.error('Error sending notification:', error);
      throw error;
    }
  });

/**
 * Clean up old FCM tokens (run weekly)
 */
export const cleanupOldTokens = functions.pubsub
  .schedule('every sunday 03:00')
  .timeZone('Europe/Stockholm')
  .onRun(async (context) => {
    const threeMonthsAgo = new Date();
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

    const oldTokensSnapshot = await admin.firestore()
      .collection('fcmTokens')
      .where('updatedAt', '<', threeMonthsAgo)
      .get();

    if (oldTokensSnapshot.empty) {
      console.log('No old tokens to clean up');
      return;
    }

    const batch = admin.firestore().batch();
    oldTokensSnapshot.docs.forEach(doc => {
      batch.delete(doc.reference);
    });

    await batch.commit();
    console.log(`Cleaned up ${oldTokensSnapshot.size} old FCM tokens`);
  });
```

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

## Client-Side Updates

### 1. FCM Token Registration

Update `lib/services/notifications/notification_service.dart`:

```dart
/// Register FCM token for push notifications
Future<void> registerFCMToken() async {
  try {
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) return;

    // Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      AppLogger.warning('Failed to get FCM token');
      return;
    }

    // Store token in Firestore
    await _firestore
        .collection('fcmTokens')
        .doc(token)
        .set({
      'userId': currentUser.uid,
      'token': token,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    AppLogger.success('FCM token registered: ${token.substring(0, 20)}...');

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _updateFCMToken(newToken);
    });

  } catch (e) {
    AppLogger.error('Failed to register FCM token', e);
  }
}

Future<void> _updateFCMToken(String newToken) async {
  try {
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('fcmTokens')
        .doc(newToken)
        .set({
      'userId': currentUser.uid,
      'token': newToken,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    AppLogger.info('FCM token updated');
  } catch (e) {
    AppLogger.error('Failed to update FCM token', e);
  }
}
```

### 2. Initialize on App Startup

Update `lib/main.dart`:

```dart
// After ApplicationBootstrap.initialize()
final notificationService = ServiceLocator.get<NotificationService>();
await notificationService.registerFCMToken();
```

### 3. Handle Notification Taps

Add to `lib/main.dart`:

```dart
// Handle notification taps
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final data = message.data;
  final conversationId = data['conversationId'];

  if (conversationId != null) {
    // Navigate to chat
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ChatViewFacade(
          conversationId: conversationId,
        ),
      ),
    );
  }
});
```

## Firestore Security Rules

Add to `firestore.rules`:

```javascript
// FCM Tokens collection
match /fcmTokens/{tokenId} {
  // Users can only read/write their own tokens
  allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
  allow write: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
}

// Conversation user settings (for mute functionality)
match /conversations/{conversationId}/userSettings/{userId} {
  // Users can only access their own settings
  allow read, write: if isAuthenticated() && request.auth.uid == userId;
}
```

## Testing

### 1. Test Notification Sending

```bash
# Send test notification via Firebase Console
# OR use Firebase Admin SDK
```

### 2. Test Mute Functionality

1. Mute a conversation in the app
2. Send a message
3. Verify no notification is received

### 3. Test Token Cleanup

1. Uninstall app
2. Wait for scheduled cleanup function
3. Verify old token is removed

## Production Checklist

- [ ] Deploy Cloud Functions to Firebase
- [ ] Update NotificationService with FCM token registration
- [ ] Initialize FCM on app startup
- [ ] Add notification tap handlers
- [ ] Update Firestore security rules
- [ ] Test notifications on Android
- [ ] Test notifications on iOS
- [ ] Test mute functionality
- [ ] Test token refresh
- [ ] Set up monitoring and alerts
- [ ] Test notification delivery rate

## Monitoring

### Cloud Functions Logs

```bash
firebase functions:log
```

### Metrics to Track

- Notification delivery rate
- Failed token count
- Average delivery time
- User engagement (notification tap rate)

## Cost Estimation

Firebase Cloud Functions pricing:
- Invocations: First 2M free, then $0.40 per million
- Compute time: First 400K GB-seconds free, then $0.0000025 per GB-second

Estimated monthly cost for 10K active users with 100 messages/day:
- ~30M function invocations = **$11.20/month**
- Compute time negligible

## Support

For issues:
1. Check Cloud Functions logs: `firebase functions:log`
2. Verify FCM tokens in Firestore console
3. Test notification payload with FCM console
4. Review security rules for token collection

## References

- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
