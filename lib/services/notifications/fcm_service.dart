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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/services/notifications/fcm_service/fcm_platform_setup.dart';
import 'package:butlery/services/notifications/fcm_service/notification_navigator.dart';
import 'package:butlery/services/notifications/fcm_service/push_access_revoker.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

class FCMService extends BaseService {
  FCMService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    required OwnProfileEditor? Function() getUserService,
    required RecipeRepository Function() getRecipeRepository,
    required FirebaseSharedMenuRepository Function() getSharedMenuRepository,
    required UnifiedRecipeService Function() getRecipeService,
    required PermissionService Function() getPermissionService,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _getUserService = getUserService,
       _getRecipeRepository = getRecipeRepository,
       _getSharedMenuRepository = getSharedMenuRepository,
       _getRecipeService = getRecipeService,
       _getPermissionService = getPermissionService;

  @override
  String get serviceName => 'FCMService';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  // Lookups, not instances: the user-scoped services change with the signed-in
  // user and UserService may not be registered yet when a consent change fires.
  final OwnProfileEditor? Function() _getUserService;
  final RecipeRepository Function() _getRecipeRepository;
  final FirebaseSharedMenuRepository Function() _getSharedMenuRepository;
  final UnifiedRecipeService Function() _getRecipeService;
  final PermissionService Function() _getPermissionService;

  String? _currentToken;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _pushPermissionsRequested = false;
  ConsentService? _consentService;
  late final NotificationNavigator _navigation = NotificationNavigator(
    getRecipeRepository: _getRecipeRepository,
    getSharedMenuRepository: _getSharedMenuRepository,
    getRecipeService: _getRecipeService,
    getPermissionService: _getPermissionService,
  );

  Function(RemoteMessage)? _onMessageReceived;
  Function(RemoteMessage)? _onMessageOpenedApp;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  bool _consentChangeInProgress = false;

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

    await safeExecute(
      () async {
        AppLogger.info('Initializing FCM service...');

        _onMessageReceived = onMessageReceived;
        _onMessageOpenedApp = onMessageOpenedApp;
        _consentService = consentService;

        // Listen for mid-session consent changes (BUT-356). BUT-752:
        // ConsentService implements Listenable so multiple subscribers
        // co-exist.
        _consentService?.addListener(_onConsentChanged);

        await FcmPlatformSetup.initializeAndroidChannels(
          _localNotifications,
          onTapped: _onLocalNotificationTapped,
        );
        await _setupMessageHandlers();

        final hasConsent = await _hasPushConsent();
        if (hasConsent) {
          await FcmPlatformSetup.requestPermissions(_messaging);
          await _refreshToken();
          _pushPermissionsRequested = true;
        } else {
          AppLogger.info(
            '🔔 FCM: Skipping permission request — pushNotifications consent not granted',
          );
        }

        // Cloud Functions send by FCM token; the FID API (register/onRegistered)
        // needs the server send path moved first (BUT-2508).
        // ignore: deprecated_member_use
        _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
          _onTokenRefresh,
        );

        _isInitialized = true;
        AppLogger.success('FCM service initialized successfully');
      },
      operationName: 'FCMService: Initialize',
    );

    // safeExecute returns null for a void operation even when it succeeds,
    // so success is read from the flag the operation sets last.
    if (!_isInitialized) {
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
        await FcmPlatformSetup.requestPermissions(_messaging);
        await _refreshToken();
        _pushPermissionsRequested = true;
      } else if (!hasConsent && _pushPermissionsRequested) {
        AppLogger.info(
          '🔔 FCM: Push consent revoked mid-session — clearing token (BUT-573)',
        );
        await PushAccessRevoker.revoke(
          messaging: _messaging,
          getUserService: _getUserService,
        );
        _currentToken = null;
        _pushPermissionsRequested = false;
      }
    } catch (e) {
      AppLogger.error('❌ FCM: Failed to handle consent change', e);
    } finally {
      _consentChangeInProgress = false;
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        AppLogger.info('🔔 Received foreground message: ${message.messageId}');
        FcmPlatformSetup.logMessageDetails(message);
        _onMessageReceived?.call(message);
      });

      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen((RemoteMessage message) {
            AppLogger.info(
              '🔔 App opened from notification: ${message.messageId}',
            );
            FcmPlatformSetup.logMessageDetails(message);
            _onMessageOpenedApp?.call(message);
          });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info(
          '🔔 App launched from notification: ${initialMessage.messageId}',
        );
        FcmPlatformSetup.logMessageDetails(initialMessage);
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

      // ignore: deprecated_member_use
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
      // Revoking consent deletes the token, and FCM then mints a new one.
      if (!await _hasPushConsent()) return;
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

        final userService = _getUserService();
        if (userService == null) {
          throw StateError('UserService is not registered');
        }
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
  Future<void> handleNotificationNavigation(RemoteMessage message) =>
      _navigation.handle(message);

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    NotificationService.onNotificationTapped?.call(
      payload,
      <String, String?>{},
    );
  }

  /// BUT-1744: the sender stores no placeholder, so the fallback is resolved
  /// here, in the recipient's own language.
  @visibleForTesting
  static String shareRequestSenderName(Map<String, dynamic> data) =>
      NotificationNavigator.shareRequestSenderName(data);

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
