/// BUT-1508: the GDPR services get their user-scoped dependencies as lookups
/// made when they run. The household repositories and NotificationService are
/// replaced at every sign-in, while the export and deletion services outlive
/// it, so a dependency captured when they were built would belong to the
/// previous account.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/account_services_from_locator.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/offline_service.dart';

import '../../../infrastructure/mocks/production_mocks.dart'
    show FakeAuthRepository, MockUser;

class _Functions extends Fake implements FirebaseFunctions {}

class _AuthService extends Mock implements AuthService {}

class _Notifications extends Mock implements NotificationService {}

class _Offline extends Mock implements OfflineService {}

class _FirestoreRepository extends Mock implements FirestoreRepository {}

class _Households extends Mock implements HouseholdRepository {}

class _Diners extends Mock implements DinerProfileRepository {}

class _FamilyRatings extends Mock implements FamilyRatingRepository {}

class _Comments extends Fake implements CommentsRepository {}

class _Ratings extends Fake implements RatingsRepository {}

class _Feedback extends Fake implements FeedbackRepository {}

class _CookSnaps extends Fake implements CookSnapRepository {}

class _CookEvents extends Fake implements CookEventRepository {}

class _ActivityEvents extends Fake implements ActivityEventRepository {}

class _WeeklyMenus extends Fake implements WeeklyMenuPlanRepository {}

class _GroupMenus extends Fake implements GroupWeeklyMenuPlanRepository {}

class _Pantry extends Fake implements PantryRepository {}

class _Recipes extends Fake implements RecipeRepository {}

class _PersonalTags extends Fake implements FirebasePersonalTagRepository {}

class _PersonalTagGroups extends Fake
    implements FirebasePersonalTagGroupRepository {}

_Notifications _notifications() {
  final n = _Notifications();
  when(n.resetForLogout).thenAnswer((_) async {});
  return n;
}

// A household the signed-in user created, so the export reads its diners and
// family ratings as well and all three user-scoped links are exercised.
final _household = Household(
  id: 'hh-u2',
  name: Household.defaultName,
  members: [
    HouseholdMember(
      userId: 'u2',
      permission: SharedListPermission.admin,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  createdBy: 'u2',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

_Households _households() {
  final h = _Households();
  when(() => h.getForUser(any())).thenAnswer((_) async => [_household]);
  return h;
}

_Diners _diners() {
  final d = _Diners();
  when(() => d.getByHousehold(any())).thenAnswer((_) async => const []);
  return d;
}

_FamilyRatings _familyRatings() {
  final r = _FamilyRatings();
  when(() => r.getForHousehold(any())).thenAnswer((_) async => const []);
  return r;
}

void main() {
  late GetIt container;

  setUp(() {
    container = GetIt.asNewInstance();
  });

  tearDown(() async {
    await container.reset();
  });

  group('buildAccountDeletionService', () {
    test('resets the NotificationService registered when it runs', () async {
      final auth = _AuthService();
      when(auth.signOut).thenAnswer((_) async {});
      container.registerSingleton<AuthService>(auth);
      final first = _notifications();
      container.registerSingleton<NotificationService>(first);

      final service = buildAccountDeletionService(container, _Functions());

      // A sign-in replaces the user scope after the service was built.
      await container.unregister<NotificationService>();
      final second = _notifications();
      container.registerSingleton<NotificationService>(second);

      await service.signOutAfterScheduling();

      verify(second.resetForLogout).called(1);
      verifyNever(first.resetForLogout);
      verify(auth.signOut).called(1);
    });
  });

  group('buildAccountDeletionService', () {
    test('clears the offline store of the account being deleted', () async {
      final auth = _AuthService();
      when(() => auth.currentUserId).thenReturn('u2');
      container.registerSingleton<AuthService>(auth);

      // Built before any user scope exists, as on a cold start.
      final service = buildAccountDeletionService(container, _Functions());

      final offline = _Offline();
      when(() => offline.clearUserData(any())).thenAnswer((_) async {});
      container.registerSingleton<OfflineService>(offline);

      // The callable is a fake that refuses every call, so the deletion stops
      // after the local clean-up; only that clean-up is under test here.
      await service.deleteUserAccount(reason: 'user_request');

      verify(() => offline.clearUserData('u2')).called(1);
    });
  });

  group('buildDataExportService', () {
    test(
      'exports the household of whoever is signed in at export time',
      () async {
        final firestore = FakeFirebaseFirestore();
        final user = MockUser()..setUserState(uid: 'u2', email: 'u2@test.se');
        final auth = FakeAuthRepository()
          ..setAuthState(user: user, userId: 'u2', isAuthenticated: true);
        final firestoreRepository = _FirestoreRepository();
        when(() => firestoreRepository.firestore).thenReturn(firestore);

        final previousAccount = _households();
        final previousDiners = _diners();
        final previousRatings = _familyRatings();
        container
          ..registerSingleton<AuthRepository>(auth)
          ..registerSingleton<FirestoreRepository>(firestoreRepository)
          ..registerSingleton<FirebaseDataExportRepository>(
            FirebaseDataExportRepository(
              firestore: firestore,
              authRepository: auth,
            ),
          )
          ..registerSingleton<CommentsRepository>(_Comments())
          ..registerSingleton<RatingsRepository>(_Ratings())
          ..registerSingleton<FeedbackRepository>(_Feedback())
          ..registerSingleton<CookSnapRepository>(_CookSnaps())
          ..registerSingleton<CookEventRepository>(_CookEvents())
          ..registerSingleton<ActivityEventRepository>(_ActivityEvents())
          ..registerSingleton<WeeklyMenuPlanRepository>(_WeeklyMenus())
          ..registerSingleton<GroupWeeklyMenuPlanRepository>(_GroupMenus())
          ..registerSingleton<PantryRepository>(_Pantry())
          ..registerSingleton<RecipeRepository>(_Recipes())
          ..registerSingleton<FirebasePersonalTagRepository>(_PersonalTags())
          ..registerSingleton<FirebasePersonalTagGroupRepository>(
            _PersonalTagGroups(),
          )
          ..registerSingleton<HouseholdRepository>(previousAccount)
          ..registerSingleton<DinerProfileRepository>(previousDiners)
          ..registerSingleton<FamilyRatingRepository>(previousRatings);

        final service = buildDataExportService(container, _Functions());

        // A sign-in replaces the user scope after the service was built.
        await container.unregister<HouseholdRepository>();
        await container.unregister<DinerProfileRepository>();
        await container.unregister<FamilyRatingRepository>();
        final signedIn = _households();
        final signedInDiners = _diners();
        final signedInRatings = _familyRatings();
        container
          ..registerSingleton<HouseholdRepository>(signedIn)
          ..registerSingleton<DinerProfileRepository>(signedInDiners)
          ..registerSingleton<FamilyRatingRepository>(signedInRatings);

        // The fakes behind the other sections refuse every read, so the bundle
        // may fail as a whole; the family section is started either way.
        try {
          await service.exportUserData();
        } on Object {
          // Irrelevant here: only which repositories were read is under test.
        }

        // The bundle can fail before the family section has finished.
        await pumpEventQueue();

        verify(() => signedIn.getForUser('u2')).called(1);
        verify(() => signedInDiners.getByHousehold('hh-u2')).called(1);
        verify(() => signedInRatings.getForHousehold('hh-u2')).called(1);
        verifyNever(() => previousAccount.getForUser(any()));
        verifyNever(() => previousDiners.getByHousehold(any()));
        verifyNever(() => previousRatings.getForHousehold(any()));
      },
    );
  });
}
