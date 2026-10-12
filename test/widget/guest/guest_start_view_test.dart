// BUT-920: "Prova utan konto". Birth year and terms first; under 15 is
// refused here, before any account exists.

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/guest/guest_start_coordinator.dart';
import 'package:butlery/views/auth/guest_start_view.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

class _MockGuestAuth extends Mock implements GuestAuthService {}

class _MockAge extends Mock implements AgeVerificationService {}

void main() {
  late _MockGuestAuth guestAuth;
  late _MockAge age;
  late FakeAuthService auth;
  late List<String> seeded;
  final defaultDestination = GuestStartView.destinationBuilder;

  setUp(() {
    guestAuth = _MockGuestAuth();
    age = _MockAge();
    auth = FakeAuthService(null);
    seeded = [];
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async {
      auth.signInAs(FakeUser(isAnonymous: true, uid: 'guest-1'));
      return true;
    });
    when(() => age.verifyAge(any())).thenAnswer(
      (_) async => const AgeVerificationResult(compliant: true, isMinor: false),
    );
    registerAuth(auth);
    GetIt.instance.registerSingleton<GuestStartCoordinator>(
      GuestStartCoordinator(
        guestAuth: () => guestAuth,
        authService: auth,
        ageVerification: () => age,
        eraseGuest: () async => true,
        seedStarterRecipes: (uid) async => seeded.add(uid),
      ),
    );
    GuestStartView.destinationBuilder = (_) => const Text('hem');
  });

  tearDown(() async {
    GuestStartView.destinationBuilder = defaultDestination;
    await resetLocator();
  });

  Future<void> pickYear(WidgetTester tester, int year) async {
    await tester.tap(find.byKey(GuestStartView.birthYearKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year').last);
    await tester.pumpAndSettle();
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(GuestStartView.submitKey));
    await tester.tap(find.byKey(GuestStartView.submitKey));
    await tester.pumpAndSettle();
  }

  testWidgets('a 14-year-old is refused before any account is made', (
    tester,
  ) async {
    await tester.pumpWidget(guestApp(const GuestStartView()));
    expect(find.text(_sv.guestStartYearNote), findsOneWidget);

    await pickYear(tester, clock.now().year - 14);
    await acceptTerms(tester);
    await submit(tester);

    expect(find.text(_sv.onboardingAgeGateTooYoungTitle), findsOneWidget);
    verifyNever(() => guestAuth.signInAsGuest());
  });

  testWidgets('"Tillbaka till inloggningen" leaves the screen', (tester) async {
    await tester.pumpWidget(
      guestApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuestStartView()),
            ),
            child: const Text('sign-in'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sign-in'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestStartView), findsOneWidget);

    await tester.ensureVisible(find.byKey(GuestStartView.backKey));
    await tester.tap(find.byKey(GuestStartView.backKey));
    await tester.pumpAndSettle();

    expect(find.byType(GuestStartView), findsNothing);
    expect(find.text('sign-in'), findsOneWidget);
  });

  testWidgets('the terms must be accepted before a guest is made', (
    tester,
  ) async {
    await tester.pumpWidget(guestApp(const GuestStartView()));

    await pickYear(tester, clock.now().year - 16);
    await submit(tester);

    expect(find.text(_sv.authTermsAcceptRequired), findsOneWidget);
    verifyNever(() => guestAuth.signInAsGuest());
  });

  testWidgets('a birth year must be picked', (tester) async {
    await tester.pumpWidget(guestApp(const GuestStartView()));

    await acceptTerms(tester);
    await submit(tester);

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(_sv.onboardingAgeGateBirthYearHint),
      ),
      findsOneWidget,
    );
    verifyNever(() => guestAuth.signInAsGuest());
  });

  testWidgets('an adult who accepts the terms is signed in, age-checked, '
      'seeded and sent on', (tester) async {
    await tester.pumpWidget(guestApp(const GuestStartView()));
    final year = clock.now().year - 16;

    await pickYear(tester, year);
    await acceptTerms(tester);
    await submit(tester);

    verify(() => age.verifyAge(year)).called(1);
    expect(seeded, ['guest-1']);
    expect(find.text('hem'), findsOneWidget);
  });

  testWidgets('a failed start says so and stays on the screen', (
    tester,
  ) async {
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async => false);
    await tester.pumpWidget(guestApp(const GuestStartView()));

    await pickYear(tester, clock.now().year - 16);
    await acceptTerms(tester);
    await submit(tester);

    expect(find.text(_sv.guestStartFailed), findsOneWidget);
    expect(find.byKey(GuestStartView.submitKey), findsOneWidget);
    expect(
      GetIt.instance<GuestStartCoordinator>().takePendingFailure(),
      isNull,
      reason: 'the screen showed it, so the sign-in screen must not again',
    );
  });
}
