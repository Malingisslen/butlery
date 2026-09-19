// The Art. 12(4) notice when the deleted person had FILED a report whose case
// was still open (Malin, 2026-09-18): the report is kept without their name
// and with what they wrote, so the notice must say so — alone, or beside the
// review hold when both were kept.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/retained_record.dart';
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

Future<AppLocalizations> _open(
  WidgetTester tester, {
  required bool reviewKept,
  required bool ownReportKept,
  bool provisional = false,
  DateTime? holdUntil,
}) async {
  await tester.pumpWidget(
    _host(
      (context) => ProfileDialogs.showRetentionNoticeDialog(
        context,
        reviewKept: reviewKept,
        ownReportKept: ownReportKept,
        provisional: provisional,
        holdUntil: holdUntil,
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(AlertDialog)));
}

void main() {
  group('the WHAT line names what was kept', () {
    testWidgets('only a report they filed', (tester) async {
      final l10n = await _open(tester, reviewKept: false, ownReportKept: true);

      expect(
        find.text(l10n.profileDeletionNoticeWhatOwnReport),
        findsOneWidget,
      );
      expect(find.text(l10n.profileDeletionNoticeWhat), findsNothing);
      // WHY and HOW LONG speak of the handling, not of a review.
      expect(find.text(l10n.profileDeletionNoticeWhyHandling), findsOneWidget);
      expect(find.text(l10n.profileDeletionNoticeWhy), findsNothing);
      expect(
        find.text(l10n.profileDeletionNoticeHowLongHandlingUnknown),
        findsOneWidget,
      );
      expect(find.text(l10n.profileDeletionNoticeHowLongUnknown), findsNothing);
      expect(find.text(l10n.profileDeletionNoticeRights), findsOneWidget);
    });

    testWidgets('both a review and a report they filed', (tester) async {
      final l10n = await _open(tester, reviewKept: true, ownReportKept: true);

      expect(find.text(l10n.profileDeletionNoticeWhatBoth), findsOneWidget);
      expect(find.text(l10n.profileDeletionNoticeWhat), findsNothing);
      expect(find.text(l10n.profileDeletionNoticeWhatOwnReport), findsNothing);
      expect(find.text(l10n.profileDeletionNoticeWhyHandling), findsOneWidget);
    });

    testWidgets('both, with the review hold provisional, stays hedged', (
      tester,
    ) async {
      final l10n = await _open(
        tester,
        reviewKept: true,
        ownReportKept: true,
        provisional: true,
      );

      expect(
        find.text(l10n.profileDeletionNoticeWhatBothUnclear),
        findsOneWidget,
      );
      expect(find.text(l10n.profileDeletionNoticeWhatBoth), findsNothing);
    });

    testWidgets('a review alone is unchanged', (tester) async {
      final l10n = await _open(tester, reviewKept: true, ownReportKept: false);

      expect(find.text(l10n.profileDeletionNoticeWhat), findsOneWidget);
      expect(find.text(l10n.profileDeletionNoticeWhatOwnReport), findsNothing);
      expect(find.text(l10n.profileDeletionNoticeWhy), findsOneWidget);
      expect(
        find.text(l10n.profileDeletionNoticeHowLongUnknown),
        findsOneWidget,
      );
      expect(find.text(l10n.profileDeletionNoticeWhyHandling), findsNothing);
    });

    // The dated HOW LONG line, both arms, as exact text: the server normally
    // sends a date, so this is the line people actually read.
    testWidgets('with a date, a review alone still speaks of the review', (
      tester,
    ) async {
      await _open(
        tester,
        reviewKept: true,
        ownReportKept: false,
        holdUntil: DateTime.utc(2027, 3, 11),
      );

      expect(
        find.text(
          'Hur länge: tills granskningen är klar, senast 11 mars 2027.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('handläggningen'), findsNothing);
    });

    testWidgets('with a date, a filed report speaks of the handling', (
      tester,
    ) async {
      await _open(
        tester,
        reviewKept: false,
        ownReportKept: true,
        holdUntil: DateTime.utc(2027, 3, 11),
      );

      expect(
        find.text(
          'Hur länge: tills handläggningen är klar, senast 11 mars 2027.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('granskningen är klar'), findsNothing);
    });
  });

  group('RetentionNoticeFacts', () {
    RetainedRecord record(
      String resourceType, {
      DateTime? until,
      bool provisional = false,
    }) => RetainedRecord(
      resourceType: resourceType,
      legalBasis: 'x',
      holdUntil: until,
      provisional: provisional,
    );

    test('tells a filed report from a review', () {
      final ownOnly = RetentionNoticeFacts.from([record('reports')]);
      expect(ownOnly.ownReportKept, isTrue);
      expect(ownOnly.reviewKept, isFalse);

      final reviewOnly = RetentionNoticeFacts.from([record('user_moderation')]);
      expect(reviewOnly.ownReportKept, isFalse);
      expect(reviewOnly.reviewKept, isTrue);
    });

    test('gives the LATEST cap when both were kept', () {
      final early = DateTime.utc(2027, 1, 1);
      final late = DateTime.utc(2027, 3, 1);
      final facts = RetentionNoticeFacts.from([
        record('user_moderation', until: early),
        record('reports', until: late),
      ]);

      expect(facts.holdUntil, late);

      // The later date FIRST, so "the last record wins" cannot pass.
      final reversed = RetentionNoticeFacts.from([
        record('reports', until: late),
        record('user_moderation', until: early),
      ]);
      expect(reversed.holdUntil, late);
    });

    test('only the review hold can make the notice provisional', () {
      final facts = RetentionNoticeFacts.from([
        record('reports', provisional: true),
      ]);

      expect(facts.provisional, isFalse);

      final review = RetentionNoticeFacts.from([
        record('user_moderation', provisional: true),
      ]);
      expect(review.provisional, isTrue);
    });
  });
}
