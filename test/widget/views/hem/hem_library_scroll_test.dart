// HEM-HERO: Hem's header and the recipe library scroll as one.
//
// Skarmar v12 del 1 #hemrecept (:124-150): "hälsning + ikväll överst,
// receptbiblioteket direkt under". At 320 x 568 dp with 200 %
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

  group('the pinned library header', () {
    const greeting = ValueKey('hem-greeting');
    const pinned = ValueKey('pinned');
    const headerHeight = 300.0;

    Future<GlobalKey<NestedScrollViewState>> pumpPinned(
      WidgetTester tester, {
      void Function(BuildContext context)? onTheme,
      Widget? body,
    }) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nestedKey = GlobalKey<NestedScrollViewState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              onTheme?.call(context);
              return Scaffold(
                body: HemLibraryScroll(
                  nestedKey: nestedKey,
                  header: const SizedBox(
                    key: greeting,
                    height: headerHeight,
                    child: Text('Hej Malin'),
                  ),
                  pinned: const SizedBox(
                    key: pinned,
                    height: 80,
                    child: Text('Dina recept'),
                  ),
                  body:
                      body ??
                      HemLibraryScroll.sliverBody(
                        slivers: [
                          SliverList.builder(
                            itemCount: _count,
                            itemBuilder: (_, i) => _card(i),
                          ),
                        ],
                      ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return nestedKey;
    }

    /// Drags on a recipe by exactly the greeting's height, which the outer
    /// scroll takes in full before the library moves.
    Future<void> scrollHemAway(WidgetTester tester) async {
      await tester.drag(
        find.byKey(const ValueKey('card-0')),
        const Offset(0, -headerHeight),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('stays at the top once Hem has scrolled away', (tester) async {
      await pumpPinned(tester);
      expect(find.byKey(greeting), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(pinned)).dy, headerHeight);

      // Further than the greeting, so the library scrolls too.
      await tester.drag(
        find.byKey(const ValueKey('card-0')),
        const Offset(0, -headerHeight - 200),
      );
      await tester.pumpAndSettle();

      final greetingFinder = find.byKey(greeting);
      expect(
        greetingFinder.evaluate().isEmpty ||
            tester.getBottomLeft(greetingFinder).dy <= 0,
        isTrue,
        reason: 'the greeting has left the screen',
      );
      expect(find.byKey(pinned), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(pinned)).dy, 0);
    });

    testWidgets('the first recipe starts under the header, not beneath it', (
      tester,
    ) async {
      final nestedKey = await pumpPinned(tester);
      await scrollHemAway(tester);

      // The premise: Hem is gone and the library itself has not moved, so
      // the first recipe is where the body begins.
      final inner = nestedKey.currentState!.innerController;
      expect(inner.position.pixels, 0);
      expect(tester.getTopLeft(find.byKey(pinned)).dy, 0);

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('card-0'))).dy,
        tester.getBottomLeft(find.byKey(pinned)).dy,
      );
    });

    // A body shorter than the screen (the empty library, an error, no
    // results): once Hem has scrolled away it must start below the header.
    testWidgets('a short body starts under the header, not beneath it', (
      tester,
    ) async {
      const short = ValueKey('short');
      await pumpPinned(
        tester,
        body: HemLibraryScroll.boxBody(
          const SizedBox(key: short, height: 100, child: Text('Tomt')),
        ),
      );
      await tester.drag(find.byKey(short), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(pinned)).dy, 0);
      expect(
        tester.getTopLeft(find.byKey(short)).dy,
        tester.getBottomLeft(find.byKey(pinned)).dy,
      );
    });

    testWidgets('is painted in the page colour, so recipes do not show '
        'through it', (tester) async {
      late Color pageColour;
      await pumpPinned(
        tester,
        onTheme: (context) =>
            pageColour = Theme.of(context).scaffoldBackgroundColor,
      );

      final box = tester.widget<ColoredBox>(
        find
            .ancestor(of: find.byKey(pinned), matching: find.byType(ColoredBox))
            .first,
      );
      expect(box.color, pageColour);
    });
  });
}
