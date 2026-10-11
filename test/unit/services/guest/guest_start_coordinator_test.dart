// BUT-920: "Prova utan konto" from the birth year to Hem.

import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_start_coordinator.dart';
import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGuestAuth extends Mock implements GuestAuthService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockAgeVerification extends Mock implements AgeVerificationService {}

class _MockUser extends Mock implements User {}

void main() {
  final now = DateTime(2026, 10, 11);
  late _MockGuestAuth guestAuth;
  late _MockAuthService authService;
  late _MockAgeVerification age;
  late List<String> seeded;
  late int erasures;
  late bool eraseSucceeds;
  late GuestStartCoordinator coordinator;

  setUp(() {
    guestAuth = _MockGuestAuth();
    authService = _MockAuthService();
    age = _MockAgeVerification();
    seeded = [];
    erasures = 0;
    eraseSucceeds = true;
    final guest = _MockUser();
    when(() => guest.uid).thenReturn('guest-1');
    when(() => authService.currentUser).thenReturn(guest);
    when(() => authService.currentUserId).thenReturn('guest-1');
    when(() => authService.signOut()).thenAnswer((_) async {});
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async => true);
    coordinator = GuestStartCoordinator(
      guestAuth: () => guestAuth,
      authService: authService,
      ageVerification: () => age,
      eraseGuest: () async {
        erasures++;
        return eraseSucceeds;
      },
      seedStarterRecipes: (uid) async => seeded.add(uid),
    );
  });

  Future<GuestStartOutcome> start(int birthYear) =>
      withClock(Clock.fixed(now), () => coordinator.start(birthYear));

  test('under 15 is refused before any account exists', () async {
    expect(await start(2012), GuestStartOutcome.tooYoung);
    verifyNever(() => guestAuth.signInAsGuest());
    verifyNever(() => age.verifyAge(any()));
  });

  test('the year that turns 15 this year is old enough', () {
    withClock(Clock.fixed(now), () {
      expect(GuestStartCoordinator.isOldEnough(2011), isTrue);
      expect(GuestStartCoordinator.isOldEnough(2012), isFalse);
    });
  });

  test('a compliant guest is age-checked, then seeded, and nothing is left '
      'to show', () async {
    when(() => age.verifyAge(1990)).thenAnswer(
      (_) async => const AgeVerificationResult(compliant: true, isMinor: false),
    );

    expect(await start(1990), GuestStartOutcome.started);
    expect(seeded, ['guest-1']);
    expect(coordinator.takePendingFailure(), isNull);
    verifyNever(() => authService.signOut());
  });

  test('the app waits while the start runs and goes on when it ends', () async {
    when(() => age.verifyAge(any())).thenAnswer(
      (_) async => const AgeVerificationResult(compliant: true, isMinor: false),
    );
    final running = <bool>[];
    coordinator.addListener(() => running.add(coordinator.isRunning));

    await start(1990);

    expect(running, [true, false]);
  });

  test('a server refusal signs out (the server deleted the account) and '
      'is kept for the sign-in screen', () async {
    when(() => age.verifyAge(any())).thenAnswer(
      (_) async =>
          const AgeVerificationResult(compliant: false, isMinor: false),
    );

    expect(await start(2010), GuestStartOutcome.tooYoung);
    verify(() => authService.signOut()).called(1);
    expect(seeded, isEmpty);
    expect(coordinator.takePendingFailure(), GuestStartOutcome.tooYoung);
    expect(coordinator.takePendingFailure(), isNull, reason: 'shown once');
  });

  test('a failed age check erases the unchecked guest', () async {
    when(() => age.verifyAge(any())).thenThrow(Exception('internal'));
    // The erasure signs out itself.
    when(() => authService.currentUser).thenReturn(null);

    expect(await start(1990), GuestStartOutcome.failed);
    expect(erasures, 1);
    expect(seeded, isEmpty);
    verifyNever(() => authService.signOut());
    expect(coordinator.takePendingFailure(), GuestStartOutcome.failed);
  });

  test(
    'an erasure that cannot reach the server still signs the guest out',
    () async {
      when(() => age.verifyAge(any())).thenThrow(Exception('unavailable'));
      eraseSucceeds = false;

      expect(await start(1990), GuestStartOutcome.failed);
      verify(() => authService.signOut()).called(1);
    },
  );

  test('a failed sign-in stops before the age check', () async {
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async => false);
    when(() => authService.currentUserId).thenReturn(null);

    expect(await start(1990), GuestStartOutcome.failed);
    verifyNever(() => age.verifyAge(any()));
    expect(erasures, 0, reason: 'nobody was signed in');
  });

  test('a sign-in that failed after the anonymous account was made erases '
      'that guest', () async {
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async => false);

    expect(await start(1990), GuestStartOutcome.failed);
    verifyNever(() => age.verifyAge(any()));
    expect(erasures, 1);
    expect(seeded, isEmpty);
  });

  test('a failed seed does not undo a started guest', () async {
    when(() => age.verifyAge(any())).thenAnswer(
      (_) async => const AgeVerificationResult(compliant: true, isMinor: false),
    );
    coordinator = GuestStartCoordinator(
      guestAuth: () => guestAuth,
      authService: authService,
      ageVerification: () => age,
      eraseGuest: () async => true,
      seedStarterRecipes: (_) async => throw Exception('offline'),
    );

    expect(await start(1990), GuestStartOutcome.started);
  });

  test('a second tap while one runs joins it', () async {
    when(() => age.verifyAge(any())).thenAnswer(
      (_) async => const AgeVerificationResult(compliant: true, isMinor: false),
    );

    await Future.wait([start(1990), start(1990)]);

    verify(() => guestAuth.signInAsGuest()).called(1);
  });
}
