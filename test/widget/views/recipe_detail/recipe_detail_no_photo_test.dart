/// BUT-2311 / B-04: a recipe page without a photo is a typographic head on
/// paper with "Lägg till foto" for whoever can edit it; a recipe with a photo
/// keeps the ring behind the header icons.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
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
import 'package:butlery/views/recipe_detail/nutrition/recipe_nutrition_section.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/recipe_image_states.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _FakeCookSnapService extends Fake implements CookSnapService {
  int watchCount = 0;

  /// Streams handed out in order; once used up, an empty gallery.
  final List<Stream<List<CookSnap>>> queued = [];

  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) {
    watchCount++;
    return queued.isEmpty
        ? Stream.value(const <CookSnap>[])
        : queued.removeAt(0);
  }
}

class _PopsTrue extends StatefulWidget {
  const _PopsTrue();

  @override
  State<_PopsTrue> createState() => _PopsTrueState();
}

class _PopsTrueState extends State<_PopsTrue> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

const _me = 'test-user-123';
const _other = 'friend-user-456';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _FakeCookSnapService cookSnaps;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    recipeService = MockUnifiedRecipeService();
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );
    userService = MockUserService();
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
    cookSnaps = _FakeCookSnapService();
    TestServiceLocator.registerMock<CookSnapService>(cookSnaps);
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
    Recipe? savedAs,
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
          if (savedAs != null && settings.name == Routes.editRecipe) {
            // The editor saved: the service holds the new recipe, the route
            // pops `true` as EditRecipeView does after a successful save.
            recipeService.setRecipeState(
              recipes: [savedAs],
              isInitialized: true,
            );
            return MaterialPageRoute<bool>(
              settings: settings,
              builder: (_) => const _PopsTrue(),
            );
          }
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

  // BUT-643: the nutrition button is on every recipe, own or not, and the
  // section is handed the scaler's portion count.
  testWidgets('the nutrition section is on the recipe and follows the scaler', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(
      id: 'r6',
      title: 'Vännens soppa',
      createdBy: _other,
      portions: 4,
      imageUrls: [],
    );
    await pump(tester, recipe);

    final section = find.byType(RecipeNutritionSection);
    expect(section, findsOneWidget);
    expect(tester.widget<RecipeNutritionSection>(section).portions, 4);

    final plus = find.byWidgetPredicate(
      (w) => w is ButleryIcon && w.icon == ButleryIcons.plus,
    );
    // Mid-screen: the bottom edge sits under the bottom navigation.
    await Scrollable.ensureVisible(
      tester.element(plus.first),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(plus.first);
    await tester.pump();
    expect(tester.widget<RecipeNutritionSection>(section).portions, 5);
  });

  testWidgets('after a saved edit the ingredient list shows the new recipe', (
    tester,
  ) async {
    final original = RecipeFactory.build(
      id: 'r7',
      title: 'Gröt',
      createdBy: _me,
      portions: 4,
      ingredients: ['4 dl mjöl'],
      imageUrls: [],
    );
    final edited = RecipeFactory.build(
      id: 'r7',
      title: 'Gröt',
      createdBy: _me,
      portions: 4,
      ingredients: ['4 dl havregryn'],
      imageUrls: [],
    );
    await pump(tester, original, savedAs: edited);
    expect(find.textContaining('mjöl', skipOffstage: false), findsWidgets);

    await tester.ensureVisible(find.byType(RecipeAddPhotoChip));
    await tester.tap(find.byType(RecipeAddPhotoChip));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('havregryn', skipOffstage: false), findsWidgets);
    expect(find.textContaining('mjöl', skipOffstage: false), findsNothing);
  });

  group('allergen status on a recipe that was never tagged', () {
    final untagged = RecipeFactory.build(
      id: 'r8',
      title: 'Otaggad',
      createdBy: _me,
      imageUrls: [],
    );
    final sv = AppLocalizationsSv();

    testWidgets('says it is unchecked when the user shows allergens', (
      tester,
    ) async {
      expect(untagged.tagResult, isNull);
      await pump(tester, untagged);

      expect(find.text(sv.allergenUncheckedLabel), findsOneWidget);
      expect(find.text(sv.allergenUncheckedDetail), findsOneWidget);
    });

    testWidgets('says nothing when the user hides allergens on detail', (
      tester,
    ) async {
      when(() => userService.allergenPreferences).thenReturn(
        UserAllergenPreferences.defaults.copyWith(showOnDetail: false),
      );
      await pump(tester, untagged);

      expect(find.text('Otaggad'), findsOneWidget);
      expect(find.text(sv.allergenUncheckedLabel), findsNothing);
      expect(find.text(sv.allergenUncheckedDetail), findsNothing);
    });
  });

  testWidgets('a failed cook-snap load offers Försök igen, which reloads', (
    tester,
  ) async {
    final failing = StreamController<List<CookSnap>>();
    cookSnaps.queued.add(failing.stream);
    final recipe = RecipeFactory.build(
      id: 'r9',
      title: 'Snaps',
      createdBy: _me,
      imageUrls: [],
    );
    await pump(tester, recipe);
    expect(cookSnaps.watchCount, 1);

    failing.addError(StateError('offline'));
    await tester.pump();
    final retry = find.text(AppLocalizationsSv().commonRetry);
    await tester.ensureVisible(retry);
    await tester.pump();

    await tester.tap(retry);
    await tester.pump();

    expect(cookSnaps.watchCount, 2);
    expect(retry, findsNothing);
  });
}
