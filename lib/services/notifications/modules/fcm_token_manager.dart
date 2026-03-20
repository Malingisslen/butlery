// lib/services/notifications/modules/fcm_token_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized Firebase Cloud Messaging token management module providing comprehensive device token lifecycle management.
/// This focused module implements sophisticated FCM token management following Single Responsibility Principle,
/// handling all aspects of device token lifecycle including registration, refresh handling, multi-device support,
/// and topic subscription management. It provides reliable token synchronization across user sessions while
/// maintaining clean separation from other notification system concerns.
/// **Single Responsibility Focus:**
/// This module exclusively handles FCM token management responsibilities:
/// - **Token Registration**: Initial device token registration and backend synchronization
/// - **Token Refresh**: Automatic token refresh handling and cross-device synchronization
/// - **Multi-Device Support**: Comprehensive device management for users with multiple devices
/// - **Topic Subscriptions**: Intelligent topic subscription management based on user preferences
/// - **Token Cleanup**: Proper token cleanup and deregistration during user logout scenarios
/// **What This Module Does NOT Handle:**
/// - Content generation and message templating (handled by NotificationContentManager)
/// - User preferences and quiet hours (handled by NotificationPreferenceManager)
/// - Notification batching and spam prevention (handled by NotificationBatchManager)
/// - Delivery analytics and tracking (handled by NotificationAnalyticsManager)
/// **Token Lifecycle Management:**
/// - Automatic token registration during app initialization with backend synchronization
/// - Real-time token refresh monitoring with immediate backend updates
/// - Multi-device token tracking enabling consistent notifications across user devices
/// - Intelligent topic subscription updates based on user preference changes
/// - Comprehensive cleanup ensuring proper token deregistration during logout
/// **Usage Examples:**
/// ```dart
/// final tokenManager = FCMTokenManager(firestore, userId);
/// // Initialize token management
/// await tokenManager.initialize();
/// // Handle token refresh
/// tokenManager.onTokenRefresh.listen((newToken) {
///   print('Token refreshed: $newToken');
/// });
/// // Update topic subscriptions
/// await tokenManager.updateTopicSubscriptions(preferences);
/// ```
class FCMTokenManager {
  final DeviceRepository _repository;
  final String _userId;
  final FirebaseMessaging _messaging;

  // Token state tracking
  String? _currentToken;
  DateTime? _lastTokenRefresh;
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Local storage keys
  static const String _tokenStorageKey = 'fcm_token';
  static const String _tokenTimestampKey = 'fcm_token_timestamp';

  // Secure storage instance for sensitive FCM token data
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  FCMTokenManager({
    required String userId,
    required DeviceRepository repository,
    FirebaseMessaging? messaging,
  })  : _repository = repository,
        _userId = userId,
        _messaging = messaging ?? FirebaseMessaging.instance;

