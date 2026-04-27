/// Unit tests for [NotificationDeepLinkRouter] (BUT-641).
///
/// Verifies that each known route maps to the expected navigator action,
/// and that missing/unknown routes default to home + log analytics so push
/// CTR can be measured even on edge cases.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/notifications/notification_deep_link_router.dart';

class _FakeAnalyticsRepository extends Fake implements AnalyticsRepository {
  final List<_LoggedEvent> events = <_LoggedEvent>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_LoggedEvent(name, parameters));
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

class _LoggedEvent {
  _LoggedEvent(this.name, this.parameters);
  final String name;
  final Map<String, Object>? parameters;
}

/// Recording NavigatorState that captures the routes pushed by the router.
/// We override only the methods the router actually calls — letting the
/// rest fall through to the real implementation would require a fully
/// constructed widget tree, which is overkill for a routing-table test.
///
/// `Mock` (rather than `Fake`) is used because `NavigatorState` mixes in
/// `Diagnosticable` whose `toString({DiagnosticLevel minLevel})` signature
/// is incompatible with `Fake`'s noSuchMethod-backed default — a
/// compile-time error mocktail's Mock doesn't trigger.
class _RecordingNavigator extends Mock implements NavigatorState {
  final List<_NavCall> calls = <_NavCall>[];

  // NavigatorState mixes in Diagnosticable, whose toString takes a named
  // `minLevel` argument. Mock's default 0-arg toString doesn't satisfy
  // that interface — declare a matching override here.
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_RecordingNavigator';

  @override
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    calls.add(_NavCall.push(routeName, arguments));
    return Future<T?>.value(null);
  }

  @override
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    calls.add(_NavCall.pushAndRemoveUntil(newRouteName, arguments));
    return Future<T?>.value(null);
  }
}

class _NavCall {
  _NavCall._(this.kind, this.route, this.arguments);
  factory _NavCall.push(String r, Object? a) => _NavCall._('push', r, a);
  factory _NavCall.pushAndRemoveUntil(String r, Object? a) =>
      _NavCall._('pushAndRemoveUntil', r, a);

  final String kind;
  final String route;
  final Object? arguments;
}

void main() {
  group('NotificationDeepLinkRouter', () {
    late _RecordingNavigator nav;
    late _FakeAnalyticsRepository analyticsRepo;
    late AnalyticsService analytics;
    late NotificationDeepLinkRouter router;

    setUpAll(() {
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      nav = _RecordingNavigator();
      analyticsRepo = _FakeAnalyticsRepository();
      analytics = AnalyticsService(repository: analyticsRepo);
      // Without a consent service the AnalyticsService check-fails-closed
      // and would suppress every event. The router test doesn't care about
      // GDPR — wire a permissive stub so we can observe events directly
      // through the repo.
      final consent = _AlwaysGrantedConsent();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);
      analytics.setConsentService(consent);
      router = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => analytics,
      );
    });

    test('recipe route pushes recipe detail with target id', () async {
      router.handle('/recipe', {'id': 'abc123', 'notificationType': 'share'});
      // Wait one microtask for the analytics fire-and-forget.
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls, hasLength(1));
      expect(nav.calls.single.kind, 'push');
      expect(nav.calls.single.route, Routes.receptDetalj);
      final args = nav.calls.single.arguments as Map<String, String?>;
      expect(args['id'], 'abc123');

      final event = analyticsRepo.events
          .firstWhere((e) => e.name == 'notification_opened');
      expect(event.parameters?['route'], '/recipe');
      expect(event.parameters?['notificationType'], 'share');
    });

    test('comment_thread route opens recipe with scrollToComments arg',
        () async {
      router.handle(
          '/comment_thread', {'id': 'r1', 'notificationType': 'comment'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.receptDetalj);
      final args = nav.calls.single.arguments as Map<String, dynamic>;
      expect(args['id'], 'r1');
      expect(args['scrollToComments'], isTrue);
    });

    test('friend_request route opens friend requests inbox', () async {
      router.handle('/friend_request',
          {'id': null, 'notificationType': 'friend_request'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.friendRequests);
    });

    test('cooking_session route opens cooking mode with session id', () async {
      router.handle(
          '/cooking_session', {'id': 'sess42', 'notificationType': 'cooking'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.cookingMode);
      final args = nav.calls.single.arguments as Map<String, String?>;
      expect(args['id'], 'sess42');
    });

    test('menu_voting route opens realtime menu', () async {
      router.handle('/menu_voting', {'id': null, 'notificationType': 'menu'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.realtimeMenu);
    });

    test('winback route lands on home (push and remove until)', () async {
      router.handle('/winback', {'id': null, 'notificationType': 'winback'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.kind, 'pushAndRemoveUntil');
      expect(nav.calls.single.route, Routes.home);
    });

    test('missing route defaults to home and logs missing-route event',
        () async {
      // Legacy in-flight notification payload — no `route` field.
      router.handle(null, {'id': null, 'notificationType': null});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.home);
      expect(nav.calls.single.kind, 'pushAndRemoveUntil');
      final names = analyticsRepo.events.map((e) => e.name).toList();
      expect(names, contains('notification_payload_missing_route'));
      expect(names, isNot(contains('notification_opened')));
    });

    test('empty-string route defaults to home + missing-route event', () async {
      // NotificationService normalizes a null route to '' before forwarding;
      // the router must treat empty the same as null.
      router.handle('', {'id': null, 'notificationType': null});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.home);
      final names = analyticsRepo.events.map((e) => e.name).toList();
      expect(names, contains('notification_payload_missing_route'));
    });

    test('unknown route defaults to home and logs unknown-route event',
        () async {
      // Defends against client-server drift: a Cloud Functions sender
      // could ship a new route string before the client knows about it.
      router.handle(
          '/unsupported_route_v9', {'id': 'x', 'notificationType': 'rogue'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.home);
      final names = analyticsRepo.events.map((e) => e.name).toList();
      expect(names, contains('notification_payload_unknown_route'));
      final unknown = analyticsRepo.events
          .firstWhere((e) => e.name == 'notification_payload_unknown_route');
      expect(unknown.parameters?['route'], '/unsupported_route_v9');
    });

    test('does not crash when navigator is null', () async {
      // Push notification can fire before the navigator has been built
      // (very early app start). Analytics still goes out so CTR isn't
      // dropped, but no navigation can happen.
      final routerNoNav = NotificationDeepLinkRouter(
        navigatorResolver: () => null,
        analyticsResolver: () => analytics,
      );
      // Should not throw.
      routerNoNav.handle('/recipe', {'id': 'abc', 'notificationType': 'x'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls, isEmpty);
      // The event was still logged.
      final names = analyticsRepo.events.map((e) => e.name).toList();
      expect(names, contains('notification_opened'));
    });

    test('recipe route with null/empty target id falls back to home', () async {
      // Without a recipe id the detail screen has nothing to render.
      router.handle('/recipe', {'id': null, 'notificationType': 'share'});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.home);
    });

    test('does not crash on null analytics', () async {
      final routerNoAnalytics = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => null,
      );
      // Should not throw.
      routerNoAnalytics.handle(null, const <String, String?>{});
      await Future<void>.delayed(Duration.zero);

      expect(nav.calls.single.route, Routes.home);
    });
  });
}

/// Minimal consent stub that always grants — keeps AnalyticsService from
/// silently dropping the events under test.
class _AlwaysGrantedConsent extends Mock implements ConsentService {}
