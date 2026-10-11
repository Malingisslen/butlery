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
import 'package:butlery/views/recipe_detail/recipe_detail_tablet_content.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../views/helpers/view_test_helpers.dart';

class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _testUserId = 'test-user-123';

void main() {
  late Recipe recipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    recipe = RecipeFactory.build(
      id: 'recipe-pane-1',
      title: 'Köttbullar med Gräddsås',
      createdBy: _testUserId,
      ingredients: ['500 g köttfärs', '1 dl grädde', '1 gul lök'],
      instructions: ['Rulla köttbullarna.', 'Stek och servera med sås.'],
    );
    final recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
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

  Widget app(Widget home, {double textScale = 1}) => MaterialApp(
    locale: const Locale('sv', 'SE'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    // Cooking mode stands in as a marker on the ROOT navigator only, so it can
    // appear only if the pane pushes past its own navigator.
    onGenerateRoute: (settings) => settings.name == Routes.cookingMode
        ? MaterialPageRoute<Object?>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('cooking-root-marker')),
          )
        : null,
    home: home,
  );

  Future<void> pumpPane(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      app(
        Scaffold(
          body: DetailPaneHost(
            master: const Center(child: Text('lista')),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RecipeDetailView(recipe: recipe),
            ),
          ),
        ),
        textScale: textScale,
      ),
    );
    await tester.pump();
    final controller = DetailPaneScope.maybeOf(
      tester.element(find.text('lista', skipOffstage: false)),
    )!;
    controller.open(const RouteSettings(name: '/recipe'), key: recipe.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // One long pump leaves a route transition unfinished here; short steps
  // finish it.
  Future<void> settleRoute(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  DetailPaneController controllerOf(WidgetTester tester) =>
      DetailPaneScope.maybeOf(
        tester.element(find.text('lista', skipOffstage: false)),
      )!;

  group('RecipeDetailView on the detail pane (BUT-723)', () {
    testWidgets('draws no rail and no bottom row, and offers Helskärm', (
      tester,
    ) async {
      await pumpPane(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ButleryNavigationRail), findsNothing);
      expect(find.byType(ButleryBottomNavigation), findsNothing);
      expect(find.text('Helskärm'), findsOneWidget);
      expect(find.text('Visa listan'), findsNothing);
      expect(find.byType(RecipeDetailTabletContent), findsNothing);
    });

    testWidgets('the Helskärm toggle reads as not toggled while collapsed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPane(tester);
      expect(
        tester.getSemantics(find.text('Helskärm')),
        matchesSemantics(
          label: 'Helskärm',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('a second page pushed in the pane gets a back arrow, not '
        'Helskärm', (tester) async {
      await pumpPane(tester);
      Navigator.of(tester.element(find.byType(RecipeDetailView))).push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetailView(recipe: recipe),
        ),
      );
      await settleRoute(tester);

      expect(find.byTooltip('Tillbaka'), findsOneWidget);
      expect(find.text('Helskärm'), findsNothing);

      await tester.tap(find.byTooltip('Tillbaka'));
      await settleRoute(tester);
      expect(find.text('Helskärm'), findsOneWidget);
    });

    testWidgets('Börja laga opens cooking mode over the whole screen and '
        'comes back to the pane', (tester) async {
      await pumpPane(tester);
      final start = find.byKey(
        const ValueKey('test-recipe-detail-start-cooking'),
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await settleRoute(tester);

      final marker = find.text('cooking-root-marker');
      expect(marker, findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(of: marker, matching: find.byType(Scaffold)).first,
            )
            .width,
        1280,
      );

      Navigator.of(tester.element(marker)).pop();
      await settleRoute(tester);
      expect(find.text('cooking-root-marker'), findsNothing);
      expect(find.text('Helskärm'), findsOneWidget);
    });

    testWidgets('Helskärm expands to two columns and Visa listan returns', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPane(tester);

      await tester.tap(find.text('Helskärm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controllerOf(tester).expanded, isTrue);
      expect(find.byType(RecipeDetailTabletContent), findsOneWidget);
      expect(find.text('Visa listan'), findsOneWidget);
      expect(find.text('Helskärm'), findsNothing);
      expect(find.byType(ButleryNavigationRail), findsNothing);
      expect(
        tester.getSemantics(find.text('Visa listan')),
        matchesSemantics(
          label: 'Visa listan',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );

      await tester.tap(find.text('Visa listan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controllerOf(tester).expanded, isFalse);
      expect(find.byType(RecipeDetailTabletContent), findsNothing);
      expect(find.text('Helskärm'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the leading button keeps 48 dp and fits at 2x text', (
      tester,
    ) async {
      await pumpPane(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Helskärm')).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text('Helskärm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(TextButton, 'Visa listan');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('outside a pane the back button and bottom row stay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app(RecipeDetailView(recipe: recipe)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ButleryBottomNavigation), findsOneWidget);
    expect(find.byType(ButleryNavigationRail), findsNothing);
    expect(find.text('Helskärm'), findsNothing);
    expect(find.byTooltip('Tillbaka'), findsOneWidget);
  });
}
