/// P5-U23: the week menu's tray of recipes that did not fit, and the
/// placement order in the cells.
///
/// produktregler.md:1123-1127 (§ 22.6), :206, :890-893; drawn in Skarmar v12
/// etapp 11 breda vyer:233-254 (#vmbdelvis). Pins:
/// - the tray is the shared partial outcome (surface.raised + warning edge,
///   I-29) in light and dark;
/// - it counts in dishes, says why, and names each recipe as written;
/// - next week is a choice in the tray, with an accessible name that says how
///   many and which week; it is absent when not offered;
/// - the cells show the order the placement followed, and announce it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

// Week 16 of 2026; next is week 17.
final _monday = DateTime(2026, 4, 13);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

final _recipes = [
  RecipeFactory.build(id: 'o1', title: 'Ugnspannkaka'),
  RecipeFactory.build(id: 'o2', title: 'Ärtsoppa med Fläsk'),
  RecipeFactory.build(id: 'o3', title: 'Rotsakslåda'),
];

OverflowTray _tray({
  VoidCallback? onNext,
  bool pastDays = false,
  bool offered = true,
}) => OverflowTray(
  overflow: _recipes,
  placedCount: 6,
  totalCount: 9,
  reason: WeeklyMenuOverflowReason(
    weekStart: _monday,
    pastDaysSkipped: pastDays,
    nextWeekOffered: offered,
  ),
  onPlaceInNextWeek: onNext,
);

/// The calendar opens on today's week, so its plan is this week's.
final _thisMonday = IsoWeekUtils.weekStartOf(DateTime.now());

WeeklyMenuPlan _plan(List<WeeklyMenuPlanEntry> entries) => WeeklyMenuPlan(
  id: IsoWeekUtils.weekIdFor('malin', _thisMonday),
  userId: 'malin',
  weekStartDate: _thisMonday,
  entries: entries,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
  });

  for (final (mode, theme, raised) in [
    ('light', AppTheme.lightTheme, const Color(0xFFE6EAD9)),
    ('dark', AppTheme.darkTheme, const Color(0xFF2F4437)),
  ]) {
    testWidgets('the tray is the partial outcome on surface.raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme, _tray(onNext: () {})));

      expect(find.byType(PartialOutcome), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.byKey(PartialOutcome.surfaceKey),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, raised);
      expect(
        (decoration.border! as Border).left.color,
        const Color(0xFFCE7C1E),
      );
    });
  }

  testWidgets('counts in dishes, says why, names recipes as written', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AppTheme.lightTheme, _tray(onNext: () {}, pastDays: true)),
    );

    expect(find.text('6 av 9 rätter placerade'), findsOneWidget);
    expect(
      find.text(
        'Vecka 16 hade inga fler lediga platser för de här. '
        'Dagar som redan har passerat fylls aldrig. '
        'De ligger kvar här tills du placerar dem eller lägger dem i vecka 17.',
      ),
      findsOneWidget,
    );
    // Never lower-cased (produktregler.md:892).
    expect(find.text('Ärtsoppa med Fläsk'), findsOneWidget);
    expect(find.text('ärtsoppa med fläsk'), findsNothing);
    for (final r in _recipes) {
      expect(find.byKey(OverflowTray.chipKey(r.id)), findsOneWidget);
    }
  });

  testWidgets('next week is a choice in the tray', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(AppTheme.lightTheme, _tray(onNext: () => taps++)),
    );

    expect(find.text('Lägg i v. 17'), findsOneWidget);
    expect(find.bySemanticsLabel('Lägg de 3 i vecka 17'), findsOneWidget);
    await tester.tap(find.byKey(OverflowTray.nextWeekKey));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('without next week the tray says it stays until placed', (
    tester,
  ) async {
    await tester.pumpWidget(_app(AppTheme.lightTheme, _tray(offered: false)));

    expect(find.byKey(OverflowTray.nextWeekKey), findsNothing);
    expect(
      find.textContaining('De ligger kvar här tills du placerar dem.'),
      findsOneWidget,
    );
  });

  testWidgets('each chip is at least 48 dp tall', (tester) async {
    await tester.pumpWidget(_app(AppTheme.lightTheme, _tray(onNext: () {})));

    for (final r in _recipes) {
      expect(
        tester.getSize(find.byKey(OverflowTray.chipKey(r.id))).height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  group('in the calendar', () {
    late _MockService service;

    setUp(() {
      service = _MockService();
      when(() => service.save(any())).thenAnswer((_) async {});
      when(() => service.overflowTrayOwnerId).thenReturn(null);
      when(() => service.readWeek(any())).thenAnswer(
        (_) async =>
            WeeklyMenuPlanRead(plan: _plan(const []), readFailed: false),
      );
    });

    Future<WeeklyMenuPlanViewModel> placed(WidgetTester tester) async {
      final entries = [
        const WeeklyMenuPlanEntry(
          id: 'e-b',
          day: DayOfWeek.tue,
          slot: MealSlot.middag,
          recipeId: 'b',
          recipeTitle: 'Kikärtsgryta',
        ),
        const WeeklyMenuPlanEntry(
          id: 'e-a',
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'a',
          recipeTitle: 'Torsk',
        ),
      ];
      when(
        () => service.distributeFromGeneratedMenu(
          generated: any(named: 'generated'),
          weekStart: any(named: 'weekStart'),
          existing: any(named: 'existing'),
          now: any(named: 'now'),
          dayPins: any(named: 'dayPins'),
        ),
      ).thenReturn(
        WeeklyMenuDistributionResult(
          plan: _plan(entries),
          overflow: [_recipes.first],
          overflowReason: WeeklyMenuOverflowReason(weekStart: _thisMonday),
        ),
      );
      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: _MockRecipes(),
        shoppingListGenerator: _MockShopping(),
      );
      addTearDown(vm.dispose);
      await vm.loadWeek(_thisMonday);
      await vm.applyGeneratedMenu(<String, List<Recipe>>{
        'middag': [_recipes.first],
      });

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          ChangeNotifierProvider<WeeklyMenuPlanViewModel>.value(
            value: vm,
            child: const CalendarWeeklyMenuWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('the cells number the placement order and announce it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await placed(tester);

      // Tuesday was placed first, Monday second: the numbers follow the
      // placement, not the days.
      expect(find.byKey(const ValueKey('placement-order-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('placement-order-2')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Kikärtsgryta')),
        findsWidgets,
      );
      final node = tester.getSemantics(
        find
            .ancestor(
              of: find.byKey(const ValueKey('placement-order-1')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.getSemanticsData().value, 'Placerad som nummer 1');
      handle.dispose();
    });

    testWidgets('the tray in the calendar offers next week', (tester) async {
      await placed(tester);

      expect(find.byType(OverflowTray), findsOneWidget);
      expect(find.text('2 av 3 rätter placerade'), findsOneWidget);
      expect(find.byKey(OverflowTray.nextWeekKey), findsOneWidget);
    });
  });
}
