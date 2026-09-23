// P5-U31 / P5-U32: multi-select as a top-bar state.
//
// "Välj" is the visible way in (B-46, beslutslogg.md:53), shown from two rows
// (produktregler.md:874). In selection mode the counter replaces the title
// and Avbryt the back arrow, and the bar changes content, not height
// (produktregler.md:873). Actions that need a selection are off at zero with
// their names readable (produktregler.md:876), in the disabled role and never
// through opacity (tokens.json:71-74, :198). "Markera alla" is a toggle
// (produktregler.md:877).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/viewmodels/recipe_list/recipe_selection_manager.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/selection_bulk_bar.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

Widget _app(Widget child, {ThemeData? theme, double textScale = 1.0}) =>
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child,
      ),
    );

Recipe _recipe(String id) =>
    (RecipeBuilder()
          ..id = id
          ..title = 'Recept $id'
          ..imageUrls = [])
        .build();

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('ButlerySelectButton.shownFor', () {
    test('no entry below two rows', () {
      expect(ButlerySelectButton.shownFor(0), isFalse);
      expect(ButlerySelectButton.shownFor(1), isFalse);
      expect(ButlerySelectButton.shownFor(2), isTrue);
      expect(ButlerySelectButton.shownFor(40), isTrue);
    });
  });

  group('the bar changes content, not height', () {
    Future<double> barHeight(
      WidgetTester tester,
      PreferredSizeWidget bar, {
      double textScale = 1.0,
    }) async {
      await tester.pumpWidget(
        _app(Scaffold(appBar: bar), textScale: textScale),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(ButleryTopBar)).height;
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('root bar at text scale $scale', (tester) async {
        final normal = await barHeight(
          tester,
          ButleryTopBar.rot(
            title: 'Inköp',
            secondaryLine: 'Veckans inköp · 4 av 16 klara',
            actions: [
              ButlerySelectButton(onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
          textScale: scale,
        );
        final selecting = await barHeight(
          tester,
          ButleryTopBar.rot(
            title: '3 valda',
            secondaryLine: 'Veckans inköp · 4 av 16 klara',
            leading: ButleryCancelSelectionButton(onPressed: () {}),
          ),
          textScale: scale,
        );

        expect(selecting, normal);
      });

      testWidgets('subpage bar at text scale $scale', (tester) async {
        final normal = await barHeight(
          tester,
          ButleryTopBar.undersida(
            title: 'Personliga taggar',
            onBack: () {},
            actions: [ButlerySelectButton(onPressed: () {})],
          ),
          textScale: scale,
        );
        final selecting = await barHeight(
          tester,
          ButleryTopBar.undersida(
            title: '0 valda',
            leading: ButleryCancelSelectionButton(onPressed: () {}),
            actions: const [
              IconButton(icon: Icon(Icons.delete_outline), onPressed: null),
            ],
          ),
          textScale: scale,
        );

        expect(selecting, normal);
      });
    }
  });

  group('off at zero, in the disabled role (P5-U32)', () {
    for (final (name, theme, brightness) in [
      ('light', AppTheme.lightTheme, Brightness.light),
      ('dark', AppTheme.darkTheme, Brightness.dark),
    ]) {
      testWidgets('root bar icon action ($name)', (tester) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              appBar: ButleryTopBar.rot(
                title: '0 valda',
                actions: const [
                  IconButton(
                    icon: Icon(Icons.local_offer_outlined),
                    onPressed: null,
                  ),
                ],
              ),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<RichText>(
          find.descendant(
            of: find.byIcon(Icons.local_offer_outlined),
            matching: find.byType(RichText),
          ),
        );
        expect(icon.text.style?.color, AppModeColors.textDisabled(brightness));
        expect(
          find.ancestor(
            of: find.byIcon(Icons.local_offer_outlined),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });

      testWidgets('bottom bulk bar delete ($name)', (tester) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              bottomNavigationBar: SelectionBulkBar(
                count: 0,
                label: '0 valda',
                onClose: () {},
                onDelete: () {},
              ),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        final delete = find.ancestor(
          of: find.text('Ta bort'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.widget<ButtonStyleButton>(delete).onPressed, isNull);
        final label = tester.widget<RichText>(
          find.descendant(
            of: find.text('Ta bort'),
            matching: find.byType(RichText),
          ),
        );
        // The name stays readable: text.disabled.onRaised on surface.raised.
        expect(label.text.style?.color, AppModeColors.textDisabled(brightness));
        expect(
          find.ancestor(of: delete, matching: find.byType(Opacity)),
          findsNothing,
        );
      });
    }
  });

  group('the recipe list (P5-U31)', () {
    late _MockRecipeListViewModel viewModel;

    setUp(() {
      viewModel = _MockRecipeListViewModel();
      when(() => viewModel.selectedIds).thenReturn(const {});
      when(() => viewModel.selectedCount).thenReturn(0);
      when(() => viewModel.isSelectionMode).thenReturn(true);
    });

    Future<List<Widget>> entry(WidgetTester tester) async {
      late List<Widget> result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              result = buildMinaReceptSelectEntry(context, viewModel);
              return Scaffold(
                appBar: ButleryTopBar.rot(
                  title: 'Mina recept',
                  actions: result,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('one recipe gives no Välj', (tester) async {
      when(() => viewModel.recipes).thenReturn([_recipe('r1')]);

      expect(await entry(tester), isEmpty);
    });

    testWidgets('two recipes give "Välj", named "Välj recept", which starts '
        'selection with nothing ticked', (tester) async {
      when(() => viewModel.recipes).thenReturn([_recipe('r1'), _recipe('r2')]);
      when(() => viewModel.startSelection()).thenReturn(null);

      expect(await entry(tester), hasLength(1));
      expect(find.text('Välj'), findsOneWidget);
      expect(find.bySemanticsLabel('Välj recept'), findsOneWidget);

      await tester.tap(find.text('Välj'));
      verify(() => viewModel.startSelection()).called(1);
    });

    Future<void> openKebab(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              appBar: buildMinaReceptSelectionAppBar(context, viewModel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mina-recept-bulk-more')));
      await tester.pumpAndSettle();
    }

    testWidgets('"Markera alla" counts the list and selects all', (
      tester,
    ) async {
      when(() => viewModel.recipes).thenReturn([_recipe('r1'), _recipe('r2')]);
      when(() => viewModel.allSelected).thenReturn(false);
      when(() => viewModel.selectAll()).thenReturn(null);

      await openKebab(tester);
      await tester.tap(find.text('Markera alla 2'));
      await tester.pumpAndSettle();

      verify(() => viewModel.selectAll()).called(1);
    });

    testWidgets('with everything ticked it unticks, and selection stays', (
      tester,
    ) async {
      when(() => viewModel.recipes).thenReturn([_recipe('r1'), _recipe('r2')]);
      when(() => viewModel.selectedIds).thenReturn(const {'r1', 'r2'});
      when(() => viewModel.selectedCount).thenReturn(2);
      when(() => viewModel.allSelected).thenReturn(true);
      when(() => viewModel.deselectAll()).thenReturn(null);

      await openKebab(tester);
      await tester.tap(find.text('Avmarkera alla'));
      await tester.pumpAndSettle();

      verify(() => viewModel.deselectAll()).called(1);
      verifyNever(() => viewModel.clearSelection());
    });

    testWidgets('at zero the kebab keeps disabled names readable, no fade', (
      tester,
    ) async {
      when(() => viewModel.recipes).thenReturn([_recipe('r1'), _recipe('r2')]);
      when(() => viewModel.allSelected).thenReturn(false);

      await openKebab(tester);

      final export = tester.widget<Text>(find.text('Exportera valda'));
      expect(
        export.style?.color,
        AppModeColors.textDisabled(Brightness.light),
      );
      final delete = tester.widget<Text>(find.text('Ta bort valda'));
      expect(
        delete.style?.color,
        AppModeColors.textDisabled(Brightness.light),
      );
    });
  });

  group('selection managers: Välj and the toggle', () {
    test('startSelection enters at zero; deselectAll keeps the mode', () {
      final recipe = RecipeSelectionManager()..startSelection();
      expect((recipe.isSelectionMode, recipe.selectedCount), (true, 0));
      recipe
        ..selectAll(['a', 'b'])
        ..deselectAll();
      expect((recipe.isSelectionMode, recipe.selectedCount), (true, 0));

      final shopping = ShoppingSelectionManager()..startSelection();
      expect((shopping.isSelectionMode, shopping.selectedCount), (true, 0));
      shopping
        ..toggleSelection('a')
        ..deselectAll();
      expect((shopping.isSelectionMode, shopping.selectedCount), (true, 0));

      final pantry = PantrySelectionManager()..startSelection();
      expect((pantry.isSelectionMode, pantry.selectedCount), (true, 0));
      pantry
        ..toggleSelection('a')
        ..deselectAll();
      expect((pantry.isSelectionMode, pantry.selectedCount), (true, 0));

      final tags = PersonalTagSelectionManager()..startSelection();
      expect((tags.isSelectionMode, tags.selectedCount), (true, 0));
      tags
        ..toggle('a')
        ..deselectAll();
      expect((tags.isSelectionMode, tags.selectedCount), (true, 0));
    });

    test('taking the last tick off a row still leaves the mode', () {
      final pantry = PantrySelectionManager()
        ..startSelection()
        ..toggleSelection('a')
        ..toggleSelection('a');
      expect(pantry.isSelectionMode, isFalse);
    });
  });
}
