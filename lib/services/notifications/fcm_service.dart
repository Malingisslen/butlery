/// Firebase Cloud Messaging service providing push notification functionality
/// with deep linking. Instance-based, extends [BaseService] (BUT-782).
///
/// **Architecture:**
/// - Constructor-injected [FirebaseMessaging] + [FlutterLocalNotificationsPlugin]
///   — production code passes nothing (defaults to platform instances), tests
///   pass mocks.
/// - Permission requests and token registration are gated behind the
///   `pushNotifications` consent purpose (GDPR Art. 6.1.a). [ConsentService]
///   is user-scoped, so it's passed via [initialize] rather than the
///   constructor (FCMService itself is app-scoped).
/// - Subscriptions are cancelled in [onDispose] per [BaseService] contract.
///
/// **Companion:** `NotificationService` coordinates the higher-level
/// notification flow; `FCMTokenManager` (per-user) owns the SecureStorage
/// cache. The split keeps app-singleton lifecycle (this class) separate from
/// per-user lifecycle (token manager).

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
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
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

class FCMService extends BaseService {
  FCMService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  @override
  String get serviceName => 'FCMService';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  String? _currentToken;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _pushPermissionsRequested = false;
  ConsentService? _consentService;

  Function(RemoteMessage)? _onMessageReceived;
  Function(RemoteMessage)? _onMessageOpenedApp;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  bool _consentChangeInProgress = false;

  static const String _generalChannelId = 'butlery_general';
  static const String _socialChannelId = 'butlery_social';
  static const String _messagingChannelId = 'butlery_messaging';

  /// Initialize FCM. Permission requests + token registration are gated
  /// behind `pushNotifications` consent via [consentService].
  ///
  /// Callbacks and consent are per-init parameters (not constructor params)
  /// because they originate from the user-scoped [NotificationService] while
  /// this service is app-scoped.
  ///
  /// Shadows [BaseService.initialize] (which is parameterless) because FCM
  /// init needs callbacks; [BaseService]'s standard lifecycle is bypassed
  /// — we use [safeExecute] for error handling and [onDispose] for cleanup,
  /// which is what extending [BaseService] is actually for.
  @override
  Future<void> initialize({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    ConsentService? consentService,
  }) async {
    if (_isInitialized) {
      AppLogger.warning('FCMService already initialized, skipping...');
      return;
    }

    final result = await safeExecute(
      () async {
        AppLogger.info('Initializing FCM service...');

        _onMessageReceived = onMessageReceived;
        _onMessageOpenedApp = onMessageOpenedApp;
        _consentService = consentService;

        // Listen for mid-session consent changes (BUT-356). BUT-752:
        // ConsentService implements Listenable so multiple subscribers
        // (this + SearchModule for Algolia re-init) co-exist.
        _consentService?.addListener(_onConsentChanged);

        await _initializeNotificationChannels();
        await _setupMessageHandlers();

        final hasConsent = await _hasPushConsent();
        if (hasConsent) {
          await _requestPermissions();
          await _refreshToken();
          _pushPermissionsRequested = true;
        } else {
          AppLogger.info(
            '🔔 FCM: Skipping permission request — pushNotifications consent not granted',
          );
        }

        _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
          _onTokenRefresh,
        );

        _isInitialized = true;
        AppLogger.success('FCM service initialized successfully');
      },
      operationName: 'FCMService: Initialize',
    );

