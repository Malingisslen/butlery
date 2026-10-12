// BUT-916: "Skapa konto" from guest with Google or Apple links the provider to
// the guest's own account, names the profile after it and finishes the same
// server step the e-mail route does.

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/auth/guest_upgrade_view.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

class _MockGuestAuth extends Mock implements GuestAuthService {}

class _MockAge extends Mock implements AgeVerificationService {}

class _MockUsers extends Mock implements UserService {}

UserProfile _profile({required bool isMinor}) => UserProfile(
  uid: 'uid-1',
  displayName: 'Gäst',
  email: 'malin@exempel.se',
  joinedAt: DateTime(2026, 6, 1),
  lastActiveAt: DateTime(2026, 6, 1),
  isMinor: isMinor,
);

void main() {
  late _MockGuestAuth guestAuth;
  late _MockAge age;
  late _MockUsers users;
  late FakeAuthService auth;

  setUp(() {
    guestAuth = _MockGuestAuth();
    age = _MockAge();
    users = _MockUsers();
    auth = FakeAuthService(FakeUser(isAnonymous: true))
      ..offeredProviders = {SignInProvider.google, SignInProvider.apple};
    registerAuth(auth);
    GetIt.instance
      ..registerSingleton<GuestAuthService>(guestAuth)
      ..registerSingleton<AgeVerificationService>(age)
      ..registerSingleton<UserService>(users);
    when(() => age.finishGuestUpgrade()).thenAnswer((_) async {});
    when(() => users.retryLoadProfile()).thenAnswer((_) async {});
    when(
      () => users.currentUserProfile,
    ).thenReturn(_profile(isMinor: false));
    when(
      () => users.createOrUpdateProfile(
        displayName: any(named: 'displayName'),
        isSearchable: any(named: 'isSearchable'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(resetLocator);

  Future<void> open(WidgetTester tester) async {
    // Tall enough that the lazy list builds the whole form and the buttons.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      guestApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => const GuestUpgradeLauncher().launch(context),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestUpgradeView), findsOneWidget);
  }

  Future<void> tapProvider(WidgetTester tester, SignInProvider provider) async {
    final button = find.byKey(GuestUpgradeView.providerKey(provider));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('only the providers the device offers get a button', (
    tester,
  ) async {
    auth.offeredProviders = {SignInProvider.google};

    await open(tester);

    expect(
      find.byKey(GuestUpgradeView.providerKey(SignInProvider.google)),
      findsOneWidget,
    );
    expect(
      find.byKey(GuestUpgradeView.providerKey(SignInProvider.apple)),
      findsNothing,
    );
  });

  testWidgets('with no provider offered the form stands alone', (tester) async {
    auth.offeredProviders = {};

    await open(tester);

    expect(find.text(_sv.commonOr), findsNothing);
    expect(find.byKey(GuestUpgradeView.emailKey), findsOneWidget);
  });

  testWidgets('a linked Google account is finished, saved under the '
      "provider's name and made searchable", (tester) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).thenAnswer(
      (_) async => const GuestProviderLink(displayName: 'Malin Gisslén'),
    );

    await open(tester);
    await tapProvider(tester, SignInProvider.google);

    verifyInOrder([
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
      () => age.finishGuestUpgrade(),
      () => users.retryLoadProfile(),
      () => users.createOrUpdateProfile(
        displayName: 'Malin Gisslén',
        isSearchable: true,
      ),
    ]);
    expect(find.text(_sv.guestUpgradeDoneProvider), findsOneWidget);
    expect(find.text(_sv.guestUpgradeDone), findsNothing);
  });

  testWidgets('a provider that gives no name leaves the profile name as it '
      'is', (tester) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.apple),
    ).thenAnswer((_) async => const GuestProviderLink());

    await open(tester);
    await tapProvider(tester, SignInProvider.apple);

    verify(
      () => users.createOrUpdateProfile(
        displayName: 'Gäst',
        isSearchable: true,
      ),
    ).called(1);
  });

  testWidgets('a closed sheet finishes nothing', (tester) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).thenAnswer((_) async => null);

    await open(tester);
    await tapProvider(tester, SignInProvider.google);

    verifyNever(() => age.finishGuestUpgrade());
    expect(find.byType(GuestUpgradeView), findsOneWidget);
    expect(
      find.byKey(GuestUpgradeView.providerKey(SignInProvider.google)),
      findsOneWidget,
    );
  });

  testWidgets('a provider account that already has a Butlery account says so '
      'and offers to sign in instead', (tester) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).thenThrow(
      const GuestUpgradeException(GuestUpgradeFailure.providerInUse, 'x'),
    );

    await open(tester);
    await tapProvider(tester, SignInProvider.google);

    expect(find.text(_sv.signInMethodsAlreadyUsed('Google')), findsOneWidget);
    expect(find.byKey(GuestUpgradeView.signInInsteadKey), findsOneWidget);
    verifyNever(() => age.finishGuestUpgrade());
  });

  testWidgets('another refusal shows its message and keeps the buttons', (
    tester,
  ) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).thenThrow(
      const GuestUpgradeException(GuestUpgradeFailure.other, 'Något gick fel'),
    );

    await open(tester);
    await tapProvider(tester, SignInProvider.google);

    expect(find.text('Något gick fel'), findsOneWidget);
    expect(find.byKey(GuestUpgradeView.signInInsteadKey), findsNothing);
    expect(
      find.byKey(GuestUpgradeView.providerKey(SignInProvider.google)),
      findsOneWidget,
    );
  });

  testWidgets('a failed server step after the link keeps the provider name '
      'for the retry', (tester) async {
    when(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).thenAnswer((_) async => const GuestProviderLink(displayName: 'Malin'));
    var attempts = 0;
    when(() => age.finishGuestUpgrade()).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('offline');
    });

    await open(tester);
    await tapProvider(tester, SignInProvider.google);

    expect(find.text(_sv.guestUpgradeFinishFailed), findsOneWidget);
    // Linked: the provider buttons are gone, only the retry is left.
    expect(
      find.byKey(GuestUpgradeView.providerKey(SignInProvider.google)),
      findsNothing,
    );

    await tester.ensureVisible(find.byKey(GuestUpgradeView.submitKey));
    await tester.tap(find.byKey(GuestUpgradeView.submitKey));
    await tester.pumpAndSettle();

    verify(
      () => users.createOrUpdateProfile(
        displayName: 'Malin',
        isSearchable: true,
      ),
    ).called(1);
    verify(
      () => guestAuth.upgradeGuestWithProvider(SignInProvider.google),
    ).called(1);
  });
}
