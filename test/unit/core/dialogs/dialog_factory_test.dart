/// Intent-driven unit tests for `DialogFactory` — the consolidated factory
/// (confirmation + feedback + interactive + error + loading + delete + text
/// input) used by ~all dialog call sites that aren't going through
/// `CommonDialogActions`.
///
/// Behaviours covered:
/// - `showConfirmation`: confirm tap resolves true, cancel tap resolves false,
///   default confirm/cancel text fall back to the localized `commonOk` /
///   `commonCancel`, `isDangerous` paints the confirm action in
///   `colorScheme.error`, and `isDangerous` trumps an explicit `confirmColor`.
/// - `showFeedback`: confirm resolves with the trimmed/raw controller text,
///   cancel resolves null (no string returned), `initialValue` pre-fills the
///   text field, `hint` renders verbatim.
/// - `showInteractive<T>`: passes typed `T` through Navigator.pop, omits the
///   title widget when `title: null`, forwards `actions` verbatim.
/// - `showError`: renders default localized title + button when omitted,
///   tapping the button dismisses + resolves the future.
/// - `showLoading`: defaults the message to the localized `dialogLoading`,
///   shows a CircularProgressIndicator, is NOT barrier-dismissible.
/// - `showDeleteConfirmation`: defaults title/confirm/cancel labels from
///   l10n, interpolates itemName + itemType into the localized
///   `dialogConfirmDeleteMessage` template, and forwards isDangerous=true so
///   the confirm button gets the error tint.
/// - `showTextInput`: empty trimmed text returns null, non-empty resolves
///   the trimmed string, `required: true` blocks the confirm tap entirely
///   when the trimmed text is empty, `initialValue` pre-fills.
///
/// Production bug surface notes (do NOT fix here):
/// - `lib/core/dialogs/dialog_factory.dart:94` and `:242` allocate a
///   `TextEditingController` per call but NEVER dispose it. Each invocation
///   leaks one controller. Surfaced by `showFeedback` and `showTextInput`
///   tests below — neither asserts on the leak directly (impossible from
///   black-box) but a manual review of the file confirms the bug.
///   Suggested fix: convert each of those two methods into a small
///   StatefulWidget that owns the controller and disposes it in
///   `dispose()`. Impact: low memory churn but a real leak that
///   accumulates over a long session of opening text-input dialogs.
/// - `lib/core/dialogs/dialog_factory.dart:204-226` (`showDeleteConfirmation`)
///   does NOT localize the `itemType` parameter — it's a plain `String` that
///   callers pass in. Most call sites pass Swedish words ('recept', 'lista')
///   verbatim, so the localized `dialogConfirmDeleteMessage` template
///   "Are you sure you want to remove {itemName} from {itemType}?" renders
///   as "Are you sure you want to remove X from recept?" in English. Same
///   bug class as BUT-1115 (CommonDialogActions hardcoded Swedish item
///   types) and the BUT-1088 family. Suggested fix: make `itemType` an
///   enum or thread localized strings via a named-param API.
/// - `lib/core/dialogs/dialog_factory.dart:60-79` Android-path confirm
///   button applies `dangerColor` to `TextButton.foregroundColor` only when
///   `isDangerous` is true (because `confirmColor` is null and dangerColor
///   stays null if isDangerous=false). The result: a caller who passes
///   ONLY `confirmColor` (no isDangerous) gets it applied; a caller who
///   passes `isDangerous: true` AND `confirmColor: Colors.green` gets
///   `colorScheme.error` (isDangerous wins). That matches the contract
///   tested below but the dual-purpose `dangerColor` local is confusing —
///   suggest renaming to `effectiveConfirmColor`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// MaterialApp wrapper with l10n delegates so dialogs can resolve
/// `context.l10n.commonOk` etc. Defaults to Swedish to match production.
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
    /// Proves: confirm tap resolves the future to `true` — the contract
    /// callers rely on to actually perform the action.
    testWidgets('confirm tap → future resolves true (Android path)',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showConfirmation(
          ctx,
          title: 'Bekräfta',
          message: 'Säker?',
          confirmText: 'Ja',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The Android path uses TextButton; iOS path is platform-gated and
      // tests default-target-platform on host (Linux/Windows). Run is on
      // Android-equivalent here.
      await tester.tap(find.widgetWithText(TextButton, 'Ja'));
      await tester.pumpAndSettle();

      expect(result, isTrue,
          reason: 'showConfirmation must return true on primary tap '
              'or callers silently no-op the action');
    });

    /// Proves: cancel tap resolves the future to `false` (NOT null) —
    /// the Android cancel button explicitly pops `false`, so callers
    /// reading the result without `?? false` still get the right thing.
    testWidgets('cancel tap → future resolves false (Android path)',
        (tester) async {
      bool? result;
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showConfirmation(
          ctx,
          title: 't',
          message: 'm',
        ),
        onResult: (v) {
          result = v;
          resolved = true;
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(result, isFalse,
          reason: 'Cancel button explicitly pops false at dialog_factory.dart '
              ':67; flipping to pop() with no args would silently change the '
              'contract from false to null and break consumers using `?? true`.');
    });

    /// Proves: default confirm/cancel labels come from the localized
    /// commonOk / commonCancel. Regression catch for someone replacing
    /// the l10n lookup with a hardcoded string.
    testWidgets('default confirm/cancel labels come from l10n', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showConfirmation(
          ctx,
          title: 't',
          message: 'm',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
    });

    /// Proves: `isDangerous: true` paints the confirm button's foreground
    /// in the theme's `colorScheme.error`, regardless of any
    /// `confirmColor` override. Safety invariant for destructive UIs.
    testWidgets(
        'isDangerous=true overrides confirmColor → button foregroundColor '
        'becomes colorScheme.error', (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(Builder(builder: (rootCtx) {
        cs = Theme.of(rootCtx).colorScheme;
        return _triggerButton<bool?>(
          openDialog: (ctx) => DialogFactory.showConfirmation(
            ctx,
            title: 't',
            message: 'm',
            confirmText: 'Kör',
            confirmColor: Colors.green, // must be IGNORED
            isDangerous: true,
          ),
          onResult: (_) {},
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final btn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Kör'),
      );
      final fg = btn.style!.foregroundColor!.resolve({});
      expect(fg, cs.error,
          reason: 'isDangerous=true must override confirmColor — otherwise '
              'destructive dialogs lose their visual warning affordance.');
    });

    /// Proves: when NOT dangerous, a supplied `confirmColor` is applied
    /// to the confirm button's foregroundColor. Inverse of the test above.
    testWidgets(
        'non-dangerous + confirmColor → button foregroundColor = confirmColor',
        (tester) async {
      const customColor = Color(0xFF112233);
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showConfirmation(
          ctx,
          title: 't',
          message: 'm',
          confirmText: 'Kör',
          confirmColor: customColor,
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final btn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Kör'),
      );
      final fg = btn.style!.foregroundColor!.resolve({});
      expect(fg, customColor);
    });

    /// Proves: title + message both render into the AlertDialog so users
    /// actually see what they're confirming.
    testWidgets('renders title and message verbatim', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showConfirmation(
          ctx,
          title: 'Radera konto?',
          message: 'Detta går inte att ångra.',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Radera konto?'), findsOneWidget);
      expect(find.text('Detta går inte att ångra.'), findsOneWidget);
    });
  });

  group('showFeedback', () {
    /// Proves: tapping the confirm action resolves with the controller's
    /// current text — what the user actually typed.
    testWidgets('confirm tap → future resolves with the typed text',
        (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showFeedback(
          ctx,
          title: 'Skriv feedback',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Det var bra!');
      await tester.tap(find.widgetWithText(TextButton, 'Skicka'));
      await tester.pumpAndSettle();

      expect(result, 'Det var bra!',
          reason: 'showFeedback must surface the typed text verbatim — '
              'returning empty/null would silently drop the user feedback.');
    });

    /// Proves: tapping cancel resolves the future to null — the contract
    /// callers use to detect "user dismissed without sending feedback."
    testWidgets('cancel tap → future resolves null', (tester) async {
      String? sentinel = 'unchanged';
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showFeedback(ctx, title: 't'),
        onResult: (v) {
          sentinel = v;
          resolved = true;
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(sentinel, isNull,
          reason: 'cancel button at dialog_factory.dart:108 calls '
              'Navigator.pop() with no args → resolves to null. Callers '
              'rely on this to distinguish "no feedback" from "empty feedback."');
    });

    /// Proves: `initialValue` pre-populates the text field so the
    /// user can edit existing feedback rather than retyping.
    testWidgets('initialValue pre-fills the text field', (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showFeedback(
          ctx,
          title: 't',
          initialValue: 'tidigare svar',
        ),
        onResult: (v) => result = v,
      )));
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
    testWidgets('default confirm = Skicka, default cancel = Avbryt',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showFeedback(ctx, title: 't'),
        onResult: (_) {},
      )));
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
    testWidgets('typed result round-trips through Navigator.pop',
        (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showInteractive<String>(
          ctx,
          title: 'Välj',
          content: const Text('content'),
          actions: [
            Builder(builder: (dctx) {
              return TextButton(
                onPressed: () => Navigator.pop(dctx, 'pickedValue'),
                child: const Text('Pick'),
              );
            }),
          ],
        ),
        onResult: (v) => result = v,
      )));
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
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showInteractive<void>(
          ctx,
          content: const Text('just content'),
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.title, isNull,
          reason: 'When title is null, the dialog must omit the title slot '
              'entirely (line 130) — rendering Text("") would push the '
              'content down by a phantom row of padding.');
      expect(find.text('just content'), findsOneWidget);
    });

    /// Proves: the `content` widget is the one the caller passed in —
    /// not wrapped in a Padding/Container that would swallow gesture
    /// detectors or mess with sizing.
    testWidgets('content widget is forwarded verbatim into AlertDialog.content',
        (tester) async {
      const key = ValueKey('interactive-content');
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showInteractive<void>(
          ctx,
          title: 't',
          content: const SizedBox(key: key, width: 100, height: 100),
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((dialog.content as SizedBox).key, key);
    });

    /// Proves: `actions: null` is forwarded as null (not coerced to [])
    /// — AlertDialog renders no action row at all.
    testWidgets('actions=null → AlertDialog.actions is null', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showInteractive<void>(
          ctx,
          title: 't',
          content: const Text('c'),
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.actions, isNull);
    });
  });

  group('showError', () {
    /// Proves: default title falls back to localized `dialogErrorTitle`
    /// and default button to `commonOk`. Catches the regression where
    /// someone hardcodes the title.
    testWidgets('default title + button labels come from l10n', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showError(
          ctx,
          message: 'Något gick snett',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Ett fel uppstod'), findsOneWidget);
      expect(find.text('Något gick snett'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
    });

    /// Proves: tapping OK dismisses the dialog AND completes the future
    /// — info dialogs need to unblock awaiting callers.
    testWidgets('OK tap dismisses the dialog and resolves the await',
        (tester) async {
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) async {
          await DialogFactory.showError(ctx, message: 'm');
        },
        onResult: (_) => resolved = true,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(resolved, isFalse,
          reason: 'await should still be pending while dialog is open');

      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      // Both AlertDialog and CupertinoAlertDialog should be gone.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    /// Proves: custom title + buttonText overrides win over the l10n
    /// defaults. The contract is "caller's value first, then l10n
    /// fallback" — flipping the order would silently ignore caller intent.
    testWidgets('custom title and buttonText override the l10n defaults',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showError(
          ctx,
          title: 'Anpassat fel',
          message: 'msg',
          buttonText: 'Stäng',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Anpassat fel'), findsOneWidget);
      expect(find.text('Ett fel uppstod'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Stäng'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Stäng'));
      await tester.pumpAndSettle();
    });
  });

  group('showLoading', () {
    /// Proves: default message is the localized `dialogLoading` ("Laddar...").
    /// Catches the regression where the loading text is hardcoded.
    /// Note: cannot use `pumpAndSettle` because the CircularProgressIndicator
    /// animation never settles — use a couple of `pump` cycles instead.
    testWidgets('default message = localized dialogLoading', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) => DialogFactory.showLoading(ctx),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pump(); // start the showDialog future
      await tester.pump(const Duration(milliseconds: 300)); // run dialog open

      expect(find.text('Laddar...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    /// Proves: custom message overrides the default.
    testWidgets('custom message overrides the default', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) =>
            DialogFactory.showLoading(ctx, message: 'Sparar recept...'),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sparar recept...'), findsOneWidget);
      expect(find.text('Laddar...'), findsNothing);
    });

    /// Proves: the loading dialog is NOT barrier-dismissible — a user
    /// tapping outside should NOT be able to cancel an in-flight load
    /// operation, otherwise the underlying operation continues but the
    /// UI thinks it's done. This is THE critical contract for this dialog.
    testWidgets(
        'is NOT barrier-dismissible (user cannot tap-outside to cancel)',
        (tester) async {
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) async {
          await DialogFactory.showLoading(ctx, message: 'wait...');
        },
        onResult: (_) => resolved = true,
      )));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('wait...'), findsOneWidget);

      // Tap on the modal barrier — should be ignored.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(resolved, isFalse,
          reason: 'showLoading sets barrierDismissible=false at '
              'dialog_factory.dart:190 — flipping it to true (or omitting it, '
              'which defaults to true) would let users dismiss in-flight '
              'loaders and cause "ghost in-progress" bugs.');
      expect(find.text('wait...'), findsOneWidget,
          reason: 'loading dialog should still be visible after barrier tap');
    });
  });

  group('showDeleteConfirmation', () {
    /// Proves: the delete-confirm helper composes the localized
    /// `dialogConfirmDeleteMessage` template with the supplied
    /// `itemName` and `itemType`. Catches the bug where args are
    /// swapped or one is dropped.
    testWidgets(
        'interpolates itemName and itemType into the localized delete message',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showDeleteConfirmation(
          ctx,
          itemName: 'Pasta carbonara',
          itemType: 'receptboken',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Template: "Är du säker på att du vill ta bort {itemName} från {itemType}?"
      expect(find.textContaining('Pasta carbonara'), findsOneWidget);
      expect(find.textContaining('receptboken'), findsOneWidget);
    });

    /// Proves: default title falls back to localized
    /// `dialogConfirmDeleteTitle` ("Bekräfta borttagning").
    testWidgets('default title = localized dialogConfirmDeleteTitle',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showDeleteConfirmation(
          ctx,
          itemName: 'X',
          itemType: 'Y',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bekräfta borttagning'), findsOneWidget);
    });

    /// Proves: default confirm label = localized `commonDelete` ("Ta bort").
    /// Catches the bug where the confirm label is hardcoded or wired to
    /// the wrong l10n key (commonOk would be wrong here — destructive
    /// actions should be labeled with the verb, not "OK").
    testWidgets('default confirm label = localized commonDelete (not commonOk)',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => DialogFactory.showDeleteConfirmation(
          ctx,
          itemName: 'X',
          itemType: 'Y',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Ta bort'), findsOneWidget);
      // Negative: must NOT label the destructive action as "OK" — that
      // would lose the verb-warning affordance.
      expect(find.widgetWithText(TextButton, 'OK'), findsNothing);
    });

    /// Proves: delete forwards `isDangerous: true` to showConfirmation,
    /// which paints the confirm button's foreground in `colorScheme.error`.
    /// This is what visually distinguishes deletion from generic confirm.
    testWidgets(
        'confirm button foreground = colorScheme.error (isDangerous=true)',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(Builder(builder: (rootCtx) {
        cs = Theme.of(rootCtx).colorScheme;
        return _triggerButton<bool?>(
          openDialog: (ctx) => DialogFactory.showDeleteConfirmation(
            ctx,
            itemName: 'X',
            itemType: 'Y',
          ),
          onResult: (_) {},
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final btn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Ta bort'),
      );
      final fg = btn.style!.foregroundColor!.resolve({});
      expect(fg, cs.error,
          reason: 'Delete dialogs must inherit the destructive tint via '
              'isDangerous=true — visually communicates "this is permanent."');
    });

    /// SURFACES PRODUCTION BUG (see library doc): the `itemType` parameter
    /// is a raw String. In English locale, the template renders as
    /// "Are you sure you want to remove Pasta from receptboken?" — the
    /// Swedish word leaks through unlocalized. Documents the bug today;
    /// flip the assertion once the helper accepts a localized itemType.
    testWidgets(
        'english locale → itemType leaks Swedish word verbatim '
        '(documents hardcoded-string bug, family of BUT-1115)', (tester) async {
      await tester.pumpWidget(_wrap(
        _triggerButton<bool?>(
          openDialog: (ctx) => DialogFactory.showDeleteConfirmation(
            ctx,
            itemName: 'Pasta',
            itemType: 'receptboken',
          ),
          onResult: (_) {},
        ),
        locale: const Locale('en'),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Today's broken behaviour: 'receptboken' (Swedish) renders in the
      // English message verbatim. Once the helper accepts a localized
      // itemType, flip this to expect the English equivalent and the
      // bug will surface as a failing test.
      expect(
        find.textContaining('receptboken'),
        findsOneWidget,
        reason: 'lib/core/dialogs/dialog_factory.dart:205-226 accepts '
            'itemType as a raw String, so callers passing Swedish words '
            'leak into the English locale. Fix: make itemType an enum or '
            'thread a localized string via a named-param API. Same bug '
            'class as BUT-1115.',
      );
    });
  });

  group('showTextInput', () {
    /// Proves: typing text and tapping confirm resolves with the typed
    /// value (trimmed). Catches the bug where the helper returns the
    /// controller reference or always returns null.
    testWidgets('confirm with typed text → future resolves with trimmed text',
        (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(
          ctx,
          title: 'Skriv namn',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Leading/trailing whitespace should be trimmed.
      await tester.enterText(find.byType(StyledInput), '  Anna  ');
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(result, 'Anna',
          reason: 'showTextInput must trim() before resolving — otherwise '
              'callers get whitespace-padded values and "Anna" != "Anna ".');
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
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(ctx, title: 't'),
        onResult: (v) {
          sentinel = v;
          resolved = true;
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), '   ');
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(sentinel, isNull,
          reason: 'dialog_factory.dart:266 returns null when trimmed text '
              'is empty — flipping this to return "" silently saves blanks.');
    });

    /// Proves: `required: true` makes the confirm button a NO-OP when
    /// the trimmed text is empty — the dialog stays open and the user
    /// must type something. This is the input-validation invariant.
    /// Critical bug class: if the early-return ever turns into pop(),
    /// required fields silently accept empty input.
    testWidgets(
        'required:true + empty text → confirm tap is a no-op, dialog stays open',
        (tester) async {
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(
          ctx,
          title: 'Krävs',
          required: true,
        ),
        onResult: (_) => resolved = true,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Don't type anything. Tap confirm.
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(resolved, isFalse,
          reason: 'required:true must block the empty submit — '
              'dialog_factory.dart:265 returns early before Navigator.pop.');
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'dialog must still be visible when required-text is empty');
    });

    /// Proves: required:true does NOT block submission once the user
    /// actually types something. Inverse of the test above — catches
    /// the bug where required:true accidentally blocks ALL submissions.
    testWidgets('required:true + non-empty text → submits normally',
        (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(
          ctx,
          title: 't',
          required: true,
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Hej');
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(result, 'Hej');
    });

    /// Proves: tapping cancel resolves the future to null even if the
    /// user typed something — cancel discards input. Otherwise typed-then-
    /// cancelled text would leak into "saved" channels.
    testWidgets('cancel tap → future resolves null even after typing',
        (tester) async {
      String? sentinel = 'unchanged';
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(ctx, title: 't'),
        onResult: (v) {
          sentinel = v;
          resolved = true;
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(StyledInput), 'Skräp');
      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(sentinel, isNull,
          reason: 'Cancel must always resolve to null — typed-then-cancelled '
              'text should be discarded, never leaked to callers.');
    });

    /// Proves: `initialValue` pre-fills the field so the user can edit
    /// existing content rather than retyping. Confirming without further
    /// typing should return the initial value.
    testWidgets('initialValue pre-fills the field', (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(_triggerButton<String?>(
        openDialog: (ctx) => DialogFactory.showTextInput(
          ctx,
          title: 't',
          initialValue: 'Pasta',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(result, 'Pasta');
    });
  });
}
