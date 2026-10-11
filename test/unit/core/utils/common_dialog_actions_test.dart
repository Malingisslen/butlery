/// Intent-driven tests for `CommonDialogActions`: the named confirmations the
/// views ask for (BUT-2366). Each preset must draw the right shared dialog
/// with its own sv l10n title and button text, and resolve the user's choice
/// as a `bool?`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

final _sv = AppLocalizationsSv();

class _Result {
  bool? value;
  bool resolved = false;
}

/// Opens [openDialog] from a trigger button and returns the holder that the
/// resolved future is written to.
Future<_Result> _open(
  WidgetTester tester,
  Future<bool?> Function(BuildContext) openDialog,
) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result.value = await openDialog(ctx);
              result.resolved = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<FilledButton>(),
);

Finder _richText(bool Function(String plain) test) => find.byWidgetPredicate(
  (w) => w is RichText && test(w.text.toPlainText()),
);

void main() {
  group('showDeleteConfirmation', () {
    Future<bool?> open(
      BuildContext ctx, {
      String message = '',
      String itemName = '',
      String? warningMessage,
      bool irreversible = false,
    }) => CommonDialogActions.showDeleteConfirmation(
      context: ctx,
      title: 'Radera boken?',
      confirmText: 'Radera boken',
      message: message,
      itemName: itemName,
      warningMessage: warningMessage,
      irreversible: irreversible,
    );

    testWidgets('draws the destructive dialog with the caller-named button', (
      tester,
    ) async {
      await _open(tester, (ctx) => open(ctx));

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text('Radera boken?'), findsOneWidget);
      expect(_button('Radera boken'), findsOneWidget);
    });

    testWidgets('confirm tap resolves true', (tester) async {
      final r = await _open(tester, (ctx) => open(ctx));

      await tester.tap(_button('Radera boken'));
      await tester.pumpAndSettle();

      expect(r.value, isTrue);
    });

    testWidgets('cancel tap resolves to no yes', (tester) async {
      final r = await _open(tester, (ctx) => open(ctx));

      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      expect(r.resolved, isTrue);
      expect(r.value, isNot(true));
    });

    testWidgets('barrier tap resolves to no yes', (tester) async {
      final r = await _open(tester, (ctx) => open(ctx));

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(r.resolved, isTrue);
      expect(r.value, isNot(true));
    });

    testWidgets('quotes the item name after the message', (tester) async {
      await _open(
        tester,
        (ctx) => open(ctx, message: 'Vill du radera', itemName: 'Pasta'),
      );

      expect(_richText((t) => t == 'Vill du radera ”Pasta”?'), findsOneWidget);
    });

    testWidgets('warningMessage renders', (tester) async {
      await _open(tester, (ctx) => open(ctx, warningMessage: 'OBS: farligt'));
      expect(find.text('OBS: farligt'), findsOneWidget);
    });

    testWidgets('irreversible adds the line', (
      tester,
    ) async {
      await _open(tester, (ctx) => open(ctx, irreversible: true));
      expect(find.text(_sv.deleteActionIrreversible), findsOneWidget);
    });

    testWidgets('not irreversible by default', (tester) async {
      await _open(tester, (ctx) => open(ctx, itemName: 'Pasta'));
      expect(find.text(_sv.deleteActionIrreversible), findsNothing);
    });
  });

  group('delete presets: sv title and button text', () {
    testWidgets('recipe: title, button and trash warning, no irreversible', (
      tester,
    ) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showRecipeDeleteConfirmation(
          context: ctx,
          recipeName: 'Pasta',
        ),
      );

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text(_sv.recipeDeleteConfirmTitle), findsOneWidget);
      expect(_button(_sv.recipeDelete), findsOneWidget);
      expect(find.text(_sv.recipeDeleteWarning), findsOneWidget);
      expect(_richText((t) => t.contains('”Pasta”')), findsOneWidget);
      // The recipe goes to the trash, so it must not claim it cannot be undone.
      expect(find.text(_sv.deleteActionIrreversible), findsNothing);
    });

    for (final count in [1, 3]) {
      testWidgets('bulk recipes ($count): title and button follow the count', (
        tester,
      ) async {
        await _open(
          tester,
          (ctx) => CommonDialogActions.showBulkRecipeDeleteConfirmation(
            context: ctx,
            count: count,
          ),
        );

        expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
        expect(find.text(_sv.bulkDeleteConfirmTitle(count)), findsOneWidget);
        expect(_button(_sv.bulkDeleteConfirmAction(count)), findsOneWidget);
        expect(find.text(_sv.bulkDeleteConfirmMessage), findsOneWidget);
      });
    }

    testWidgets('comment: title and button', (tester) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showCommentDeleteConfirmation(
          context: ctx,
          commentText: 'Gott!',
        ),
      );

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text(_sv.commentDeleteConfirmTitle), findsOneWidget);
      expect(_button(_sv.commentDeleteConfirmAction), findsOneWidget);
      expect(_richText((t) => t == '”Gott!”'), findsOneWidget);
    });

    testWidgets('comment: a long comment is cut at 40 characters with "…"', (
      tester,
    ) async {
      final long = List.filled(60, 'x').join();
      await _open(
        tester,
        (ctx) => CommonDialogActions.showCommentDeleteConfirmation(
          context: ctx,
          commentText: long,
        ),
      );

      expect(
        _richText((t) => t == '”${long.substring(0, 40)}…”'),
        findsOneWidget,
      );
    });

    testWidgets('cook snap: title and button, no quoted name', (tester) async {
      await _open(
        tester,
        (ctx) =>
            CommonDialogActions.showCookSnapDeleteConfirmation(context: ctx),
      );

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text(_sv.cookSnapDeleteConfirmTitle), findsOneWidget);
      expect(_button(_sv.cookSnapDelete), findsOneWidget);
      expect(_richText((t) => t.contains('””')), findsNothing);
    });

  });

  group('showActionConfirmation', () {
    testWidgets('dangerous: destructive dialog, icon on the button', (
      tester,
    ) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 'Lämna?',
          message: 'Säker?',
          confirmText: 'Lämna',
          icon: ButleryIcons.logOut,
          isDangerous: true,
        ),
      );

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(
        find.descendant(
          of: _button('Lämna'),
          matching: find.byIcon(ButleryIcons.logOut),
        ),
        findsOneWidget,
      );
    });

    testWidgets('not dangerous: plain confirmation, icon above the title', (
      tester,
    ) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 'Dela?',
          message: 'Säker?',
          confirmText: 'Dela',
          icon: ButleryIcons.share2,
        ),
      );

      expect(find.byType(ConfirmationDialog), findsOneWidget);
      expect(find.byType(DestructiveConfirmationDialog), findsNothing);
      expect(find.byIcon(ButleryIcons.share2), findsOneWidget);
      expect(
        find.descendant(
          of: _button('Dela'),
          matching: find.byIcon(ButleryIcons.share2),
        ),
        findsNothing,
      );
    });

    testWidgets('confirm resolves true, cancel does not', (tester) async {
      var r = await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
        ),
      );
      await tester.tap(_button('Ja'));
      await tester.pumpAndSettle();
      expect(r.value, isTrue);

      r = await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
        ),
      );
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();
      expect(r.resolved, isTrue);
      expect(r.value, isNot(true));
    });

    testWidgets('cancelText defaults to commonCancel', (tester) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
        ),
      );
      expect(find.text(_sv.commonCancel), findsOneWidget);
    });

    testWidgets('a custom cancelText replaces the default (dangerous too)', (
      tester,
    ) async {
      await _open(
        tester,
        (ctx) => CommonDialogActions.showActionConfirmation(
          context: ctx,
          title: 't',
          message: 'm',
          confirmText: 'Ja',
          cancelText: 'Nope',
          isDangerous: true,
        ),
      );

      expect(find.text('Nope'), findsOneWidget);
      expect(find.text(_sv.commonCancel), findsNothing);
    });
  });

  group('showLeaveGroupConfirmation', () {
    testWidgets('names the group and is destructive', (tester) async {
      final r = await _open(
        tester,
        (ctx) => CommonDialogActions.showLeaveGroupConfirmation(
          context: ctx,
          groupName: 'Familjen',
        ),
      );

      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text(_sv.groupLeaveTitle), findsOneWidget);
      expect(find.textContaining('Familjen', findRichText: true), findsWidgets);

      await tester.tap(_button(_sv.groupLeaveAction));
      await tester.pumpAndSettle();
      expect(r.value, isTrue);
    });
  });

  group('showUnsavedChangesConfirmation', () {
    testWidgets('confirm discards (true), cancel keeps editing', (
      tester,
    ) async {
      var r = await _open(
        tester,
        (ctx) =>
            CommonDialogActions.showUnsavedChangesConfirmation(context: ctx),
      );
      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
      expect(find.text(_sv.unsavedChangesTitle), findsOneWidget);
      expect(
        find.text(_sv.unsavedChangesMessage, findRichText: true),
        findsOneWidget,
      );
      await tester.tap(_button(_sv.cancelWithoutSaving));
      await tester.pumpAndSettle();
      expect(r.value, isTrue);

      r = await _open(
        tester,
        (ctx) =>
            CommonDialogActions.showUnsavedChangesConfirmation(context: ctx),
      );
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();
      expect(r.resolved, isTrue);
      expect(r.value, isNot(true));
    });
  });
}
