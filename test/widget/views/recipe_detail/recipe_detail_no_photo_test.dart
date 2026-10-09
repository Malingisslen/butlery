/// BUT-2311 / B-04: a recipe page without a photo is a typographic head on
/// paper with "Lägg till foto" for whoever can edit it; a recipe with a photo
/// keeps the ring behind the header icons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
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
import 'package:butlery/widgets/recipe/recipe_image_states.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _me = 'test-user-123';
const _other = 'friend-user-456';

void main() {
  late MockUnifiedRecipeService recipeService;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    recipeService = MockUnifiedRecipeService();
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );
    final userService = MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(userService);
    final socialVm = MockSocialRecipeViewModel();
    when(() => socialVm.initialize()).thenAnswer((_) async {});
    when(() => socialVm.refreshComments(any())).thenAnswer((_) async {});
    when(() => socialVm.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(socialVm);
    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offline);
    TestServiceLocator.registerMock<CookSnapService>(_FakeCookSnapService());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  String? pushedRoute;

  Future<void> pump(
    WidgetTester tester,
    Recipe recipe, {
    Size size = const Size(420, 900),
    bool readOnly = false,
  }) async {
    pushedRoute = null;
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: RecipeDetailView(recipe: recipe, readOnly: readOnly),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Color? ringColor(WidgetTester tester) {
    final ring = tester.widget<Container>(
      find.byKey(const ValueKey('recipe-detail-paper-ring')).first,
    );
    return (ring.decoration as BoxDecoration).color;
  }

  testWidgets('no photo, own recipe: typographic head and the add-photo chip', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r1',
      title: 'Krämig svamppasta',
      createdBy: _me,
      mealType: 'Middag',
      imageUrls: [],
    );
    await pump(tester, recipe);

    expect(find.byKey(const ValueKey('recipe-detail-brand-line')), findsOne);
    expect(find.text('MIDDAG'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Krämig svamppasta'));
    expect(title.style!.fontSize, 26);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(find.byType(RecipeAddPhotoChip), findsOneWidget);
    expect(ringColor(tester), Colors.transparent);

    expect(pushedRoute, isNull);
    await tester.ensureVisible(find.byType(RecipeAddPhotoChip));
    await tester.tap(find.byType(RecipeAddPhotoChip));
    await tester.pump();
    expect(pushedRoute, Routes.editRecipe);
  });

  testWidgets('no photo, own recipe on a tablet: the add-photo chip', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r4',
      title: 'Krämig svamppasta',
      createdBy: _me,
      imageUrls: [],
    );
    await pump(tester, recipe, size: const Size(1100, 900));

    expect(find.byKey(const ValueKey('recipe-detail-brand-line')), findsOne);
    expect(find.byType(RecipeAddPhotoChip), findsOneWidget);
  });

  testWidgets('no photo, own recipe opened read-only: no add-photo chip', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r5',
      title: 'Krämig svamppasta',
      createdBy: _me,
      imageUrls: [],
    );
    await pump(tester, recipe, readOnly: true);

    expect(find.byKey(const ValueKey('recipe-detail-brand-line')), findsOne);
    expect(find.byType(RecipeAddPhotoChip), findsNothing);
  });

  testWidgets('no photo, someone else\'s recipe: no add-photo chip', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r2',
      title: 'Vännens pasta',
      createdBy: _other,
      imageUrls: [],
    );
    await pump(tester, recipe);

    expect(find.byKey(const ValueKey('recipe-detail-brand-line')), findsOne);
    expect(find.byType(RecipeAddPhotoChip), findsNothing);
  });

  testWidgets('with a photo: no brand line, no chip, visible rings', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r3',
      title: 'Med bild',
      createdBy: _me,
      imageUrls: ['https://example.com/a.jpg'],
    );
    await pump(tester, recipe);

    expect(
      find.byKey(const ValueKey('recipe-detail-brand-line')),
      findsNothing,
    );
    expect(find.byType(RecipeAddPhotoChip), findsNothing);
    expect(ringColor(tester), isNot(Colors.transparent));
  });
}
