// BUT-2183 5g: the comment thread, shelf, related-recipe chip and picker
// thumbnail, substitution badge and merge-sheet handle leave the old opacity
// steps. A fill is surface.raised (surface.base when it stands on a raised
// parent), a line is border.subtle, and a dimmed glyph is text.disabled.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';
import 'package:butlery/widgets/recipe/duplicate_merge_sheet.dart';
import 'package:butlery/widgets/recipe/ingredient_substitution_sheet.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';
import 'package:butlery/widgets/recipe/recipe_shelf.dart';
import 'package:butlery/widgets/recipe/related_recipes_editor.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../infrastructure/helpers/ink_fill.dart';

class _FakeSubstitutions extends Fake implements SubstitutionSuggestionService {
  @override
  Future<List<IngredientSubstitution>> suggestFor(
    String ingredientName,
  ) async => const [IngredientSubstitution(name: 'Yoghurt', ratio: 0.75)];
}

Recipe _recipe({String id = 'r1', String title = 'Pastasås'}) => Recipe(
  core: RecipeCore(
    id: id,
    title: title,
    description: '',
    ingredients: const ['tomat', 'lök', 'vitlök'],
    instructions: const [],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

RecipeComment _comment({String id = 'c1'}) => RecipeComment(
  id: id,
  recipeId: 'r1',
  authorId: 'u1',
  authorDisplayName: 'Test Author',
  text: 'Hej, jättegott!',
  createdAt: DateTime(2026, 1, 1),
);

Widget _app(ThemeData theme, Widget home) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

BoxDecoration _decorationAround(WidgetTester tester, Finder inner) {
  final box = find.ancestor(of: inner, matching: find.byType(Container));
  return tester.widget<Container>(box.first).decoration! as BoxDecoration;
}

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('recipe widgets tokens ($name)', () {
      testWidgets('a reply is surface.raised, a top-level comment has no '
          'fill, and the thread line is outlineVariant', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            Builder(
              builder: (context) => Column(
                children: [
                  CommentItemWidgets.buildCommentItem(
                    context: context,
                    comment: _comment(id: 'top'),
                    authorDisplayName: 'Förälder',
                    authorAvatarUrl: null,
                    formattedTime: '2m',
                    onReply: () {},
                    onToggleLike: () {},
                    onShowLikes: () {},
                  ),
                  CommentItemWidgets.buildCommentItem(
                    context: context,
                    comment: _comment(id: 'reply'),
                    authorDisplayName: 'Svarare',
                    authorAvatarUrl: null,
                    formattedTime: '1m',
                    onReply: () {},
                    onToggleLike: () {},
                    onShowLikes: () {},
                    depth: 1,
                  ),
                  CommentItemWidgets.buildCommentWithReplies(
                    context: context,
                    comment: _comment(id: 'parent'),
                    replies: [_comment(id: 'child')],
                    commentBuilder: (comment, depth) =>
                        Text('trådkommentar ${comment.id}'),
                  ),
                ],
              ),
            ),
          ),
        );

        final replyFill = _decorationAround(tester, find.text('Svarare'));
        expect(replyFill.color, cs.surfaceContainerHighest);
        final topFill = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.text('Förälder'),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>();
        expect(
          topFill.where((d) => d.color != null),
          isEmpty,
          reason: 'a top-level comment draws no fill',
        );

        final thread = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('trådkommentar child'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final border = (thread.decoration as BoxDecoration).border! as Border;
        expect(border.left.color, cs.outlineVariant);
      });

      testWidgets('the shelf divider is outlineVariant', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            RecipeShelf(
              title: 'Nyligen',
              recipes: [_recipe()],
              onRecipeTap: (_) {},
            ),
          ),
        );
        expect(
          tester.widget<Divider>(find.byType(Divider)).color,
          cs.outlineVariant,
        );
      });

      testWidgets(
        'the shelf placeholder is the title initial on surface.raised '
        'in text.secondary, with no vegetable',
        (tester) async {
          await tester.pumpWidget(
            _app(
              theme,
              RecipeShelf(
                title: 'Nyligen',
                recipes: [_recipe()],
                onRecipeTap: (_) {},
              ),
            ),
          );
          final plate = find.byType(RecipeInitialPlate);
          expect(plate, findsOneWidget);
          expect(find.byType(VegetableIllustration), findsNothing);
          expect(
            tester
                .widget<ColoredBox>(
                  find.descendant(of: plate, matching: find.byType(ColoredBox)),
                )
                .color,
            cs.surfaceContainerHighest,
          );
          final letter = tester.widget<Text>(
            find.descendant(of: plate, matching: find.text('P')),
          );
          expect(letter.style!.color, cs.onSurfaceVariant);
        },
      );

      testWidgets('a related-recipe chip is surface.raised with an '
          'outlineVariant line', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            RelatedRecipesEditor(
              currentRecipeId: 'r-current',
              relatedRecipes: const [(id: 'r2', title: 'Tacos')],
              onLink: (_) async => true,
              onUnlink: (_) async => true,
            ),
          ),
        );
        final chip = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('Tacos'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = chip.decoration as BoxDecoration;
        expect(decoration.color, cs.surfaceContainerHighest);
        expect((decoration.border! as Border).top.color, cs.outlineVariant);
      });

      // BUT-2205: the chip's own fill used to sit above the ink layer, so
      // the remove × showed no press.
      testWidgets('a pressed remove × on a related-recipe chip shows the '
          'step on raised', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            RelatedRecipesEditor(
              currentRecipeId: 'r-current',
              relatedRecipes: const [(id: 'r2', title: 'Tacos')],
              onLink: (_) async => true,
              onUnlink: (_) async => true,
            ),
          ),
        );
        final remove = find.descendant(
          of: find
              .ancestor(
                of: find.text('Tacos'),
                matching: find.byType(DecoratedBox),
              )
              .first,
          matching: find.byType(InkWell),
        );
        expect(pressIsCovered(tester, remove), isFalse);
        final gesture = await holdPress(tester, remove);
        expect(
          paintsInkFill(
            tester,
            remove,
            ModeColors.of(theme.brightness).pressedOnRaised,
          ),
          isTrue,
        );
        await gesture.cancel();
      });

      testWidgets('the picker thumbnail placeholder is surface.raised', (
        tester,
      ) async {
        final mockVm = MockRecipeListViewModel();
        mockVm.setRecipeListState(recipes: [_recipe()], isLoading: false);
        TestServiceLocator.registerMock<RecipeListViewModel>(mockVm);

        await tester.pumpWidget(
          _app(
            theme,
            RelatedRecipesEditor(
              currentRecipeId: 'r-current',
              relatedRecipes: const [],
              onLink: (_) async => true,
              onUnlink: (_) async => true,
            ),
          ),
        );
        await tester.tap(find.text('+ Länka relaterat recept'));
        await tester.pump();
        await tester.pump();

        final placeholder = find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.utensils,
          ),
          matching: find.byType(Container),
        );
        expect(
          tester.widget<Container>(placeholder.first).color,
          cs.surfaceContainerHighest,
        );
      });

      testWidgets('the substitution ratio badge is surface.base with an '
          'outlineVariant line on the raised option card', (tester) async {
        TestServiceLocator.registerMock<SubstitutionSuggestionService>(
          _FakeSubstitutions(),
        );
        await tester.pumpWidget(
          _app(
            theme,
            const IngredientSubstitutionSheet(ingredientName: 'Grädde'),
          ),
        );
        await tester.pumpAndSettle();

        final card = _decorationAround(tester, find.text('Yoghurt'));
        expect(card.color, cs.surfaceContainerHighest);

        final badge = _decorationAround(tester, find.text('75%'));
        expect(badge.color, cs.surface);
        expect((badge.border! as Border).top.color, cs.outlineVariant);
      });

      testWidgets('the merge sheet drag handle is text.disabled', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: theme,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDuplicateMergeSheet(
                  context: context,
                  existingRecipe: _recipe(id: 'a', title: 'Gammal'),
                  newRecipe: _recipe(id: 'b', title: 'Ny'),
                  similarityScore: 0.9,
                ),
                child: const Text('öppna'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('öppna'));
        await tester.pumpAndSettle();

        final handle = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color != null &&
              w.constraints?.maxHeight == 4,
        );
        expect(handle, findsOneWidget);
        expect(
          tester.widget<Container>(handle).color,
          AppModeColors.textDisabled(theme.brightness),
        );
      });
    });
  }
}
