// BUT-1589: widget test for LayoutScaffolds.detailBottomNav (shipped BUT-1526).
//
// The shared detail/leaf bottom nav (used on settings, legal, notifications,
// FAQ) must keep the four main destinations one tap away, render NOTHING as
// selected (currentIndex null — no leaf view is a main tab), and push each
// destination's route with stack-based `pushNamed` so Back returns to the leaf
// view. Before this test the only verification was a manual screenshot sign-off,
// so a regression in any of those contracts would not fail any test.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

/// Records the names of routes pushed onto the navigator so the test can assert
/// which destination `detailBottomNav` navigated to. A NavigatorObserver is used
/// (rather than onGenerateRoute) because pushNamed('/') resolves to MaterialApp's
/// `home` and never reaches onGenerateRoute — the observer sees every push.
class _RoutePushRecorder extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  // The four main destinations, in order, keyed by the `test-nav-<route>` keys
  // ButleryBottomNavigation stamps on each item.
  const expectedRoutes = ['/', '/veckomeny', '/inkopslista', '/laggTill'];

  // Pumps the detail bottom nav inside a localized MaterialApp and returns the
  // observer recording every pushed route name.
  Future<_RoutePushRecorder> pumpDetailNav(WidgetTester tester) async {
    final recorder = _RoutePushRecorder();
    await tester.pumpWidget(
      MaterialApp(
        // Fresh key per pump so a re-pump tears down the previous navigator
        // (a route pushed by an earlier tap would otherwise cover the nav).
        key: UniqueKey(),
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        navigatorObservers: [recorder],
        // Named pushes resolve to a throwaway page so navigation completes.
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: settings,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Drop the initial `home` push so only tap-driven navigation is recorded.
    recorder.pushed.clear();
    return recorder;
  }

  group('LayoutScaffolds.detailBottomNav', () {
    testWidgets(
      'renders the shared bottom nav with the four main destinations and '
      'nothing selected',
      (tester) async {
        await pumpDetailNav(tester);

        // The shared bottom nav widget is used (not a bespoke one-off bar).
        final navFinder = find.byType(ButleryBottomNavigation);
        expect(navFinder, findsOneWidget);

        final nav = tester.widget<ButleryBottomNavigation>(navFinder);

        // All four main destinations are present, in mockup order.
        expect(nav.items.map((i) => i.route).toList(), expectedRoutes);

        // No leaf view is a main tab → nothing renders as selected.
        expect(nav.currentIndex, isNull);

        // Each destination is tappable (keyed for a11y/route matching).
        for (final route in expectedRoutes) {
          expect(
            find.byKey(ValueKey('test-nav-$route')),
            findsOneWidget,
            reason: 'missing nav item for route $route',
          );
        }
      },
    );

    testWidgets(
      'tapping a destination pushes its route (stack-based, Back returns)',
      (tester) async {
        for (final route in expectedRoutes) {
          final recorder = await pumpDetailNav(tester);

          await tester.tap(find.byKey(ValueKey('test-nav-$route')));
          await tester.pumpAndSettle();

          expect(
            recorder.pushed,
            contains(route),
            reason: 'tapping the $route destination should pushNamed($route)',
          );
        }
      },
    );
  });
}
