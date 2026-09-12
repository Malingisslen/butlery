// The two dialog changes that carry Malin's 2026-09-12 decisions.
//
// (1) The RE-SHOWN notice opens collapsed. It surfaces on the sign-in screen,
// where the person reading may not be the person the notice is about — on a
// shared family device the next person must not be told that the previous
// account holder had content under moderation review. The notice shown LIVE,
// in the session that just deleted the account, has no collapsed state: there
// is no bystander there, and an extra tap would only make the original easier
// to miss. That asymmetry is the decision, not an oversight, so both halves are
// pinned — a later "harmonisation" in either direction reddens.
//
// (2) The delete-account confirmation gains a hedged row when the user has ever
// been reported. It is derived from `totalReports`, which counts reports EVER
// FILED and cannot tell a closed case from an open one, so the copy must never
// assert that a review is under way. The wording is pinned here rather than
// only described in the plan, because prose is what drifts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

Widget _host(void Function(BuildContext) onPressed) {
  return MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => onPressed(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('the re-shown notice, collapsed', () {
    testWidgets('says nothing about moderation before it is expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: DateTime.utc(2027, 3, 11),
            startCollapsed: true,
          ),
        ),
      );
      await _open(tester);

      expect(
        find.text('Ett meddelande om ett raderat konto på den här enheten.'),
        findsOneWidget,
      );
      // The whole point: none of the four elements is on screen yet.
      expect(find.text('Ditt konto är raderat'), findsNothing);
      expect(find.textContaining('granskning'), findsNothing);
      expect(find.textContaining('IMY'), findsNothing);
    });

    testWidgets('offers Visa mer, and expanding carries all four elements', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: DateTime.utc(2027, 3, 11),
            startCollapsed: true,
          ),
        ),
      );
      await _open(tester);

      await tester.tap(find.text('Visa mer'));
      await tester.pumpAndSettle();

      // Art. 12(4) owes all four, and the expander must not cost any of them —
      // "same dialog, different trigger" is an assumption, so it is measured.
      expect(find.text('Ditt konto är raderat'), findsOneWidget);
      expect(
        find.textContaining('pågående granskning av innehåll som anmälts'),
        findsOneWidget,
      );
      expect(
        find.textContaining('hantera anmälningen färdigt'),
        findsOneWidget,
      );
      expect(find.textContaining('11 mars 2027'), findsOneWidget);
      expect(find.textContaining('IMY'), findsOneWidget);
      expect(find.textContaining('domstol'), findsOneWidget);
    });

    testWidgets('the provisional hedge survives the expander', (tester) async {
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: DateTime.utc(2027, 3, 11),
            provisional: true,
            startCollapsed: true,
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Visa mer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('En sak kan ha sparats'), findsOneWidget);
    });

    testWidgets('a second showing starts collapsed again', (tester) async {
      // The bystander protection is per-showing. An expanded flag that
      // survived would hand the next person the full notice.
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            startCollapsed: true,
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Visa mer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();

      await _open(tester);

      expect(
        find.text('Ett meddelande om ett raderat konto på den här enheten.'),
        findsOneWidget,
      );
      expect(find.text('Ditt konto är raderat'), findsNothing);
    });
  });

  group('the live notice', () {
    testWidgets('has no collapsed state and no Visa mer', (tester) async {
      // The other half of the asymmetry. If this ever reddens because somebody
      // made the live dialog collapse "for consistency", that is the decision
      // being reversed, not a test to fix.
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: DateTime.utc(2027, 3, 11),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('Visa mer'), findsNothing);
      expect(find.text('Ditt konto är raderat'), findsOneWidget);
      expect(find.textContaining('IMY'), findsOneWidget);
    });
  });

  group('the pre-deletion warning', () {
    testWidgets('is absent by default', (tester) async {
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showDeleteAccountDialog(context)),
      );
      await _open(tester);

      expect(find.textContaining('pågående granskning'), findsNothing);
    });

    testWidgets('appears when the user has been reported', (tester) async {
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showDeleteAccountDialog(
            context,
            mayHaveOpenReview: true,
          ),
        ),
      );
      await _open(tester);

      expect(
        find.textContaining('Om det finns en pågående granskning'),
        findsOneWidget,
      );
    });

    testWidgets('stays conditional — it never asserts an open case', (
      tester,
    ) async {
      // `totalReports` cannot distinguish a closed case from an open one, so
      // this sentence is only true while it is hedged. A copy edit that turns
      // "om det finns" into a statement of fact makes the app tell people
      // something nobody measured.
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showDeleteAccountDialog(
            context,
            mayHaveOpenReview: true,
          ),
        ),
      );
      await _open(tester);

      final row = tester
          .widgetList<Text>(find.textContaining('granskning'))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains('granskning'));

      expect(row, startsWith('Om det finns'));
      expect(row, contains('kan vi behöva'));
      // The claims it must NOT make.
      expect(row, isNot(contains('Det finns en pågående')));
      expect(row, isNot(contains('Du är under')));
    });

    testWidgets('leaves the existing warnings untouched', (tester) async {
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showDeleteAccountDialog(
            context,
            mayHaveOpenReview: true,
          ),
        ),
      );
      await _open(tester);

      expect(find.textContaining('Ta bort alla dina recept'), findsOneWidget);
      expect(
        find.textContaining('Ta bort alla vänner och meddelanden'),
        findsOneWidget,
      );
    });
  });
}
