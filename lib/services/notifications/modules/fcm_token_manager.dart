// lib/services/notifications/modules/fcm_token_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/notification_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for Firebase Cloud Messaging token management
/// 
/// This module handles ONLY FCM token responsibilities:
/// - FCM token registration and updates
/// - Token refresh handling and synchronization
/// - User device management and multi-device support
/// - Topic subscription management based on preferences
/// - Token cleanup for signed-out users
/// 
/// ❌ DOES NOT CONTAIN: Content generation, preferences, batching, analytics
class FCMTokenManager {
  final FirebaseFirestore _firestore;
  final String _userId;
  
  // Token state tracking
  String? _currentToken;
  DateTime? _lastTokenRefresh;
  StreamSubscription<String>? _tokenRefreshSubscription;
  
  // Collections
  static const String _tokensCollection = 'user_fcm_tokens';
  static const String _deviceInfoCollection = 'user_devices';
  
  // Local storage keys
  static const String _tokenStorageKey = 'fcm_token';
  static const String _tokenTimestampKey = 'fcm_token_timestamp';

  FCMTokenManager({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore, _userId = userId;

  // ===== INITIALIZATION AND TOKEN REGISTRATION =====

  /// Initialize FCM token management for the user
  /// 
  /// This should be called after user authentication to ensure tokens are properly managed
  Future<void> initialize() async {
    try {
      AppLogger.info('🔔 Initializing FCM token management for user: $_userId');

      // Check if FCM is available
      final messaging = FirebaseMessaging.instance;
      
      // Request permission for notifications
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.warning('⚠️ User denied notification permissions');
        return;
      }

      // Get initial token
      await _refreshToken();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Clean up old devices for this user
      await _cleanupOldDevices();

      AppLogger.success('✅ FCM token management initialized successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize FCM token management', e);
      rethrow;
    }
  }

  /// Get current FCM token
  /// 
  /// Returns cached token if valid, otherwise fetches a new one
  Future<String?> getCurrentToken() async {
    try {
      // Return cached token if valid and recent
      if (_currentToken != null && _isTokenFresh()) {
        AppLogger.debug('📋 Using cached FCM token');
        return _currentToken;
      }

      // Fetch new token
      await _refreshToken();
      return _currentToken;
    } catch (e) {
      AppLogger.error('❌ Failed to get current FCM token', e);
      return null;
    }
  }

  /// Force refresh the FCM token
  /// 
  /// This will get a new token from Firebase and update all storage locations
  Future<void> refreshToken() async {
    AppLogger.info('🔄 Force refreshing FCM token');
    await _refreshToken();
  }

  // ===== TOKEN REFRESH AND SYNCHRONIZATION =====

  /// Internal token refresh logic
  Future<void> _refreshToken() async {
    try {
      AppLogger.debug('🔔 Refreshing FCM token');

      final messaging = FirebaseMessaging.instance;
      final newToken = await messaging.getToken();

      if (newToken == null) {
        AppLogger.warning('⚠️ Failed to get FCM token - may not be supported on this platform');
        return;
      }

      final oldToken = _currentToken;
      _currentToken = newToken;
      _lastTokenRefresh = DateTime.now();

      // Only update if token actually changed
      if (oldToken != newToken) {
        AppLogger.info('🔑 FCM token updated: ${newToken.substring(0, 20)}...');
        
        // Save to Firestore
        await _saveTokenToFirestore(newToken);
        
        // Save locally for offline access
        await _saveTokenLocally(newToken);
        
        // Update device info
        await _updateDeviceInfo(newToken);
        
        // Clean up old token if it existed
        if (oldToken != null) {
          await _removeOldToken(oldToken);
        }
        
        AppLogger.debug('✅ Token refresh complete');
      } else {
        AppLogger.debug('📋 Token unchanged, updating timestamp only');
        await _updateTokenTimestamp(newToken);
      }
    } catch (e) {
      AppLogger.error('❌ Failed to refresh FCM token', e);
      rethrow;
    }
  }

  /// Set up listener for automatic token refresh
  void _setupTokenRefreshListener() {
    try {
      final messaging = FirebaseMessaging.instance;
      
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (newToken) async {
          AppLogger.info('🔄 FCM token refreshed automatically');
          _currentToken = newToken;
          _lastTokenRefresh = DateTime.now();
          
          try {
            await _saveTokenToFirestore(newToken);
            await _saveTokenLocally(newToken);
            await _updateDeviceInfo(newToken);
            AppLogger.success('✅ Auto token refresh complete');
          } catch (e) {
            AppLogger.error('❌ Failed to handle auto token refresh', e);
          }
        },
        onError: (error) {
          AppLogger.error('❌ FCM token refresh listener error', error);
        },
      );

      AppLogger.debug('👂 FCM token refresh listener set up');
    } catch (e) {
      AppLogger.error('❌ Failed to set up token refresh listener', e);
    }
  }

