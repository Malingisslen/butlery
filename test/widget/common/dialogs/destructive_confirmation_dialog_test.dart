// BUT-2366: the one confirmation before something is deleted, removed or
// left. These tests pin what a user sees and what a tap resolves to.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

final _sv = AppLocalizationsSv();

class _Harness {
  bool? result;
  bool resolved = false;
}

Future<_Harness> _open(
  WidgetTester tester, {
  ThemeData? theme,
  String message = '',
  String itemName = '',
  String? warning,
  bool irreversible = false,
  Future<void> Function()? onConfirm,
  String confirmText = 'Radera receptet',
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              harness.result = await DestructiveConfirmationDialog.show(
                context,
                title: 'Radera receptet?',
                message: message,
                itemName: itemName,
                warning: warning,
                irreversible: irreversible,
                onConfirm: onConfirm,
                primaryActionText: confirmText,
              );
              harness.resolved = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

Finder _primaryButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<FilledButton>(),
);

void main() {
  group('message and item name', () {
    testWidgets('the item name follows the message, quoted and bold', (
      tester,
    ) async {
      await _open(tester, message: 'Vill du radera', itemName: 'Pasta');

      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Pasta'),
        ),
      );
      expect(rich.text.toPlainText(), 'Vill du radera ”Pasta”?');

      final spans = <TextSpan>[];
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
      final messageSpan = spans.firstWhere((s) => s.text == 'Vill du radera');
      final nameSpan = spans.firstWhere((s) => s.text!.contains('Pasta'));
      expect(
        nameSpan.style!.fontWeight!.value,
        greaterThan(messageSpan.style?.fontWeight?.value ?? 400),
      );
    });

    testWidgets('a name without a message is still quoted, with no "?"', (
      tester,
    ) async {
      await _open(tester, itemName: 'Pasta');

      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '”Pasta”',
        ),
        findsOneWidget,
      );
    });
  });

  group('button', () {
    testWidgets('carries the text the caller named', (tester) async {
      await _open(tester, confirmText: 'Ta bort som vän');

      expect(_primaryButton('Ta bort som vän'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('is error on onError in ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await _open(
          tester,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        );
        final cs = Theme.of(
          tester.element(find.byType(AlertDialog)),
        ).colorScheme;

        final style = tester
            .widget<FilledButton>(_primaryButton('Radera receptet'))
            .style!;
        expect(style.backgroundColor!.resolve({}), cs.error);
        expect(style.foregroundColor!.resolve({}), cs.onError);
      });
    }
  });

  group('lines under the message', () {
    testWidgets('the irreversible line shows only when irreversible', (
      tester,
    ) async {
      await _open(tester, message: 'Vill du radera', irreversible: true);
      expect(find.text(_sv.deleteActionIrreversible), findsOneWidget);
    });

    testWidgets('no irreversible line by default', (tester) async {
      await _open(tester, message: 'Vill du radera');
      expect(find.text('Vill du radera', findRichText: true), findsOneWidget);
      expect(find.text(_sv.deleteActionIrreversible), findsNothing);
    });

    testWidgets('the warning is shown', (tester) async {
      await _open(tester, message: 'Vill du radera', warning: 'OBS: farligt');
      expect(find.text('OBS: farligt'), findsOneWidget);
    });
  });

  group('answering', () {
    testWidgets('confirm without onConfirm pops true', (tester) async {
      final h = await _open(tester);

      await tester.tap(_primaryButton('Radera receptet'));
      await tester.pumpAndSettle();

      expect(h.result, isTrue);
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    });

    testWidgets('confirm runs onConfirm once, then pops true', (tester) async {
      var calls = 0;
      final h = await _open(tester, onConfirm: () async => calls++);

      await tester.tap(_primaryButton('Radera receptet'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(h.result, isTrue);
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    });

    testWidgets('cancel pops without a yes and never runs onConfirm', (
      tester,
    ) async {
      var calls = 0;
      final h = await _open(tester, onConfirm: () async => calls++);

      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      expect(h.resolved, isTrue);
      expect(h.result, isNull);
      expect(calls, 0);
    });
  });

  group('onConfirm in flight', () {
    testWidgets('the button keeps its label and a second tap does nothing', (
      tester,
    ) async {
      final gate = Completer<void>();
      var calls = 0;
      final h = await _open(
        tester,
        onConfirm: () {
          calls++;
          return gate.future;
        },
      );

      await tester.tap(_primaryButton('Radera receptet'));
      // The busy line animates, so a single pump rather than settling.
      await tester.pump();
      expect(find.text('Radera receptet'), findsOneWidget);

      await tester.tap(_primaryButton('Radera receptet'), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      expect(h.resolved, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(h.result, isTrue);
    });

    testWidgets('a tap outside does not close the dialog while it runs', (
      tester,
    ) async {
      final gate = Completer<void>();
      final h = await _open(tester, onConfirm: () => gate.future);

      await tester.tap(_primaryButton('Radera receptet'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(h.resolved, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(h.result, isTrue);
    });

    testWidgets('without onConfirm a tap outside closes it with no yes', (
      tester,
    ) async {
      final h = await _open(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
      expect(h.resolved, isTrue);
      expect(h.result, isNot(true));
    });
  });

  group('onConfirm throws', () {
    testWidgets('stays open with a plain error and Försök igen', (
      tester,
    ) async {
      final h = await _open(
        tester,
        onConfirm: () async => throw Exception('boom-secret'),
      );

      await tester.tap(_primaryButton('Radera receptet'));
      await tester.pumpAndSettle();

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.byType(InlineError), findsOneWidget);
      expect(find.text(_sv.dialogActionFailed), findsOneWidget);
      expect(find.text(_sv.commonRetry), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('boom-secret'), findsNothing);
      expect(h.resolved, isFalse);
    });

    testWidgets('Försök igen runs onConfirm again and can succeed', (
      tester,
    ) async {
      var calls = 0;
      final h = await _open(
        tester,
        onConfirm: () async {
          calls++;
          if (calls == 1) throw Exception('first');
        },
      );

      await tester.tap(_primaryButton('Radera receptet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.commonRetry));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(h.result, isTrue);
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    });
  });
}
