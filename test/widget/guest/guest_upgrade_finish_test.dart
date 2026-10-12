// BUT-920: what "Skapa konto" from guest does to the profile once the e-mail
// is linked — the typed name is saved, and only an adult becomes searchable.

import 'package:butlery/l10n/app_localizations_sv.dart';
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

  // The profile the service holds before the reload and the one it holds
  // after it, so a read taken before the reload sees the wrong one.
  void stubProfile({UserProfile? before, required UserProfile? after}) {
    var current = before;
    when(() => users.currentUserProfile).thenAnswer((_) => current);
    when(() => users.retryLoadProfile()).thenAnswer((_) async {
      current = after;
    });
  }

  setUp(() {
    guestAuth = _MockGuestAuth();
    age = _MockAge();
    users = _MockUsers();
    registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
    GetIt.instance
      ..registerSingleton<GuestAuthService>(guestAuth)
      ..registerSingleton<AgeVerificationService>(age)
      ..registerSingleton<UserService>(users);
    when(
      () => guestAuth.upgradeGuest(
        displayName: any(named: 'displayName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(() => age.finishGuestUpgrade()).thenAnswer((_) async {});
    when(
      () => users.createOrUpdateProfile(
        displayName: any(named: 'displayName'),
        isSearchable: any(named: 'isSearchable'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(resetLocator);

  Future<void> upgrade(WidgetTester tester) async {
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

    await tester.enterText(find.byKey(GuestUpgradeView.nameKey), '  Malin ');
    await tester.enterText(
      find.byKey(GuestUpgradeView.emailKey),
      'malin@exempel.se',
    );
    await tester.enterText(
      find.byKey(GuestUpgradeView.passwordKey),
      'Hemligt123!x',
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.byKey(GuestUpgradeView.submitKey));
    await tester.tap(find.byKey(GuestUpgradeView.submitKey));
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestUpgradeDone), findsOneWidget);
  }

  testWidgets('an adult is saved under the typed name and made searchable, '
      'after the profile was reloaded', (tester) async {
    // Before the reload no profile is held, which the view treats as a minor;
    // only the reloaded one says adult.
    stubProfile(after: _profile(isMinor: false));

    await upgrade(tester);

    verifyInOrder([
      () => users.retryLoadProfile(),
      () => users.createOrUpdateProfile(
        displayName: 'Malin',
        isSearchable: true,
      ),
    ]);
  });

  testWidgets('a minor is saved under the typed name and is not made '
      'searchable', (tester) async {
    // The profile held before the reload says adult, so a minor flag read
    // from it would make this account searchable.
    stubProfile(
      before: _profile(isMinor: false),
      after: _profile(isMinor: true),
    );

    await upgrade(tester);

    verifyInOrder([
      () => users.retryLoadProfile(),
      () => users.createOrUpdateProfile(
        displayName: 'Malin',
        isSearchable: null,
      ),
    ]);
  });

  testWidgets('an account whose profile is still missing after the reload is '
      'treated as a minor and not made searchable', (tester) async {
    // The profile held before the reload says adult, so only the missing
    // reloaded one can decide.
    stubProfile(before: _profile(isMinor: false), after: null);

    await upgrade(tester);

    verify(
      () => users.createOrUpdateProfile(
        displayName: 'Malin',
        isSearchable: null,
      ),
    ).called(1);
  });
}
