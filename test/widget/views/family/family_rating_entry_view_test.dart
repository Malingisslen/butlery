// "Vad tyckte ni?": the hand-the-phone-around screen. Each present diner gets a
// row; the account holder is named as such, unrated rows say so, tapping a star
// sets that row's verdict, and the private-note explains the skip option.
//
// The view model runs for real over a fake Firestore household, as in
// family_rating_entry_viewmodel_test.dart.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/family/family_rating_entry_view.dart';
import 'package:butlery/widgets/common/navigation/butlery_bottom_navigation.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

const _malin = 'user-malin';

class _FailingRatings extends FamilyRatingService {
  int calls = 0;

  @override
  Future<FamilyRating?> rateAsFamily({
    required String recipeId,
    required String householdId,
    required String memberId,
    required HouseholdMemberType memberType,
    required int stars,
    required String enteredByUid,
  }) async {
    calls++;
    return null;
  }
}

void main() {
  final sv = AppLocalizationsSv();
  late FakeFirebaseFirestore fs;
  late String householdId;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() async {
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(
          user: FakeUser(uid: _malin),
          userId: _malin,
          isAuthenticated: true,
        );
    (TestServiceLocator.get<UserService>() as MockUserService).setUserState(
      users: {
        _malin: MockFactory.createUserProfile(
          userId: _malin,
          displayName: 'Malin',
        ),
      },
    );
    TestServiceLocator.registerSingleton<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _malin),
    );

    fs = FakeFirebaseFirestore();
    final householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
    );
    final dinerRepo = FirebaseDinerProfileRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<FamilyRatingRepository>(
      FirebaseFamilyRatingRepository(
        firestore: fs,
        authRepository: TestServiceLocator.get<AuthRepository>(),
        householdRepository: householdRepo,
      ),
    );
    TestServiceLocator.registerSingleton<HouseholdRosterService>(
      HouseholdRosterService(),
    );
    final socialOps = _MockSocialRecipeOperations();
    final recipeService = _MockUnifiedRecipeService();
    when(() => recipeService.social).thenReturn(socialOps);
    TestServiceLocator.registerSingleton<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerSingleton<FamilyRatingService>(
      FamilyRatingService(),
    );

    final household = await householdRepo.ensureForUser(_malin);
    householdId = household.id;
    await dinerRepo.create(
      DinerProfile.create(
        householdId: householdId,
        name: 'Farfar',
        ageBand: DinerAgeBand.adult,
        createdBy: _malin,
      ),
    );
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const FamilyRatingEntryView(
          recipeId: 'recipe-1',
          recipeTitle: 'Pannkakor',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('the account holder is named "· du" and unrated rows say '
      'so', (tester) async {
    await pumpView(tester);

    expect(find.text('Malin · ${sv.familyRatingYou}'), findsOneWidget);
    expect(find.text('Farfar'), findsOneWidget);
    expect(find.text(sv.familyRatingNotSet), findsNWidgets(2));
  });

  testWidgets('the recipe is the line under the title and Spara stands where '
      'the tab bar would', (tester) async {
    await pumpView(tester);

    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text(sv.familyRatingSave), findsOneWidget);
    expect(find.byType(ButleryBottomNavigation), findsNothing);
  });

  testWidgets('tapping the fourth star gives that diner the score 4,0 and '
      'leaves the others unset', (tester) async {
    await pumpView(tester);

    await tester.tap(
      find.bySemanticsLabel(sv.a11yRateStarsForMember('Farfar', 4)),
    );
    await tester.pumpAndSettle();

    expect(find.text('4,0'), findsOneWidget);
    expect(find.text(sv.familyRatingNotSet), findsOneWidget);
  });

  testWidgets('the private note tells the user the rows can be skipped', (
    tester,
  ) async {
    await pumpView(tester);

    expect(
      find.textContaining(sv.familyRatingNoteSkip, findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a failed save says so with a retry, and keeps the screen', (
    tester,
  ) async {
    final failing = _FailingRatings();
    TestServiceLocator.registerSingleton<FamilyRatingService>(failing);
    await pumpView(tester);

    await tester.tap(
      find.bySemanticsLabel(sv.a11yRateStarsForMember('Farfar', 4)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.familyRatingSave));
    await tester.pumpAndSettle();

    expect(find.text(sv.commonRetry), findsOneWidget);
    expect(find.byType(FamilyRatingEntryView), findsOneWidget);
    final before = failing.calls;

    await tester.tap(find.text(sv.commonRetry));
    await tester.pumpAndSettle();
    expect(failing.calls, greaterThan(before), reason: 'retry saves again');
  });

  testWidgets('leaving after a changed star asks first', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FamilyRatingEntryView(
                    recipeId: 'recipe-1',
                    recipeTitle: 'Pannkakor',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FamilyRatingEntryView), findsNothing, reason: 'clean');

    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(sv.a11yRateStarsForMember('Farfar', 4)),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(sv.unsavedChangesTitle), findsOneWidget);
    expect(find.byType(FamilyRatingEntryView), findsOneWidget);
  });
}
