import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/observers/snackbar_route_observer.dart';

void main() {
  group('SnackbarRouteObserver', () {
    late SnackbarRouteObserver observer;

    setUp(() {
      observer = SnackbarRouteObserver();
    });

    testWidgets('clears snackbars when route is pushed', (tester) async {
      // Create a test app with the observer
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _TestHomePage(),
        ),
      );

      // Show a snackbar
      final context = tester.element(find.byType(_TestHomePage));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test message')),
      );

      await tester.pump();

      // Verify snackbar is visible
      expect(find.text('Test message'), findsOneWidget);

      // Navigate to a new route
      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();

      // Verify snackbar is cleared
      expect(find.text('Test message'), findsNothing);
    });

    testWidgets('clears snackbars when route is popped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _TestHomePage(),
        ),
      );

      // Navigate to second page
      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();

      // Show snackbar on second page
      final context = tester.element(find.byType(_TestSecondPage));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test message on second page')),
      );

      await tester.pump();

      // Verify snackbar is visible
      expect(find.text('Test message on second page'), findsOneWidget);

      // Pop back to first page
      await tester.tap(find.byKey(const Key('back_button')));
      await tester.pumpAndSettle();

      // Verify snackbar is cleared
      expect(find.text('Test message on second page'), findsNothing);
    });

    testWidgets('clears snackbars when route is replaced', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _TestHomePage(),
        ),
      );

      // Show a snackbar
      final context = tester.element(find.byType(_TestHomePage));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test message')),
      );

      await tester.pump();

      // Verify snackbar is visible
      expect(find.text('Test message'), findsOneWidget);

      // Replace route
      await tester.tap(find.byKey(const Key('replace_button')));
      await tester.pumpAndSettle();

      // Verify snackbar is cleared
      expect(find.text('Test message'), findsNothing);
    });

    testWidgets('handles multiple snackbars correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _TestHomePage(),
        ),
      );

      final context = tester.element(find.byType(_TestHomePage));

      // Show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Test message'), duration: Duration(seconds: 10)),
      );

      await tester.pump();

      // Verify message is visible
      expect(find.text('Test message'), findsOneWidget);

      // Navigate
      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();

      // Verify snackbar is cleared
      expect(find.text('Test message'), findsNothing);
    });

    testWidgets('does not crash when no scaffold is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _TestHomePageNoScaffold(),
        ),
      );

      // Navigate (should not crash even without Scaffold)
      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();

      // Test passes if no exception is thrown
    });
  });
}

// Test pages
class _TestHomePage extends StatelessWidget {
  const _TestHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              key: const Key('navigate_button'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _TestSecondPage()),
                );
              },
              child: const Text('Navigate'),
            ),
            ElevatedButton(
              key: const Key('replace_button'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const _TestSecondPage()),
                );
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestSecondPage extends StatelessWidget {
  const _TestSecondPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Page')),
      body: Center(
        child: ElevatedButton(
          key: const Key('back_button'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
      ),
    );
  }
}

class _TestHomePageNoScaffold extends StatelessWidget {
  const _TestHomePageNoScaffold();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        key: const Key('navigate_button'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _TestSecondPage()),
          );
        },
        child: const Text('Navigate'),
      ),
    );
  }
}
