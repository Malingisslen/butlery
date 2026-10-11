// BUT-723: what the week menu hands the detail pane. The pane has suites of its
// own; this one pins that Meny offers its dish first, and that a list card and
// a calendar cell open on the right inside a pane and push outside one.

import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../views/design_states/hosts/menu_hosts.dart';
import '../../../views/design_states/state_harness.dart';
import '../../../views/design_states/state_host.dart';
import '../../../views/design_states/state_hosts.dart'
    show registerHostFallbacks;
import '../../../views/design_states/state_runner.dart';
import '../../../views/golden_linux/golden_hosts.dart';

/// Counts the view's offers, so a repeat the controller would ignore anyway
/// still shows.
class _SpyController extends DetailPaneController {
  final offers = <Object>[];

  @override
  void offerFirst(RouteSettings settings, {required Object key}) {
    offers.add(key);
    super.offerFirst(settings, key: key);
  }
}

class _FakeMenuViewModel extends Mock implements MenuViewModel {}

class _MockPlanService extends Mock implements WeeklyMenuPlanService {
  @override
  Stream<String?> get weekWrites => const Stream.empty();

  @override
  Stream<LateWeekConflict> get lateConflicts => const Stream.empty();
}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockListGenerator extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _row = StateRow(
  view: 'veckomeny',
  state: 'DEFAULT',
  drawing: '-',
  evidence: '-',
  host: '-',
  hostFile: '-',
  hostNote: null,
  block288Category: '-',
  ownerNow: null,
);

Recipe? _shown(DetailPaneController pane) {
  final args = pane.selected?.arguments;
  return args is Recipe ? args : (args as Map?)?['recipe'] as Recipe?;
}

