/// Widget tests for the BUT-975 branded Friends-tab empty state.
///
/// Intent: prove the onboarding empty state shows the branded copy and that
/// each CTA is wired to the callback the parent supplies (invite link /
/// jump to the Find Friends tab) — the whole point of the ticket is those
/// two entry points existing and firing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/social/friends_list/friends_empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

void main() {
  group('FriendsEmptyState (BUT-975)', () {
    testWidgets('renders branded headline + subtitle copy', (tester) async {
      await tester.pumpWidget(_wrap(
        FriendsEmptyState(onInvite: () {}, onFindByUsername: () {}),
      ));

      expect(find.text('Laga tillsammans med vänner'), findsOneWidget);
      expect(
        find.text(
          'Dela recept, se vad dina vänner lagar och planera menyer ihop.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('primary CTA fires onInvite', (tester) async {
      var invited = 0;
      await tester.pumpWidget(_wrap(
        FriendsEmptyState(
          onInvite: () => invited++,
          onFindByUsername: () {},
        ),
      ));

      await tester.tap(find.text('Bjud in vänner'));
      await tester.pump();

      expect(invited, 1, reason: 'invite CTA must call onInvite exactly once');
    });

    testWidgets('secondary CTA fires onFindByUsername', (tester) async {
      var searched = 0;
      await tester.pumpWidget(_wrap(
        FriendsEmptyState(
          onInvite: () {},
          onFindByUsername: () => searched++,
        ),
      ));

      await tester.tap(find.text('Hitta vänner med användarnamn'));
      await tester.pump();

      expect(searched, 1,
          reason: 'find-by-username CTA must call onFindByUsername once');
    });

    testWidgets('both CTAs are announced as labeled buttons to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        FriendsEmptyState(onInvite: () {}, onFindByUsername: () {}),
      ));

      // The CTAs are real button primitives, so the a11y tree must expose
      // each as a button carrying its visible label — what a screen reader
      // reads out. Assert the role + label directly (not exhaustive
      // matchesSemantics, which is brittle across Flutter versions).
      final invite = tester.getSemantics(find.text('Bjud in vänner'));
      expect(invite.flagsCollection.isButton, isTrue);
      expect(invite.label, 'Bjud in vänner');

      final find2 =
          tester.getSemantics(find.text('Hitta vänner med användarnamn'));
      expect(find2.flagsCollection.isButton, isTrue);
      expect(find2.label, 'Hitta vänner med användarnamn');
      handle.dispose();
    });
  });
}
