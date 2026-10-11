/// Intent-driven unit tests for `DialogFactory`: confirmation, feedback,
/// interactive, error, loading and text-input dialogs used by call sites that
/// don't go through `CommonDialogActions`.
///
/// `showConfirmation` (BUT-2366): `isDangerous` draws the shared
/// `DestructiveConfirmationDialog`, otherwise a `ConfirmationDialog`; the
/// confirm label is the caller's and cancel falls back to `commonCancel`.
///
/// Production bug surface note (do NOT fix here): `showFeedback` and
/// `showTextInput` allocate a `TextEditingController` per call and never
/// dispose it, so each invocation leaks one controller. The tests below
/// cannot observe the leak; the fix is a small StatefulWidget per method that
/// owns and disposes the controller.
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
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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

  group('showFeedback', () {
    /// Proves: tapping the confirm action resolves with the controller's
    /// current text — what the user actually typed.
    testWidgets('confirm tap → future resolves with the typed text', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showFeedback(
              ctx,
              title: 'Skriv feedback',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Det var bra!');
      await tester.tap(find.widgetWithText(TextButton, 'Skicka'));
      await tester.pumpAndSettle();

      expect(
        result,
        'Det var bra!',
        reason:
            'showFeedback must surface the typed text verbatim — '
            'returning empty/null would silently drop the user feedback.',
      );
    });

    /// Proves: tapping cancel resolves the future to null — the contract
    /// callers use to detect "user dismissed without sending feedback."
    testWidgets('cancel tap → future resolves null', (tester) async {
      String? sentinel = 'unchanged';
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showFeedback(ctx, title: 't'),
            onResult: (v) {
              sentinel = v;
              resolved = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(
        sentinel,
        isNull,
        reason:
            'cancel button calls '
            'Navigator.pop() with no args → resolves to null. Callers '
            'rely on this to distinguish "no feedback" from "empty feedback."',
      );
    });

    /// Proves: `initialValue` pre-populates the text field so the
    /// user can edit existing feedback rather than retyping.
    testWidgets('initialValue pre-fills the text field', (tester) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showFeedback(
              ctx,
              title: 't',
              initialValue: 'tidigare svar',
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Without typing anything, confirm should return the initialValue.
      await tester.tap(find.widgetWithText(TextButton, 'Skicka'));
      await tester.pumpAndSettle();

      expect(result, 'tidigare svar');
    });

    /// Proves: default confirm label falls back to the localized
    /// `commonSend` ("Skicka" in Swedish), default cancel falls back to
    /// `commonCancel`. Catches l10n key drift.
    testWidgets('default confirm = Skicka, default cancel = Avbryt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showFeedback(ctx, title: 't'),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Skicka'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
    });
  });

  group('showInteractive<T>', () {
    /// Proves: typed generic round-trip — Navigator.pop(ctx, value) with a
    /// String value resolves the Future<String?>. Catches a regression
    /// where someone removes the `<T>` and dialogs lose their typed
    /// result channel.
    testWidgets('typed result round-trips through Navigator.pop', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _triggerButton<String?>(
            openDialog: (ctx) => DialogFactory.showInteractive<String>(
              ctx,
              title: 'Välj',
              content: const Text('content'),
              actions: [
                Builder(
                  builder: (dctx) {
                    return TextButton(
                      onPressed: () => Navigator.pop(dctx, 'pickedValue'),
                      child: const Text('Pick'),
                    );
                  },
                ),
              ],
            ),
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Pick'));
      await tester.pumpAndSettle();

      expect(result, 'pickedValue');
    });

    /// Proves: when `title` is null, the AlertDialog's `title` slot is
    /// also null — the layout should not crash and should not render a
    /// stray empty Text widget. Catches the bug class where a null guard
    /// is replaced with `Text(title ?? '')`.
    testWidgets('title=null → AlertDialog.title is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) => DialogFactory.showInteractive<void>(
              ctx,
              content: const Text('just content'),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        dialog.title,
        isNull,
        reason:
            'When title is null, the dialog must omit the title slot '
            'entirely (line 130) — rendering Text("") would push the '
            'content down by a phantom row of padding.',
      );
      expect(find.text('just content'), findsOneWidget);
    });

    /// Proves: the `content` widget is the one the caller passed in —
    /// not wrapped in a Padding/Container that would swallow gesture
    /// detectors or mess with sizing.
    testWidgets(
      'content widget is forwarded verbatim into AlertDialog.content',
      (tester) async {
        const key = ValueKey('interactive-content');
        await tester.pumpWidget(
          _wrap(
            _triggerButton<void>(
              openDialog: (ctx) => DialogFactory.showInteractive<void>(
                ctx,
                title: 't',
                content: const SizedBox(key: key, width: 100, height: 100),
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect((dialog.content as SizedBox).key, key);
      },
    );

    /// Proves: `actions: null` is forwarded as null (not coerced to [])
    /// — AlertDialog renders no action row at all.
    testWidgets('actions=null → AlertDialog.actions is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) => DialogFactory.showInteractive<void>(
              ctx,
              title: 't',
              content: const Text('c'),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.actions, isNull);
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

  group('showLoading', () {
    /// Proves: default message is the localized `dialogLoading` ("Laddar …").
    /// Catches the regression where the loading text is hardcoded.
    /// Note: cannot use `pumpAndSettle` because the CircularProgressIndicator
    /// animation never settles — use a couple of `pump` cycles instead.
    testWidgets('default message = localized dialogLoading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) => DialogFactory.showLoading(ctx),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(); // start the showDialog future
      await tester.pump(const Duration(milliseconds: 300)); // run dialog open

      expect(find.text('Laddar …'), findsOneWidget);
      // Plate line plus text, never a spinner (produktregler.md:163).
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    /// Proves: custom message overrides the default.
    testWidgets('custom message overrides the default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton<void>(
            openDialog: (ctx) =>
                DialogFactory.showLoading(ctx, message: 'Sparar recept...'),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sparar recept...'), findsOneWidget);
      expect(find.text('Laddar …'), findsNothing);
    });

    /// Proves: the loading dialog is NOT barrier-dismissible — a user
    /// tapping outside should NOT be able to cancel an in-flight load
    /// operation, otherwise the underlying operation continues but the
    /// UI thinks it's done. This is THE critical contract for this dialog.
    testWidgets(
      'is NOT barrier-dismissible (user cannot tap-outside to cancel)',
      (tester) async {
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            _triggerButton<void>(
              openDialog: (ctx) async {
                await DialogFactory.showLoading(ctx, message: 'wait...');
              },
              onResult: (_) => resolved = true,
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('wait...'), findsOneWidget);

        // Tap on the modal barrier — should be ignored.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          resolved,
          isFalse,
          reason:
              'showLoading sets barrierDismissible=false at '
              'dialog_factory.dart:190 — flipping it to true (or omitting it, '
              'which defaults to true) would let users dismiss in-flight '
              'loaders and cause "ghost in-progress" bugs.',
        );
        expect(
          find.text('wait...'),
          findsOneWidget,
          reason: 'loading dialog should still be visible after barrier tap',
        );
      },
    );
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
      await tester.tap(find.widgetWithText(TextButton, 'Spara'));
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
        await tester.tap(find.widgetWithText(TextButton, 'Spara'));
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
        await tester.tap(find.widgetWithText(TextButton, 'Spara'));
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
      await tester.tap(find.widgetWithText(TextButton, 'Spara'));
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

      await tester.tap(find.widgetWithText(TextButton, 'Spara'));
      await tester.pumpAndSettle();

      expect(result, 'Pasta');
    });
  });
}