  // ===== TOPIC SUBSCRIPTION MANAGEMENT =====

  /// Subscribe to notification topics based on user preferences
  /// 
  /// This should be called after preferences are updated
  Future<void> updateTopicSubscriptions(NotificationPreferences preferences) async {
    try {
      AppLogger.info('🔔 Updating FCM topic subscriptions based on preferences');

      final messaging = FirebaseMessaging.instance;
      
      // User-specific topic (always subscribed when logged in)
      await messaging.subscribeToTopic('user_$_userId');
      AppLogger.debug('✅ Subscribed to user-specific topic');

      // System updates - based on system notification preferences
      if (preferences.isEnabled(NotificationCategory.system, NotificationType.digest)) {
        await messaging.subscribeToTopic('system_updates');
        AppLogger.debug('✅ Subscribed to system_updates topic');
      } else {
        await messaging.unsubscribeFromTopic('system_updates');
        AppLogger.debug('📋 Unsubscribed from system_updates topic');
      }

      // Social digest - based on social notification preferences
      if (preferences.isEnabled(NotificationCategory.social, NotificationType.digest)) {
        await messaging.subscribeToTopic('social_digest');
        AppLogger.debug('✅ Subscribed to social_digest topic');
      } else {
        await messaging.unsubscribeFromTopic('social_digest');
        AppLogger.debug('📋 Unsubscribed from social_digest topic');
      }

      // Recipe recommendations - based on recipe preferences
      if (preferences.isEnabled(NotificationCategory.recipes, NotificationType.digest)) {
        await messaging.subscribeToTopic('recipe_recommendations');
        AppLogger.debug('✅ Subscribed to recipe_recommendations topic');
      } else {
        await messaging.unsubscribeFromTopic('recipe_recommendations');
        AppLogger.debug('📋 Unsubscribed from recipe_recommendations topic');
      }

      // Friend activity digest - based on friend preferences
      if (preferences.isEnabled(NotificationCategory.friends, NotificationType.digest)) {
        await messaging.subscribeToTopic('friend_activity');
        AppLogger.debug('✅ Subscribed to friend_activity topic');
      } else {
        await messaging.unsubscribeFromTopic('friend_activity');
        AppLogger.debug('📋 Unsubscribed from friend_activity topic');
      }

      AppLogger.success('✅ Topic subscriptions updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update topic subscriptions', e);
    }
  }

  /// Unsubscribe from all topics (called on logout)
  Future<void> unsubscribeFromAllTopics() async {
    try {
      AppLogger.info('🔔 Unsubscribing from all FCM topics');

      final messaging = FirebaseMessaging.instance;
      
      // Unsubscribe from all known topics
      final topics = [
        'user_$_userId',
        'system_updates',
        'social_digest',
        'recipe_recommendations',
        'friend_activity',
      ];

      for (final topic in topics) {
        try {
          await messaging.unsubscribeFromTopic(topic);
          AppLogger.debug('📋 Unsubscribed from $topic');
        } catch (e) {
          AppLogger.warning('⚠️ Failed to unsubscribe from $topic: $e');
        }
      }

      AppLogger.success('✅ Unsubscribed from all topics');
    } catch (e) {
      AppLogger.error('❌ Failed to unsubscribe from topics', e);
    }
  }

  // ===== TOKEN STORAGE AND DEVICE MANAGEMENT =====

  /// Save token to Firestore for server-side usage
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final tokenDoc = {
        'userId': _userId,
        'token': token,
        'platform': _getPlatformName(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore
          .collection(_tokensCollection)
          .doc('${_userId}_${_getDeviceId()}')
          .set(tokenDoc, SetOptions(merge: true));

      AppLogger.debug('✅ Saved FCM token to Firestore');
    } catch (e) {
      AppLogger.error('❌ Failed to save token to Firestore', e);
      rethrow;
    }
  }

