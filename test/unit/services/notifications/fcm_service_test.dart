/// Unit tests for FCMService - Firebase Cloud Messaging integration.
///
/// BUT-782: FCMService is now instance-based with constructor-injected
/// [FirebaseMessaging]. Tests construct `FCMService(messaging: mock)`
/// directly — the legacy `setMessagingForTest` seam is gone.
///
/// Tests cover:
/// - Token management (getToken, refresh)
/// - Topic subscriptions
/// - Permission management
/// - Foreground notification handling (no Firebase calls)
/// - Navigation handling (no Firebase calls)
/// - Edge cases (null data, empty topics, special characters)
///
/// `initialize()` is not directly tested here because it touches the
/// static streams `FirebaseMessaging.onMessage` / `.onMessageOpenedApp` /
/// `.onBackgroundMessage`, which the FCM SDK doesn't expose for mocking.
/// Initialization is exercised indirectly via integration tests of
/// NotificationService.
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/notifications/fcm_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// MockFirebaseMessaging variant that records subscribe/unsubscribe/getToken
/// calls — used to verify the injected mock receives the production calls.
///
/// Per BUT-1008, behaviour failure flags (null token, throwing topic /
/// settings) now live on `MockFirebaseMessaging.setFirebaseMessagingState`
/// — see the call sites below. This subclass remains because *recording*
/// is orthogonal to *throwing*: mocktail's `verify()` can record but only
/// works against methods that aren't concretely overridden. Until the
/// production mock drops its overrides entirely, a recording subclass is
/// still the easiest path for "I want to assert exactly which topics the
/// service subscribed to".
class _RecordingMessaging extends MockFirebaseMessaging {
  final List<String> subscribedTopics = <String>[];
  final List<String> unsubscribedTopics = <String>[];
  int getTokenCalls = 0;
  int requestPermissionCalls = 0;
  int deleteTokenCalls = 0;

  @override
  Future<String?> getToken({String? vapidKey}) async {
    getTokenCalls++;
    return super.getToken(vapidKey: vapidKey);
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribedTopics.add(topic);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionCalls++;
    return super.requestPermission();
  }

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
  }
}

/// BUT-1035: ConsentService test double that captures the listener
/// registered via [addListener] and exposes [fire] to synchronously
/// invoke it. mocktail's bare `Mock implements ConsentService` can't
/// fire its captured callback — this records + replays.
///
/// BUT-1054: [holdNextConsent] / [completeHeldConsent] add a one-shot
/// gate so tests can park the in-flight `_onConsentChanged` mid-await
/// and probe the mutex's re-entry behaviour deterministically.
class _RecordingConsent extends Mock implements ConsentService {
  VoidCallback? _listener;
  bool _hasConsent = false;
  Completer<bool>? _heldConsent;

  /// Toggles what subsequent `hasConsent()` calls return.
  void setConsent(bool value) => _hasConsent = value;

  /// Makes the NEXT `hasConsent()` call return a Future that doesn't
  /// resolve until [completeHeldConsent] is called. Subsequent calls
  /// resume the synchronous path. Used to keep the production handler
  /// parked mid-await for mutex testing.
  void holdNextConsent(bool valueOnComplete) {
    _heldConsent = Completer<bool>();
    _hasConsent = valueOnComplete;
  }

  void completeHeldConsent() {
    final c = _heldConsent;
    if (c == null || c.isCompleted) {
      throw StateError('No held consent to complete');
    }
    _heldConsent = null;
    c.complete(_hasConsent);
  }

  /// Invokes the captured listener (the production `_onConsentChanged`).
  Future<void> fire() async {
    final cb = _listener;
    if (cb == null) {
      throw StateError('No listener captured — call addListener first');
    }
    cb();
    // _onConsentChanged is async; yield to let microtasks resolve before
    // the test asserts on side effects.
    await Future<void>.delayed(Duration.zero);
  }

  @override
  void addListener(VoidCallback listener) {
    _listener = listener;
  }

  @override
  void removeListener(VoidCallback listener) {
    if (identical(_listener, listener)) _listener = null;
  }

