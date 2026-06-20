/// Unit tests for [NotificationDeepLinkRouter] (BUT-641).
///
/// Verifies that each known route maps to the expected navigator action,
/// and that missing/unknown routes default to home + log analytics so push
/// CTR can be measured even on edge cases.
///
/// Recipe-bearing routes (`/recipe`, `/comment_thread`) resolve the id to a
/// full [Recipe] before navigating — the recipeDetail route requires a
/// Recipe object, not an id string (the pre-release-audit B2 fix). The fetch
/// is injected as a test seam so these tests never touch Firebase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/notifications/notification_deep_link_router.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

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

  // The router guards navigation with `navigator.mounted` after the async
  // recipe fetch. A live navigator is the default for these routing tests.
  @override
  bool get mounted => true;

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
    late List<String> fetchedIds;
    // Reassignable per-test so a test can force a null (recipe not accessible)
    // result. Defaults to resolving any id to a stub Recipe.
    late Future<Recipe?> Function(String id) fetchRecipe;

    /// Drains the microtask queue enough for the fire-and-forget async
    /// navigation (`unawaited(_openRecipe...)`) to run: one turn for the
    /// recipe fetch, one for the subsequent pushNamed.
    Future<void> drain() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    setUpAll(() {
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      nav = _RecordingNavigator();
      analyticsRepo = _FakeAnalyticsRepository();
      analytics = AnalyticsService(repository: analyticsRepo);
      fetchedIds = <String>[];
      fetchRecipe = (id) async {
        fetchedIds.add(id);
        return RecipeFactory.build(id: id);
      };
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
        fetchRecipe: (id) => fetchRecipe(id),
      );
    });

    test('recipe route resolves id and pushes recipe detail', () async {
      router.handle('/recipe', {'id': 'abc123', 'notificationType': 'share'});
      await drain();

      expect(fetchedIds, <String>['abc123']);
      expect(nav.calls, hasLength(1));
      expect(nav.calls.single.kind, 'push');
      expect(nav.calls.single.route, Routes.recipeDetail);
      final args = nav.calls.single.arguments as Map<String, dynamic>;
      expect((args['recipe'] as Recipe).id, 'abc123');
      expect(args['scrollToComments'], isFalse);

      final event = analyticsRepo.events
          .firstWhere((e) => e.name == 'notification_opened');
      expect(event.parameters?['route'], '/recipe');
      expect(event.parameters?['notificationType'], 'share');
    });

    test('comment_thread route opens recipe with scrollToComments arg',
        () async {
      router.handle(
          '/comment_thread', {'id': 'r1', 'notificationType': 'comment'});
      await drain();

      expect(nav.calls.single.route, Routes.recipeDetail);
      final args = nav.calls.single.arguments as Map<String, dynamic>;
      expect((args['recipe'] as Recipe).id, 'r1');
      expect(args['scrollToComments'], isTrue);
    });

    test('recipe route falls back to home when recipe is not accessible',
        () async {
      // `read` is user-scoped → returns null for a recipe the current user
      // can't see (e.g. a stale notification about a friend's recipe). Must
      // land on home, never the "page not found" error route.
      fetchRecipe = (id) async => null;

      router.handle('/recipe', {'id': 'gone', 'notificationType': 'share'});
      await drain();

      expect(nav.calls.single.kind, 'pushAndRemoveUntil');
      expect(nav.calls.single.route, Routes.home);
    });

    test('recipe route falls back to home when fetch throws', () async {
      fetchRecipe = (id) async => throw Exception('network down');

      router.handle('/recipe', {'id': 'x', 'notificationType': 'share'});
      await drain();

      expect(nav.calls.single.route, Routes.home);
    });

    test('friend_request route opens friend requests inbox', () async {
      router.handle('/friend_request',
          {'id': null, 'notificationType': 'friend_request'});
      await drain();

      expect(nav.calls.single.route, Routes.friendRequests);
    });

    test('cooking_session route falls back to home (no live sender)', () async {
      // `targetId` is a cooking-session id, not a recipeId, and no Cloud
      // Function emits this route yet — it must land on home, not the error
      // screen, until a real session→recipe resolver exists.
      router.handle(
          '/cooking_session', {'id': 'sess42', 'notificationType': 'cooking'});
      await drain();

      expect(nav.calls.single.kind, 'pushAndRemoveUntil');
      expect(nav.calls.single.route, Routes.home);
    });

    test('menu_voting route opens realtime menu', () async {
      router.handle('/menu_voting', {'id': null, 'notificationType': 'menu'});
      await drain();

      expect(nav.calls.single.route, Routes.realtimeMenu);
    });

    test('winback route lands on home (push and remove until)', () async {
      router.handle('/winback', {'id': null, 'notificationType': 'winback'});
      await drain();

      expect(nav.calls.single.kind, 'pushAndRemoveUntil');
      expect(nav.calls.single.route, Routes.home);
    });

    test('missing route defaults to home and logs missing-route event',
        () async {
      // Legacy in-flight notification payload — no `route` field.
      router.handle(null, {'id': null, 'notificationType': null});
      await drain();

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
      await drain();

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
      await drain();

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
        fetchRecipe: (id) => fetchRecipe(id),
      );
      // Should not throw.
      routerNoNav.handle('/recipe', {'id': 'abc', 'notificationType': 'x'});
      await drain();

      expect(nav.calls, isEmpty);
      // The event was still logged.
      final names = analyticsRepo.events.map((e) => e.name).toList();
      expect(names, contains('notification_opened'));
    });

    test('recipe route with null/empty target id falls back to home', () async {
      // Without a recipe id there's nothing to resolve — never reaches fetch.
      router.handle('/recipe', {'id': null, 'notificationType': 'share'});
      await drain();

      expect(nav.calls.single.route, Routes.home);
      expect(fetchedIds, isEmpty);
    });

    test('does not crash on null analytics', () async {
      final routerNoAnalytics = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => null,
        fetchRecipe: (id) => fetchRecipe(id),
      );
      // Should not throw.
      routerNoAnalytics.handle(null, const <String, String?>{});
      await drain();

      expect(nav.calls.single.route, Routes.home);
    });

    // -----------------------------------------------------------------
    // Security-review C1 follow-up: server-side open-event recording.
    // The recordOpened seam is fire-and-forget — assert on call shape
    // (correct fields), conditional invocation (skipped without id),
    // and failure-tolerance (navigation proceeds even on rejection).
    // -----------------------------------------------------------------

    test('records server-side open event with id, type, and route', () async {
      final calls = <_RecordedOpen>[];
      Future<void> seam({
        required String notificationId,
        required String notificationType,
        String? route,
      }) async {
        calls.add(_RecordedOpen(notificationId, notificationType, route));
      }

      final routerWithSeam = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => analytics,
        recordOpened: seam,
        fetchRecipe: (id) => fetchRecipe(id),
      );

      routerWithSeam.handle('/recipe', const {
        'id': 'recipe-1',
        'notificationId': 'msg-abc',
        'notificationType': 'recipe_shared',
      });
      await drain();

      expect(calls, hasLength(1));
      expect(calls.single.notificationId, 'msg-abc');
      expect(calls.single.notificationType, 'recipe_shared');
      expect(calls.single.route, '/recipe');
      // Navigation still happened.
      expect(nav.calls.single.route, Routes.recipeDetail);
    });

    test('skips server-side recording when notificationId is missing',
        () async {
      final calls = <_RecordedOpen>[];
      Future<void> seam({
        required String notificationId,
        required String notificationType,
        String? route,
      }) async {
        calls.add(_RecordedOpen(notificationId, notificationType, route));
      }

      final routerWithSeam = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => analytics,
        recordOpened: seam,
        fetchRecipe: (id) => fetchRecipe(id),
      );

      // No `notificationId` key — server-side dedup requires one,
      // so we must NOT call the recorder at all.
      routerWithSeam.handle('/recipe', const {
        'id': 'recipe-1',
        'notificationType': 'recipe_shared',
      });
      await drain();

      expect(calls, isEmpty);
      // Navigation still happened — analytics path unaffected.
      expect(nav.calls.single.route, Routes.recipeDetail);
    });

    test('navigates even when recordOpened throws', () async {
      // Simulates a rejected Future from the callable — the kind of
      // failure mode FirebaseFunctionsException(code: "unavailable")
      // produces in production. Without the call-site try/catch this
      // would emit an unhandled-async-error to the test zone and the
      // test would fail with a "test completed with errors" warning.
      Future<void> failingSeam({
        required String notificationId,
        required String notificationType,
        String? route,
      }) {
        return Future<void>.error(
          Exception('FirebaseFunctionsException(code: "unavailable")'),
        );
      }

      final routerWithSeam = NotificationDeepLinkRouter(
        navigatorResolver: () => nav,
        analyticsResolver: () => analytics,
        recordOpened: failingSeam,
        fetchRecipe: (id) => fetchRecipe(id),
      );

      routerWithSeam.handle('/recipe', const {
        'id': 'recipe-1',
        'notificationId': 'msg-abc',
        'notificationType': 'recipe_shared',
      });
      // Navigation is async now (after the recipe fetch) — drain first.
      await drain();
      expect(nav.calls.single.route, Routes.recipeDetail);
    });
  });
}

/// Record-shape capture for the recordOpened seam tests.
class _RecordedOpen {
  _RecordedOpen(this.notificationId, this.notificationType, this.route);
  final String notificationId;
  final String notificationType;
  final String? route;
}

/// Minimal consent stub that always grants — keeps AnalyticsService from
/// silently dropping the events under test.
class _AlwaysGrantedConsent extends Mock implements ConsentService {}
