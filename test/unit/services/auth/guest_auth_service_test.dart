// BUT-920: signing in as a guest and turning the guest into an account.

import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

void main() {
  late _MockRepo repo;
  late _MockAuthService authService;
  late _MockAnalytics analytics;
  late int scopePushes;
  late List<String> termsRecorded;
  late GuestAuthService service;

  setUpAll(() => registerFallbackValue(_MockUser()));

  setUp(() {
    repo = _MockRepo();
    authService = _MockAuthService();
    analytics = _MockAnalytics();
    scopePushes = 0;
    termsRecorded = [];
    when(
      () => analytics.logSignUp(method: any(named: 'method')),
    ).thenAnswer((_) async {});
    when(() => authService.reloadUser()).thenAnswer((_) async {});
    service = GuestAuthService(
      authRepository: repo,
      authService: authService,
      analyticsService: analytics,
      pushUserScope: () async => scopePushes++,
      recordTerms: (uid) async => termsRecorded.add(uid),
    );
  });

  _MockUser user({required bool anonymous}) {
    final u = _MockUser();
    when(() => u.isAnonymous).thenReturn(anonymous);
    when(() => u.uid).thenReturn('guest-1');
    return u;
  }

  group('signInAsGuest', () {
    test('signs in anonymously and opens the user scope', () async {
      final guest = user(anonymous: true);
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(guest);
      when(() => repo.signInAnonymously()).thenAnswer((_) async => credential);

      expect(await service.signInAsGuest(), isTrue);
      expect(scopePushes, 1);
      verify(() => analytics.logSignUp(method: 'guest')).called(1);
    });

    test('a refused sign-in reports false and opens no scope', () async {
      when(
        () => repo.signInAnonymously(),
      ).thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));

      expect(await service.signInAsGuest(), isFalse);
      expect(scopePushes, 0);
    });
  });

  group('upgradeGuest', () {
    test('links the e-mail, names the account, sends the verification '
        'mail and tells AuthService the account changed', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(guest);
      when(
        () => repo.linkEmailPassword(any(), any()),
      ).thenAnswer((_) async => credential);
      when(() => repo.updateDisplayName(any(), any())).thenAnswer((_) async {});
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});

      await service.upgradeGuest(
        displayName: ' Malin ',
        email: ' malin@exempel.se ',
        password: 'Hemligt123!',
      );

      verify(
        () => repo.linkEmailPassword('malin@exempel.se', 'Hemligt123!'),
      ).called(1);
      verify(() => repo.updateDisplayName(guest, 'Malin')).called(1);
      expect(termsRecorded, ['guest-1']);
      verify(() => repo.sendEmailVerification()).called(1);
      // The link keeps the uid, so the auth stream stays quiet: without this
      // the guest band would stay up.
      verify(() => authService.reloadUser()).called(1);
    });

    for (final code in ['email-already-in-use', 'credential-already-in-use']) {
      test('$code is reported as emailInUse and changes nothing', () async {
        final current = user(anonymous: true);
        when(() => repo.currentUser).thenReturn(current);
        when(
          () => repo.linkEmailPassword(any(), any()),
        ).thenThrow(FirebaseAuthException(code: code));

        await expectLater(
          service.upgradeGuest(
            displayName: 'Malin',
            email: 'malin@exempel.se',
            password: 'Hemligt123!',
          ),
          throwsA(
            isA<GuestUpgradeException>().having(
              (e) => e.reason,
              'reason',
              GuestUpgradeFailure.emailInUse,
            ),
          ),
        );
        verifyNever(() => repo.updateDisplayName(any(), any()));
        verifyNever(() => authService.reloadUser());
        expect(termsRecorded, isEmpty);
      });
    }

    test('another refusal is reported as other', () async {
      final current = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(current);
      when(
        () => repo.linkEmailPassword(any(), any()),
      ).thenThrow(FirebaseAuthException(code: 'weak-password'));

      await expectLater(
        service.upgradeGuest(
          displayName: 'Malin',
          email: 'malin@exempel.se',
          password: 'kort',
        ),
        throwsA(
          isA<GuestUpgradeException>().having(
            (e) => e.reason,
            'reason',
            GuestUpgradeFailure.other,
          ),
        ),
      );
    });

    test('an account that is not a guest is not linked', () async {
      final current = user(anonymous: false);
      when(() => repo.currentUser).thenReturn(current);

      await expectLater(
        service.upgradeGuest(
          displayName: 'Malin',
          email: 'malin@exempel.se',
          password: 'Hemligt123!',
        ),
        throwsA(
          isA<GuestUpgradeException>().having(
            (e) => e.reason,
            'reason',
            GuestUpgradeFailure.notGuest,
          ),
        ),
      );
      verifyNever(() => repo.linkEmailPassword(any(), any()));
    });

    for (final failing in ['name', 'terms', 'analytics']) {
      test('a failed $failing step after the link does not fail the upgrade '
          'or skip the others, because the link cannot be undone', () async {
        final guest = user(anonymous: true);
        when(() => repo.currentUser).thenReturn(guest);
        final credential = _MockCredential();
        when(() => credential.user).thenReturn(guest);
        when(
          () => repo.linkEmailPassword(any(), any()),
        ).thenAnswer((_) async => credential);
        when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
        if (failing == 'name') {
          when(
            () => repo.updateDisplayName(any(), any()),
          ).thenThrow(Exception('offline'));
        } else {
          when(
            () => repo.updateDisplayName(any(), any()),
          ).thenAnswer((_) async {});
        }
        if (failing == 'analytics') {
          when(
            () => analytics.logSignUp(method: any(named: 'method')),
          ).thenThrow(Exception('offline'));
        }
        final terms = <String>[];
        service = GuestAuthService(
          authRepository: repo,
          authService: authService,
          analyticsService: analytics,
          pushUserScope: () async => scopePushes++,
          recordTerms: (uid) async {
            if (failing == 'terms') throw Exception('offline');
            terms.add(uid);
          },
        );

        await service.upgradeGuest(
          displayName: 'Malin',
          email: 'malin@exempel.se',
          password: 'Hemligt123!',
        );

        verify(() => repo.updateDisplayName(guest, 'Malin')).called(1);
        expect(terms, failing == 'terms' ? isEmpty : ['guest-1']);
        verify(() => repo.sendEmailVerification()).called(1);
        verify(() => authService.reloadUser()).called(1);
        verify(() => analytics.logSignUp(method: 'guest_upgrade')).called(1);
      });
    }

    test('a failed verification mail does not fail the upgrade', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(guest);
      when(
        () => repo.linkEmailPassword(any(), any()),
      ).thenAnswer((_) async => credential);
      when(() => repo.updateDisplayName(any(), any())).thenAnswer((_) async {});
      when(() => repo.sendEmailVerification()).thenThrow(Exception('offline'));

      await service.upgradeGuest(
        displayName: 'Malin',
        email: 'malin@exempel.se',
        password: 'Hemligt123!',
      );

      verify(() => authService.reloadUser()).called(1);
    });
  });

  group('upgradeGuestWithProvider', () {
    test('links the provider, names the account after it, records the terms '
        'and tells AuthService the account changed', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      when(
        () => authService.linkProviderToGuest(SignInProvider.google),
      ).thenAnswer((_) async => const ProviderAttempt.signedIn());
      when(
        () => authService.linkedProviderName(SignInProvider.google),
      ).thenReturn('Malin Gisslén');
      when(() => repo.updateDisplayName(any(), any())).thenAnswer((_) async {});

      final link = await service.upgradeGuestWithProvider(
        SignInProvider.google,
      );

      expect(link?.displayName, 'Malin Gisslén');
      verify(() => repo.updateDisplayName(guest, 'Malin Gisslén')).called(1);
      expect(termsRecorded, ['guest-1']);
      verify(() => authService.reloadUser()).called(1);
      verify(
        () => analytics.logSignUp(method: 'guest_upgrade_google'),
      ).called(1);
      // A provider's address is verified by the provider.
      verifyNever(() => repo.sendEmailVerification());
    });

    test('an account the provider gives no name keeps its own name', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      when(
        () => authService.linkProviderToGuest(SignInProvider.apple),
      ).thenAnswer((_) async => const ProviderAttempt.signedIn());
      when(
        () => authService.linkedProviderName(SignInProvider.apple),
      ).thenReturn(null);

      final link = await service.upgradeGuestWithProvider(SignInProvider.apple);

      expect(link?.displayName, isNull);
      verifyNever(() => repo.updateDisplayName(any(), any()));
      verify(() => authService.reloadUser()).called(1);
    });

    test('a closed sheet returns null and changes nothing', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      when(
        () => authService.linkProviderToGuest(SignInProvider.google),
      ).thenAnswer((_) async => const ProviderAttempt.cancelled());

      expect(
        await service.upgradeGuestWithProvider(SignInProvider.google),
        isNull,
      );
      verifyNever(() => authService.reloadUser());
      expect(termsRecorded, isEmpty);
    });

    for (final code in ['credential-already-in-use', 'email-already-in-use']) {
      test('$code is reported as providerInUse and changes nothing', () async {
        final guest = user(anonymous: true);
        when(() => repo.currentUser).thenReturn(guest);
        when(
          () => authService.linkProviderToGuest(SignInProvider.google),
        ).thenAnswer(
          (_) async =>
              ProviderAttempt.failed(FirebaseAuthException(code: code)),
        );

        await expectLater(
          service.upgradeGuestWithProvider(SignInProvider.google),
          throwsA(
            isA<GuestUpgradeException>().having(
              (e) => e.reason,
              'reason',
              GuestUpgradeFailure.providerInUse,
            ),
          ),
        );
        verifyNever(() => authService.reloadUser());
        expect(termsRecorded, isEmpty);
      });
    }

    test('another refusal is reported as other', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      when(
        () => authService.linkProviderToGuest(SignInProvider.google),
      ).thenAnswer((_) async => const ProviderAttempt.failed());

      await expectLater(
        service.upgradeGuestWithProvider(SignInProvider.google),
        throwsA(
          isA<GuestUpgradeException>().having(
            (e) => e.reason,
            'reason',
            GuestUpgradeFailure.other,
          ),
        ),
      );
    });

    test('an account that is not a guest is not linked', () async {
      final current = user(anonymous: false);
      when(() => repo.currentUser).thenReturn(current);

      await expectLater(
        service.upgradeGuestWithProvider(SignInProvider.google),
        throwsA(
          isA<GuestUpgradeException>().having(
            (e) => e.reason,
            'reason',
            GuestUpgradeFailure.notGuest,
          ),
        ),
      );
      verifyNever(
        () => authService.linkProviderToGuest(SignInProvider.google),
      );
    });

    test('a failed name or terms step after the link does not fail the '
        'upgrade or skip the others', () async {
      final guest = user(anonymous: true);
      when(() => repo.currentUser).thenReturn(guest);
      when(
        () => authService.linkProviderToGuest(SignInProvider.google),
      ).thenAnswer((_) async => const ProviderAttempt.signedIn());
      when(
        () => authService.linkedProviderName(SignInProvider.google),
      ).thenReturn('Malin');
      when(
        () => repo.updateDisplayName(any(), any()),
      ).thenThrow(Exception('offline'));
      service = GuestAuthService(
        authRepository: repo,
        authService: authService,
        analyticsService: analytics,
        pushUserScope: () async => scopePushes++,
        recordTerms: (uid) async => throw Exception('offline'),
      );

      final link = await service.upgradeGuestWithProvider(
        SignInProvider.google,
      );

      expect(link?.displayName, 'Malin');
      verify(() => authService.reloadUser()).called(1);
      verify(
        () => analytics.logSignUp(method: 'guest_upgrade_google'),
      ).called(1);
    });
  });
}