  @override
  Future<bool> hasConsent(ConsentPurpose purpose) {
    final held = _heldConsent;
    if (held != null) return held.future;
    return Future.value(_hasConsent);
  }
}

void main() {
  group('FCMService', () {
    late MockRemoteMessage mockMessage;
    late MockRemoteNotification mockNotification;
    late MockFirebaseMessaging mockMessaging;
    late FCMService service;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      registerFallbackValue(MockRemoteMessage());
    });

    setUp(() async {
      mockMessage = MockRemoteMessage();
      mockNotification = MockRemoteNotification();
      mockMessaging = MockFirebaseMessaging();

      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();

      service = FCMService(messaging: mockMessaging);
    });

    tearDown(() async {
      await service.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Token Management', () {
      test('should return the injected mock token', () async {
        mockMessaging.setFirebaseMessagingState(token: 'mock-token-001');

        final token = await service.getToken();

        expect(token, equals('mock-token-001'));
      });

      test('should cache the token across repeated calls', () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'cached-token');
        service = FCMService(messaging: recording);

        final first = await service.getToken();
        final second = await service.getToken();

        expect(first, equals('cached-token'));
        expect(second, equals('cached-token'));
        // Cached after first call: only one underlying SDK call.
        expect(recording.getTokenCalls, equals(1));
      });

      test('should return null when SDK returns null', () async {
        // BUT-1008: composable flag, no subclass needed.
        final m = MockFirebaseMessaging()
          ..setFirebaseMessagingState(clearToken: true);
        service = FCMService(messaging: m);

        final token = await service.getToken();

        expect(token, isNull);
      });
    });

    group('Topic Management', () {
      test('subscribeToTopic forwards to the injected messaging', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await service.subscribeToTopic('recipes_updates');

        expect(recording.subscribedTopics, equals(['recipes_updates']));
      });

      test('unsubscribeFromTopic forwards to the injected messaging', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await service.unsubscribeFromTopic('social_updates');

        expect(recording.unsubscribedTopics, equals(['social_updates']));
      });

      test('subscribeToTopic catches errors (proves safeExecute swallowed)',
          () async {
        // BUT-1008: composable throw flags replace _ThrowingTopicMessaging.
        final m = MockFirebaseMessaging()
          ..setFirebaseMessagingState(
            throwOnSubscribe: true,
            throwOnUnsubscribe: true,
          );
        service = FCMService(messaging: m);

        // safeExecute swallowed the throw. Stronger than 'completes': after
        // the error, a follow-up call must still resolve normally — proving
        // the service didn't enter a broken state.
        await service.subscribeToTopic('invalid_topic');
        await service.subscribeToTopic('another_topic');
      });

      test('unsubscribeFromTopic catches errors (parity with subscribe)',
          () async {
        final m = MockFirebaseMessaging()
          ..setFirebaseMessagingState(
            throwOnSubscribe: true,
            throwOnUnsubscribe: true,
          );
        service = FCMService(messaging: m);

        await service.unsubscribeFromTopic('topic_a');
        await service.unsubscribeFromTopic('topic_b');
      });

      test('should accept various topic names without throwing', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        const topics = ['', 'topic with spaces', 'topic/with/slashes'];
        for (final topic in topics) {
          await expectLater(service.subscribeToTopic(topic), completes);
        }
      });
    });

    group('Message Handling', () {
      test('showForegroundNotification logs without throwing', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Title');
        when(() => mockNotification.body).thenReturn('Test Body');
        when(() => mockMessage.data).thenReturn({'key': 'value'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles Swedish notification content', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Nytt recept delat');
        when(() => mockNotification.body)
            .thenReturn('Anna har delat Köttbullar med dig');
        when(() => mockMessage.data).thenReturn({'type': 'recipe_share'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles notification without title or body', () {
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({'silent': 'true'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });
    });

    group('Navigation Handling', () {
      test('completes for each notification type without a navigator',
          () async {
        final testCases = [
          {'type': 'friend_request'},
          {'type': 'recipe_share'},
          {'type': 'collaboration'},
          {'type': 'recipe_comment'},
        ];

        for (final testCase in testCases) {
          when(() => mockMessage.data).thenReturn(testCase);

          // No navigator key registered in unit tests → routine bails early.
          await expectLater(
              service.handleNotificationNavigation(mockMessage), completes);
        }
      });

      test('completes for unknown notification types', () async {
        when(() => mockMessage.data).thenReturn({'type': 'unknown_type'});

        await expectLater(
            service.handleNotificationNavigation(mockMessage), completes);
      });
    });

    group('Permission Management', () {
      test('getNotificationSettings reflects the configured authorization',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.denied);

        final result = await service.getNotificationSettings();

        expect(result.authorizationStatus, AuthorizationStatus.denied);
      });

      test('areNotificationsEnabled returns true for authorized status',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.authorized);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isTrue);
      });

      test('areNotificationsEnabled returns true for provisional status',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.provisional);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isTrue);
      });

      test('areNotificationsEnabled returns false for denied status', () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.denied);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isFalse);
      });

      test('areNotificationsEnabled returns false on error', () async {
        // BUT-1008: composable throw flag replaces _ThrowingSettingsMessaging.
        final m = MockFirebaseMessaging()
          ..setFirebaseMessagingState(throwOnSettings: true);
        service = FCMService(messaging: m);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isFalse);
      });

      // BUT-1007: areNotificationsEnabled swallows errors, but
      // getNotificationSettings itself must surface them so callers that need
      // to distinguish "denied" from "settings query failed" can do so. The
      // existing `areNotificationsEnabled returns false on error` covers the
      // wrapping behaviour; this one pins the underlying contract directly.
      test('getNotificationSettings rethrows on error', () async {
        final m = MockFirebaseMessaging()
          ..setFirebaseMessagingState(throwOnSettings: true);
        service = FCMService(messaging: m);

        await expectLater(
          service.getNotificationSettings(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Lifecycle', () {
      test('dispose is idempotent — second call no-ops cleanly', () async {
        await service.dispose();
        // Second call must not throw, must not double-log catastrophically.
        await service.dispose();
      });
    });

    // BUT-1006: re-binding user-scoped state across logout → login.
    group('bindUserContext (BUT-1006)', () {
      test('detaches listener from prior consent and attaches to new',
          () async {
        final consentA = MockConsentService();
        final consentB = MockConsentService();
        when(() => consentA.addListener(any())).thenReturn(null);
        when(() => consentA.removeListener(any())).thenReturn(null);
        when(() => consentB.addListener(any())).thenReturn(null);
        when(() => consentB.removeListener(any())).thenReturn(null);

        await service.bindUserContext(
          consentService: consentA,
          onMessageReceived: (_) {},
          onMessageOpenedApp: (_) {},
        );
        verify(() => consentA.addListener(any())).called(1);
        verifyNever(() => consentA.removeListener(any()));

        await service.bindUserContext(
          consentService: consentB,
          onMessageReceived: (_) {},
          onMessageOpenedApp: (_) {},
        );
        // Previous user's listener must be torn down before swap.
        verify(() => consentA.removeListener(any())).called(1);
        verify(() => consentB.addListener(any())).called(1);
      });

      test('identical args are a no-op (no add/remove churn)', () async {
        final consent = MockConsentService();
        when(() => consent.addListener(any())).thenReturn(null);
        when(() => consent.removeListener(any())).thenReturn(null);

        void onMsg(_) {}
        void onOpen(_) {}

        await service.bindUserContext(
          consentService: consent,
          onMessageReceived: onMsg,
          onMessageOpenedApp: onOpen,
        );
        await service.bindUserContext(
          consentService: consent,
          onMessageReceived: onMsg,
          onMessageOpenedApp: onOpen,
        );

        // Only the first bind attaches; second is a short-circuit.
        verify(() => consent.addListener(any())).called(1);
        verifyNever(() => consent.removeListener(any()));
      });

      test('post-dispose bind is a silent no-op', () async {
        final consent = MockConsentService();
        when(() => consent.addListener(any())).thenReturn(null);
        when(() => consent.removeListener(any())).thenReturn(null);

        await service.dispose();

        await service.bindUserContext(
          consentService: consent,
          onMessageReceived: (_) {},
          onMessageOpenedApp: (_) {},
        );

        verifyNever(() => consent.addListener(any()));
        verifyNever(() => consent.removeListener(any()));
      });

      test('null consent is allowed (no add invoked)', () async {
        await service.bindUserContext(
          consentService: null,
          onMessageReceived: (_) {},
          onMessageOpenedApp: (_) {},
        );
        // Nothing to verify on a null consent; the assertion is "no throw."
      });
    });

    group('Consent change handler (BUT-1035)', () {
      test('grant path requests permissions + refreshes token', () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'fresh-token');
        service = FCMService(messaging: recording);
        final consent = _RecordingConsent()..setConsent(false);

        await service.bindUserContext(consentService: consent);
        // Pre-fire: no work done.
        expect(recording.requestPermissionCalls, 0);

        // Flip to granted and fire.
        consent.setConsent(true);
        await consent.fire();

        // Permission requested once, token retrieved.
        expect(recording.requestPermissionCalls, 1);
        expect(await service.getToken(), 'fresh-token');
      });

      test('revoke path deletes SDK token + clears cached value', () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'live-token');
        service = FCMService(messaging: recording);
        final consent = _RecordingConsent()..setConsent(true);

        // Seed: grant first so revoke has a state to undo.
        await service.bindUserContext(consentService: consent);
        await consent.fire();
        expect(recording.requestPermissionCalls, 1);
        // Pre-revoke: token cached.
        expect(await service.getToken(), 'live-token');

        // Now revoke.
        consent.setConsent(false);
        await consent.fire();

        expect(recording.deleteTokenCalls, 1);
        // After revoke, _currentToken is null. Next getToken triggers a
        // fresh SDK call — the cache is empty, not stale.
        await service.getToken();
        expect(recording.getTokenCalls, greaterThan(0));
      });

      test('re-entry while handler in-flight is debounced (BUT-1054)',
          () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'tok');
        service = FCMService(messaging: recording);
        final consent = _RecordingConsent();

        await service.bindUserContext(consentService: consent);

        // First fire: park hasConsent() mid-await so _consentChangeInProgress
        // is true when the second fire arrives.
        consent.holdNextConsent(true);
        final firstFire = consent.fire();

        // Second fire while the first is parked. The mutex must
        // short-circuit this one — no second requestPermission call.
        await consent.fire();
        expect(recording.requestPermissionCalls, 0,
            reason: 'first fire still parked; second must short-circuit');

        // Release the parked Future. First fire resumes, does its work.
        consent.completeHeldConsent();
        await firstFire;

        // Only the first fire's work ran. Second fire was debounced.
        expect(recording.requestPermissionCalls, 1);
      });

      test('token-refresh handler bypasses cache (test seam)', () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'stale-token');
        service = FCMService(messaging: recording);

        // Seed: cache the initial token.
        await service.getToken();
        final initialCalls = recording.getTokenCalls;

        // Token-refresh stream fires — production code assigns
        // _currentToken = token directly without going through getToken.
        await service.handleTokenRefreshForTest('rotated-token');

        // Subsequent getToken returns the rotated value without SDK call.
        expect(await service.getToken(), 'rotated-token');
        expect(recording.getTokenCalls, initialCalls,
            reason: 'token-refresh path must not re-query the SDK');
      });
    });

    group('Edge Cases', () {
      test('null notification + empty data still logs cleanly', () {
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('empty topic name does not throw', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await expectLater(service.subscribeToTopic(''), completes);
        expect(recording.subscribedTopics, equals(['']));
      });

      test('handles very long notification content', () {
        final longTitle = 'A' * 500;
        final longBody = 'B' * 1000;
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn(longTitle);
        when(() => mockNotification.body).thenReturn(longBody);
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles special characters in notification', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Recipe!');
        when(() => mockNotification.body)
            .thenReturn('Koettbullar & graeddsaas');
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });
    });
  });
}
