/// Widget tests for RetagProgressDialog.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

Future<void> _showDialog(
  WidgetTester tester, {
  required Future<int> Function(void Function(int, int)) retagFn,
}) async {
  await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
    return ElevatedButton(
      onPressed: () => showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => RetagProgressDialog(retagFunction: retagFn),
      ),
      child: const Text('Open'),
    );
  })));
  await tester.tap(find.text('Open'));
  await tester.pump(); // Show dialog frame
}

void main() {
  group('RetagProgressDialog — initial render', () {
    testWidgets('renders title with sync icon', (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      // Cleanup: complete the future so the dialog drains
      completer.complete(0);
      await tester.pumpAndSettle();
    });

    testWidgets('shows linear progress indicator', (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      completer.complete(0);
      await tester.pumpAndSettle();
    });

    testWidgets('cancel button is enabled while running', (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      // The Avbryt button should be tappable
      final btn = tester.widget<TextButton>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ));
      expect(btn.onPressed, isNotNull);
      completer.complete(0);
      await tester.pumpAndSettle();
    });
  });

  group('RetagProgressDialog — progress updates', () {
    testWidgets('LinearProgressIndicator is indeterminate when total=0',
        (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      final lpi = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(lpi.value, isNull);
      completer.complete(0);
      await tester.pumpAndSettle();
    });

    testWidgets('LinearProgressIndicator value updates as progress reports',
        (tester) async {
      final completer = Completer<int>();
      void Function(int, int)? captured;
      await _showDialog(tester, retagFn: (onProgress) {
        captured = onProgress;
        return completer.future;
      });
      captured!(3, 10);
      await tester.pump();
      final lpi = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(lpi.value, closeTo(0.3, 0.001));
      completer.complete(3);
      await tester.pumpAndSettle();
    });
  });

  group('RetagProgressDialog — completion', () {
    testWidgets('completes → dialog pops and snackbar shows the count',
        (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      completer.complete(7);
      await tester.pumpAndSettle();
      // Dialog gone
      expect(find.byType(AlertDialog), findsNothing);
      // Snackbar visible
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('RetagProgressDialog — error', () {
    testWidgets('error → dialog stays open with Close button + error text',
        (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      completer.completeError(Exception('retag failed'));
      await tester.pumpAndSettle();
      // Dialog still visible
      expect(find.byType(AlertDialog), findsOneWidget);
      // Error message
      expect(find.textContaining('retag failed'), findsOneWidget);
      // No LinearProgressIndicator (error path replaces it)
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('error close button pops the dialog', (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      completer.completeError(Exception('failed'));
      await tester.pumpAndSettle();
      // Tap the close button (only TextButton in error branch)
      final btn = tester.widget<TextButton>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ));
      expect(btn.onPressed, isNotNull);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('RetagProgressDialog — cancel during run', () {
    testWidgets('cancel taps pop the dialog before completion', (tester) async {
      final completer = Completer<int>();
      await _showDialog(tester, retagFn: (onProgress) => completer.future);
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      // Drain the pending future without further updates
      completer.complete(0);
      // No snackbar because dialog was already cancelled (unmounted before pop call)
      // Don't pumpAndSettle here — would re-trigger the success path on the
      // unmounted state. Just pump once.
      await tester.pump();
    });
  });
}
