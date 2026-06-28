/// BUT-1439: Journey test — `butlery://import?url=...` deep link → Smart Import.
///
/// Proves the full wiring end-to-end:
///   auth gate passes → host guard recognises "import" → _handleImportLink
///   pushNamed(Routes.smartImport, arguments: decodedUrl)
///
/// The test does NOT render SmartImportView (which pulls in a heavy DI graph).
/// Instead, onGenerateRoute stubs unknown route names with a trivial Scaffold,
/// while the spy NavigatorObserver records every push with its RouteSettings.
/// The assertion is on the RouteSettings — proving the Navigator call actually
/// fired (not a false-green from a silent exception swallow).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/factories/mock_factory.dart';

// ---------------------------------------------------------------------------
// Spy navigator observer
// ---------------------------------------------------------------------------

class _SpyNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

// ---------------------------------------------------------------------------
// Minimal test app
// ---------------------------------------------------------------------------

Widget _testApp({required _SpyNavigatorObserver observer}) {
  return MaterialApp(
    navigatorObservers: [observer],
    // Home gives us a BuildContext that is mounted and has a Navigator.
    home: const Scaffold(body: SizedBox.shrink()),
    // Stub every generated route with a trivial Scaffold so pushNamed
    // succeeds without pulling in the real SmartImportView dependency graph.
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        body: Text('stub:${settings.name}'),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  late _SpyNavigatorObserver observer;
  late DeepLinkHandler handler;

  setUp(() async {
    // Wire up TestServiceLocator (registers FakeAuthRepository etc. into the
    // shared GetIt) then wrap with the prod DIContainer so that
    // ServiceLocator.get<AuthRepository>() inside processDeepLink resolves.
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());

    // Override AuthRepository with an authed user so the auth gate passes.
    final authedRepo = MockFactory.createAuthRepository(
      isAuthenticated: true,
      userId: 'journey-test-user',
    );
    TestServiceLocator.registerMock<AuthRepository>(authedRepo);

    // Reset the singleton handler so previous test state doesn't bleed.
    handler = DeepLinkHandler();
    handler.reset();

    observer = _SpyNavigatorObserver();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  group('Deep-link import journey', () {
    testWidgets(
      'butlery://import?url=... pushes Routes.smartImport with decoded URL',
      (tester) async {
        await tester.pumpWidget(_testApp(observer: observer));
        await tester.pumpAndSettle();

        // Grab the BuildContext from the live widget tree.
        final context = tester.element(find.byType(Scaffold).first);

        const deepLink =
            'butlery://import?url=https%3A%2F%2Frecipes.example.com%2Fx';
        const expectedUrl = 'https://recipes.example.com/x';

        await tester.runAsync(() async {
          await handler.processDeepLink(deepLink, context);
        });
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // The spy must have recorded at least one push beyond the initial
        // home route — if processing was silently swallowed the list stays
        // at 1 (just the home push) and this assertion fails, ruling out a
        // false-green from the silent catch block.
        final namedPushes = observer.pushed
            .where((r) => r.settings.name == Routes.smartImport)
            .toList();

        expect(
          namedPushes,
          isNotEmpty,
          reason:
              'Expected a push to Routes.smartImport but observer recorded '
              'only: ${observer.pushed.map((r) => r.settings.name).toList()}',
        );

        final pushedRoute = namedPushes.first;
        expect(
          pushedRoute.settings.name,
          equals(Routes.smartImport),
        );
        expect(
          pushedRoute.settings.arguments,
          equals(expectedUrl),
          reason:
              'arguments should be the percent-decoded URL, got: '
              '${pushedRoute.settings.arguments}',
        );
      },
    );

    testWidgets(
      'unknown butlery:// host pushes nothing',
      (tester) async {
        await tester.pumpWidget(_testApp(observer: observer));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold).first);

        // Capture how many routes are in the observer before the call.
        final pushCountBefore = observer.pushed.length;

        await tester.runAsync(() async {
          await handler.processDeepLink(
            'butlery://evil.example.com/x',
            context,
          );
        });
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // No new pushes should have been recorded.
        expect(
          observer.pushed.length,
          equals(pushCountBefore),
          reason:
              'An unknown butlery:// host must not trigger any navigation, '
              'but observer gained pushes: '
              '${observer.pushed.skip(pushCountBefore).map((r) => r.settings.name).toList()}',
        );
      },
    );
  });
}
