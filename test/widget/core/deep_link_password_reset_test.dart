/// BUT-2170: a "glömt lösenord" link opens "Välj nytt lösenord" whether or
/// not anyone is signed in, and the link stream's replay of the link that
/// started the app does not open it twice.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/models/auth/password_reset_link.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';

String _resetLink(String code) =>
    'https://${PasswordResetLink.linkDomain}/__/auth/links?link='
    '${Uri.encodeComponent('https://${PasswordResetLink.linkDomain}/__/auth/action?mode=resetPassword&oobCode=$code')}';

void main() {
  late List<RouteSettings> pushed;

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(isAuthenticated: false),
    );
    DeepLinkHandler().reset();
    pushed = [];
  });

  tearDown(() async {
    DeepLinkHandler().reset();
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  Future<BuildContext> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Text('hem'),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Text('välj nytt'),
          );
        },
      ),
    );
    return tester.element(find.text('hem'));
  }

  testWidgets(
    'a reset link opens the view with its code; the replay does not',
    (
      tester,
    ) async {
      final context = await pumpApp(tester);
      final handler = DeepLinkHandler();

      expect(handler.handleAuthActionLink(_resetLink('abc'), context), isTrue);
      expect(handler.handleAuthActionLink(_resetLink('abc'), context), isTrue);
      await tester.pumpAndSettle();

      expect(pushed, hasLength(1));
      expect(pushed.single.name, Routes.setNewPassword);
      expect(pushed.single.arguments, 'abc');
    },
  );

  testWidgets('tapping the same mail link again later opens the view again', (
    tester,
  ) async {
    final context = await pumpApp(tester);
    final handler = DeepLinkHandler();
    final t0 = DateTime(2026, 10, 8, 12);
    void tapAt(Duration after) => withClock(
      Clock.fixed(t0.add(after)),
      () => handler.handleAuthActionLink(_resetLink('abc'), context),
    );

    tapAt(Duration.zero);
    tapAt(const Duration(seconds: 1)); // the replay
    tapAt(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(pushed, hasLength(2));
  });

  testWidgets('without a replay, the next tap of the same link still opens', (
    tester,
  ) async {
    final context = await pumpApp(tester);
    final handler = DeepLinkHandler();
    final t0 = DateTime(2026, 10, 8, 12);
    void tapAt(Duration after) => withClock(
      Clock.fixed(t0.add(after)),
      () => handler.handleAuthActionLink(_resetLink('abc'), context),
    );

    tapAt(Duration.zero);
    tapAt(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(pushed, hasLength(2));
  });

  testWidgets('the app\'s own links are not taken', (tester) async {
    final context = await pumpApp(tester);
    expect(
      DeepLinkHandler().handleAuthActionLink(
        'https://butlery.se/recipe?id=1',
        context,
      ),
      isFalse,
    );
    expect(pushed, isEmpty);
  });

  testWidgets('signed out, a reset link opens without the sign-in check', (
    tester,
  ) async {
    final context = await pumpApp(tester);
    await DeepLinkHandler().processDeepLink(_resetLink('abc'), context);
    await tester.pumpAndSettle();
    expect(pushed.single.name, Routes.setNewPassword);
    expect(pushed.single.arguments, 'abc');
  });

  testWidgets('signed out, the app\'s own links stop at the sign-in check', (
    tester,
  ) async {
    final context = await pumpApp(tester);
    await DeepLinkHandler().processDeepLink(
      'butlery://butlery.app/recipe/1',
      context,
    );
    await tester.pumpAndSettle();
    expect(pushed, isEmpty);
    expect(DeepLinkHandler().debugInfo['has_pending_link'], isTrue);
  });

  group('a link arriving while the app is open', () {
    testWidgets('a reset link opens the view', (tester) async {
      await pumpApp(tester);
      DeepLinkHandler().onLinkWhileRunning(_resetLink('abc'));
      await tester.pumpAndSettle();
      expect(pushed.single.name, Routes.setNewPassword);
    });

    testWidgets(
      'a shared link goes the cold-start route, so signed out it is parked',
      (tester) async {
        await pumpApp(tester);
        DeepLinkHandler().onLinkWhileRunning('https://butlery.se/recipe?id=1');
        await tester.pumpAndSettle();
        expect(pushed, isEmpty);
        expect(DeepLinkHandler().debugInfo['has_pending_link'], isTrue);
      },
    );

    testWidgets(
      'before the app has a screen, a shared link is kept for later',
      (tester) async {
        DeepLinkHandler().onLinkWhileRunning('https://butlery.se/recipe?id=1');
        expect(DeepLinkHandler().debugInfo['has_pending_link'], isTrue);
      },
    );

    testWidgets('before the app has a screen, it waits and then opens', (
      tester,
    ) async {
      DeepLinkHandler().onLinkWhileRunning(_resetLink('abc'));
      final context = await pumpApp(tester);
      expect(pushed, isEmpty);

      await DeepLinkHandler().processPendingDeepLink(context);
      await tester.pumpAndSettle();
      expect(pushed.single.name, Routes.setNewPassword);
      expect(pushed.single.arguments, 'abc');
    });
  });

  group('the stream replaying the link that started the app', () {
    final started = DateTime(2026, 11, 7, 12);
    const link = 'https://butlery.se/recipe?id=1';
    bool replay(String l, {String? start = link, int seconds = 1}) =>
        DeepLinkHandler.isReplayOfStartLink(
          link: l,
          startLink: start,
          startedAt: start == null ? null : started,
          now: started.add(Duration(seconds: seconds)),
        );

    testWidgets('onLinkWhileRunning swallows it only inside the window', (
      tester,
    ) async {
      await pumpApp(tester);
      bool parked(String l, int seconds) {
        DeepLinkHandler()
          ..reset()
          ..debugSeedStartLink(link, started);
        withClock(
          Clock.fixed(started.add(Duration(seconds: seconds))),
          () => DeepLinkHandler().onLinkWhileRunning(l),
        );
        return DeepLinkHandler().debugInfo['has_pending_link'] as bool;
      }

      expect(parked(link, 1), isFalse);
      expect(parked(link, 6), isTrue);
      expect(parked('https://butlery.se/menu?id=2', 1), isTrue);
    });

    test('is swallowed right after the start', () {
      expect(replay(link), isTrue);
    });

    test('is handled when the same link is tapped later', () {
      expect(replay(link, seconds: 6), isFalse);
    });

    test('is handled when it is a different link', () {
      expect(replay('https://butlery.se/menu?id=2'), isFalse);
    });

    test('is handled when the app was not started by a link', () {
      expect(replay(link, start: null), isFalse);
    });

    test('leaves mail action links to their own guard', () {
      final reset = _resetLink('abc');
      expect(replay(reset, start: reset), isFalse);
    });
  });
}
