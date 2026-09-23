/// P4-U04: Mina recept takes in the new components.
///
/// - The selection bar is the root bar with other content: the count in
///   place of the title and "Avbryt" in place of the back arrow, never an X
///   (produktregler.md:873; Skarmar v12 etapp 9 #flervalingang).
/// - A chosen card is surface.selected with a real border, never a tint
///   (tokens.json:116-119, opacityLadder :40-53; #flerbar).
/// - The empty library has exactly one saffron action (produktregler.md:292;
///   Grafisk manual v6:219; Skarmar v12 del 1 #tomtrecept).
/// - The recipe card follows its own focus node for the ring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/empty_state_widgets.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

class _MockUserService extends Mock implements UserService {}

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Filled buttons on screen whose resting fill is the saffron action colour.
int _heroCount(WidgetTester tester, Brightness b) => tester
    .widgetList<FilledButton>(find.byType(FilledButton))
    .where(
      (button) =>
          button.style?.backgroundColor?.resolve(const {}) ==
          AppModeColors.actionPrimary(b),
    )
    .length;

void main() {
  late _MockRecipeListViewModel viewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Recipe recipe() =>
      (RecipeBuilder()
            ..id = 'r1'
            ..title = 'Pannbiffar med lök'
            ..imageUrls = [])
          .build();

  setUp(() {
    viewModel = _MockRecipeListViewModel();
    when(() => viewModel.selectedIds).thenReturn(const {'r1'});
    when(() => viewModel.selectedCount).thenReturn(1);
    when(() => viewModel.isSelectionMode).thenReturn(true);
    when(() => viewModel.isGridView).thenReturn(false);
    when(() => viewModel.pantryOnly).thenReturn(false);
    when(() => viewModel.pantryMatches).thenReturn(const {});
    when(() => viewModel.pooledStats).thenReturn(const {});
  });

  group('selection bar', () {
    Future<void> pumpBar(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              appBar: buildMinaReceptSelectionAppBar(
                context,
                viewModel,
                secondaryLine: '12 recept',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is the root bar with the count and Avbryt, no X, no back', (
      tester,
    ) async {
      await pumpBar(tester);

      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.pattern, ButleryTopBarPattern.rot);
      expect(find.text('1 valda'), findsOneWidget);
      expect(find.text('12 recept'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('Avbryt leaves the selection', (tester) async {
      when(() => viewModel.clearSelection()).thenReturn(null);
      await pumpBar(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
      verify(() => viewModel.clearSelection()).called(1);
    });
  });

  group('chosen card', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('is surface.selected with a text.primary border ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SizedBox(
                width: 360,
                child: MinaReceptRecipeCard(
                  viewModel: viewModel,
                  recipe: recipe(),
                  allergenPrefs: const UserAllergenPreferences(
                    trackedAllergens: {},
                    trackedDietary: {},
                  ),
                  onDelete: (_) {},
                ),
              ),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        final cs = theme.colorScheme;
        final card = tester.widget<HoverableCard>(find.byType(HoverableCard));
        final deco = card.restDecoration as BoxDecoration;
        // surface.selected: #E6EAD9 light, #2F4437 dark (tokens.json:116-119),
        // fully opaque.
        expect(deco.color, cs.surfaceContainerHighest);
        expect(deco.color!.a, 1.0);
        final border = deco.border! as Border;
        expect(border.top.color, cs.onSurface);
        expect(border.top.width, 1.5);
        // No tinted layer over the card.
        expect(
          find.descendant(
            of: find.byType(Stack),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.color != null &&
                  w.color!.a > 0 &&
                  w.color!.a < 1,
            ),
          ),
          findsNothing,
        );
        expect(
          tester.widget<RecipeCard>(find.byType(RecipeCard)).isSelected,
          isTrue,
        );
      });
    }

    testWidgets('the card rings its own focus, not its buttons\'', (
      tester,
    ) async {
      when(() => viewModel.isSelectionMode).thenReturn(false);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SizedBox(
              width: 360,
              child: MinaReceptRecipeCard(
                viewModel: viewModel,
                recipe: recipe(),
                allergenPrefs: const UserAllergenPreferences(
                  trackedAllergens: {},
                  trackedDietary: {},
                ),
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(ButleryAncestorFocusRing),
        ),
        findsWidgets,
      );
    });
  });

  group('empty library', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('has exactly one saffron action ($mode)', (tester) async {
        final userService = _MockUserService();
        when(() => userService.currentUserProfile).thenReturn(null);
        await tester.pumpWidget(
          _app(
            ChangeNotifierProvider<UserService>.value(
              value: userService,
              child: const Scaffold(body: MinaReceptEmptyState()),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga sparade recept än'), findsOneWidget);
        expect(_heroCount(tester, theme.brightness), 1);
        expect(
          find.widgetWithText(FilledButton, 'Lägg till recept'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Importera länk'),
          findsOneWidget,
        );
      });
    }
  });
}