    if (result == null) {
      throw Exception('Failed to initialize FCM service');
    }
  }

  /// BUT-1006: re-bind user-scoped state (consent listener, foreground
  /// callbacks, permission-request gate) without re-running the
  /// channel/message-handler setup that [initialize] does.
  ///
  /// Called by [NotificationService.onInitialize] on every user push —
  /// the `_isInitialized` early-return in [initialize] would otherwise
  /// leave the FCM service pointing at the previous user's disposed
  /// `ConsentService` and `_handleForegroundMessage` closure (which
  /// captures the prior user's `_userId`), causing:
  /// * mid-session consent revoke to silently no-op for user B
  /// * foreground push analytics to log under user A's `_userId`
  /// * `StateError: No authenticated user` from
  ///   `notification_service.dart` if user A's closure runs after logout
  ///
  /// Safe to call before [initialize] — the listener add becomes a
  /// no-op when [consentService] is null, and the callbacks just stay
  /// null until set by a real bind. Safe to call after [onDispose] too —
  /// `_isDisposed` short-circuits the work.
  Future<void> bindUserContext({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    ConsentService? consentService,
  }) async {
    if (_isDisposed) return;

    // Short-circuit when nothing actually changed (re-entering an already-
    // bound user's session). `identical()` is correct for the ConsentService
    // (per-user instance). For the callbacks, the current call sites pass
    // method tear-offs (`_handleForegroundMessage`) which Dart guarantees
    // equal across re-evaluations; if a future caller switches to an inline
    // closure (`(m) => _handleForegroundMessage(m)`) this short-circuit
    // silently stops firing — that's a correctness-neutral perf cost (we
    // re-bind the same handler), not a bug.
    final sameConsent = identical(_consentService, consentService);
    final sameOnMessage = _onMessageReceived == onMessageReceived;
    final sameOnOpened = _onMessageOpenedApp == onMessageOpenedApp;
    if (sameConsent && sameOnMessage && sameOnOpened) return;

    // Detach the prior user's listener before swapping — failing to do this
    // would leave user A's ConsentService holding `_onConsentChanged` after
    // its `dispose()`, leaking a callback into a teardown phase.
    if (!sameConsent) {
      _consentService?.removeListener(_onConsentChanged);
      _consentService = consentService;
      _consentService?.addListener(_onConsentChanged);
    }

    _onMessageReceived = onMessageReceived;
    _onMessageOpenedApp = onMessageOpenedApp;

    // Reset the permission-request gate so user B's first consent grant
    // triggers a fresh `requestPermission()` instead of being short-circuited
    // by user A's prior request.
    _pushPermissionsRequested = false;

    AppLogger.info(
      '🔔 FCM: bindUserContext — consentService=${consentService != null}, '
      'onMessage=${onMessageReceived != null}, '
      'onOpened=${onMessageOpenedApp != null}',
    );
  }

  /// Fails closed — if consent cannot be determined, deny by default.
  Future<bool> _hasPushConsent() async {
    return ConsentService.checkSafely(
      _consentService,
      ConsentPurpose.pushNotifications,
      logTag: 'FCMService',
    );
  }

  /// BUT-356, BUT-573 — handle grant *and* revoke mid-session.
  Future<void> _onConsentChanged() async {
    if (_consentChangeInProgress) return;
    _consentChangeInProgress = true;
    try {
      final hasConsent = await _hasPushConsent();
      if (hasConsent && !_pushPermissionsRequested) {
        AppLogger.info(
          '🔔 FCM: Push consent granted mid-session — requesting permissions',
        );
        await _requestPermissions();
        await _refreshToken();
        _pushPermissionsRequested = true;
      } else if (!hasConsent && _pushPermissionsRequested) {
        AppLogger.info(
          '🔔 FCM: Push consent revoked mid-session — clearing token (BUT-573)',
        );
        await _revokePushAccess();
        _pushPermissionsRequested = false;
      }
    } catch (e) {
      AppLogger.error('❌ FCM: Failed to handle consent change', e);
    } finally {
      _consentChangeInProgress = false;
    }
  }

  /// Delete FCM token from SDK + Firestore + memory after consent revoke
  /// (BUT-573). Best-effort: each cleanup is independent so partial success
  /// beats total failure. SDK + Firestore deletes run in parallel — they
  /// don't depend on each other.
  ///
  /// Companion: NotificationService.`_handleConsentChange` →
  /// FCMTokenManager.`clearLocalToken()` covers the per-user SecureStorage
  /// cache (BUT-754). The split is intentional: FCMService is app-singleton
  /// (SDK + Firestore + memory); FCMTokenManager is per-user (SecureStorage +
  /// instance memory). Each half owns its own lifecycle scope.
  Future<void> _revokePushAccess() async {
    final hasUserService = ServiceLocator.isRegistered<UserService>();

    await Future.wait<void>([
      _messaging.deleteToken().catchError((e) {
        AppLogger.warning('⚠️ FCM: Failed to delete SDK token: $e');
      }),
      if (hasUserService)
        ServiceLocator.get<UserService>().clearFCMToken().catchError((e) {
          AppLogger.warning('⚠️ FCM: Failed to clear profile token: $e');
        }),
    ]);

    if (!hasUserService) {
      AppLogger.info(
        '🔔 FCM: UserService not registered — skipping profile-token clear',
      );
    }

    _currentToken = null;
  }

  Future<void> _initializeNotificationChannels() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      AppLogger.info('🔔 Initializing Android notification channels...');

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

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(generalChannel);
        await androidPlugin.createNotificationChannel(socialChannel);
        await androidPlugin.createNotificationChannel(messagingChannel);
        AppLogger.success('✅ Android notification channels created');
      }

      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to initialize notification channels: $e');
      // Non-critical — FCM still works with default channel
    }
  }

  Future<NotificationSettings> _requestPermissions() async {
    try {
      AppLogger.info('🔔 Requesting notification permissions...');

      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.info(
        '🔔 Notification permission status: ${settings.authorizationStatus}',
      );

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

  Future<void> _setupMessageHandlers() async {
    try {
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        AppLogger.info('🔔 Received foreground message: ${message.messageId}');
        _logMessageDetails(message);
        _onMessageReceived?.call(message);
      });

      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen((RemoteMessage message) {
            AppLogger.info(
              '🔔 App opened from notification: ${message.messageId}',
            );
            _logMessageDetails(message);
            _onMessageOpenedApp?.call(message);
          });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info(
          '🔔 App launched from notification: ${initialMessage.messageId}',
        );
        _logMessageDetails(initialMessage);
        _onMessageOpenedApp?.call(initialMessage);
      }

      // Background handler must be top-level (Firebase isolate requirement).
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      AppLogger.success('✅ FCM message handlers set up successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to set up FCM message handlers', e);
      rethrow;
    }
  }

  Future<String?> getToken() async {
    try {
      if (_currentToken != null) {
        return _currentToken;
      }

      _currentToken = await _messaging.getToken();

      if (_currentToken != null) {
        AppLogger.info(
          '🔔 FCM token retrieved: ${_currentToken!.substring(0, _currentToken!.length.clamp(0, 20))}...',
        );
      } else {
        AppLogger.warning('⚠️ Failed to retrieve FCM token');
      }

      return _currentToken;
    } catch (e) {
      AppLogger.error('❌ Failed to get FCM token', e);
      return null;
    }
  }

  Future<void> _refreshToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _updateUserToken(token);
      }
    } catch (e) {
      AppLogger.error('❌ Failed to refresh FCM token', e);
    }
  }

  /// BUT-1035 test seam: exercises the token-refresh-stream handler
  /// without running [initialize] (which touches static FirebaseMessaging
  /// streams that the SDK doesn't expose for mocking).
  @visibleForTesting
  Future<void> handleTokenRefreshForTest(String token) =>
      _onTokenRefresh(token);

  Future<void> _onTokenRefresh(String token) async {
    try {
      AppLogger.info(
        '🔔 FCM token refreshed: ${token.substring(0, token.length.clamp(0, 20))}...',
      );
      _currentToken = token;
      await _updateUserToken(token);
    } catch (e) {
      AppLogger.error('❌ Failed to handle token refresh', e);
    }
  }

  Future<void> _updateUserToken(String token) async {
    await safeExecute(
      () async {
        AppLogger.info(
          'Updating user profile with FCM token: ${token.substring(0, token.length.clamp(0, 20))}...',
        );

        final userService = ServiceLocator.get<UserService>();
        await userService.updateFCMToken(token);
      },
      operationName: 'FCMService: Update user token',
    );
  }

  Future<void> subscribeToTopic(String topic) async {
    await safeExecute(
      () async {
        AppLogger.info('Subscribing to topic: $topic');
        await _messaging.subscribeToTopic(topic);
        AppLogger.success('Subscribed to topic: $topic');
      },
      operationName: 'FCMService: Subscribe to topic $topic',
    );
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await safeExecute(
      () async {
        AppLogger.info('Unsubscribing from topic: $topic');
        await _messaging.unsubscribeFromTopic(topic);
        AppLogger.success('Unsubscribed from topic: $topic');
      },
      operationName: 'FCMService: Unsubscribe from topic $topic',
    );
  }

  Future<NotificationSettings> getNotificationSettings() async {
    try {
      return await _messaging.getNotificationSettings();
    } catch (e) {
      AppLogger.error('❌ Failed to get notification settings', e);
      rethrow;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      AppLogger.error('❌ Failed to check notification status', e);
      return false;
    }
  }

  void showForegroundNotification(RemoteMessage message) {
    AppLogger.info(
      '🔔 Should show foreground notification: ${message.notification?.title}',
    );
  }

  /// Uses [appNavigatorKey] to avoid stale BuildContext crashes.
  Future<void> handleNotificationNavigation(RemoteMessage message) async {
    try {
      final data = message.data;
      final notificationType = data['type'];
      final screen = data['screen'];

      AppLogger.info(
        '🔔 Handling notification navigation: type=$notificationType, screen=$screen',
      );

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
          await _navigateToSharedRecipe(
            navigator,
            data,
            scrollToComments: true,
          );
          break;
        case NotificationPayloadType.recipeShareRequest:
          await _navigateToOwnRecipeForShareRequest(navigator, data);
          break;
        default:
          AppLogger.warning(
            '⚠️ Unknown notification type for navigation: $notificationType',
          );
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle notification navigation', e);
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    NotificationService.onNotificationTapped?.call(
      payload,
      <String, String?>{},
    );
  }

  Future<void> _navigateToSharedRecipe(
    NavigatorState navigator,
    Map<String, dynamic> data, {
    bool scrollToComments = false,
  }) async {
    final recipeId = data['recipeId'] as String?;
    if (recipeId == null) return;

    final recipeRepo = ServiceLocator.get<RecipeRepository>();
    final recipe = await recipeRepo.read(recipeId);
    if (recipe != null) {
      final arguments = scrollToComments
          ? <String, dynamic>{'recipe': recipe, 'scrollToComments': true}
          : recipe;
      navigator.pushNamed(Routes.recipeDetail, arguments: arguments);
    }
  }

  /// Opens the owner's own recipe with a one-tap share-back banner.
  /// Tapped when the owner receives a "X wants your recipe" push notification.
  Future<void> _navigateToOwnRecipeForShareRequest(
    NavigatorState navigator,
    Map<String, dynamic> data,
  ) async {
    final recipeId = data['recipeId'] as String?;
    final requestId = data['requestId'] as String?;
    if (recipeId == null || requestId == null) return;

    final fromUserId = data['fromUserId'] as String?;
    if (fromUserId == null || fromUserId.isEmpty) return;
    final fromUserName = data['fromUserName'] as String?;

    final recipe = ServiceLocator.get<UnifiedRecipeService>().getRecipeById(
      recipeId,
    );
    if (recipe == null) return;

    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;

    final request = SocialRequest(
      id: requestId,
      type: SocialRequestType.recipeShareRequest,
      fromUserId: fromUserId.orEmpty(),
      toUserId: currentUserId.orEmpty(),
      recipeId: recipeId,
      fromUserName: fromUserName,
    );

    navigator.pushNamed(
      Routes.recipeDetail,
      arguments: <String, dynamic>{'recipe': recipe, 'shareRequest': request},
    );
  }

  Future<void> _navigateToCollaboration(
    NavigatorState navigator,
    Map<String, dynamic> data,
  ) async {
    final resourceId = data['resourceId'] as String?;
    final resourceType = data['resourceType'] as String?;

    if (resourceId == null || resourceType == null) return;

    switch (resourceType) {
      case 'recipe':
        final recipeRepo = ServiceLocator.get<RecipeRepository>();
        final recipe = await recipeRepo.read(resourceId);
        if (recipe != null) {
          navigator.pushNamed(Routes.recipeDetail, arguments: recipe);
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
        navigator.pushNamed(
          Routes.collaborativeShopping,
          arguments: resourceId,
        );
        break;
      default:
        AppLogger.warning(
          '⚠️ Unknown collaboration resource type: $resourceType',
        );
    }
  }

  void _logMessageDetails(RemoteMessage message) {
    if (kDebugMode) {
      AppLogger.debug(
        '🔔 Message details: '
        'messageId=${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'from=${message.from}, '
        'category=${message.category}',
      );
    }
  }

  @override
  Future<void> onDispose() async {
    // Idempotent — guards against container + manual dispose double-fire.
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    try {
      AppLogger.info('🔔 Disposing FCM service...');

      await _tokenRefreshSubscription?.cancel();
      await _onMessageSubscription?.cancel();
      await _onMessageOpenedAppSubscription?.cancel();

      _tokenRefreshSubscription = null;
      _onMessageSubscription = null;
      _onMessageOpenedAppSubscription = null;

      _currentToken = null;
      _consentService?.removeListener(_onConsentChanged);
      _consentService = null;
      _pushPermissionsRequested = false;
      _isInitialized = false;
      _onMessageReceived = null;
      _onMessageOpenedApp = null;
    } catch (e) {
      AppLogger.error('❌ Failed to dispose FCM service', e);
    }
  }
}

/// Top-level background handler. Firebase SDK requires this to be a top-level
/// function (or static method) annotated `@pragma('vm:entry-point')` because
/// it runs in a background isolate without app context.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    AppLogger.info('🔔 Handling background message: ${message.messageId}');

    if (kDebugMode) {
      AppLogger.debug(
        '🔔 Background message: '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}',
      );
    }
  } catch (e) {
    AppLogger.error('❌ Failed to handle background message', e);
  }
}
