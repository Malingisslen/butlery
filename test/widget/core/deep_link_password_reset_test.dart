/// BUT-2170: a "glömt lösenord" link opens "Välj nytt lösenord" whether or
/// not anyone is signed in, and the link stream's replay of the link that
/// started the app does not open it twice.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/auth/password_reset_link.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

String _resetLink(String code) =>
    'https://${PasswordResetLink.linkDomain}/__/auth/links?link='
    '${Uri.encodeComponent('https://${PasswordResetLink.linkDomain}/__/auth/action?mode=resetPassword&oobCode=$code')}';

void main() {
  late List<RouteSettings> pushed;

  setUp(() {
    DeepLinkHandler().reset();
    pushed = [];
  });

  tearDown(() => DeepLinkHandler().reset());

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
        'https://butlery.app/recipe?id=1',
        context,
      ),
      isFalse,
    );
    expect(pushed, isEmpty);
  });

  testWidgets('signed out, a reset link opens without the sign-in check', (
    tester,
  ) async {
    // No AuthRepository is registered, so anything that reaches the
    // sign-in check fails there and opens nothing.
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
  });

  group('a link arriving while the app is open', () {
    testWidgets('a reset link opens the view; the app\'s own links do not', (
      tester,
    ) async {
      await pumpApp(tester);
      DeepLinkHandler()
        ..onLinkWhileRunning('https://butlery.app/recipe?id=1')
        ..onLinkWhileRunning(_resetLink('abc'));
      await tester.pumpAndSettle();
      expect(pushed.single.name, Routes.setNewPassword);
    });

    testWidgets(
      'before the app has a screen, the app\'s own links are not kept',
      (
        tester,
      ) async {
        DeepLinkHandler().onLinkWhileRunning('https://butlery.app/recipe?id=1');
        expect(DeepLinkHandler().debugInfo['has_pending_link'], isFalse);
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
}
