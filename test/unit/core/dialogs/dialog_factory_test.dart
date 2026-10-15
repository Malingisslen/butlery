/// Intent-driven unit tests for `DialogFactory`: confirmation, error and
/// text-input dialogs used by call sites that don't go through
/// `CommonDialogActions`.
///
/// `showConfirmation` (BUT-2366): `isDangerous` draws the shared
/// `DestructiveConfirmationDialog`, otherwise a `ConfirmationDialog`; the
/// confirm label is the caller's and cancel falls back to `commonCancel`.
///
/// Production bug surface note (do NOT fix here): `showTextInput` allocates a
/// `TextEditingController` per call and never disposes it, so each invocation
/// leaks one controller. The tests below cannot observe the leak; the fix is a
/// small StatefulWidget that owns and disposes the controller.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// MaterialApp wrapper with l10n delegates so dialogs can resolve
/// `context.l10n.commonCancel` etc. Defaults to Swedish to match production.
Widget _wrap(Widget child, {Locale locale = const Locale('sv')}) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: Scaffold(body: child),
);

/// Trigger button that opens the dialog and exposes its resolved future to
/// the test via [onResult]. Lifted from sibling
/// `common_dialog_actions_test.dart`.
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
      child: const Text('Open'),
    ),
  );
}

void main() {
  group('showConfirmation', () {
    Finder confirmButton(String label) => find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<FilledButton>(),
    );

    Future<void> open(
      WidgetTester tester, {
      String confirmText = 'Ja',
      String? cancelText,
      bool isDangerous = false,
      IconData dangerIcon = ButleryIcons.trash2,
      void Function(bool?)? onResult,
    }) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<bool?>(
            openDialog: (ctx) => DialogFactory.showConfirmation(
              ctx,
              title: 'Radera konto?',
              message: 'Detta går inte att ångra.',
              confirmText: confirmText,
              cancelText: cancelText,
              isDangerous: isDangerous,
              dangerIcon: dangerIcon,
            ),
            onResult: onResult ?? (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('isDangerous draws the destructive dialog', (tester) async {
      await open(tester, isDangerous: true);

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('the confirm button carries the trash glyph unless told '
        'otherwise', (tester) async {
      await open(tester, isDangerous: true);
      expect(
        find.descendant(
          of: confirmButton('Ja'),
          matching: find.byIcon(ButleryIcons.trash2),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dangerIcon replaces the trash glyph on the button', (
      tester,
    ) async {
      await open(tester, isDangerous: true, dangerIcon: ButleryIcons.logOut);
      expect(
        find.descendant(
          of: confirmButton('Ja'),
          matching: find.byIcon(ButleryIcons.logOut),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(ButleryIcons.trash2), findsNothing);
    });

    testWidgets('not dangerous draws the plain confirmation dialog', (
      tester,
    ) async {
      await open(tester);

      expect(find.byType(ConfirmationDialog), findsOneWidget);
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    });

    for (final dangerous in [false, true]) {
      testWidgets('confirm tap resolves true (dangerous: $dangerous)', (
        tester,
      ) async {
        bool? result;
        await open(tester, isDangerous: dangerous, onResult: (v) => result = v);

        await tester.tap(confirmButton('Ja'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      });

      testWidgets('cancel tap does not resolve true (dangerous: $dangerous)', (
        tester,
      ) async {
        bool? result;
        var resolved = false;
        await open(
          tester,
          isDangerous: dangerous,
          onResult: (v) {
            result = v;
            resolved = true;
          },
        );

        await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
        await tester.pumpAndSettle();

        expect(resolved, isTrue);
        expect(result, isNot(true));
      });
    }

    testWidgets('confirm label comes from the caller, cancel from l10n', (
      tester,
    ) async {
      await open(tester, confirmText: 'Radera kontot');

      expect(confirmButton('Radera kontot'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('a custom cancelText replaces the default', (tester) async {
      await open(tester, cancelText: 'Nej tack', isDangerous: true);

      expect(find.widgetWithText(TextButton, 'Nej tack'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsNothing);
    });

    testWidgets('iOS shows the Material dialog, not the Cupertino alert', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await open(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(confirmButton('Ja'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders title and message', (tester) async {
      await open(tester, isDangerous: true);

      expect(find.text('Radera konto?'), findsOneWidget);
      expect(
        find.text('Detta går inte att ångra.', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('showError', () {
    /// Proves: default title falls back to localized `dialogErrorTitle`
    /// and default button to `commonClose` ("Stäng", never "OK";
    /// content-style-guide.md:77). Catches the regression where
    /// someone hardcodes the title.
    testWidgets('default title + button labels come from l10n', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) => DialogFactory.showError(
              ctx,
              message: 'Något gick snett',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Det gick inte att slutföra'), findsOneWidget);
      expect(find.text('Något gick snett'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Stäng'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'OK'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Stäng'));
      await tester.pumpAndSettle();
    });

    /// Proves: tapping Stäng dismisses the dialog AND completes the future
    /// — info dialogs need to unblock awaiting callers.
    testWidgets('Stäng tap dismisses the dialog and resolves the await', (
      tester,
    ) async {
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) async {
              await DialogFactory.showError(ctx, message: 'm');
            },
            onResult: (_) => resolved = true,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        resolved,
        isFalse,
        reason: 'await should still be pending while dialog is open',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Stäng'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      // Both AlertDialog and CupertinoAlertDialog should be gone.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    /// Proves: custom title + buttonText overrides win over the l10n
    /// defaults. The contract is "caller's value first, then l10n
    /// fallback" — flipping the order would silently ignore caller intent.
    testWidgets('custom title and buttonText override the l10n defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) => DialogFactory.showError(
              ctx,
              title: 'Anpassat fel',
              message: 'msg',
              buttonText: 'Tillbaka',
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Anpassat fel'), findsOneWidget);
      expect(find.text('Det gick inte att slutföra'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Tillbaka'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Stäng'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Tillbaka'));
      await tester.pumpAndSettle();
    });

    /// Proves: on iOS the error dialog is the Material dialog with "Stäng",
    /// never the Cupertino alert (plattformsmatris.md:73-75).
    testWidgets('iOS shows the Material error dialog with Stäng', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _wrap(
            _triggerButton<void>(
              openDialog: (ctx) => DialogFactory.showError(ctx, message: 'm'),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(find.widgetWithText(TextButton, 'Stäng'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('showTextInput', () {
    /// Proves: typing text and tapping confirm resolves with the typed
    /// value (trimmed). Catches the bug where the helper returns the
    /// controller reference or always returns null.
    testWidgets('confirm with typed text → future resolves with trimmed text', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showTextInput(
              ctx,
              confirmText: 'Spara',
              title: 'Skriv namn',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Leading/trailing whitespace should be trimmed.
      await tester.enterText(find.byType(StyledInput), '  Anna  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
      await tester.pumpAndSettle();

      expect(
        result,
        'Anna',
        reason:
            'showTextInput must trim() before resolving — otherwise '
            'callers get whitespace-padded values and "Anna" != "Anna ".',
      );
    });

    /// Proves: confirming with empty (or whitespace-only) text and
    /// `required: false` resolves the future to null, NOT empty string.
    /// Callers commonly use `if (result != null) save(result)` and would
    /// silently save empty values if this returned ''.
    testWidgets(
      'confirm with empty/whitespace text + required:false → resolves null',
      (tester) async {
        String? sentinel = 'unchanged';
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            _triggerButton<String?>(
              openDialog: (ctx) => DialogFactory.showTextInput(
                ctx,
                title: 't',
                confirmText: 'Spara',
              ),
              onResult: (v) {
                sentinel = v;
                resolved = true;
              },
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(StyledInput), '   ');
        await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
        await tester.pumpAndSettle();

        expect(resolved, isTrue);
        expect(
          sentinel,
          isNull,
          reason:
              'dialog_factory.dart:266 returns null when trimmed text '
              'is empty — flipping this to return "" silently saves blanks.',
        );
      },
    );

    /// Proves: `required: true` makes the confirm button a NO-OP when
    /// the trimmed text is empty — the dialog stays open and the user
    /// must type something. This is the input-validation invariant.
    /// Critical bug class: if the early-return ever turns into pop(),
    /// required fields silently accept empty input.
    testWidgets(
      'required:true + empty text → confirm tap is a no-op, dialog stays open',
      (tester) async {
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            _triggerButton<String?>(
              openDialog: (ctx) => DialogFactory.showTextInput(
                ctx,
                confirmText: 'Spara',
                title: 'Krävs',
                required: true,
              ),
              onResult: (_) => resolved = true,
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Don't type anything. Tap confirm.
        await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
        await tester.pumpAndSettle();

        expect(
          resolved,
          isFalse,
          reason:
              'required:true must block the empty submit — '
              'dialog_factory.dart:265 returns early before Navigator.pop.',
        );
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'dialog must still be visible when required-text is empty',
        );
      },
    );

    /// Proves: required:true does NOT block submission once the user
    /// actually types something. Inverse of the test above — catches
    /// the bug where required:true accidentally blocks ALL submissions.
    testWidgets('required:true + non-empty text → submits normally', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showTextInput(
              ctx,
              confirmText: 'Spara',
              title: 't',
              required: true,
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Hej');
      await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
      await tester.pumpAndSettle();

      expect(result, 'Hej');
    });

    /// Proves: tapping cancel resolves the future to null even if the
    /// user typed something — cancel discards input. Otherwise typed-then-
    /// cancelled text would leak into "saved" channels.
    testWidgets('cancel tap → future resolves null even after typing', (
      tester,
    ) async {
      String? sentinel = 'unchanged';
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showTextInput(
              ctx,
              title: 't',
              confirmText: 'Spara',
            ),
            onResult: (v) {
              sentinel = v;
              resolved = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Skräp');
      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(
        sentinel,
        isNull,
        reason:
            'Cancel must always resolve to null — typed-then-cancelled '
            'text should be discarded, never leaked to callers.',
      );
    });

    /// Proves: `initialValue` pre-fills the field so the user can edit
    /// existing content rather than retyping. Confirming without further
    /// typing should return the initial value.
    testWidgets('initialValue pre-fills the field', (tester) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showTextInput(
              ctx,
              confirmText: 'Spara',
              title: 't',
              initialValue: 'Pasta',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
      await tester.pumpAndSettle();

      expect(result, 'Pasta');
    });
  });
}
