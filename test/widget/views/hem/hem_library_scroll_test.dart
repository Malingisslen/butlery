// HEM-HERO: Hem's header and the recipe library scroll as one.
//
// Skarmar v12 del 1 #hemrecept (:124-150): "hälsning + ikväll överst,
// receptbiblioteket direkt under". The library is built as Mina recept builds
// it: a fixed search row above a primary list (or the grid toggle's
// ContentSizedGrid) with no controller of its own. At 320 x 568 dp with 200 %
// text the header is at its tallest; scrolling the library must take it off
// the screen and leave every recipe reachable.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/views/hem/hem_section.dart';
import 'package:butlery/widgets/common/content_sized_grid.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

// Thursday 9 July 2026 at 18:00.
final _now = DateTime(2026, 7, 9, 18);

const _count = 30;

Future<HemViewModel> _vm() async {
  final recipe =
      (RecipeBuilder()
            ..id = 'r1'
            ..title = 'Krämig svamppasta med timjan'
            ..timeMinutes = 45
            ..portions = 4)
          .build();
  final vm = HemViewModel(
    readWeek: (_) async => WeeklyMenuPlanRead(
      plan: WeeklyMenuPlan.empty(userId: 'u1', date: _now).copyWith(
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.thu,
            slot: MealSlot.middag,
            recipeId: 'r1',
            recipeTitle: 'Krämig svamppasta med timjan',
          ),
        ],
      ),
      readFailed: false,
    ),
    recipeById: (id) => id == 'r1' ? recipe : null,
    pantryIngredientIds: () async => const {},
    isOnline: () => true,
  );
  await withClock(Clock.fixed(_now), vm.load);
  return vm;
}

Widget _card(int i) => SizedBox(
  key: ValueKey('card-$i'),
  height: 120,
  child: Text('Recept $i'),
);

Widget _app(HemViewModel vm, {required bool grid, double textScale = 2}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('sv'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: HemLibraryScroll(
            header: HemSection(
              viewModel: vm,
              now: _now,
              firstName: 'Malin',
              libraryEmpty: false,
              isOnline: true,
              onStartCooking: (_) {},
              onOpenMenu: () {},
            ),
            body: Column(
              children: [
                const SizedBox(height: 56, child: Text('Sök')),
                Expanded(
                  child: grid
                      ? ContentSizedGrid(
                          primary: true,
                          columns: 1,
                          spacing: 8,
                          itemCount: _count,
                          itemBuilder: (_, i) => _card(i),
                        )
                      : ListView.builder(
                          itemCount: _count,
                          itemBuilder: (_, i) => _card(i),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final grid in [false, true]) {
    final mode = grid ? 'grid' : 'list';

    testWidgets('scrolling the library takes Hem off the screen ($mode)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = await _vm();
      addTearDown(vm.dispose);

      // At 100 % text the header leaves room for recipes under it, so the
      // drag starts on the library itself.
      await tester.pumpWidget(_app(vm, grid: grid, textScale: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('hem-greeting')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-0')), findsOneWidget);

      // Drag on a recipe, not on the header.
      await tester.drag(
        find.byKey(const ValueKey('card-0')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      final greeting = find.byKey(const ValueKey('hem-greeting'));
      expect(
        greeting.evaluate().isEmpty || tester.getBottomLeft(greeting).dy <= 0,
        isTrue,
        reason: 'the greeting has left the screen',
      );
    });

    testWidgets('the last recipe can be reached ($mode)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = await _vm();
      addTearDown(vm.dispose);

      await tester.pumpWidget(_app(vm, grid: grid));
      await tester.pumpAndSettle();

      for (var i = 0; i < 20; i++) {
        final visible = find.byKey(const ValueKey('card-${_count - 1}'));
        if (visible.evaluate().isNotEmpty) break;
        await tester.flingFrom(
          const Offset(160, 480),
          const Offset(0, -400),
          3000,
        );
        await tester.pumpAndSettle();
      }
      await tester.flingFrom(
        const Offset(160, 480),
        const Offset(0, -400),
        3000,
      );
      await tester.pumpAndSettle();

      final last = find.byKey(const ValueKey('card-${_count - 1}'));
      expect(last, findsOneWidget);
      expect(
        tester.getBottomLeft(last).dy,
        lessThanOrEqualTo(568),
        reason: 'the last recipe is fully on the screen',
      );
      expect(tester.getTopLeft(last).dy, greaterThanOrEqualTo(0));
    });
  }

  testWidgets('reports the library offset for BUT-1028', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = await _vm();
    addTearDown(vm.dispose);
    final offsets = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HemLibraryScroll(
            onLibraryScrolled: offsets.add,
            header: const SizedBox(height: 300, child: Text('Hem')),
            body: ListView.builder(
              itemCount: _count,
              itemBuilder: (_, i) => _card(i),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(offsets, isNotEmpty);
    expect(offsets.last, greaterThan(0));
  });
}