  /// Initialize FCM token management for the user
  /// This should be called after user authentication to ensure tokens are properly managed
  Future<void> initialize() async {
    try {
      AppLogger.info('🔔 Initializing FCM token management for user: $_userId');

      // Request permission for notifications
      final permission = await _messaging.requestPermission(
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
  /// This will get a new token from Firebase and update all storage locations
  Future<void> refreshToken() async {
    AppLogger.info('🔄 Force refreshing FCM token');
    await _refreshToken();
  }

  /// Internal token refresh logic
  Future<void> _refreshToken() async {
    try {
      AppLogger.debug('🔔 Refreshing FCM token');

      final newToken = await _messaging.getToken();

      if (newToken == null) {
        AppLogger.warning(
            '⚠️ Failed to get FCM token - may not be supported on this platform');
        return;
      }

      final oldToken = _currentToken;
      _currentToken = newToken;
      _lastTokenRefresh = DateTime.now();

      // Only update if token actually changed
      if (oldToken != newToken) {
        AppLogger.info('FCM token updated successfully');

        // Run independent writes concurrently
        await Future.wait([
          _saveTokenToFirestore(newToken),
          _saveTokenLocally(newToken),
          _updateDeviceInfo(newToken),
        ]);

        // Deactivate old token after new one is saved
        if (oldToken != null) {
          await _deactivateDeviceToken();
        }

        AppLogger.debug('✅ Token refresh complete');
      } else {
        AppLogger.debug('📋 Token unchanged, updating timestamp only');
        await _updateTokenTimestamp();
      }
    } catch (e) {
      AppLogger.error('❌ Failed to refresh FCM token', e);
      rethrow;
    }
  }

  /// Set up listener for automatic token refresh
  void _setupTokenRefreshListener() {
    try {
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (newToken) async {
          AppLogger.info('🔄 FCM token refreshed automatically');
          final oldToken = _currentToken;
          _currentToken = newToken;
          _lastTokenRefresh = DateTime.now();

          try {
            await Future.wait([
              _saveTokenToFirestore(newToken),
              _saveTokenLocally(newToken),
              _updateDeviceInfo(newToken),
            ]);

            // Deactivate old token (mirrors _refreshToken behavior)
            if (oldToken != null && oldToken != newToken) {
              await _deactivateDeviceToken();
            }

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

  /// Subscribe to notification topics based on user preferences
  /// This should be called after preferences are updated
  Future<void> updateTopicSubscriptions(
      NotificationPreferences preferences) async {
    try {
      AppLogger.info(
          '🔔 Updating FCM topic subscriptions based on preferences');

      // User-specific topic (always subscribed when logged in)
      await _messaging.subscribeToTopic('user_$_userId');
      AppLogger.debug('✅ Subscribed to user-specific topic');

      // System updates - based on system notification preferences
      if (preferences.isEnabled(
          NotificationCategory.system, NotificationType.digest)) {
        await _messaging.subscribeToTopic('system_updates');
        AppLogger.debug('✅ Subscribed to system_updates topic');
      } else {
        await _messaging.unsubscribeFromTopic('system_updates');
        AppLogger.debug('📋 Unsubscribed from system_updates topic');
      }

      // Social digest - based on social notification preferences
      if (preferences.isEnabled(
          NotificationCategory.social, NotificationType.digest)) {
        await _messaging.subscribeToTopic('social_digest');
        AppLogger.debug('✅ Subscribed to social_digest topic');
      } else {
        await _messaging.unsubscribeFromTopic('social_digest');
        AppLogger.debug('📋 Unsubscribed from social_digest topic');
      }

      // Recipe recommendations - based on recipe preferences
      if (preferences.isEnabled(
          NotificationCategory.recipes, NotificationType.digest)) {
        await _messaging.subscribeToTopic('recipe_recommendations');
        AppLogger.debug('✅ Subscribed to recipe_recommendations topic');
      } else {
        await _messaging.unsubscribeFromTopic('recipe_recommendations');
        AppLogger.debug('📋 Unsubscribed from recipe_recommendations topic');
      }

      // Friend activity digest - based on friend preferences
      if (preferences.isEnabled(
          NotificationCategory.friends, NotificationType.digest)) {
        await _messaging.subscribeToTopic('friend_activity');
        AppLogger.debug('✅ Subscribed to friend_activity topic');
      } else {
        await _messaging.unsubscribeFromTopic('friend_activity');
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
          await _messaging.unsubscribeFromTopic(topic);
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

  /// Save token to Firestore for server-side usage
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final tokenDoc = {
        'userId': _userId,
        'token': token,
        'platform': _getPlatformName(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _repository.saveTokenToFirestore(
        '${_userId}_${await _getDeviceId()}',
        tokenDoc,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to save token to Firestore', e);
      rethrow;
    }
  }

  /// Save token locally for offline access using secure storage
  Future<void> _saveTokenLocally(String token) async {
    try {
      await _secureStorage.write(key: _tokenStorageKey, value: token);
      await _secureStorage.write(
          key: _tokenTimestampKey, value: DateTime.now().toIso8601String());
      AppLogger.debug('Saved FCM token to secure storage');
    } catch (e) {
      AppLogger.warning('Failed to save token to secure storage: $e');
    }
  }

  /// Update device information with new token
  Future<void> _updateDeviceInfo(String token) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceDoc = {
        'userId': _userId,
        'deviceId': deviceId,
        'platform': _getPlatformName(),
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _repository.updateDeviceInfo(
        '${_userId}_$deviceId',
        deviceDoc,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update device info: $e');
    }
  }

  /// Update token timestamp without changing the token
  Future<void> _updateTokenTimestamp() async {
    try {
      await _repository.updateTokenTimestamp(
        '${_userId}_${await _getDeviceId()}',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update token timestamp: $e');
    }
  }

  /// Deactivate the current device's token doc in Firestore
  Future<void> _deactivateDeviceToken() async {
    try {
      await _repository.removeOldToken(_userId, await _getDeviceId());
    } catch (e) {
      AppLogger.warning('⚠️ Failed to deactivate device token: $e');
    }
  }

  /// Clean up old devices for the user
  Future<void> _cleanupOldDevices() async {
    try {
      // Use repository method for device cleanup
      await _repository.cleanupOldDevices(
        _userId,
        DateTime.now().subtract(const Duration(days: 30)),
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to cleanup old devices: $e');
    }
  }

  /// Check if current token is fresh (less than 1 hour old)
  bool _isTokenFresh() {
    if (_lastTokenRefresh == null) return false;

    final age = DateTime.now().difference(_lastTokenRefresh!);
    return age.inHours < 1;
  }

  /// Cached device ID to avoid repeated async calls
  String? _cachedDeviceId;

  /// Get a unique device identifier using device_info_plus
  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      if (kIsWeb) {
        _cachedDeviceId = await _fallbackDeviceId();
      } else {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await deviceInfo.androidInfo;
          _cachedDeviceId = android.id;
        } else if (Platform.isIOS) {
          final ios = await deviceInfo.iosInfo;
          _cachedDeviceId =
              ios.identifierForVendor ?? await _fallbackDeviceId();
        } else {
          _cachedDeviceId = await _fallbackDeviceId();
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to get device ID: $e');
      _cachedDeviceId = await _fallbackDeviceId();
    }
    return _cachedDeviceId!;
  }

  static const _fallbackDeviceIdKey = 'butlery_fallback_device_id';

  /// Fallback device ID when platform-specific ID is unavailable.
  /// Persists to secure storage so the same ID is reused across sessions.
  Future<String> _fallbackDeviceId() async {
    final existing = await _secureStorage.read(key: _fallbackDeviceIdKey);
    if (existing != null) return existing;

    final newId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    await _secureStorage.write(key: _fallbackDeviceIdKey, value: newId);
    return newId;
  }

  /// Get platform name for tracking
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Get all active tokens for the current user (for admin purposes)
  Future<List<String>> getAllUserTokens() async {
    try {
      return await _repository.getAllUserTokens(_userId);
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

  /// Clean up on user logout
  Future<void> cleanup() async {
    try {
      AppLogger.info('🔔 Cleaning up FCM token management');

      // Unsubscribe from all topics
      await unsubscribeFromAllTopics();

      // Mark current token as inactive
      if (_currentToken != null) {
        await _deactivateDeviceToken();
      }

      // Invalidate token on Google's servers (not just Firestore)
      try {
        await _messaging.deleteToken();
      } catch (e) {
        AppLogger.warning('⚠️ Failed to delete FCM token from SDK: $e');
      }

      // Mark device as inactive
      try {
        await _repository.markDeviceInactive(
          '${_userId}_${await _getDeviceId()}',
        );
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
