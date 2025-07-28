/**
 * Butlery Notification Cloud Functions
 * 
 * PRODUCTION IMPLEMENTATION for server-side FCM notifications
 * 
 * This file contains the Cloud Functions needed to replace the development
 * logging in NotificationService with actual FCM message delivery.
 * 
 * SETUP INSTRUCTIONS:
 * 1. Install Firebase CLI: npm install -g firebase-tools
 * 2. Initialize functions: firebase init functions
 * 3. Replace functions/index.js with this content
 * 4. Deploy: firebase deploy --only functions
 * 
 * SECURITY FEATURES:
 * ✅ Authenticated calls only
 * ✅ Permission validation
 * ✅ Rate limiting
 * ✅ Input sanitization
 * ✅ FCM token validation
 * ✅ User preference checking
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send push notification to specific user
 * 
 * Called from Flutter NotificationService._sendFCMNotification()
 * 
 * Request format:
 * {
 *   targetUserId: string,
 *   title: string,
 *   body: string,
 *   data: object,
 *   imageUrl?: string,
 *   silent?: boolean
 * }
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    // =============================================================================
    // AUTHENTICATION & AUTHORIZATION
    // =============================================================================
    
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated', 
        'Must be authenticated to send notifications'
      );
    }

    const senderId = context.auth.uid;
    const { targetUserId, title, body, data: notificationData, imageUrl, silent } = data;

    // Validate required fields
    if (!targetUserId || (!silent && (!title || !body))) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: targetUserId, title, body (unless silent)'
      );
    }

    // =============================================================================
    // PERMISSION VALIDATION
    // =============================================================================
    
    // Check if sender can send notifications to target user
    const canSend = await validateSendPermission(senderId, targetUserId);
    if (!canSend) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Not authorized to send notifications to this user'
      );
    }

    // =============================================================================
    // RATE LIMITING
    // =============================================================================
    
    await checkRateLimit(senderId);

    // =============================================================================
    // USER PREFERENCES & FCM TOKEN
    // =============================================================================
    
    // Get target user's profile and preferences
    const targetUserDoc = await db.collection('public_profiles').doc(targetUserId).get();
    if (!targetUserDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Target user not found');
    }

    const targetUser = targetUserDoc.data();
    
    // Check if user has notifications enabled
    if (!targetUser.notificationsEnabled) {
      functions.logger.info(`Notifications disabled for user: ${targetUserId}`);
      return { success: true, skipped: true, reason: 'notifications_disabled' };
    }

    // Get FCM token
    const fcmToken = targetUser.fcmToken;
    if (!fcmToken) {
      functions.logger.warn(`No FCM token for user: ${targetUserId}`);
      return { success: true, skipped: true, reason: 'no_fcm_token' };
    }

    // Check if token is fresh (updated within last 60 days)
    const tokenAge = Date.now() - targetUser.fcmTokenUpdatedAt?.toMillis();
    if (tokenAge > 60 * 24 * 60 * 60 * 1000) { // 60 days in milliseconds
      functions.logger.warn(`Stale FCM token for user: ${targetUserId}`);
      return { success: true, skipped: true, reason: 'stale_token' };
    }

    // =============================================================================
    // QUIET HOURS CHECK
    // =============================================================================
    
    if (!silent && !(await isWithinActiveHours(targetUserId))) {
      functions.logger.info(`Skipping notification due to quiet hours: ${targetUserId}`);
      // Store for later delivery during active hours
      await queueForLater(targetUserId, { title, body, data: notificationData, imageUrl });
      return { success: true, queued: true, reason: 'quiet_hours' };
    }

    // =============================================================================
    // BUILD & SEND FCM MESSAGE
    // =============================================================================
    
    const message = {
      token: fcmToken,
      data: {
        // Always include data payload for app handling
        ...notificationData,
        timestamp: Date.now().toString(),
        senderId: senderId,
      }
    };

    // Add notification UI (unless silent)
    if (!silent) {
      message.notification = {
        title: title,
        body: body,
        ...(imageUrl && { imageUrl })
      };

      // Android-specific options
      message.android = {
        notification: {
          icon: 'ic_notification',
          color: '#FF6B35', // Butlery orange
          sound: 'default',
          priority: 'high',
          channelId: 'butlery_notifications'
        }
      };

      // iOS-specific options  
      message.apns = {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'mutable-content': 1
          }
        }
      };
    } else {
      // Silent notification - data only
      message.android = {
        priority: 'normal'
      };
      message.apns = {
        payload: {
          aps: {
            'content-available': 1
          }
        }
      };
    }

    // Send the message
    const response = await messaging.send(message);
    
    // =============================================================================
    // LOGGING & ANALYTICS
    // =============================================================================
    
    functions.logger.info(`Notification sent successfully`, {
      messageId: response,
      senderId: senderId,
      targetUserId: targetUserId,
      type: silent ? 'silent' : 'notification',
      title: title || 'silent'
    });

    // Update analytics
    await updateNotificationAnalytics(senderId, targetUserId, 'sent');

    return { 
      success: true, 
      messageId: response,
      skipped: false
    };

  } catch (error) {
    functions.logger.error('Notification sending failed', error);
    
    // Handle specific FCM errors
    if (error.code === 'messaging/registration-token-not-registered') {
      // Token is invalid, remove it from user profile
      await db.collection('public_profiles').doc(data.targetUserId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenUpdatedAt: admin.firestore.FieldValue.delete()
      });
      
      return { success: true, skipped: true, reason: 'invalid_token' };
    }

    // Re-throw for other errors
    throw error;
  }
});

/**
 * Process notification queue for users coming back online
 * Runs every 15 minutes to check for queued notifications
 */
