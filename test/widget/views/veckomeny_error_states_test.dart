/// P5-U15 and P5-U16: the week menu's two error states.
///
/// U15 (veckogenerering ERROR): placing a generated menu failed. The failure
/// says what happened, what was kept and offers Försök igen
/// (content-style-guide.md:87-97). It says the week is unchanged only when
/// the week really is (BUT-2132: claim only an undo that happened), and it
/// hides the success toast first, so the last thing read is still true.
///
/// U16 (veckomeny ERROR): the week's shopping list could not be made. It says
/// the week is unchanged and Försök igen runs the generation again
/// (content-style-guide.md:96: never OK).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/veckomeny_view.dart';

final _sv = AppLocalizationsSv();

Widget _app(void Function(BuildContext context) onTap) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onTap(context),
        child: const Text('go'),
      ),
    ),
  ),
);

void main() {
  group('P5-U15: a failed placement', () {
    testWidgets('hides the success toast, says the week is unchanged and '
        'the menu kept, and Försök igen places again', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app((context) {
          // The publish-first path has already put the receipt on screen.
          SnackBarUtils.showSuccessWithAction(
            context,
            _sv.menuAutoPlacedToast(3),
            actionLabel: _sv.menuAutoPlacedChangeAction,
            onAction: () {},
            duration: const Duration(seconds: 7),
          );
          showWeekPlacementFailure(
            context,
            what: _sv.weeklyMenuSaveFailed,
            weekUnchanged: true,
            onRetry: () => retries++,
          );
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining(_sv.menuAutoPlacedToast(3)), findsNothing);
      expect(find.textContaining(_sv.weeklyMenuSaveFailed), findsOneWidget);
      expect(
        find.textContaining(_sv.weekPlacementFailedWeekUnchanged),
        findsOneWidget,
      );
      expect(find.text('OK'), findsNothing);

      await tester.tap(find.text(_sv.commonRetry));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('a skipped rollback does not claim the week is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          (context) => showWeekPlacementFailure(
            context,
            what: _sv.weeklyMenuSaveFailed,
            weekUnchanged: false,
            onRetry: () {},
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining(_sv.weeklyMenuSaveFailed), findsOneWidget);
      expect(
        find.textContaining(_sv.weekPlacementFailedMenuKept),
        findsOneWidget,
      );
      expect(find.textContaining('oförändrad'), findsNothing);
    });
  });

  group('P5-U16: a failed shopping list', () {
    testWidgets('says the week is unchanged and Försök igen runs it again', (
      tester,
    ) async {
      var runs = 0;
      await tester.pumpWidget(
        _app(
          (context) =>
              showWeekShoppingListFailure(context, onRetry: () => runs++),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(_sv.menuShoppingListGenerationFailed),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.menuShoppingListGenerationPreserved),
        findsOneWidget,
      );
      expect(find.textContaining('försök igen'), findsNothing);

      await tester.tap(find.text(_sv.commonRetry));
      await tester.pump();
      expect(runs, 1);
    });
  });
}
