// test/unit/core/observers/route_tracker_test.dart
//
// BUT-521 follow-up: behavioral coverage for the route-name tracker that
// powers Cmd+K dedupe. Tests pump a real `MaterialApp` with the tracker as
// a navigator observer so push/pop/replace are exercised through the
// production code path, not synthesized observer events.

import 'package:butlery/core/observers/route_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteTracker', () {
    late RouteTracker tracker;

    setUp(() {
      tracker = RouteTracker();
    });

    Widget appWith({
      required Map<String, WidgetBuilder> routes,
      String initial = '/',
    }) {
      return MaterialApp(
        navigatorObservers: [tracker],
        initialRoute: initial,
        routes: routes,
      );
    }

    testWidgets('records initial route name on first push', (tester) async {
      await tester.pumpWidget(
        appWith(routes: {'/': (_) => const Scaffold(body: Text('home'))}),
      );
      await tester.pumpAndSettle();

      expect(tracker.currentRouteName, '/');
    });

    testWidgets('updates currentRouteName on pushNamed', (tester) async {
      late BuildContext rootContext;
      await tester.pumpWidget(appWith(
        routes: {
          '/': (ctx) {
            rootContext = ctx;
            return const Scaffold(body: Text('home'));
          },
          '/search': (_) => const Scaffold(body: Text('search')),
        },
      ));
      await tester.pumpAndSettle();

      Navigator.of(rootContext).pushNamed('/search');
      await tester.pumpAndSettle();

      expect(tracker.currentRouteName, '/search');
    });

    testWidgets('restores previous route name after pop', (tester) async {
      late BuildContext rootContext;
      await tester.pumpWidget(appWith(
        routes: {
          '/': (ctx) {
            rootContext = ctx;
            return const Scaffold(body: Text('home'));
          },
          '/search': (_) => const Scaffold(body: Text('search')),
        },
      ));
      await tester.pumpAndSettle();

      final navigator = Navigator.of(rootContext);
      navigator.pushNamed('/search');
      await tester.pumpAndSettle();
      expect(tracker.currentRouteName, '/search');

      navigator.pop();
      await tester.pumpAndSettle();
      expect(tracker.currentRouteName, '/');
    });

    testWidgets('updates currentRouteName on pushReplacementNamed', (
      tester,
    ) async {
      late BuildContext rootContext;
      await tester.pumpWidget(appWith(
        routes: {
          '/': (ctx) {
            rootContext = ctx;
            return const Scaffold(body: Text('home'));
          },
          '/search': (_) => const Scaffold(body: Text('search')),
          '/recipes': (_) => const Scaffold(body: Text('recipes')),
        },
      ));
      await tester.pumpAndSettle();

      Navigator.of(rootContext).pushNamed('/search');
      await tester.pumpAndSettle();
      Navigator.of(rootContext).pushReplacementNamed('/recipes');
      await tester.pumpAndSettle();

      expect(tracker.currentRouteName, '/recipes');
    });

    testWidgets(
      'two pushNamed of same route still stack (tracker is descriptive, not policy)',
      (tester) async {
        // The tracker only reports state — the dedupe POLICY lives in the
        // _pushSearch handler. This guards against accidentally moving the
        // dedupe into the tracker, which would silently break other
        // legitimate same-route pushes.
        late BuildContext rootContext;
        await tester.pumpWidget(appWith(
          routes: {
            '/': (ctx) {
              rootContext = ctx;
              return const Scaffold(body: Text('home'));
            },
            '/search': (_) => const Scaffold(body: Text('search')),
          },
        ));
        await tester.pumpAndSettle();

        final navigator = Navigator.of(rootContext);
        navigator.pushNamed('/search');
        await tester.pumpAndSettle();
        navigator.pushNamed('/search');
        await tester.pumpAndSettle();

        expect(tracker.currentRouteName, '/search');

        navigator.pop();
        await tester.pumpAndSettle();
        // Still '/search' — there were two on the stack, popping reveals
        // the other one.
        expect(tracker.currentRouteName, '/search');

        navigator.pop();
        await tester.pumpAndSettle();
        expect(tracker.currentRouteName, '/');
      },
    );
  });
}
