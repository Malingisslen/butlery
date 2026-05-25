/// Intent-driven unit tests for `CommonDialogActions` — the factory of
/// delete/action/info dialog helpers used across 25+ call sites.
///
/// Behaviours covered:
/// - `showDeleteConfirmation`: confirm tap resolves `true`, cancel tap
///   resolves `false`, barrier-tap (outside dismiss) resolves `null`, custom
///   `warningMessage` renders, dialog renders the localized
///   `deleteConfirmMessage` + `deleteActionIrreversible` strings.
/// - `showRecipeDeleteConfirmation` / `showGroupDeleteConfirmation` /
///   `showShoppingListDeleteConfirmation`: surface the right localized
///   warning string for their item type (recipeDeleteWarning, etc.) and
///   round-trip the user's choice as a `bool?` future.
/// - `showActionConfirmation`: confirm → `true`, cancel → `false`,
///   default `cancelText` falls back to the localized `commonCancel`,
///   `confirmColor` is honored for the FilledButton background, and the
///   `isDangerous` flag forces the colorScheme.error tint regardless of
///   `confirmColor`.
/// - `showLeaveGroupConfirmation` and `showUnsavedChangesConfirmation`:
///   render their localized title/message/confirm-text triplets and
///   resolve correctly.
/// - `showShareConfirmation`: collapses long recipient lists to
///   "name1, name2 och N till" via `shareRecipientsMore`.
/// - `showSuccessDialog` / `showWarningDialog` / `showErrorDialog`:
///   render with the localized `commonOk` button, dismiss on tap,
///   future resolves once the user acknowledges.
///
/// Production bug surface notes (do NOT fix here):
/// - `lib/core/utils/common_dialog_actions.dart:46, 60, 74` pass HARDCODED
///   Swedish item-type strings ('recept', 'grupp', 'inköpslista') into the
///   dialog title. The dialog title becomes "Ta bort recept?" in Swedish but
///   would become "Delete recept?" in English — these literals bypass l10n.
///   Same bug class as BUT-1088. Surfaced by the
///   `english locale → recipe delete title leaks Swedish 'recept'` test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

/// Wraps the [child] in a MaterialApp with l10n delegates so dialogs can
/// resolve `context.l10n.commonCancel` etc. Defaults to Swedish, matching
/// the production app's default locale.
Widget _wrap(Widget child, {Locale locale = const Locale('sv')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: child),
    );

