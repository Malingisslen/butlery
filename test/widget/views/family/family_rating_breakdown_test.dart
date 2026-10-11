/// The family-rating breakdown in the recipe detail, drawn as Skarmar v12
/// del 3 #betygsoversikt has it: the average as a pill, one row per diner
/// with "★ 5,0", and the legend. Real repository stack on a fake store.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
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
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/family/family_rating_breakdown.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

const _malin = 'user-malin';
const _johan = 'user-johan';
const _hh = 'hh-duo';
const _recipe = 'recipe-1';

void main() {
  late FakeFirebaseFirestore fs;
  late DinerProfileRepository dinerRepo;
  late FamilyRatingService ratingService;

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
        _johan: MockFactory.createUserProfile(
          userId: _johan,
          displayName: 'Johan',
        ),
      },
    );
    TestServiceLocator.registerSingleton<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _malin),
    );

    fs = FakeFirebaseFirestore();
    // Two account holders so a proxy entry (Johan, entered by Malin) is real.
    final hh = Household(
      id: _hh,
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: _malin,
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
        HouseholdMember(
          userId: _johan,
          permission: SharedListPermission.edit,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      createdBy: _malin,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await fs.collection('households').doc(_hh).set(hh.toFirestore());

    final householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
    );
    dinerRepo = FirebaseDinerProfileRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    final ratingRepo = FirebaseFamilyRatingRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<FamilyRatingRepository>(ratingRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(
      HouseholdRosterService(),
    );

    final socialOps = _MockSocialRecipeOperations();
    when(
      () => socialOps.rateRecipe(
        recipeId: any(named: 'recipeId'),
        rating: any(named: 'rating'),
        review: any(named: 'review'),
      ),
    ).thenAnswer((_) async => true);
    final recipeService = _MockUnifiedRecipeService();
    when(() => recipeService.social).thenReturn(socialOps);
    TestServiceLocator.registerSingleton<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerSingleton<FamilyRatingService>(
      FamilyRatingService(),
    );
    ratingService = FamilyRatingService();
  });

  Future<void> rate(
    String memberId,
    HouseholdMemberType type,
    int stars, {
    String enteredBy = _malin,
  }) => ratingService.rateAsFamily(
    recipeId: _recipe,
    householdId: _hh,
    memberId: memberId,
    memberType: type,
    stars: stars,
    enteredByUid: enteredBy,
  );

  Future<void> pumpBreakdown(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FamilyRatingBreakdown(
            recipe: RecipeFactory.build(id: _recipe, title: 'Svamppasta'),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('an expanded breakdown shows each diner as a star and a number', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await rate(_malin, HouseholdMemberType.user, 5);
      await rate(_johan, HouseholdMemberType.user, 3, enteredBy: _malin);
    });
    await pumpBreakdown(tester);

    await tester.tap(find.text('betyg'));
    await tester.pumpAndSettle();

    expect(find.text('Malin'), findsOneWidget);
    expect(find.text('5,0'), findsOneWidget);
    expect(find.text('3,0'), findsOneWidget);
  });
}
