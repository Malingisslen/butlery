/// Advanced Firebase Cloud Messaging service providing comprehensive push notification functionality with deep linking.
/// This service implements sophisticated FCM integration for reliable push notification delivery across iOS and Android
/// platforms. It provides comprehensive token management, message handling, permission management, and deep linking
/// capabilities with intelligent background processing and seamless integration with the broader notification system
/// for enhanced user engagement and cooking-focused notifications.
/// **Architecture Integration:**
/// - Integrates with [FirebaseMessaging] for cloud push notification delivery and cross-platform compatibility
/// - Uses [AppLogger] for comprehensive logging and debugging capabilities during development and production
/// - Coordinates with [UserService] for user-specific token management and notification personalization
/// - Implements static service pattern for app-wide FCM functionality and lifecycle management
/// **Core FCM Responsibilities:**
/// - **Token Management**: Device token registration, renewal, and cross-device synchronization
/// - **Message Handling**: Foreground and background message processing with intelligent routing
/// - **Permission Management**: iOS and Android permission requests with graceful handling of user choices
/// - **Deep Link Navigation**: Notification-triggered navigation with context preservation and state management
/// - **Background Processing**: Reliable message handling when app is backgrounded or terminated
/// **Push Notification Features:**
/// - **Recipe Sharing Notifications**: Rich recipe sharing alerts with preview content and social context
/// - **Cooking Reminders**: Timer-based notifications and meal planning alerts with actionable content
/// - **Social Engagement**: Friend interactions, cooking collaborations, and community notifications
/// - **System Messages**: App updates, feature announcements, and important system communications
/// - **Swedish Localized Content**: Complete Swedish language support for culturally appropriate messaging
/// **Platform Optimization:**
/// - **iOS Integration**: APNs integration with proper badge management and notification categories
/// - **Android Integration**: FCM optimization with notification channels and adaptive delivery
/// - **Cross-Platform Consistency**: Unified notification experience across different device types
/// - **Background Reliability**: Robust background message handling ensuring delivery in all app states
/// **Usage Examples:**
/// ```dart
/// // Initialize FCM service during app startup
/// await FCMService.initialize(
///   onMessageReceived: (message) {
///     showInAppNotification(message);
///   },
///   onMessageOpenedApp: (message) {
///     navigateToNotificationContent(message);
///   },
/// );
/// // Get current FCM token for user registration
/// final token = await FCMService.getToken();
/// await registerTokenWithBackend(token);
/// // Handle token refresh for reliable delivery
/// FCMService.onTokenRefresh.listen((newToken) {
///   updateTokenOnBackend(newToken);
/// });
/// ```

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';

/// Firebase Cloud Messaging service for push notifications with deep linking.
///
/// Uses static pattern for app-wide FCM functionality. ErrorHandlingMixin is
/// available via [_errorHandler] for consistent error classification and logging.
/// Permission requests and token registration are gated behind the
/// pushNotifications consent purpose (GDPR Art. 6.1.a).
class FCMService with ErrorHandlingMixin {
  // Static instance for accessing ErrorHandlingMixin methods from static context
  static final FCMService _errorHandler = FCMService._();
  FCMService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _currentToken;
  static bool _isInitialized = false;
  static bool _pushPermissionsRequested = false;
  static ConsentService? _consentService;

  // Callbacks for handling different notification scenarios
  static Function(RemoteMessage)? _onMessageReceived;
  static Function(RemoteMessage)? _onMessageOpenedApp;

  // Subscription tracking for proper disposal
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  // Android notification channels
  static const String _generalChannelId = 'butlery_general';
  static const String _socialChannelId = 'butlery_social';
  static const String _messagingChannelId = 'butlery_messaging';

