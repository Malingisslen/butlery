/// BUT-900: focus-return-after-dialog-dismissal behaviour.
///
/// Intent: a keyboard / switch-access / screen-reader user who activates a
/// trigger control to open a dialog must, after the dialog closes, have input
/// focus returned to that trigger control — not dropped to nowhere (which makes
/// the next Tab restart from the top of the screen and leaves screen-reader
/// focus stranded on the dismissed dialog's last node).
///
/// The accessibility-focus return that TalkBack/VoiceOver perform rides on top
/// of Flutter's INPUT-focus restoration, and input focus IS assertable in a
/// widget test (FocusManager.primaryFocus). So this test pins the substrate the
/// manual screen-reader pass depends on, even though the screen-reader pass
/// itself stays manual.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'focus returns to the trigger button after a showDialog dialog closes',
    (tester) async {
      final triggerFocus = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocus.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              focusNode: triggerFocus,
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Dialog'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Simulate a keyboard / screen-reader user landing on the trigger.
      triggerFocus.requestFocus();
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        triggerFocus,
        reason: 'precondition: trigger should hold focus before opening',
      );

      // Open the dialog, then close it via its action button.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);

      // The contract: focus is back on the trigger.
      expect(
        FocusManager.instance.primaryFocus,
        triggerFocus,
        reason:
            'after the dialog closes, focus must return to the trigger button '
            'so keyboard/screen-reader users are not stranded',
      );
    },
  );

  testWidgets(
    'focus returns to the trigger after a showDialog dialog is '
    'barrier-dismissed (tap outside)',
    (tester) async {
      final triggerFocus = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocus.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              focusNode: triggerFocus,
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => const AlertDialog(title: Text('Dialog')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      triggerFocus.requestFocus();
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsOneWidget);

      // Barrier-dismiss: tap the modal barrier near the top-left corner, which
      // a centred AlertDialog never covers on the default 800x600 test surface.
      // The `findsNothing` check below also guards this: if the tap missed the
      // barrier the dialog would stay open and the test would fail there.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);

      expect(
        FocusManager.instance.primaryFocus,
        triggerFocus,
        reason:
            'barrier-dismiss must also return focus to the trigger, not strand '
            'it on the dismissed route',
      );
    },
  );

  testWidgets(
    'focus returns to the trigger after a showModalBottomSheet closes',
    (tester) async {
      final triggerFocus = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocus.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              focusNode: triggerFocus,
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                builder: (sheetCtx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Close sheet'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      triggerFocus.requestFocus();
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Close sheet'), findsOneWidget);

      await tester.tap(find.text('Close sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Close sheet'), findsNothing);

      expect(
        FocusManager.instance.primaryFocus,
        triggerFocus,
        reason:
            'after a bottom sheet closes, focus must return to the trigger '
            'control (bottom sheets use a different modal route than dialogs)',
      );
    },
  );

  // Guards the project's OWN shared dialog infrastructure, not just raw
  // showDialog: ConfirmationDialog.show (the BaseDialog family in base_dialog
  // .dart) is the most-used confirm path in the app. If a future refactor swaps
  // its showDialog for a custom Navigator route that doesn't restore focus, this
  // case fails — catching a real a11y regression at the choke point.
  testWidgets(
    'focus returns to the trigger after ConfirmationDialog.show closes',
    (tester) async {
      final triggerFocus = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocus.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              focusNode: triggerFocus,
              onPressed: () => ConfirmationDialog.show(
                ctx,
                title: 'Bekräfta',
                message: 'Är du säker?',
                primaryActionText: 'OK',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      triggerFocus.requestFocus();
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Bekräfta'), findsOneWidget);

      // Close via the cancel button (sv default "Avbryt").
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(find.text('Bekräfta'), findsNothing);

      expect(
        FocusManager.instance.primaryFocus,
        triggerFocus,
        reason:
            "the app's shared ConfirmationDialog must preserve focus return so "
            'every call site inherits the contract',
      );
    },
  );
}
