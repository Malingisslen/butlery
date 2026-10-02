// BUT-2183 5k: the tag chips and the ingredient swap glyph on the recipe
// detail leave the old opacity steps. A chip inside a raised tag card is
// surface.base with an outlineVariant border; a user-added tag is picked out
// by a 1.5 px onSurface border, not by a stronger fill. The swap glyph is
// textDisabled. Each test runs in both modes and asserts the text colour as
// well as the fill.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

late Recipe _recipe;

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final service = MockUnifiedRecipeService();
  service.setRecipeState(recipes: [_recipe], isInitialized: true);
  TestServiceLocator.registerMock<UnifiedRecipeService>(service);
  final cooking = MockFactory.createRecipeCookingService();
  TestServiceLocator.registerMock<RecipeCookingService>(cooking);

  final viewModel = RecipeDetailViewModel(
    recipe: _recipe,
    recipeService: service,
    cookingService: cooking,
  );
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecipeDetailContent(
            viewModel: viewModel,
            scaledIngredients: _recipe.ingredients,
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
      ),
    ),
  );
  await tester.pump();
}

BoxDecoration _chipDecoration(WidgetTester tester, String label) {
  final container = find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

Border _border(BoxDecoration d) => d.border! as Border;

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    _recipe =
        RecipeFactory.build(
          id: 'tokens-1',
          ingredients: ['500 g köttfärs', '1 dl grädde'],
          instructions: ['Rulla.', 'Stek.'],
          personalTagIds: ['a', 'b', 'c', 'd'],
        ).copyWith(
          tagResult: TagResult(
            tags: {'vegetarisk', 'snabbt'},
            allergenStatus: const {},
            dietaryStatus: const {},
            coverage: 1,
            generatedAt: DateTime(2026, 1, 1),
          ),
          tagOverrides: const TagOverrides(addedTags: {'budget'}),
        );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('recipe tags, $mode', () {
      testWidgets('an auto tag is surface.base with an outlineVariant border', (
        tester,
      ) async {
        await _pump(tester, theme);

        final label = find.text('Vegetarisk');
        expect(label, findsOneWidget);
        final d = _chipDecoration(tester, 'Vegetarisk');
        expect(d.color, cs.surface);
        expect(_border(d).top.color, cs.outlineVariant);
        expect(_border(d).top.width, 1);
        expect(tester.widget<Text>(label).style?.color, cs.onSurface);
      });

      testWidgets(
        'a user-added tag is picked out by a 1.5 px onSurface border, on the '
        'same fill',
        (tester) async {
          await _pump(tester, theme);

          final d = _chipDecoration(tester, 'Budget');
          expect(d.color, cs.surface);
          expect(_border(d).top.color, cs.onSurface);
          expect(_border(d).top.width, 1.5);
        },
      );
    });

    group('personal tags, $mode', () {
      testWidgets(
        'a personal tag is surface.base with an outlineVariant border and '
        'onSurface text',
        (tester) async {
          await _pump(tester, theme);

          final d = _chipDecoration(tester, 'Favorit');
          expect(d.color, cs.surface);
          expect(_border(d).top.color, cs.outlineVariant);
          expect(
            tester.widget<Text>(find.text('Favorit')).style?.color,
            cs.onSurface,
          );
        },
      );

      testWidgets('the overflow chip reads in the secondary text on raised', (
        tester,
      ) async {
        await _pump(tester, theme);

        final label = find.text('+1 till');
        expect(label, findsOneWidget);
        final d = _chipDecoration(tester, '+1 till');
        expect(d.color, cs.surface);
        expect(_border(d).top.color, cs.outlineVariant);
        expect(
          tester.widget<Text>(label).style?.color,
          AppModeColors.textSecondaryOnRaised(theme.brightness),
        );
      });
    });

    group('ingredient rows, $mode', () {
      testWidgets('the swap glyph is textDisabled', (tester) async {
        await _pump(tester, theme);

        final glyph = find.byIcon(ButleryIcons.swapHorizontal);
        expect(glyph, findsWidgets);
        for (final icon in tester.widgetList<Icon>(glyph)) {
          expect(icon.color, AppModeColors.textDisabled(theme.brightness));
        }
      });
    });
  }
}