  // Flutter local notifications plugin
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize FCM service with permission handling
  /// Should be called during app startup after Firebase initialization.
  /// Permission requests and token registration are gated behind
  /// pushNotifications consent via [consentService].
  static Future<void> initialize({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    ConsentService? consentService,
  }) async {
    if (_isInitialized) {
      AppLogger.warning('FCMService already initialized, skipping...');
      return;
    }

    final result = await _errorHandler.safeExecute(
      () async {
        AppLogger.info('Initializing FCM service...');

        _onMessageReceived = onMessageReceived;
        _onMessageOpenedApp = onMessageOpenedApp;
        _consentService = consentService;

        // Listen for mid-session consent changes (BUT-356)
        _consentService?.onConsentChanged = _onConsentChanged;

        await _initializeNotificationChannels();
        await _setupMessageHandlers();

        // Gate permission request and token registration behind consent
        final hasConsent = await _hasPushConsent();
        if (hasConsent) {
          await _requestPermissions();
          await _refreshToken();
          _pushPermissionsRequested = true;
        } else {
          AppLogger.info(
              '🔔 FCM: Skipping permission request — pushNotifications consent not granted');
        }

        _tokenRefreshSubscription =
            _messaging.onTokenRefresh.listen(_onTokenRefresh);

        _isInitialized = true;
        AppLogger.success('FCM service initialized successfully');
      },
      operationName: 'FCMService: Initialize',
    );

    if (result == null) {
      throw Exception('Failed to initialize FCM service');
    }
  }

  /// Check if user has granted push notification consent (GDPR Art. 6.1.a).
  /// Fails closed: if consent cannot be determined, deny by default.
  static Future<bool> _hasPushConsent() async {
    return ConsentService.checkSafely(
        _consentService, ConsentPurpose.pushNotifications,
        logTag: 'FCMService');
  }

  /// Called when consent changes mid-session (BUT-356).
  /// Re-enables push permissions and token registration if consent is now granted.
  static bool _consentChangeInProgress = false;

  static Future<void> _onConsentChanged() async {
    if (_pushPermissionsRequested || _consentChangeInProgress) return;
    _consentChangeInProgress = true;
    try {
      final hasConsent = await _hasPushConsent();
      if (hasConsent) {
        AppLogger.info(
            '🔔 FCM: Push consent granted mid-session — requesting permissions');
        await _requestPermissions();
        await _refreshToken();
        _pushPermissionsRequested = true;
      }
    } catch (e) {
      AppLogger.error('❌ FCM: Failed to handle consent change', e);
    } finally {
      _consentChangeInProgress = false;
    }
  }

