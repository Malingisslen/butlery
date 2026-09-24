/// Unit tests for SessionTimeoutService.
///
/// BUG-31: focuses on the warning-callback robustness contract — a missing or
/// late-registered warning callback must not silently log the user out without
/// any visible warning. Uses `fakeAsync` + `withClock` (the step-timer pattern)
/// so the inactivity/warning timers and `clock.now()`-based `timeRemaining`
/// advance on the same fake timeline.
library;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/session_timeout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [body] inside a fakeAsync zone whose `clock.now()` is pinned to the
  /// elapsed fake time, so timer firing and `timeRemaining` stay consistent.
  void withFakeTime(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(
        Clock(
          () => DateTime.fromMillisecondsSinceEpoch(
            DateTime(2026, 1, 1).millisecondsSinceEpoch +
                async.elapsed.inMilliseconds,
          ),
        ),
        () => body(async),
      );
    });
  }

  late MockAuthService authService;
  late MockAnalyticsService analyticsService;

  setUp(() {
    authService = MockAuthService();
    analyticsService = MockAnalyticsService();
    // MockAuthService exposes concrete, state-backed getters (isAuthenticated
    // is driven by setAuthState, not when()). The service only signs out while
    // authenticated, so keep it true so the logout path is reachable.
    authService.setAuthState(
      currentUser: MockFactory.createMockUser(uid: 'session_user'),
      isAuthenticated: true,
    );
    // logoutDueToInactivity isn't concretely overridden on the mock — stub the
    // Future<void> so the timeout logout path doesn't throw a null-future.
    when(() => authService.logoutDueToInactivity()).thenAnswer((_) async {});
  });

  SessionTimeoutService buildService() => SessionTimeoutService(
    authService: authService,
    analyticsService: analyticsService,
    timeoutDuration: const Duration(minutes: 10),
    warningOffset: const Duration(minutes: 5),
  );

  group('SessionTimeoutService warning callback (BUG-31)', () {
    test('warning fires the registered callback exactly once', () {
      withFakeTime((async) {
        final service = buildService();
        var warningCount = 0;
        service.registerWarningCallback(() => warningCount++);

        service.initialize();
        // Advance to just past the warning point (10 - 5 = 5 minutes in).
        async.elapse(const Duration(minutes: 5, seconds: 1));

        expect(warningCount, 1, reason: 'warning callback should fire once');
        expect(service.shouldShowWarning, isTrue);
      });
    });

    test(
      'missing callback does not throw and does not block the warning state',
      () {
        withFakeTime((async) {
          final service = buildService();
          // Intentionally do NOT register a warning callback.
          service.initialize();

          // Reaching the warning point must not crash even with no callback.
          expect(
            () => async.elapse(const Duration(minutes: 5, seconds: 1)),
            returnsNormally,
          );
          expect(
            service.shouldShowWarning,
            isTrue,
            reason: 'warning state still advances so logout is not silent-only',
          );
        });
      },
    );

    test('late-registered callback receives the pending warning (replay)', () {
      withFakeTime((async) {
        final service = buildService();
        service.initialize();

        // Warning fires while no callback is registered.
        async.elapse(const Duration(minutes: 5, seconds: 1));
        expect(service.shouldShowWarning, isTrue);

        // UI registers its callback AFTER the warning already fired but while
        // the session is still alive — it must be replayed immediately so the
        // user isn't logged out without ever seeing the warning.
        var warningCount = 0;
        service.registerWarningCallback(() => warningCount++);

        expect(
          warningCount,
          1,
          reason: 'pending warning must replay to a late-registered callback',
        );
      });
    });

    test('recording activity before warning cancels the pending warning', () {
      withFakeTime((async) {
        final service = buildService();
        var warningCount = 0;
        service.registerWarningCallback(() => warningCount++);
        service.initialize();

        // Activity at 4 minutes resets the 5-minute warning timer.
        async.elapse(const Duration(minutes: 4));
        service.recordActivity();
        async.elapse(const Duration(minutes: 4));

        expect(
          warningCount,
          0,
          reason: 'activity reset should push the warning past this point',
        );
        expect(service.shouldShowWarning, isFalse);
      });
    });

    test('no replay once the session has already timed out', () {
      withFakeTime((async) {
        final service = buildService();
        service.initialize();

        // Elapse past the full timeout so the session is gone.
        async.elapse(const Duration(minutes: 11));

        var warningCount = 0;
        service.registerWarningCallback(() => warningCount++);

        expect(
          warningCount,
          0,
          reason: 'a timed-out session must not replay a stale warning',
        );
      });
    });
  });

  // P6-U08a / P6-U06 (produktregler.md:829-834, § 16.2; flow 06 session).
  group('session end: queue untouched, notice, return path', () {
    const pending = PendingChanges(recipeChanges: 2, imageUploads: 1);

    SessionTimeoutService buildWithQueue(List<SessionEnd> ends) {
      final service = SessionTimeoutService(
        authService: authService,
        analyticsService: analyticsService,
        timeoutDuration: const Duration(minutes: 10),
        warningOffset: const Duration(minutes: 5),
        pendingChangesReader: () async => pending,
      );
      service.registerSessionEndCallback(ends.add);
      return service;
    }

    setUp(() {
      SessionEndNotice.clear();
      SessionReturnPath.reset();
      SharedPreferences.setMockInitialValues({});
    });

    test('a foreground timeout signs out without clearing anything', () {
      withFakeTime((async) {
        final ends = <SessionEnd>[];
        final service = buildWithQueue(ends);
        service.initialize();
        async.elapse(const Duration(minutes: 10, seconds: 1));
        async.flushMicrotasks();

        verify(() => authService.logoutDueToInactivity()).called(1);
        expect(ends, hasLength(1));
        expect(ends.single.reason, SessionEndReason.timeout);
        expect(ends.single.userId, 'session_user');
        expect(ends.single.pendingChanges, pending);
        expect(
          SessionEndNotice.pending,
          isNull,
          reason: 'the foreground timeout was warned about; no notice',
        );
      });
    });

    test('a background timeout records the calm notice with the count', () {
      withFakeTime((async) {
        final ends = <SessionEnd>[];
        final service = buildWithQueue(ends);
        service.initialize();
        service.recordActivity();
        service.onAppPaused();
        async.elapse(const Duration(minutes: 11));
        service.onAppResumed();
        async.flushMicrotasks();

        verify(() => authService.logoutDueToInactivity()).called(1);
        expect(ends.single.reason, SessionEndReason.backgroundTimeout);
        expect(SessionEndNotice.pending?.pendingChanges.total, 3);
      });
    });

    test('"Logga ut nu" is user_requested: queue kept, drafts go', () async {
      // PQ-12 = A: drafts go when the user signs out herself. The queue is
      // never cleared by any timeout reason (produktregler.md:833); the
      // service has no path to it at all, only to the pending COUNT.
      SharedPreferences.setMockInitialValues({
        'recipe_drafts_metadata': '[]',
        'recipe_draft_d1': '{"title":"x"}',
      });
      final ends = <SessionEnd>[];
      final service = buildWithQueue(ends);
      await service.forceLogout();

      verify(() => authService.logoutDueToInactivity()).called(1);
      expect(ends.single.reason, SessionEndReason.userRequested);
      expect(ends.single.pendingChanges, pending);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('recipe_draft_d1'), isNull);
    });

    test('an automatic timeout keeps the drafts (PQ-12 = A)', () async {
      SharedPreferences.setMockInitialValues({
        'recipe_drafts_metadata': '[]',
        'recipe_draft_d1': '{"title":"x"}',
      });
      final ends = <SessionEnd>[];
      final service = buildWithQueue(ends);
      service.initialize();
      service.recordActivity();
      service.onAppPaused();
      await withClock(
        Clock.fixed(clock.now().add(const Duration(minutes: 11))),
        () async => service.onAppResumed(),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ends.single.reason, SessionEndReason.backgroundTimeout);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('recipe_draft_d1'), isNotNull);
    });

    test('the return path goes to the same account only, once', () {
      SessionReturnPath.remember(
        userId: 'anna',
        routeName: '/recipe-detail',
        arguments: const {'recipeId': 'r1'},
      );
      expect(SessionReturnPath.takeFor('bertil'), isNull);
      // Another account signing in drops it.
      expect(SessionReturnPath.takeFor('anna'), isNull);

      SessionReturnPath.remember(
        userId: 'anna',
        routeName: '/recipe-detail',
        arguments: const {'recipeId': 'r1'},
      );
      final route = SessionReturnPath.takeFor('anna');
      expect(route?.routeName, '/recipe-detail');
      expect(route?.arguments, {'recipeId': 'r1'});
      expect(SessionReturnPath.takeFor('anna'), isNull);
    });

    test('a route whose arguments are not plain values falls back to Hem', () {
      SessionReturnPath.remember(
        userId: 'anna',
        routeName: '/recipe-detail',
        arguments: Object(),
      );
      expect(SessionReturnPath.peek, isNull);

      SessionReturnPath.remember(userId: 'anna', routeName: '/auth');
      expect(SessionReturnPath.peek, isNull);
    });
  });
}
