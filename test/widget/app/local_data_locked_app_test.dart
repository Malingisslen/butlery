/// The screen shown when the encrypted local database cannot be opened.
/// Nothing may be deleted unless the person confirms in the second step.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/app/local_data_locked_app.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/storage/drift/database_key_store.dart';

void main() {
  group('isLocalDataLocked', () {
    test('matches both key errors, also wrapped by a DI module', () {
      expect(isLocalDataLocked(const DatabaseKeyLost()), isTrue);
      expect(isLocalDataLocked(const DatabaseKeyUnavailable()), isTrue);
      expect(
        isLocalDataLocked(
          const DIModuleException(
            'Content',
            'initialization',
            'Failed to initialize content services',
            DatabaseKeyLost(),
          ),
        ),
        isTrue,
      );
    });

    test('does not match another start failure', () {
      expect(isLocalDataLocked(StateError('boom')), isFalse);
    });
  });

  Future<int Function()> pump(
    WidgetTester tester, {
    void Function()? onRetry,
    Future<void> Function()? onStartOver,
  }) async {
    var startOvers = 0;
    await tester.pumpWidget(
      LocalDataLockedApp(
        onRetry: onRetry ?? () {},
        onStartOver:
            onStartOver ??
            () async {
              startOvers++;
            },
      ),
    );
    return () => startOvers;
  }

  testWidgets('renders the title and explanation', (tester) async {
    await pump(tester);
    expect(find.text(LocalDataLockedApp.title), findsOneWidget);
    expect(find.text(LocalDataLockedApp.explanation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Försök igen" retries and deletes nothing', (tester) async {
    var retries = 0;
    final startOvers = await pump(tester, onRetry: () => retries++);
    await tester.tap(find.text(LocalDataLockedApp.retryLabel));
    await tester.pump();
    expect(retries, 1);
    expect(startOvers(), 0);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final startOvers = await pump(tester);
    await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
    await tester.pumpAndSettle();
    expect(find.text(LocalDataLockedApp.confirmBody), findsOneWidget);
    await tester.tap(find.text(LocalDataLockedApp.cancelLabel));
    await tester.pumpAndSettle();
    expect(startOvers(), 0);
  });

  testWidgets('confirming starts over once', (tester) async {
    final startOvers = await pump(tester);
    await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LocalDataLockedApp.confirmLabel));
    // Not pumpAndSettle: the button keeps its spinner until main() replaces
    // the whole app.
    await tester.pump();
    await tester.pump();
    expect(startOvers(), 1);
  });

  testWidgets('a failed start-over says so and can be tried again', (
    tester,
  ) async {
    await pump(
      tester,
      onStartOver: () async => throw StateError('file busy'),
    );
    await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LocalDataLockedApp.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.text(LocalDataLockedApp.startOverFailed), findsOneWidget);
    expect(find.textContaining('file busy'), findsNothing);

    await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
    await tester.pumpAndSettle();
    expect(find.text(LocalDataLockedApp.confirmTitle), findsOneWidget);
  });

  testWidgets(
    'a start that stops on the lock again leaves the buttons usable',
    (
      tester,
    ) async {
      final pending = Completer<void>();
      await pump(tester, onStartOver: () => pending.future);
      await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LocalDataLockedApp.confirmLabel));
      await tester.pump();
      await tester.pump();

      // What main does when the next start stops on the lock again.
      await pump(tester);
      await tester.pump();

      await tester.tap(find.text(LocalDataLockedApp.startOverLabel));
      await tester.pumpAndSettle();
      expect(find.text(LocalDataLockedApp.confirmTitle), findsOneWidget);
    },
  );
}