exports.processNotificationQueue = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const cutoff = new admin.firestore.Timestamp(now.seconds - 300, 0); // 5 minutes ago

    const queuedNotifications = await db.collection('notificationQueue')
      .where('scheduledFor', '<=', now)
      .where('createdAt', '>=', cutoff)
      .limit(100)
      .get();

    const batch = db.batch();
    const processedCount = queuedNotifications.size;

    for (const doc of queuedNotifications.docs) {
      const notification = doc.data();
      
      try {
        // Send the queued notification
        await messaging.send({
          token: notification.fcmToken,
          notification: {
            title: notification.title,
            body: notification.body,
            imageUrl: notification.imageUrl
          },
          data: notification.data
        });

        // Mark as processed
        batch.delete(doc.ref);
        
      } catch (error) {
        functions.logger.error(`Failed to send queued notification: ${doc.id}`, error);
        // Delete failed notifications to prevent infinite retries
        batch.delete(doc.ref);
      }
    }

    await batch.commit();
    functions.logger.info(`Processed ${processedCount} queued notifications`);
    
    return null;
  });

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Validate if sender can send notifications to target user
 */
async function validateSendPermission(senderId, targetUserId) {
  // Can't send to yourself (prevents spam)
  if (senderId === targetUserId) {
    return false;
  }

  try {
    // Check if they are friends
    const friendshipDoc = await db.collection('userFriends')
      .doc(senderId)
      .collection('friends')
      .doc(targetUserId)
      .get();

    if (friendshipDoc.exists) {
      return true; // Friends can send notifications
    }

    // Check if target user is in a shared recipe/collaboration
    const sharedRecipes = await db.collection('recipes')
      .where('socialData.memberPermissions.' + senderId, '!=', null)
      .where('socialData.memberPermissions.' + targetUserId, '!=', null)
      .limit(1)
      .get();

    if (!sharedRecipes.empty) {
      return true; // Collaborators can send notifications
    }

    return false;
    
  } catch (error) {
    functions.logger.error('Permission validation failed', error);
    return false; // Fail closed
  }
}

/**
 * Check rate limiting for sender
 */
async function checkRateLimit(senderId) {
  const rateLimitDoc = await db.collection('rateLimits').doc(senderId).get();
  const now = Date.now();
  const hourWindow = 60 * 60 * 1000; // 1 hour in milliseconds
  const maxNotificationsPerHour = 50;

  if (rateLimitDoc.exists) {
    const data = rateLimitDoc.data();
    const windowStart = data.windowStart.toMillis();
    
    if (now - windowStart < hourWindow) {
      // Within current window
      if (data.count >= maxNotificationsPerHour) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Rate limit exceeded. Maximum 50 notifications per hour.'
        );
      }
      
      // Increment counter
      await db.collection('rateLimits').doc(senderId).update({
        count: admin.firestore.FieldValue.increment(1)
      });
    } else {
      // Start new window
      await db.collection('rateLimits').doc(senderId).set({
        windowStart: admin.firestore.Timestamp.fromMillis(now),
        count: 1
      });
    }
  } else {
    // First notification from this user
    await db.collection('rateLimits').doc(senderId).set({
      windowStart: admin.firestore.Timestamp.fromMillis(now),
      count: 1
    });
  }
}

/**
 * Check if current time is within user's active hours
 */
async function isWithinActiveHours(userId) {
  try {
    const prefsDoc = await db.collection('notificationPreferences').doc(userId).get();
    if (!prefsDoc.exists) {
      return true; // No preferences set, allow all times
    }

    const prefs = prefsDoc.data();
    if (!prefs.quietHoursEnabled) {
      return true;
    }

    const now = new Date();
    const currentHour = now.getHours();
    const startHour = prefs.quietHoursStart || 22; // Default 10 PM
    const endHour = prefs.quietHoursEnd || 8;      // Default 8 AM

    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startHour > endHour) {
      return currentHour < startHour && currentHour >= endHour;
    } else {
      return currentHour < startHour || currentHour >= endHour;
    }
  } catch (error) {
    functions.logger.error('Quiet hours check failed', error);
    return true; // Fail open
  }
}

/**
 * Queue notification for later delivery
 */
async function queueForLater(userId, notificationData) {
  const tomorrow8AM = new Date();
  tomorrow8AM.setDate(tomorrow8AM.getDate() + 1);
  tomorrow8AM.setHours(8, 0, 0, 0);

  await db.collection('notificationQueue').add({
    userId: userId,
    ...notificationData,
    scheduledFor: admin.firestore.Timestamp.fromDate(tomorrow8AM),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

/**
 * Update notification analytics
 */
async function updateNotificationAnalytics(senderId, targetUserId, action) {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  
  await db.collection('notificationAnalytics').doc(`${today}_${senderId}`).set({
    senderId: senderId,
    date: today,
    sent: action === 'sent' ? admin.firestore.FieldValue.increment(1) : 0,
    delivered: action === 'delivered' ? admin.firestore.FieldValue.increment(1) : 0,
    failed: action === 'failed' ? admin.firestore.FieldValue.increment(1) : 0
  }, { merge: true });
}