/// Builds a trigger button that opens the dialog and exposes the resolved
/// future to the test via [onResult]. Standard recipe pattern lifted from
/// Flutter's showDialog cookbook and the sibling confirmation_dialogs_test.
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
  group('showDeleteConfirmation', () {
    /// Proves: tapping the delete (primary) action resolves the returned
    /// Future to `true` — the contract callers rely on to actually perform
    /// the deletion.
    testWidgets('delete tap resolves the future with true', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'Min favorit',
          itemType: 'recept',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Primary action label is the localized "Ta bort" — rendered as a
      // bare Text inside FilledButton.icon. Title is "Ta bort recept?"
      // (full sentence), so find.text('Ta bort') uniquely hits the button.
      expect(find.text('Ta bort'), findsOneWidget);
      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();

      expect(result, isTrue,
          reason: 'delete-confirm must return true on primary tap '
              'or callers will silently no-op the deletion');
    });

    /// Proves: tapping cancel pops with `null` — the standard
    /// Navigator.pop() with no args. Callers commonly `?? false` this.
    testWidgets('cancel tap resolves the future with null (Navigator.pop)',
        (tester) async {
      bool? sentinel = true; // distinguish "not called" from "called with null"
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'Min favorit',
          itemType: 'recept',
        ),
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
      // The BaseDialog cancel button calls Navigator.of(context).pop() with
      // no args → showDialog<bool>() resolves with null. If a refactor ever
      // accidentally pops `true` or `false` from the cancel button, callers
      // would silently delete; this assertion locks the null contract.
      expect(sentinel, isNull);
    });

    /// Proves: dismissing the dialog via the barrier (tap outside)
    /// resolves with null. `barrierDismissible` defaults to true in
    /// BaseDialog and most callers depend on it.
    testWidgets('barrier-tap (outside dismiss) resolves the future with null',
        (tester) async {
      bool? sentinel = true;
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'X',
          itemType: 'recept',
        ),
        onResult: (v) {
          sentinel = v;
          resolved = true;
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap on the modal barrier at the very top of the screen (outside
      // the AlertDialog content area).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(sentinel, isNull);
    });

    /// Proves: the localized confirm message + irreversibility hint render.
    /// These are the two strings every user reads before clicking delete —
    /// if either silently disappears, the dialog becomes far less safe.
    testWidgets(
        'renders the localized confirm message and the '
        '"action is irreversible" hint', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'Pasta carbonara',
          itemType: 'recept',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // RichText composes "Vill du verkligen ta bort \"<itemName>\"?".
      expect(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final txt = w.text.toPlainText();
          return txt.contains('Vill du verkligen ta bort') &&
              txt.contains('Pasta carbonara');
        }),
        findsOneWidget,
      );
      // Static italic irreversibility footnote.
      expect(find.text('Denna åtgärd kan inte ångras.'), findsOneWidget);
    });

    /// Proves: passing a `warningMessage` renders it verbatim above the
    /// "action is irreversible" footnote.
    testWidgets('renders custom warningMessage when provided', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'X',
          itemType: 'recept',
          warningMessage: 'OBS: detta är farligt',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('OBS: detta är farligt'), findsOneWidget);
    });

    /// Proves: omitting `warningMessage` does NOT render an empty Text or
    /// the placeholder text. Catches the bug class where a null-guarded
    /// section accidentally always renders something.
    testWidgets('omits warningMessage section when not provided',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showDeleteConfirmation(
          context: ctx,
          itemName: 'X',
          itemType: 'recept',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // No warning section should be present — only the standard
      // confirm message + the static irreversibility footnote.
      expect(find.text('OBS: detta är farligt'), findsNothing);
      expect(find.text('Denna åtgärd kan inte ångras.'), findsOneWidget);
    });
  });

  group('domain-specific delete helpers', () {
    /// Proves: the recipe variant surfaces the localized
    /// `recipeDeleteWarning` to the user. Off-by-one bug class: if the
    /// helper accidentally wired the warning to the wrong l10n key, the
    /// user would see the wrong consequence statement.
    testWidgets('showRecipeDeleteConfirmation shows the recipe warning string',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showRecipeDeleteConfirmation(
          context: ctx,
          recipeName: 'Pasta',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
          find.text('Receptet kommer att tas bort permanent.'), findsOneWidget);
    });

    /// Proves: the group variant surfaces the group-specific warning, NOT
    /// the recipe one. Catches a copy-paste bug between the three sibling
    /// helpers.
    testWidgets('showGroupDeleteConfirmation shows the group warning string',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showGroupDeleteConfirmation(
          context: ctx,
          groupName: 'Familjen',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Alla medlemmar kommer att lämna gruppen.'),
          findsOneWidget);
      // Negative: the recipe warning must NOT leak into the group dialog.
      expect(
          find.text('Receptet kommer att tas bort permanent.'), findsNothing);
    });

    /// Proves: the shopping-list variant surfaces its own warning. Same
    /// rationale as above.
    testWidgets(
        'showShoppingListDeleteConfirmation shows the shopping warning string',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) =>
            CommonDialogActions.showShoppingListDeleteConfirmation(
          context: ctx,
          listName: 'Veckohandling',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Alla varor på listan kommer att försvinna.'),
          findsOneWidget);
    });

    /// SURFACES PRODUCTION BUG (see library doc): English locale should
    /// localize "recept" → "recipe" but the production code hardcodes the
    /// Swedish word. This test EXPECTS the broken behaviour today (so it
    /// passes), but the `reason:` documents the bug so a future
    /// l10n-fix PR will flip this assertion to the corrected expectation.
    testWidgets(
        'english locale → recipe delete title still leaks Swedish "recept" '
        '(documents BUT-style hardcoded-string bug)', (tester) async {
      await tester.pumpWidget(_wrap(
        _triggerButton<bool?>(
          openDialog: (ctx) => CommonDialogActions.showRecipeDeleteConfirmation(
            context: ctx,
            recipeName: 'Pasta',
          ),
          onResult: (_) {},
        ),
        locale: const Locale('en'),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Today's broken behaviour: title is "Delete recept?" in English.
      // Once the production code properly localizes the itemType (e.g.
      // via context.l10n.itemTypeRecipe), flip the matcher to expect
      // "Delete recipe?" and the broken-locale leak will surface.
      expect(
        find.text('Delete recept?'),
        findsOneWidget,
        reason: 'lib/core/utils/common_dialog_actions.dart:46 passes the '
            'literal Swedish string \'recept\' as itemType, which lands in '
            'the dialog title verbatim regardless of locale. Same bug class '
            'as BUT-1088 (hardcoded Swedish in nominally-localized helpers). '
            'Fix: thread a localized itemType through the public helper.',
      );
    });
  });

  group('showActionConfirmation', () {
    /// Proves: tapping the primary action resolves with true.
    testWidgets('confirm tap → future resolves true', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 'Bekräfta',
          message: 'Säker?',
          confirmText: 'Ja',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Ja'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    /// Proves: tapping cancel pops with `false` explicitly — note that
    /// `_ActionConfirmationDialog` (unlike the BaseDialog flow used by
    /// showDeleteConfirmation) wires cancel to `Navigator.pop(false)`,
    /// so callers get a concrete `false`, not `null`.
    testWidgets('cancel tap → future resolves false (not null)',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Default cancel label is localized Avbryt.
      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    /// Proves: omitting `cancelText` falls back to the localized
    /// `commonCancel` ("Avbryt" in Swedish). Catches the regression where
    /// someone changes the default to a hardcoded string.
    testWidgets('default cancelText comes from the localized commonCancel',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
    });

    /// Proves: a custom `cancelText` overrides the localized default. The
    /// other way the test could fail: someone makes the helper ignore the
    /// custom value and always use commonCancel.
    testWidgets('custom cancelText overrides the localized default',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
          cancelText: 'Nope',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Nope'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsNothing);
    });

    /// Proves: when `isDangerous: true`, the primary button's background
    /// is the theme's `colorScheme.error`, even if a confirmColor is
    /// supplied — `isDangerous` must trump the override. This is the
    /// safety invariant for destructive-action UIs.
    testWidgets(
        'isDangerous forces colorScheme.error background even with confirmColor',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(Builder(
        builder: (rootCtx) {
          cs = Theme.of(rootCtx).colorScheme;
          return _triggerButton<bool?>(
            openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
              context: ctx,
              title: 't',
              message: 'm',
              confirmText: 'Kör',
              confirmColor: Colors.green, // should be IGNORED
              isDangerous: true,
            ),
            onResult: (_) {},
          );
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kör'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, cs.error,
          reason: 'isDangerous=true must override any confirmColor — '
              'otherwise destructive UIs could be rendered in the wrong '
              'colour and lose their visual warning affordance.');
    });

    /// Proves: when NOT dangerous, the supplied confirmColor wins over the
    /// theme primary. Inverse of the test above.
    testWidgets(
        'non-dangerous + confirmColor → button uses the supplied confirmColor',
        (tester) async {
      const customColor = Color(0xFF112233);
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Kör',
          confirmColor: customColor,
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kör'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, customColor);
    });
  });

  group('showLeaveGroupConfirmation', () {
    /// Proves: the leave-group helper renders the localized title and
    /// substitutes the group name into the localized message template.
    /// Catches the bug where the helper passes the name to the wrong
    /// localization function (or forgets to interpolate it at all).
    testWidgets(
        'renders localized title, message-with-group-name, and confirm action',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showLeaveGroupConfirmation(
          context: ctx,
          groupName: 'Familjen',
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Lämna grupp?'), findsOneWidget);
      // Message: "Vill du verkligen lämna gruppen \"Familjen\"?"
      expect(find.textContaining('Familjen'), findsWidgets);
      // Confirm action label: "Lämna grupp".
      expect(find.widgetWithText(FilledButton, 'Lämna grupp'), findsOneWidget);
    });

    /// Proves: the confirm tap resolves true so callers actually leave.
    testWidgets('confirm tap resolves the future with true', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showLeaveGroupConfirmation(
          context: ctx,
          groupName: 'Familjen',
        ),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Lämna grupp'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    /// Proves: marked `isDangerous: true`, the warning-tinted button gets
    /// colorScheme.error — see the showActionConfirmation invariant above.
    /// This is the per-helper guarantee that leaving a group looks
    /// destructive, not casual.
    testWidgets('leave-group uses the error-tinted button (isDangerous=true)',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(Builder(
        builder: (rootCtx) {
          cs = Theme.of(rootCtx).colorScheme;
          return _triggerButton<bool?>(
            openDialog: (ctx) => CommonDialogActions.showLeaveGroupConfirmation(
              context: ctx,
              groupName: 'g',
            ),
            onResult: (_) {},
          );
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lämna grupp'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, cs.error);
    });
  });

  group('showUnsavedChangesConfirmation', () {
    /// Proves: localized title + message + "cancel without saving" confirm
    /// label all render. Catches the bug where any of the three is wired
    /// to the wrong l10n key.
    testWidgets('renders localized title, message, and confirm label',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) =>
            CommonDialogActions.showUnsavedChangesConfirmation(context: ctx),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Osparade ändringar'), findsOneWidget);
      expect(find.text('Du har osparade ändringar. Vill du verkligen avbryta?'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Avbryt utan att spara'),
          findsOneWidget);
    });

    /// Proves: tapping "Avbryt utan att spara" resolves the future to
    /// true so the caller actually discards the unsaved changes.
    testWidgets('confirm tap → future resolves true (discard changes)',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) =>
            CommonDialogActions.showUnsavedChangesConfirmation(context: ctx),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester
          .tap(find.widgetWithText(FilledButton, 'Avbryt utan att spara'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    /// Proves: tapping the secondary "Avbryt" resolves the future to
    /// false so the caller keeps the form open. Note: must be `false`,
    /// not `null` — `_ActionConfirmationDialog` pops with an explicit
    /// `false` from the cancel button.
    testWidgets('cancel tap → future resolves false (keep editing)',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) =>
            CommonDialogActions.showUnsavedChangesConfirmation(context: ctx),
        onResult: (v) => result = v,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Secondary action (cancel) uses the default localized Avbryt label.
      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('showShareConfirmation', () {
    /// Proves: a recipient list <= 3 long is joined with ", " verbatim
    /// (no "and N more" tail). Off-by-one bug class: the helper switches
    /// behaviour at length 3 vs 4.
    testWidgets(
        '<= 3 recipients → all names joined with ", " (no overflow tail)',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showShareConfirmation(
          context: ctx,
          itemType: 'recept',
          recipientNames: const ['Anna', 'Beata', 'Cecilia'],
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Message template: "Vill du dela recept med Anna, Beata, Cecilia?"
      expect(find.textContaining('Anna, Beata, Cecilia'), findsOneWidget);
      // Must NOT contain the "och N till" suffix at this length.
      expect(find.textContaining('och'), findsNothing);
    });

    /// Proves: at length 4+, the helper takes the first 2 names and
    /// appends the localized `shareRecipientsMore(count-2)` tail.
    /// Validates both the boundary (4 = first overflow) AND the count.
    testWidgets('>= 4 recipients → first 2 names + "och N till" overflow',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showShareConfirmation(
          context: ctx,
          itemType: 'recept',
          recipientNames: const ['Anna', 'Beata', 'Cecilia', 'Disa', 'Eva'],
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Expected: "Anna, Beata och 3 till" (5 recipients → 2 shown + 3 more)
      expect(find.textContaining('Anna, Beata'), findsOneWidget);
      expect(find.textContaining('och 3 till'), findsOneWidget);
      // Negative: the overflowed names must NOT appear.
      expect(find.textContaining('Cecilia'), findsNothing);
    });

    /// Proves: the share confirm button uses the localized "Dela" label.
    testWidgets('confirm button uses localized commonShare label',
        (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton<bool?>(
        openDialog: (ctx) => CommonDialogActions.showShareConfirmation(
          context: ctx,
          itemType: 'recept',
          recipientNames: const ['Anna'],
        ),
        onResult: (_) {},
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Dela'), findsOneWidget);
    });
  });

  group('showSuccessDialog / showWarningDialog / showErrorDialog', () {
    /// Proves: the success info dialog renders title, message, the
    /// localized OK button, and uses the butlery success color on the
    /// button background — captured from the live extension rather than
    /// hardcoded so a theme tweak doesn't break the test.
    testWidgets(
        'success dialog renders content + localized OK + butleryColors.success button',
        (tester) async {
      late Color expectedColor;
      var resolved = false;
      await tester.pumpWidget(_wrap(Builder(
        builder: (rootCtx) {
          expectedColor = rootCtx.butleryColors.success;
          return _triggerButton<void>(
            openDialog: (ctx) async {
              await CommonDialogActions.showSuccessDialog(
                context: ctx,
                title: 'Klart!',
                message: 'Det funkade',
              );
            },
            onResult: (_) => resolved = true,
          );
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Klart!'), findsOneWidget);
      expect(find.text('Det funkade'), findsOneWidget);

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'OK'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, expectedColor);

      // Acknowledge to make sure the future resolves (caller commonly
      // `await`s and continues afterwards).
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(resolved, isTrue);
    });

    /// Proves: the warning dialog uses butleryColors.warning. Same shape
    /// as the success test, swapping the colour invariant.
    testWidgets('warning dialog uses butleryColors.warning on the button',
        (tester) async {
      late Color expectedColor;
      await tester.pumpWidget(_wrap(Builder(
        builder: (rootCtx) {
          expectedColor = rootCtx.butleryColors.warning;
          return _triggerButton<void>(
            openDialog: (ctx) async {
              await CommonDialogActions.showWarningDialog(
                context: ctx,
                title: 'Obs',
                message: 'Var försiktig',
              );
            },
            onResult: (_) {},
          );
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'OK'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, expectedColor);

      // Tear down the open dialog so the test framework doesn't complain
      // about a still-mounted modal route.
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
    });

    /// Proves: the error dialog uses the theme's `colorScheme.error`
    /// (NOT butleryColors.warning — these are intentionally different
    /// channels in the design system).
    testWidgets('error dialog uses colorScheme.error on the button',
        (tester) async {
      late Color expectedColor;
      await tester.pumpWidget(_wrap(Builder(
        builder: (rootCtx) {
          expectedColor = Theme.of(rootCtx).colorScheme.error;
          return _triggerButton<void>(
            openDialog: (ctx) async {
              await CommonDialogActions.showErrorDialog(
                context: ctx,
                title: 'Fel',
                message: 'Något gick snett',
              );
            },
            onResult: (_) {},
          );
        },
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'OK'),
      );
      final bg = btn.style!.backgroundColor!.resolve({});
      expect(bg, expectedColor);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
    });

    /// Proves: tapping OK dismisses the info dialog — info dialogs are
    /// the only way for an info-modal caller to continue (no barrier-
    /// cancel for these, since they don't take a `bool?`).
    testWidgets('OK tap dismisses the info dialog and resolves the await',
        (tester) async {
      var resolved = false;
      await tester.pumpWidget(_wrap(_triggerButton<void>(
        openDialog: (ctx) async {
          await CommonDialogActions.showSuccessDialog(
            context: ctx,
            title: 't',
            message: 'm',
          );
        },
        onResult: (_) => resolved = true,
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(resolved, isFalse, reason: 'await should still be pending');

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(resolved, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
