/// Widget tests for ConfirmationDialogs.
///
/// Each test wires the dialog up via a Builder + button, so we can capture the
/// `Future<bool|String?>` the helper returns and assert it resolves to the
/// expected sentinel after the user taps confirm/cancel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Wraps a child in MaterialApp with the project's l10n delegates so the
/// dialogs can resolve `context.l10n.commonCancel` etc.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// Builds a trigger button that, when tapped, calls [openDialog] with the
/// surrounding BuildContext. The returned future is exposed so the test can
/// `await` it after the user taps confirm/cancel inside the dialog.
///
/// Pattern lifted from Flutter's own showDialog cookbook.
Widget _triggerButton<T>({
  required Future<T> Function(BuildContext) openDialog,
  required void Function(T) onResult,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () async {
        final result = await openDialog(ctx);
        onResult(result);
      },
      child: const Text('Show'),
    ),
  );
}

void main() {
  group('showConfirmationDialog', () {
    testWidgets('renders title, message, and confirm button label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) => ConfirmationDialogs.showConfirmationDialog(
              ctx,
              title: 'Bekräfta',
              message: 'Är du säker?',
              confirmText: 'Ja, gör det',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Bekräfta'), findsOneWidget);
      expect(find.text('Är du säker?'), findsOneWidget);
      expect(find.text('Ja, gör det'), findsOneWidget);
    });

    testWidgets('default cancel label is the localized Avbryt', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) => ConfirmationDialogs.showConfirmationDialog(
              ctx,
              confirmText: 'Bekräfta',
              title: 't',
              message: 'm',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Swedish locale → commonCancel resolves to "Avbryt"
      expect(find.text('Avbryt'), findsOneWidget);
    });

    testWidgets('custom cancelText is used instead of the localized default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) => ConfirmationDialogs.showConfirmationDialog(
              ctx,
              confirmText: 'Bekräfta',
              title: 't',
              message: 'm',
              cancelText: 'Nej tack',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Nej tack'), findsOneWidget);
      expect(find.text('Avbryt'), findsNothing);
    });

    testWidgets('confirm tap resolves the future with true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) => ConfirmationDialogs.showConfirmationDialog(
              ctx,
              title: 't',
              message: 'm',
              confirmText: 'Bekräfta',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bekräfta'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel tap resolves the future with false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) => ConfirmationDialogs.showConfirmationDialog(
              ctx,
              confirmText: 'Bekräfta',
              title: 't',
              message: 'm',
              cancelText: 'Avbryt',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      // ?? false converts null pop into a concrete false
      expect(result, isFalse);
    });
  });

  group('showDestructiveConfirmationDialog', () {
    testWidgets('renders the title and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showDestructiveConfirmationDialog(
                  ctx,
                  title: 'Radera receptet?',
                  message: 'Detta kan inte ångras',
                  confirmText: 'Radera receptet',
                ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Radera receptet?'), findsOneWidget);
      // The helper passes no item name, so nothing may follow the message
      // (BUT-2164: it used to end in ' ""?').
      expect(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          return w.text.toPlainText() == 'Detta kan inte ångras';
        }),
        findsOneWidget,
      );
    });

    testWidgets('confirm tap resolves the future with true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showDestructiveConfirmationDialog(
                  ctx,
                  title: 'Radera',
                  message: 'Säkert?',
                  confirmText: 'Ta bort',
                ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel tap resolves the future with false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showDestructiveConfirmationDialog(
                  ctx,
                  title: 'Radera',
                  message: 'Säkert?',
                  confirmText: 'Radera receptet',
                  cancelText: 'Avbryt',
                ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('showLoadingConfirmationDialog', () {
    // The indeterminate plate line runs an infinite animation, so
    // pumpAndSettle would never return. Use bounded pumps + small delay
    // to drive the showDialog scale animation past its 150ms barrier.
    Future<void> openAndPump(WidgetTester tester) async {
      await tester.tap(find.text('Show'));
      await tester.pump(); // start dialog route
      await tester.pump(const Duration(milliseconds: 300)); // past anim
    }

    testWidgets('renders title, message, hint, and the plate line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showLoadingConfirmationDialog(
                  ctx,
                  title: 'Vänta',
                  message: 'Det kan dröja',
                ),
            onResult: (_) {},
          ),
        ),
      );
      await openAndPump(tester);

      expect(find.text('Vänta'), findsOneWidget);
      expect(find.text('Det kan dröja'), findsOneWidget);
      // Swedish locale → dialogMayTakeAWhile = "Detta kan ta en stund …" (content-style-guide.md:63)
      expect(find.text('Detta kan ta en stund …'), findsOneWidget);
      expect(find.byType(PlateLine), findsOneWidget);
    });

    testWidgets('default action labels come from l10n', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showLoadingConfirmationDialog(
                  ctx,
                  title: 't',
                  message: 'm',
                ),
            onResult: (_) {},
          ),
        ),
      );
      await openAndPump(tester);

      // commonCancel + commonContinue
      expect(find.text('Avbryt'), findsOneWidget);
      expect(find.text('Fortsätt'), findsOneWidget);
    });

    testWidgets('custom button labels override defaults', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showLoadingConfirmationDialog(
                  ctx,
                  title: 't',
                  message: 'm',
                  confirmText: 'Kör',
                  cancelText: 'Stopp',
                ),
            onResult: (_) {},
          ),
        ),
      );
      await openAndPump(tester);

      expect(find.text('Kör'), findsOneWidget);
      expect(find.text('Stopp'), findsOneWidget);
      expect(find.text('Fortsätt'), findsNothing);
      expect(find.text('Avbryt'), findsNothing);
    });

    testWidgets('confirm tap resolves the future with true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showLoadingConfirmationDialog(
                  ctx,
                  title: 't',
                  message: 'm',
                  confirmText: 'Kör',
                ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await openAndPump(tester);

      await tester.tap(find.text('Kör'));
      // Dismiss animation also won't settle (spinner alive until popped) -
      // bounded pumps suffice for the future to resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isTrue);
    });

    testWidgets('cancel tap resolves the future with false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool>(
            openDialog: (ctx) =>
                ConfirmationDialogs.showLoadingConfirmationDialog(
                  ctx,
                  title: 't',
                  message: 'm',
                  cancelText: 'Stopp',
                ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await openAndPump(tester);

      await tester.tap(find.text('Stopp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isFalse);
    });
  });

  group('showTextInputDialog', () {
    testWidgets('renders title, hint, and a focused text field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
              ctx,
              confirmText: 'Spara',
              title: 'Namnge',
              hintText: 'Skriv något',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Namnge'), findsOneWidget);
      expect(find.text('Skriv något'), findsOneWidget); // hint
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('initialValue prefills the controller', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
              ctx,
              confirmText: 'Spara',
              title: 't',
              initialValue: 'förvalt',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'förvalt');
    });

    testWidgets('confirm tap returns the trimmed entered text', (tester) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
              ctx,
              title: 't',
              confirmText: 'Spara',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Whitespace at the edges should be trimmed off by the helper.
      await tester.enterText(find.byType(TextField), '  Hej världen  ');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(result, 'Hej världen');
    });

    testWidgets('cancel tap resolves the future with null', (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
              ctx,
              confirmText: 'Spara',
              title: 't',
              cancelText: 'Avbryt',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'will be discarded');
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets(
      'isRequired blocks confirm when the entered text is empty/whitespace',
      (tester) async {
        String? result = 'untouched';
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            _triggerButton<String?>(
              openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
                ctx,
                title: 't',
                confirmText: 'Spara',
                isRequired: true,
              ),
              onResult: (v) {
                result = v;
                resolved = true;
              },
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Empty (well, only whitespace) — confirm should be a no-op.
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('Spara'));
        await tester.pumpAndSettle();

        // Dialog must still be on screen and the future must not have resolved.
        expect(find.byType(TextField), findsOneWidget);
        expect(resolved, isFalse);
        expect(result, 'untouched');
      },
    );

    testWidgets('maxLength is forwarded to the underlying TextField', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => ConfirmationDialogs.showTextInputDialog(
              ctx,
              confirmText: 'Spara',
              title: 't',
              maxLength: 12,
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 12);
    });
  });
}