  /// Save token locally for offline access
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenStorageKey, token);
      await prefs.setString(_tokenTimestampKey, DateTime.now().toIso8601String());
      AppLogger.debug('✅ Saved FCM token locally');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save token locally: $e');
    }
  }

  /// Update device information with new token
  Future<void> _updateDeviceInfo(String token) async {
    try {
      final deviceDoc = {
        'userId': _userId,
        'deviceId': _getDeviceId(),
        'platform': _getPlatformName(),
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore
          .collection(_deviceInfoCollection)
          .doc('${_userId}_${_getDeviceId()}')
          .set(deviceDoc, SetOptions(merge: true));

      AppLogger.debug('✅ Updated device info');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update device info: $e');
    }
  }

  /// Update token timestamp without changing the token
  Future<void> _updateTokenTimestamp(String token) async {
    try {
      await _firestore
          .collection(_tokensCollection)
          .doc('${_userId}_${_getDeviceId()}')
          .update({
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update token timestamp: $e');
    }
  }

  /// Remove old token from Firestore
  Future<void> _removeOldToken(String oldToken) async {
    try {
      // Query for documents with the old token
      final query = await _firestore
          .collection(_tokensCollection)
          .where('userId', isEqualTo: _userId)
          .where('token', isEqualTo: oldToken)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        AppLogger.debug('🧹 Marked ${query.docs.length} old tokens as inactive');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to remove old token: $e');
    }
  }

  /// Clean up old devices for the user
  Future<void> _cleanupOldDevices() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final query = await _firestore
          .collection(_deviceInfoCollection)
          .where('userId', isEqualTo: _userId)
          .where('lastSeen', isLessThan: cutoffTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in query.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
        
        AppLogger.info('🧹 Cleaned up ${query.docs.length} old devices');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to cleanup old devices: $e');
    }
  }

  // ===== TOKEN VALIDATION AND UTILITIES =====

  /// Check if current token is fresh (less than 1 hour old)
  bool _isTokenFresh() {
    if (_lastTokenRefresh == null) return false;
    
    final age = DateTime.now().difference(_lastTokenRefresh!);
    return age.inHours < 1;
  }

  /// Get a unique device identifier
  String _getDeviceId() {
    // This would typically use a device ID package
    // For now, use a simple hash based on platform and timestamp
    return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  }

  /// Get platform name for tracking
  String _getPlatformName() {
    // This would typically use Platform.operatingSystem
    // For now, assume it's available from somewhere
    return 'android'; // or 'ios', 'web', etc.
  }


  // ===== PUBLIC UTILITY METHODS =====

  /// Get all active tokens for the current user (for admin purposes)
  Future<List<String>> getAllUserTokens() async {
    try {
      final query = await _firestore
          .collection(_tokensCollection)
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => doc.data()['token'] as String)
          .toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get user tokens', e);
      return [];
    }
  }

  /// Check if FCM is properly initialized
  bool get isInitialized => _currentToken != null;

  /// Get token age in minutes
  int? get tokenAgeMinutes {
    if (_lastTokenRefresh == null) return null;
    return DateTime.now().difference(_lastTokenRefresh!).inMinutes;
  }

  // ===== LIFECYCLE METHODS =====

  /// Clean up on user logout
  Future<void> cleanup() async {
    try {
      AppLogger.info('🔔 Cleaning up FCM token management');

      // Unsubscribe from all topics
      await unsubscribeFromAllTopics();

      // Mark current token as inactive
      if (_currentToken != null) {
        await _removeOldToken(_currentToken!);
      }

      // Mark device as inactive
      try {
        await _firestore
            .collection(_deviceInfoCollection) 
            .doc('${_userId}_${_getDeviceId()}')
            .update({'isActive': false});
      } catch (e) {
        AppLogger.warning('⚠️ Failed to mark device as inactive: $e');
      }

      AppLogger.success('✅ FCM token cleanup complete');
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup FCM tokens', e);
    }
  }

  /// Dispose resources
  void dispose() {
    AppLogger.info('🔔 Disposing FCMTokenManager for user $_userId');

    // Cancel token refresh subscription
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    // Clear token state
    _currentToken = null;
    _lastTokenRefresh = null;

    AppLogger.debug('✅ FCMTokenManager disposed');
  }
}