// The one Avbryt of every dialog: the default name, closing with null, and
// the off state a dialog uses while its primary action works.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

Future<void> _openDialog(
  WidgetTester tester,
  DialogCancelButton button, {
  required void Function(Object? result) onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<Object?>(
                context: context,
                builder: (_) => AlertDialog(actions: [button]),
              );
              onClosed(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('is named Avbryt and closes the dialog with null', (
    tester,
  ) async {
    var closed = false;
    Object? result = 'unset';
    await _openDialog(
      tester,
      const DialogCancelButton(),
      onClosed: (r) {
        closed = true;
        result = r;
      },
    );

    expect(find.text('Avbryt'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DialogCancelButton),
        matching: find.byType(TextButton),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a label replaces the name', (tester) async {
    await _openDialog(
      tester,
      const DialogCancelButton(label: 'Vänta på synk'),
      onClosed: (_) {},
    );

    expect(find.text('Vänta på synk'), findsOneWidget);
    expect(find.text('Avbryt'), findsNothing);
  });

  testWidgets('an onPressed replaces closing with null', (tester) async {
    var taps = 0;
    Object? result = 'unset';
    late BuildContext dialogContext;
    await _openDialog(
      tester,
      DialogCancelButton(
        onPressed: () {
          taps++;
          Navigator.pop(dialogContext, false);
        },
      ),
      onClosed: (r) => result = r,
    );
    dialogContext = tester.element(find.byType(AlertDialog));

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(result, isFalse);
  });

  testWidgets('enabled: false leaves the dialog open and the button off', (
    tester,
  ) async {
    var closed = false;
    await _openDialog(
      tester,
      const DialogCancelButton(enabled: false),
      onClosed: (_) => closed = true,
    );

    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(DialogCancelButton),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Avbryt'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('enabled: false wins over an onPressed', (tester) async {
    var taps = 0;
    await _openDialog(
      tester,
      DialogCancelButton(enabled: false, onPressed: () => taps++),
      onClosed: (_) {},
    );

    await tester.tap(find.text('Avbryt'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });
}