  /// Initialize Android notification channels (required for Android 8+)
  static Future<void> _initializeNotificationChannels() async {
    // Only initialize on Android
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      AppLogger.info('🔔 Initializing Android notification channels...');

      // Define notification channels
      final generalChannel = AndroidNotificationChannel(
        _generalChannelId,
        AppLocale.current.fcmChannelGeneralTitle,
        description: AppLocale.current.fcmChannelGeneralDescription,
        importance: Importance.defaultImportance,
      );

      final socialChannel = AndroidNotificationChannel(
        _socialChannelId,
        AppLocale.current.fcmChannelSocialTitle,
        description: AppLocale.current.fcmChannelSocialDescription,
        importance: Importance.high,
      );

      final messagingChannel = AndroidNotificationChannel(
        _messagingChannelId,
        AppLocale.current.fcmChannelMessagingTitle,
        description: AppLocale.current.fcmChannelMessagingDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      // Create channels using flutter_local_notifications
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(generalChannel);
        await androidPlugin.createNotificationChannel(socialChannel);
        await androidPlugin.createNotificationChannel(messagingChannel);
        AppLogger.success('✅ Android notification channels created');
      }

      // Initialize flutter_local_notifications
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to initialize notification channels: $e');
      // Non-critical - FCM will still work with default channel
    }
  }

  /// Request notification permissions from user
  static Future<NotificationSettings> _requestPermissions() async {
    try {
      AppLogger.info('🔔 Requesting notification permissions...');

      final settings = await _messaging.requestPermission(
        alert: true, // Show notification alerts
        announcement: false, // Not needed for Butlery
        badge: true, // Update app badge count
        carPlay: false, // Not applicable
        criticalAlert: false, // Only for emergency apps
        provisional: false, // Don't use provisional authorization
        sound: true, // Play notification sounds
      );

      AppLogger.info(
          '🔔 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.success('✅ Notification permissions granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        AppLogger.info('📋 Provisional notification permissions granted');
      } else {
        AppLogger.warning('⚠️ Notification permissions denied');
      }

      return settings;
    } catch (e) {
      AppLogger.error('❌ Failed to request notification permissions', e);
      rethrow;
    }
  }

  /// Set up foreground, background, and opened app message handlers
  static Future<void> _setupMessageHandlers() async {
    try {
      // Handle messages when app is in foreground (store subscription for disposal)
      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.info('🔔 Received foreground message: ${message.messageId}');
        _logMessageDetails(message);

        // Show in-app notification or update UI
        _onMessageReceived?.call(message);
      });

      // Handle messages when app is opened from notification (store subscription for disposal)
      _onMessageOpenedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info('🔔 App opened from notification: ${message.messageId}');
        _logMessageDetails(message);

        // Navigate to relevant screen
        _onMessageOpenedApp?.call(message);
      });

      // Check for messages that opened the app when it was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info(
            '🔔 App launched from notification: ${initialMessage.messageId}');
        _logMessageDetails(initialMessage);

        // Handle app launch navigation
        _onMessageOpenedApp?.call(initialMessage);
      }

      // Handle background messages (must be top-level function)
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      AppLogger.success('✅ FCM message handlers set up successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to set up FCM message handlers', e);
      rethrow;
    }
  }

  /// Get current FCM token for this device
  static Future<String?> getToken() async {
    try {
      if (_currentToken != null) {
        return _currentToken;
      }

      _currentToken = await _messaging.getToken();

      if (_currentToken != null) {
        AppLogger.info(
            '🔔 FCM token retrieved: ${_currentToken!.substring(0, _currentToken!.length.clamp(0, 20))}...');
      } else {
        AppLogger.warning('⚠️ Failed to retrieve FCM token');
      }

      return _currentToken;
    } catch (e) {
      AppLogger.error('❌ Failed to get FCM token', e);
      return null;
    }
  }

  /// Refresh FCM token and update user profile
  static Future<void> _refreshToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _updateUserToken(token);
      }
    } catch (e) {
      AppLogger.error('❌ Failed to refresh FCM token', e);
    }
  }

  /// Handle FCM token refresh events
  static Future<void> _onTokenRefresh(String token) async {
    try {
      AppLogger.info(
          '🔔 FCM token refreshed: ${token.substring(0, token.length.clamp(0, 20))}...');
      _currentToken = token;
      await _updateUserToken(token);
    } catch (e) {
      AppLogger.error('❌ Failed to handle token refresh', e);
    }
  }

  static Future<void> _updateUserToken(String token) async {
    await _errorHandler.safeExecute(
      () async {
        AppLogger.info(
            'Updating user profile with FCM token: ${token.substring(0, token.length.clamp(0, 20))}...');

        final userService = ServiceLocator.get<UserService>();
        await userService.updateFCMToken(token);
      },
      operationName: 'FCMService: Update user token',
    );
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _errorHandler.safeExecute(
      () async {
        AppLogger.info('Subscribing to topic: $topic');
        await _messaging.subscribeToTopic(topic);
        AppLogger.success('Subscribed to topic: $topic');
      },
      operationName: 'FCMService: Subscribe to topic $topic',
    );
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _errorHandler.safeExecute(
      () async {
        AppLogger.info('Unsubscribing from topic: $topic');
        await _messaging.unsubscribeFromTopic(topic);
        AppLogger.success('Unsubscribed from topic: $topic');
      },
      operationName: 'FCMService: Unsubscribe from topic $topic',
    );
  }

  /// Get notification settings status
  static Future<NotificationSettings> getNotificationSettings() async {
    try {
      return await _messaging.getNotificationSettings();
    } catch (e) {
      AppLogger.error('❌ Failed to get notification settings', e);
      rethrow;
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      AppLogger.error('❌ Failed to check notification status', e);
      return false;
    }
  }

  /// Show local notification for foreground messages
  /// Note: This is a basic implementation - you might want to use flutter_local_notifications
  static void showForegroundNotification(RemoteMessage message) {
    // For now, just log the notification
    // In a production app, you'd use flutter_local_notifications or similar
    AppLogger.info(
        '🔔 Should show foreground notification: ${message.notification?.title}');
  }

  /// Navigate to appropriate screen based on notification data.
  /// Uses appNavigatorKey to avoid stale BuildContext crashes.
  static Future<void> handleNotificationNavigation(
      RemoteMessage message) async {
    try {
      final data = message.data;
      final notificationType = data['type'];
      final screen = data['screen'];

      AppLogger.info(
          '🔔 Handling notification navigation: type=$notificationType, screen=$screen');

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('⚠️ Cannot navigate - no navigator available');
        return;
      }

      switch (notificationType) {
        case NotificationPayloadType.friendRequest:
          navigator.pushNamed(Routes.friends, arguments: {'tab': 'requests'});
          break;
        case NotificationPayloadType.recipeShared:
          await _navigateToSharedRecipe(navigator, data);
          break;
        case NotificationPayloadType.collaborationInvite:
          await _navigateToCollaboration(navigator, data);
          break;
        case NotificationPayloadType.recipeComment:
          await _navigateToSharedRecipe(navigator, data,
              scrollToComments: true);
          break;
        default:
          AppLogger.warning(
              '⚠️ Unknown notification type for navigation: $notificationType');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle notification navigation', e);
    }
  }

  /// Handle local notification tap via appNavigatorKey.
  static void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // Delegate to onNotificationTapped if wired
    NotificationService.onNotificationTapped?.call(
      payload,
      <String, String?>{},
    );
  }

  /// Navigate to recipe detail, optionally with comments auto-expanded.
  static Future<void> _navigateToSharedRecipe(
      NavigatorState navigator, Map<String, dynamic> data,
      {bool scrollToComments = false}) async {
    final recipeId = data['recipeId'] as String?;
    if (recipeId == null) return;

    final recipeRepo = ServiceLocator.get<RecipeRepository>();
    final recipe = await recipeRepo.read(recipeId);
    if (recipe != null) {
      final arguments = scrollToComments
          ? <String, dynamic>{'recipe': recipe, 'scrollToComments': true}
          : recipe;
      navigator.pushNamed(Routes.receptDetalj, arguments: arguments);
    }
  }

  /// Navigate to collaboration screen
  static Future<void> _navigateToCollaboration(
      NavigatorState navigator, Map<String, dynamic> data) async {
    final resourceId = data['resourceId'] as String?;
    final resourceType = data['resourceType'] as String?;

    if (resourceId == null || resourceType == null) return;

    switch (resourceType) {
      case 'recipe':
        final recipeRepo = ServiceLocator.get<RecipeRepository>();
        final recipe = await recipeRepo.read(resourceId);
        if (recipe != null) {
          navigator.pushNamed(Routes.receptDetalj, arguments: recipe);
        }
        break;
      case 'menu':
        final menuRepo = ServiceLocator.get<FirebaseSharedMenuRepository>();
        final menu = await menuRepo.getSharedMenu(resourceId);
        if (menu != null) {
          navigator.pushNamed(Routes.menuPreview, arguments: menu);
        }
        break;
      case 'shopping_list':
        navigator.pushNamed(Routes.collaborativeShopping,
            arguments: resourceId);
        break;
      default:
        AppLogger.warning(
            '⚠️ Unknown collaboration resource type: $resourceType');
    }
  }

  /// Log detailed message information for debugging
  static void _logMessageDetails(RemoteMessage message) {
    if (kDebugMode) {
      AppLogger.debug('🔔 Message details: '
          'messageId=${message.messageId}, '
          'title=${message.notification?.title}, '
          'body=${message.notification?.body}, '
          'from=${message.from}, '
          'category=${message.category}');
    }
  }

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      AppLogger.info('🔔 Disposing FCM service...');

      // Cancel all subscriptions to prevent memory leaks
      await _tokenRefreshSubscription?.cancel();
      await _onMessageSubscription?.cancel();
      await _onMessageOpenedAppSubscription?.cancel();

      _tokenRefreshSubscription = null;
      _onMessageSubscription = null;
      _onMessageOpenedAppSubscription = null;

      _currentToken = null;
      _consentService?.onConsentChanged = null;
      _consentService = null;
      _pushPermissionsRequested = false;
      _isInitialized = false;
      _onMessageReceived = null;
      _onMessageOpenedApp = null;
      AppLogger.success('✅ FCM service disposed');
    } catch (e) {
      AppLogger.error('❌ Failed to dispose FCM service', e);
    }
  }
}

/// Top-level function for handling background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    AppLogger.info('🔔 Handling background message: ${message.messageId}');

    // Handle background message processing
    // This runs in an isolate, so has limited access to app state

    // Log message for debugging
    if (kDebugMode) {
      AppLogger.debug('🔔 Background message: '
          'title=${message.notification?.title}, '
          'body=${message.notification?.body}');
    }

    // Process background-specific logic here
    // E.g., update local database, sync data, etc.
  } catch (e) {
    AppLogger.error('❌ Failed to handle background message', e);
  }
}
