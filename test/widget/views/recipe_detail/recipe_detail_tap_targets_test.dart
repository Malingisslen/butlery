// BUT-2218: three recipe-detail controls no a11y-matrix fixture rendered were
// under the 48 dp touch target (tokens.json touchTarget.min): the remove-own-
// rating X, the personal tags' "Visa alla" button and its "+N till" chip. Each
// test renders the control and asserts the size of the tappable itself, and
// that a press in the added space (not on the glyph or label) still reaches it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';
import '../../../test_support/semantics_announcement.dart';

// The remove control shows only for a shared recipe the user has rated.
class _RatedSocial extends FakeSocialRecipeOperations {
  @override
  Future<Map<String, dynamic>?> getUserRating(String recipeId) async => {
    'rating': 4.0,
  };
}

class _RatedRecipeService extends MockUnifiedRecipeService {
  final _social = _RatedSocial();

  @override
  SocialRecipeOperations get social => _social;
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('sv', 'SE'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  const min = AppDimensions.minTouchTarget;
  final sv = AppLocalizationsSv();

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  testWidgets('the remove-own-rating control is at least 48 x 48 dp and a '
      'press beside the glyph opens the confirmation', (tester) async {
    final recipe = RecipeFactory.build(
      id: 'rated-1',
      rating: 4.0,
      type: RecipeType.shared,
    );
    final service = _RatedRecipeService()
      ..setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(service);
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );
    final vm = RecipeDetailViewModel(recipe: recipe, recipeService: service);
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      _app(
        RecipeDetailMetadata(
          viewModel: vm,
          currentPortions: 4,
          isScaled: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final control = find
        .ancestor(
          of: find.byIcon(ButleryIcons.x),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(control, findsOneWidget);
    final size = tester.getSize(control);
    expect(size.width, greaterThanOrEqualTo(min));
    expect(size.height, greaterThanOrEqualTo(min));
    expect(tester.getSize(find.byIcon(ButleryIcons.x)), const Size(14, 14));

    // 2 dp inside the corner: well clear of the 14 dp glyph.
    await tester.tapAt(tester.getTopLeft(control) + const Offset(2, 2));
    await tester.pump();
    expect(find.text(sv.ratingRemoveTitle), findsOneWidget);
  });

  // BUT-2218: on the narrowest phone (Breakpoints.mobileSmall, 320 dp) and at
  // double text size, the 48 dp remove control wraps below the stars rather
  // than overflowing the rating row, and stays whole on screen.
  for (final (width, scale) in [(320.0, 1.0), (360.0, 2.0)]) {
    testWidgets('the rating row fits at $width dp, text x$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final recipe = RecipeFactory.build(
        id: 'rated-narrow',
        rating: 4.5,
        type: RecipeType.shared,
      );
      final service = _RatedRecipeService()
        ..setRecipeState(recipes: [recipe], isInitialized: true);
      TestServiceLocator.registerMock<UnifiedRecipeService>(service);
      TestServiceLocator.registerMock<RecipeCookingService>(
        MockFactory.createRecipeCookingService(),
      );
      final vm = RecipeDetailViewModel(recipe: recipe, recipeService: service);
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1600),
            textScaler: TextScaler.linear(scale),
          ),
          child: _app(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RecipeDetailMetadata(
                viewModel: vm,
                currentPortions: 4,
                isScaled: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final control = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(ButleryIcons.x),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(control.right, lessThanOrEqualTo(width - 16));
      expect(control.width, greaterThanOrEqualTo(min));
    });
  }

  group('personal tags overflow', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recipe = RecipeFactory.build(
        id: 'tags-1',
        ingredients: ['500 g köttfärs'],
        instructions: ['Stek.'],
        personalTagIds: ['a', 'b', 'c', 'd'],
      );
      final service = MockUnifiedRecipeService()
        ..setRecipeState(recipes: [recipe], isInitialized: true);
      TestServiceLocator.registerMock<UnifiedRecipeService>(service);
      final cooking = MockFactory.createRecipeCookingService();
      TestServiceLocator.registerMock<RecipeCookingService>(cooking);
      final vm = RecipeDetailViewModel(
        recipe: recipe,
        recipeService: service,
        cookingService: cooking,
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _app(
          RecipeDetailContent(
            viewModel: vm,
            scaledIngredients: recipe.ingredients,
            currentPortions: 4,
            onPortionChanged: (_, _) {},
            onImageTap: (_, _) {},
            personalTagNames: const {
              'a': 'Favorit',
              'b': 'Vardag',
              'c': 'Fest',
              'd': 'Helg',
            },
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the "Visa alla" button is at least 48 dp tall', (
      tester,
    ) async {
      await pump(tester);

      final button = find.ancestor(
        of: find.text(sv.commonShowAllCount(4)),
        matching: find.bySubtype<TextButton>(),
      );
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(min));
    });

    testWidgets('the "+1 till" chip hit area is at least 48 x 48 dp and a '
        'press beside the chip expands the tags', (tester) async {
      await pump(tester);

      final chip = find.text(sv.commonMoreCount(1));
      final control = find
          .ancestor(of: chip, matching: find.byType(GestureDetector))
          .first;
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(min));
      expect(size.height, greaterThanOrEqualTo(min));

      // 2 dp inside the corner of the 48 dp area is outside the visual chip.
      final chipBox = tester.getRect(
        find.ancestor(of: chip, matching: find.byType(Container)).first,
      );
      final corner = tester.getTopLeft(control) + const Offset(2, 2);
      expect(chipBox.contains(corner), isFalse);
      await tester.tapAt(corner);
      await tester.pump();
      expect(find.text(sv.commonMoreCount(1)), findsNothing);
      expect(find.text('Helg'), findsOneWidget);
    });

    testWidgets('rows name their action once and leave the content to their '
        'text', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final more = find.bySemanticsLabel(RegExp('^Visa fler'));
      expect(more, findsOneWidget);
      expect(announcedLines(tester, more), contains(sv.commonMoreCount(1)));

      final substitutions = find.bySemanticsLabel(RegExp('^Visa substitut'));
      expect(substitutions, findsOneWidget);
      expect(announcedLines(tester, substitutions), contains('köttfärs'));

      final step = find.bySemanticsLabel(RegExp('^Markera som klart'));
      expect(step, findsOneWidget);
      expect(announcedLines(tester, step), contains('Stek.'));

      for (final row in [more, substitutions, step]) {
        expectNothingAnnouncedTwice(tester, row);
        expectActivatable(tester, row);
      }
      handle.dispose();
    });
  });
}
