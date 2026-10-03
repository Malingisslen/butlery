/// P8-U03 · flow 06, the two e-mail verification transitions that were built
/// but had no test (flows-roles-budget.md:88; fas2/block288-uxfrysning.json
/// overgangar, both REQUIRED; the rows in fas2/stateflow-applicability-0608
/// .json name the visible effect).
///
/// - TR::FLOW::06::verifiera-epost::klart: the link is opened, the account
///   is verified and the user is let in. The view polls every 5 s
///   (lib/views/auth/email_verification_view.dart:33, :62-81), so the
///   verification is seen at the first poll after the link was opened.
/// - TR::FLOW::06::verifieringslank::utgangen: an expired link means asking
///   for a new one. The view offers "Skicka igen", sends a new link, and
///   holds the next one for 60 s (:34, :84-118). Two known gaps are pinned
///   below (BUT-2172): the button is not given back after the 60 s, and the
///   countdown is part of the button's name, where produktregler.md:676
///   puts it outside the name. The tests find the button as the resend
///   action, not by the text that carries the countdown.
///
/// The real EmailVerificationView runs under fake time. The fake is the
/// AuthService edge only: whether the address is verified, the reload, and
/// the send.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/auth/email_verification_view.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/helpers/offline_banner_support.dart';

const _email = 'anna@example.com';
final _sv = AppLocalizationsSv();

void main() {
  late MockAuthService auth;
  late bool verifiedOnServer;
  late bool linkOpened;
  late int reloads;
  late int sends;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    verifiedOnServer = false;
    linkOpened = false;
    reloads = 0;
    sends = 0;
    auth = MockAuthService()..setAuthState(isAuthenticated: true);
    // The cached flag only turns true after a reload that follows the
    // opened link, as FirebaseAuth's User.emailVerified does.
    when(() => auth.isEmailVerified).thenAnswer((_) => verifiedOnServer);
    when(() => auth.reloadUser()).thenAnswer((_) async {
      reloads++;
      if (linkOpened) verifiedOnServer = true;
    });
    when(() => auth.sendEmailVerification()).thenAnswer((_) async => sends++);

    final container = DIContainer();
    container.container.registerSingleton<AuthService>(auth);
    ServiceLocator.initialize(container);
    ensureOfflineService();
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Widget view({ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const EmailVerificationView(email: _email),
  );

  group('TR::FLOW::06::verifiera-epost::klart', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('the opened link is seen at the next 5 s poll, and the view '
          'says the address is verified ($mode)', (tester) async {
        await tester.pumpWidget(view(theme: theme));
        await tester.pump();
        expect(find.text(_sv.emailVerificationTitle), findsOneWidget);

        // Not opened yet: a poll reloads and nothing changes.
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(reloads, 1);
        expect(find.text(_sv.emailVerificationSuccess), findsNothing);

        // The user opens the link in the mail.
        linkOpened = true;
        await tester.pump(const Duration(milliseconds: 4900));
        expect(find.text(_sv.emailVerificationSuccess), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(reloads, 2);
        expect(find.text(_sv.emailVerificationSuccess), findsOneWidget);
        expect(find.text(_sv.emailVerificationTitle), findsNothing);
        expect(find.text(_sv.emailVerificationResend), findsNothing);

        // Verified, the polling stops.
        await tester.pump(const Duration(seconds: 30));
        expect(reloads, 2);
      });
    }
  });

  // The resend action: the one ElevatedButton on the screen (the other way
  // on, "Fortsätt utan att verifiera", is a TextButton).
  final resend = find.byType(ElevatedButton);
  bool resendEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(resend).onPressed != null;

  group('TR::FLOW::06::verifieringslank::utgangen', () {
    testWidgets('Skicka igen sends a new link, and no second one is sent '
        'inside the 60 s wait', (tester) async {
      await tester.pumpWidget(view());
      await tester.pump();

      expect(resend, findsOneWidget);
      expect(resendEnabled(tester), isTrue);
      await tester.tap(resend);
      await tester.pump();
      expect(sends, 1);

      // Inside the wait the action is off.
      expect(resendEnabled(tester), isFalse);
      await tester.tap(resend, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(resend, warnIfMissed: false);
      await tester.pump();
      expect(sends, 1, reason: 'no second link inside the 60 s');
    });

    // Known gaps, shrink-only (census PARTIAL, BUT-2172). This pins today's
    // behaviour, which is wrong on two counts:
    // - the countdown is built into the button's name,
    //   "Skicka igen (60s)" (email_verification_view.dart:170-172), where
    //   produktregler.md:676 puts it outside the name, since a name that
    //   changes every second is never read out;
    // - the wait is only read when something else rebuilds the view. The
    //   5 s poll does not call setState, so the button stays off after the
    //   60 s.
    // This test fails once either is fixed; then assert the canonical
    // behaviour instead, drop the known_gap in
    // test/fixtures/design/transition_census.json and set the entry TESTED.
    testWidgets('known gap: the wait is counted in the button name, and the '
        'button is not given back after the 60 s', (tester) async {
      await tester.pumpWidget(view());
      await tester.pump();
      await tester.tap(resend);
      await tester.pump();

      expect(
        find.descendant(
          of: resend,
          matching: find.text('${_sv.emailVerificationResend} (60s)'),
        ),
        findsOneWidget,
        reason: 'known gap: the countdown is in the name (produktregler:676)',
      );

      await tester.pump(const Duration(seconds: 90));
      await tester.pump();

      expect(
        resendEnabled(tester),
        isFalse,
        reason: 'known gap: the action is not given back after the 60 s',
      );
    });
  });
}
