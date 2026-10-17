/// Hosts for the Mer, settings and family views the register had not drawn
/// on their own.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/family/family_member_form_view.dart';
import 'package:butlery/views/family/min_familj_view.dart';
import 'package:butlery/views/more/account_area_view.dart';
import 'package:butlery/views/more/account_sign_in_methods_view.dart';
import 'package:butlery/views/more/app_settings_view.dart';
import 'package:butlery/views/more/blocked_users_view.dart';
import 'package:butlery/views/more/privacy_area_view.dart';
import 'package:butlery/views/settings/collection_stats_view.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_host.dart';

class _MockAuth extends Mock with ChangeNotifier implements AuthService {}

class _MockNotifications extends Mock implements NotificationService {}

class _MockNotifPermission extends Mock
    implements NotificationPermissionService {}

const _me = 'test-user-123';

UserProfile _profile() => testUserProfile(
  uid: _me,
  displayName: 'Malin Gisslén',
  email: 'malin@exempel.se',
);

/// An auth service that signs in with a password and Google, so the sign-in
/// rows have something to say.
_MockAuth _auth() {
  final auth = _MockAuth();
  when(() => auth.hasPasswordSignIn).thenReturn(true);
  when(() => auth.currentUserEmail).thenReturn('malin@exempel.se');
  when(() => auth.canUnlinkSignInMethod).thenReturn(true);
  when(() => auth.revokesAppleOnUnlink).thenReturn(false);
  when(() => auth.errorMessage).thenReturn(null);
  for (final p in SignInProvider.values) {
    final linked = p == SignInProvider.google;
    when(() => auth.isProviderLinked(p)).thenReturn(linked);
    when(() => auth.isProviderOffered(p)).thenReturn(true);
    when(
      () => auth.providerAccountEmail(p),
    ).thenReturn(linked ? 'malin@gmail.com' : null);
  }
  return auth;
}

MockUserService _users({UserProfile? current}) {
  final users = MockUserService();
  when(() => users.currentUserProfile).thenReturn(current ?? _profile());
  when(() => users.addListener(any())).thenReturn(null);
  when(() => users.removeListener(any())).thenReturn(null);
  return users;
}

/// Signed in as [_me], with a household holding two family members.
Future<void> _household() async {
  (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository).setAuthState(
    user: FakeUser(uid: _me),
    userId: _me,
    isAuthenticated: true,
  );
  (TestServiceLocator.get<UserService>() as MockUserService).setUserState(
    users: {
      _me: MockFactory.createUserProfile(userId: _me, displayName: 'Malin'),
    },
  );
  TestServiceLocator.registerSingleton<PermissionService>(
    MockFactory.createPermissionService(currentUserId: _me),
  );
  final fs = FakeFirebaseFirestore();
  final auth = TestServiceLocator.get<AuthRepository>();
  final households = FirebaseHouseholdRepository(
    firestore: fs,
    authRepository: auth,
  );
  final diners = FirebaseDinerProfileRepository(
    firestore: fs,
    authRepository: auth,
    householdRepository: households,
  );
  TestServiceLocator.registerSingleton<HouseholdRepository>(households);
  TestServiceLocator.registerSingleton<DinerProfileRepository>(diners);
  TestServiceLocator.registerSingleton<HouseholdRosterService>(
    HouseholdRosterService(),
  );
  final household = await households.ensureForUser(_me);
  for (final (name, band) in [
    ('Emma', DinerAgeBand.child),
    ('Albin', DinerAgeBand.teen),
  ]) {
    await diners.create(
      DinerProfile.create(
        householdId: household.id,
        name: name,
        ageBand: band,
        createdBy: _me,
        guardianConsent: GuardianConsent(
          byUid: _me,
          at: DateTime.utc(2026, 1, 1),
          consentVersion: DinerProfile.currentConsentVersion,
          includesAllergenConsent: false,
        ),
      ),
    );
  }
}

final reviewBHosts = <String, StateHost>{
  'AccountAreaView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<AuthService>(_auth());
      TestServiceLocator.registerMock<UserService>(_users());
      return const AccountAreaView();
    },
  ),
  'AccountSignInMethodsView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<AuthService>(_auth());
      return const AccountSignInMethodsView();
    },
  ),
  'AppSettingsView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerSingleton<LocaleProvider>(LocaleProvider());
      TestServiceLocator.registerSingleton<ThemeService>(ThemeService());
      TestServiceLocator.registerMock<UserService>(_users());
      return const AppSettingsView();
    },
  ),
  'BlockedUsersView': StateHost(
    build: (ctx) async {
      final management = MockFriendsManagementOperations()
        ..setManagementState(blockedUsers: {'u-anna', 'u-per'});
      final friends = MockFactory.createUnifiedFriendsService()
        ..setFriendsState(management: management, isInitialized: true);
      TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
      TestServiceLocator.registerMock<UserService>(
        MockUserService()..setUserState(
          users: {
            'u-anna': testUserProfile(
              uid: 'u-anna',
              displayName: 'Anna Lindqvist',
            ),
            'u-per': testUserProfile(uid: 'u-per', displayName: 'Per Nilsson'),
          },
        ),
      );
      return const BlockedUsersView();
    },
  ),
  'PrivacyAreaView': StateHost(
    build: (ctx) async => const PrivacyAreaView(),
  ),
  'CollectionStatsView': StateHost(
    build: (ctx) async {
      final now = DateTime(2026, 10, 10);
      final recipes = MockUnifiedRecipeService()
        ..setRecipeState(
          isInitialized: true,
          currentUserId: _me,
          recipes: [
            RecipeFactory.build(
              id: 'r1',
              title: 'Linsgryta med kokos',
              mealType: 'Middag',
              personalTagIds: ['vegetariskt', 'snabbt'],
              lastCookedAt: now.subtract(const Duration(days: 3)),
            ),
            RecipeFactory.build(
              id: 'r2',
              title: 'Pannkakor med lingon',
              mealType: 'Frukost',
              personalTagIds: ['barnvänligt'],
              imageUrls: ['https://example.com/a.jpg'],
            ),
            RecipeFactory.build(
              id: 'r3',
              title: 'Ugnsbakad lax',
              mealType: 'Middag',
              personalTagIds: ['snabbt'],
              rating: 5,
            ),
            RecipeFactory.build(
              id: 'r4',
              title: 'Quinoasallad',
              mealType: 'Lunch',
              personalTagIds: ['vegetariskt'],
              timeMinutes: null,
              ingredients: ['Quinoa'],
            ),
          ],
        );
      TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
      return const CollectionStatsView();
    },
  ),
  'NotificationPreferencesView': StateHost(
    build: (ctx) async {
      final service = _MockNotifications();
      when(
        service.getPreferences,
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      final permission = _MockNotifPermission();
      when(permission.blockedInSystem).thenAnswer((_) async => false);
      TestServiceLocator.registerMock<NotificationService>(service);
      TestServiceLocator.registerMock<NotificationPermissionService>(
        permission,
      );
      return const NotificationPreferencesView();
    },
  ),
  'FamilyMemberFormView': StateHost(
    build: (ctx) async {
      await _household();
      return const FamilyMemberFormView();
    },
  ),
  'MinFamiljView': StateHost(
    build: (ctx) async {
      await _household();
      return const MinFamiljView(backTo: 'Mer');
    },
    reach: (tester, ctx) async {
      await tester.pump(const Duration(milliseconds: 100));
    },
  ),
};
