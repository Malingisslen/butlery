// BUT-2046 follow-up: the GDPR Art. 12(4) notice shown when an account
// deletion lawfully retained moderation evidence.
//
// Why the assertions here are shaped as they are:
//
// The dialog renders ALL FOUR elements Art. 12(4) requires — what was kept,
// why, for how long, and the two remedies. A notice missing one of them is not
// a lesser notice, it is a non-compliant one, so each is its own assertion
// rather than a single "the dialog appears" check.
//
// The "how long" line renders the cap DATE the server sent, never a number
// written into the copy — a hardcoded "180 days" becomes a false promise the
// moment `ERASURE_HOLD_MAX_DAYS` changes, and the person it is legally owed to
// has no way to know.
//
// `RetainedRecord` parses what the callable actually sends and degrades rather
// than throws on a shape it does not recognise — this is the last screen the
// person ever sees, so a malformed date must cost the date and not the whole
// notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
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

void main() {
  group('the Art. 12(4) retention notice', () {
    testWidgets('carries all four elements the article requires', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showRetentionNoticeDialog(context)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );

      expect(find.text(l10n.profileDeletionNoticeTitle), findsOneWidget);
      expect(
        find.text(l10n.profileDeletionNoticeWhat),
        findsOneWidget,
        reason: 'Art. 12(4) requires saying WHAT was kept',
      );
      expect(
        find.text(l10n.profileDeletionNoticeWhy),
        findsOneWidget,
        reason: 'Art. 12(4) requires the reason',
      );
      expect(
        find.text(l10n.profileDeletionNoticeHowLongUnknown),
        findsOneWidget,
        reason: 'the outer cap is what makes the hold temporary',
      );
      expect(
        find.text(l10n.profileDeletionNoticeRights),
        findsOneWidget,
        reason:
            'IMY and the judicial remedy are the two Art. 12(4) elements a '
            'notice most easily ships without',
      );
      // By CONTENT, not only by symbol: the assertion above proves that key
      // renders, and would keep passing if the string were reworded into
      // something that names neither remedy.
      expect(
        l10n.profileDeletionNoticeRights,
        contains('IMY'),
        reason: 'Art. 12(4) requires naming the supervisory authority',
      );
      expect(
        l10n.profileDeletionNoticeRights.toLowerCase(),
        contains('domstol'),
        reason: 'and the judicial remedy beside it',
      );
    });

    testWidgets('renders the cap DATE the server sent, not a number in the copy', (
      tester,
    ) async {
      final holdUntil = DateTime.utc(2027, 3, 8);
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: holdUntil,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The formatted date must actually appear. Asserting the l10n string with
      // the same argument would pass on a dialog that renders a constant.
      expect(
        find.textContaining(DateFormat.yMMMMd('sv').format(holdUntil)),
        findsOneWidget,
        reason: 'the notice must state the cap the SERVER computed',
      );
      expect(
        find.textContaining('180'),
        findsNothing,
        reason:
            'a number in the copy is a promise the constant can silently break',
      );
    });

    testWidgets('says less rather than a number when no date was sent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showRetentionNoticeDialog(context)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );
      expect(
        find.text(l10n.profileDeletionNoticeHowLongUnknown),
        findsOneWidget,
      );
    });

    testWidgets('hedges the WHAT line when the hold is PROVISIONAL', (
      tester,
    ) async {
      // Asserting a pending review as fact would tell the person something
      // nobody measured — Malin's call, BUT-2047.
      await tester.pumpWidget(
        _host(
          (context) => ProfileDialogs.showRetentionNoticeDialog(
            context,
            provisional: true,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );
      expect(find.text(l10n.profileDeletionNoticeWhatUnclear), findsOneWidget);
      expect(
        find.text(l10n.profileDeletionNoticeWhat),
        findsNothing,
        reason: 'the confident wording must not survive a provisional hold',
      );
      // Everything else the dialog renders is unchanged — only the WHAT line
      // hedges, and a repair that swapped the whole notice would redden here.
      expect(find.text(l10n.profileDeletionNoticeTitle), findsOneWidget);
      expect(find.text(l10n.profileDeletionNoticeWhy), findsOneWidget);
      expect(
        find.text(l10n.profileDeletionNoticeHowLongUnknown),
        findsOneWidget,
      );
      expect(find.text(l10n.profileDeletionNoticeRights), findsOneWidget);
    });

    testWidgets('states it plainly when the hold is NOT provisional', (
      tester,
    ) async {
      // The control for the case above. Without it, a dialog hard-wired to the
      // hedged string would pass.
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showRetentionNoticeDialog(context)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );
      expect(find.text(l10n.profileDeletionNoticeWhat), findsOneWidget);
      expect(find.text(l10n.profileDeletionNoticeWhatUnclear), findsNothing);
    });

    testWidgets('cannot be dismissed by tapping outside it', (tester) async {
      // The account is already gone when this shows, so there is no second
      // chance to give the notice and no signed-in surface to return to.
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showRetentionNoticeDialog(context)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('closes on its button', (tester) async {
      await tester.pumpWidget(
        _host((context) => ProfileDialogs.showRetentionNoticeDialog(context)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('RetainedRecord', () {
    test('parses the shape the callable actually sends', () {
      final records = RetainedRecord.listFrom([
        {
          'resourceType': 'user_moderation',
          'legalBasis': 'GDPR Art. 17(3)(e)',
          'holdUntil': '2027-03-08T00:00:00.000Z',
        },
      ]);

      expect(records, hasLength(1));
      expect(records.first.resourceType, 'user_moderation');
      expect(records.first.legalBasis, 'GDPR Art. 17(3)(e)');
      expect(
        records.first.holdUntil,
        DateTime.parse('2027-03-08T00:00:00.000Z'),
      );
    });

    test(
      'a missing or unparsable holdUntil costs the date, not the notice',
      () {
        final records = RetainedRecord.listFrom([
          {
            'resourceType': 'user_moderation',
            'legalBasis': 'GDPR Art. 17(3)(e)',
          },
        ]);

        expect(records, hasLength(1));
        expect(records.first.legalBasis, 'GDPR Art. 17(3)(e)');
        expect(records.first.holdUntil, isNull);
      },
    );

    test('carries the provisional flag off the wire, in both directions', () {
      final held = RetainedRecord.listFrom([
        {
          'resourceType': 'user_moderation',
          'legalBasis': 'GDPR Art. 17(3)(e)',
          'holdUntil': '2027-03-08T00:00:00.000Z',
          'provisional': true,
        },
      ]);
      expect(held.first.provisional, isTrue);

      // A record with no flag is the ordinary hold, and reads as confident.
      // Both arms, because a parser hard-wired either way would pass on one.
      final ordinary = RetainedRecord.listFrom([
        {'resourceType': 'user_moderation', 'legalBasis': 'x'},
      ]);
      expect(ordinary.first.provisional, isFalse);
    });

    test('a field the server never sends reads as nothing kept', () {
      // An older deployment omits `retained` entirely. That must land on the
      // ordinary deletion path, never on an exception.
      expect(RetainedRecord.listFrom(null), isEmpty);
      expect(RetainedRecord.listFrom('unexpected'), isEmpty);
      expect(RetainedRecord.listFrom(const []), isEmpty);
    });
  });

  group('AccountDeletionOutcome', () {
    test('decides whether the notice is shown — in both directions', () {
      // Both arms, because the branch in `auth_action_handler` reads this
      // getter and a one-armed test would pass on a getter hard-wired to true.
      const held = AccountDeletionOutcome(
        success: true,
        accountDeleted: true,
        retained: [
          RetainedRecord(
            resourceType: 'user_moderation',
            legalBasis: 'GDPR Art. 17(3)(e)',
            holdUntil: null,
          ),
        ],
      );
      const ordinary = AccountDeletionOutcome(success: true);

      expect(held.hasRetainedRecords, isTrue);
      expect(ordinary.hasRetainedRecords, isFalse);
      // The notice is owed when data was KEPT — not only when the erasure fully
      // succeeded (Malin, BUT-2047) — but it does require the account to be
      // gone, because the notice's own title says it is.
      expect(
        held.owesRetentionNotice,
        isTrue,
        reason: 'account gone + something kept',
      );
      const heldButAccountSurvived = AccountDeletionOutcome(
        success: false,
        accountDeleted: false,
        retained: [
          RetainedRecord(
            resourceType: 'user_moderation',
            legalBasis: 'GDPR Art. 17(3)(e)',
            holdUntil: null,
          ),
        ],
      );
      expect(
        heldButAccountSurvived.owesRetentionNotice,
        isFalse,
        reason:
            'the notice opens with "Ditt konto är raderat"; it must not be '
            'shown while the account is still there',
      );
      // And the case the whole decision is about: the erasure did NOT fully
      // succeed, the account IS gone, something was kept — the notice is owed.
      const heldOnFailedErasure = AccountDeletionOutcome(
        success: false,
        accountDeleted: true,
        retained: [
          RetainedRecord(
            resourceType: 'user_moderation',
            legalBasis: 'GDPR Art. 17(3)(e)',
            holdUntil: null,
            provisional: true,
          ),
        ],
      );
      expect(heldOnFailedErasure.owesRetentionNotice, isTrue);
      // The arm that grades the OTHER conjunct. Without it `owesRetentionNotice`
      // could be `=> accountDeleted` and every arm above still agrees.
      // `accountDeleted` is seeded TRUE here on purpose: the constructor
      // defaults it to false, so a fixture that left it out would agree with
      // the mutant too.
      const nothingKept = AccountDeletionOutcome(
        success: true,
        accountDeleted: true,
      );
      expect(
        nothingKept.owesRetentionNotice,
        isFalse,
        reason: 'an ordinary deletion kept nothing, so nothing is owed',
      );
      // A successful deletion that kept something is still a SUCCESS: a lawful
      // Art. 17(3) exception is not a failed erasure.
      expect(held.success, isTrue);
    });
  });
}
