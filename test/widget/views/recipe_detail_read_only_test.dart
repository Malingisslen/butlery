// test/widget/views/recipe_detail_read_only_test.dart
//
// Task 4 (2026-06-21): readOnly mode on RecipeDetailView.
// When readOnly:true, owner actions (favorite toggle, Edit, Edit-tags, Delete)
// are hidden; the Save-a-copy (fork) action and comments/ratings remain.
//
// Harness mirrors test/views/recipe_detail_view_test.dart:
//   production.ServiceLocator.initialize(DIContainer()) + ViewTestHelpers
//   bridge + MockUnifiedRecipeService/MockUserService/MockSocialRecipeViewModel/
//   MockOfflineService/FakeCookSnapService registered in the shared GetIt.
//
// Scope note: the overflow menu is not opened — tapping PopupMenuButton in
// widget tests requires the route/overlay infrastructure present in
// recipe_detail_view_test.dart. The favorite-toggle key assertion is the
// highest-value behavioral check: it is visible without scrolling and directly
// verifies the readOnly contract. The save-copy check verifies the retained
// action. Both are in the hero button column, no overlay interaction needed.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail_view.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../views/helpers/view_test_helpers.dart';

// Minimal CookSnapService fake — gallery only needs its stream.
class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _testUserId = 'test-user-123';
const _friendUserId = 'friend-user-456';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late MockSocialRecipeViewModel socialVm;
  late Recipe ownedRecipe;
  late Recipe friendRecipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // An owned recipe: favorite toggle is visible (readOnly defaults to false).
    ownedRecipe = RecipeFactory.build(
      id: 'recipe-owned-1',
      title: 'Ägda Pannkakor',
      createdBy: _testUserId,
      ingredients: ['mjöl', 'mjölk', 'ägg'],
      instructions: ['Blanda.', 'Stek.'],
    );

    // A friend's recipe: createdBy differs from test user → showForkInAppBar
    // returns true so test-recipe-detail-save-copy appears; readOnly:true hides
    // the favorite toggle.
    friendRecipe = RecipeFactory.build(
      id: 'recipe-friend-1',
      title: 'Vännens Pasta',
      createdBy: _friendUserId,
      ingredients: ['pasta', 'tomatsås', 'ost'],
      instructions: ['Koka pasta.', 'Häll på sås.'],
    );

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(
        recipes: [ownedRecipe, friendRecipe], isInitialized: true);
    when(() => recipeService.toggleFavorite(any(), any()))
        .thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

    TestServiceLocator.registerMock<RecipeCookingService>(
        MockFactory.createRecipeCookingService());

    userService = MockUserService();
    when(() => userService.allergenPreferences)
        .thenReturn(UserAllergenPreferences.defaults);
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(userService);

    socialVm = MockSocialRecipeViewModel();
    when(() => socialVm.initialize()).thenAnswer((_) async {});
    when(() => socialVm.refreshComments(any())).thenAnswer((_) async {});
    when(() => socialVm.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(socialVm);

    final offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    TestServiceLocator.registerMock<CookSnapService>(_FakeCookSnapService());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget localize(Widget home) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: home,
    );
  }

  Future<void> pumpView(WidgetTester tester, Widget view) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(localize(view));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('RecipeDetailView — readOnly mode (Task 4)', () {
    testWidgets('readOnly:true hides the favorite toggle and shows save-copy',
        (tester) async {
      // Proves: when a friend's recipe is shown with readOnly:true, the
      // favorite toggle (owner action) is absent and the save-a-copy fork
      // button (non-owner action) is present.
      await pumpView(
          tester, RecipeDetailView(recipe: friendRecipe, readOnly: true));

      expect(tester.takeException(), isNull);
      // Owner action hidden:
      expect(find.byKey(const ValueKey('test-recipe-detail-favorite')),
          findsNothing,
          reason: 'Favorite toggle must be hidden when readOnly:true');
      // Non-owner/retained action present:
      expect(find.byKey(const ValueKey('test-recipe-detail-save-copy')),
          findsOneWidget,
          reason: 'Save-a-copy must remain visible when readOnly:true');
    });

    testWidgets('readOnly:false (default) keeps the favorite toggle visible',
        (tester) async {
      // Proves: the default behavior (owned recipe, readOnly omitted) still
      // shows the favorite toggle — the flag does not regress the normal path.
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('test-recipe-detail-favorite')),
          findsOneWidget,
          reason: 'Favorite toggle must be visible when readOnly:false');
    });
  });
}