void main() {
  setUpAll(() {
    registerHostFallbacks();
    registerFallbackValue(_FakePlan());
  });

  group('VeckomenyView offers its dish', () {
    final host = menuHosts['veckomeny::DEFAULT']!;

    // The view reads the clock on every rebuild, so the whole test body runs
    // on the goldens' fixed date, not only the first pump.
    Future<void> onGoldenDay(
      WidgetTester tester,
      Future<void> Function() body,
    ) {
      final start = tester.binding.clock.now();
      return withClock(
        Clock(
          () => goldenNow.add(tester.binding.clock.now().difference(start)),
        ),
        body,
      );
    }

    Future<StateRun> pumpMeny(WidgetTester tester, DetailPaneController? pane) {
      return pumpState(
        tester,
        _row,
        Brightness.light,
        size: const Size(400, 1600),
        host: StateHost(
          build: (ctx) async {
            final view = await host.build(ctx);
            return pane == null
                ? view
                : DetailPaneScope(controller: pane, child: view);
          },
        ),
      );
    }

    testWidgets(
      'the first dish is offered once, then left alone',
      (
        tester,
      ) => onGoldenDay(tester, () async {
        final pane = _SpyController();
        addTearDown(pane.dispose);
        final run = await pumpMeny(tester, pane);
        await tester.pump();
        await tester.pump();

        final shown = _shown(pane);
        expect(pane.selected?.name, Routes.recipeDetail);
        // goldenNow is a Thursday, and Thursday's dish is r3 (not the week's first).
        expect(shown?.id, 'r3');
        expect(pane.isSelected(shown!.id), isTrue);
        expect(pane.offers, [shown.id]);

        pane.notifyListeners();
        await tester.pump();
        await tester.pump();
        expect(pane.offers, [shown.id]);

        run.capture.restore();
        expect(run.capture.exceptions, isEmpty);
        await finishState(tester, run);
      }),
    );

    testWidgets(
      'follows the dish when it changes, until the user picks',
      (tester) => onGoldenDay(tester, () async {
        final pane = _SpyController();
        addTearDown(pane.dispose);
        final run = await pumpMeny(tester, pane);
        await tester.pump();
        await tester.pump();
        expect(pane.offers, ['r3']);

        final vm = tester
            .element(find.byType(CalendarWeeklyMenuWidget))
            .read<WeeklyMenuPlanViewModel>();
        void keepOnly(bool Function(WeeklyMenuPlanEntry) test) => vm.adoptPlan(
          vm.plan!.copyWith(entries: vm.plan!.entries.where(test).toList()),
        );

        // Thursday's dish is gone, so the week's first dish (r1) is shown.
        keepOnly((e) => e.recipeId != 'r3');
        await tester.pump();
        await tester.pump();
        expect(pane.offers, ['r3', 'r1']);
        expect(_shown(pane)?.id, 'r1');
        expect(pane.isSelected('r1'), isTrue);

        final pick = _shown(pane)!;
        pane.open(
          RouteSettings(name: Routes.recipeDetail, arguments: pick),
          key: 'pick',
        );
        keepOnly((e) => e.recipeId != 'r1');
        await tester.pump();
        await tester.pump();
        expect(pane.isSelected('pick'), isTrue);
        expect(_shown(pane)?.id, 'r1');

        run.capture.restore();
        expect(run.capture.exceptions, isEmpty);
        await finishState(tester, run);
      }),
    );

    testWidgets(
      'without a pane the view offers nothing and still draws',
      (
        tester,
      ) => onGoldenDay(tester, () async {
        final run = await pumpMeny(tester, null);
        await tester.pump();
        run.capture.restore();
        expect(run.capture.exceptions, isEmpty);
        expect(find.byType(CalendarWeeklyMenuWidget), findsOneWidget);
        await finishState(tester, run);
      }),
    );
  });

  group('a list-mode menu recipe card', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    final first = RecipeFactory.build(id: 'r1', title: 'Köttbullar');
    final second = RecipeFactory.build(id: 'r2', title: 'Fiskgratäng');

    Widget cards() {
      final vm = _FakeMenuViewModel();
      when(() => vm.isGenerating).thenReturn(false);
      when(() => vm.canEditMenu).thenReturn(true);
      when(() => vm.isUnknownSoft(any())).thenReturn(false);
      when(() => vm.isHouseholdUnsafe(any())).thenReturn(false);
      when(() => vm.mealAllergenScopeOn).thenReturn(false);
      return Builder(
        builder: (context) => SingleChildScrollView(
          child: MenuContentWidgets.buildMenuSection(
            context,
            viewModel: vm,
            category: 'middag',
            recipes: [first, second],
          ),
        ),
      );
    }

    ui.Tristate selectedOf(WidgetTester tester, String title) => tester
        .getSemantics(
          find.ancestor(
            of: find.text(title),
            matching: find.bySemanticsLabel(RegExp(r'^Öppna receptet')),
          ),
        )
        .getSemanticsData()
        .flagsCollection
        .isSelected;

    testWidgets('opens on the right, and only that card reads as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final pane = _SpyController();
      addTearDown(pane.dispose);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: DetailPaneScope(controller: pane, child: cards()),
        ),
      );
      expect(selectedOf(tester, 'Köttbullar'), ui.Tristate.isFalse);

      await tester.tap(find.text('Köttbullar'));
      await tester.pump();

      expect(pane.selected?.name, Routes.recipeDetail);
      expect(pane.selected?.arguments, same(first));
      expect(pane.isSelected('r1'), isTrue);
      expect(selectedOf(tester, 'Köttbullar'), ui.Tristate.isTrue);
      expect(selectedOf(tester, 'Fiskgratäng'), ui.Tristate.isFalse);
      handle.dispose();
    });

    testWidgets(
      'pushes the recipe page outside a pane, with no selected state',
      (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        RouteSettings? pushed;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: cards(),
            onGenerateRoute: (settings) {
              pushed = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Text('RECIPE PAGE'),
              );
            },
          ),
        );
        expect(selectedOf(tester, 'Köttbullar'), ui.Tristate.none);

        await tester.tap(find.text('Köttbullar'));
        await tester.pumpAndSettle();

        expect(pushed?.name, Routes.recipeDetail);
        expect(pushed?.arguments, same(first));
        expect(find.text('RECIPE PAGE'), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('a calendar cell', () {
    late _MockPlanService service;
    late _MockRecipeService recipes;
    late Recipe pasta;
    RouteSettings? pushed;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      pushed = null;
      service = _MockPlanService();
      recipes = _MockRecipeService();
      pasta = RecipeFactory.build(id: 'r-mon', title: 'Pasta');
      when(() => recipes.getRecipeById('r-mon')).thenReturn(pasta);
    });

    Future<void> pumpCalendar(
      WidgetTester tester,
      DetailPaneController? pane,
    ) async {
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
      final plan = WeeklyMenuPlan(
        id: IsoWeekUtils.weekIdFor('u-1', weekStart),
        userId: 'u-1',
        weekStartDate: weekStart,
        entries: [
          WeeklyMenuPlanEntry(
            id: 'mon-m',
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r-mon',
            recipeTitle: 'Pasta',
          ),
        ],
        createdAt: DateTime(2026, 4, 18),
        updatedAt: DateTime(2026, 4, 18),
      );
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
      );
      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipes,
        shoppingListGenerator: _MockListGenerator(),
      );
      addTearDown(vm.dispose);
      Widget body = ChangeNotifierProvider<WeeklyMenuPlanViewModel>.value(
        value: vm,
        child: const Scaffold(
          body: SingleChildScrollView(child: CalendarWeeklyMenuWidget()),
        ),
      );
      if (pane != null) {
        body = DetailPaneScope(controller: pane, child: body);
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.lightTheme,
          home: body,
          onGenerateRoute: (settings) {
            pushed = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Text('RECIPE PAGE'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await vm.loadWeek(weekStart);
      await tester.pumpAndSettle();
    }

    testWidgets('opens its recipe on the right inside a pane', (tester) async {
      final pane = _SpyController();
      addTearDown(pane.dispose);
      await pumpCalendar(tester, pane);

      await tester.tap(find.text('pasta'));
      await tester.pumpAndSettle();

      expect(pane.selected?.name, Routes.recipeDetail);
      expect(_shown(pane), same(pasta));
      expect(pane.isSelected('r-mon'), isTrue);
      expect(pushed, isNull);
    });

    testWidgets('pushes the registered recipe route outside a pane', (
      tester,
    ) async {
      await pumpCalendar(tester, null);

      await tester.tap(find.text('pasta'));
      await tester.pumpAndSettle();

      expect(pushed?.name, Routes.recipeDetail);
      expect(pushed?.name, isNot('/recipe-detail'));
      expect(find.text('RECIPE PAGE'), findsOneWidget);
    });
  });
}
