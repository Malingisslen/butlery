// BUT-2153: bulk "Lägg till i veckomeny" from Mina recept. The choice for
// recipes that do not fit is made in the slot picker before anything is
// written, and the snackbar only reports what happened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  late _MockRecipeListViewModel viewModel;
  late _MockPlanService planService;

  Recipe recipe(String id) =>
      (RecipeBuilder()
            ..id = id
            ..title = 'Recept $id'
            ..imageUrls = [])
          .build();

  final recipes = [
    for (final id in ['r1', 'r2', 'r3', 'r4']) recipe(id),
  ];
  final thisWeek = IsoWeekUtils.weekStartOf(DateTime.now());
  final nextWeek = thisWeek.add(const Duration(days: 7));

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    viewModel = _MockRecipeListViewModel();
    when(() => viewModel.selectedCount).thenReturn(4);
    when(() => viewModel.isSelectionMode).thenReturn(true);
    when(() => viewModel.allSelected).thenReturn(false);
    when(() => viewModel.recipes).thenReturn(recipes);
    when(() => viewModel.selectedRecipes).thenReturn(recipes);

    planService = _MockPlanService();
    when(() => planService.readWeek(any())).thenAnswer(
      (invocation) async => WeeklyMenuPlanRead(
        plan: WeeklyMenuPlan.empty(
          userId: 'u',
          date: IsoWeekUtils.weekStartOf(
            invocation.positionalArguments.single as DateTime,
          ),
        ),
        readFailed: false,
      ),
    );
    // Friday to Sunday hold three; the fourth spills.
    when(
      () => planService.bulkAssignRecipes(
        weekStart: any(named: 'weekStart'),
        startDay: any(named: 'startDay'),
        slot: any(named: 'slot'),
        recipes: any(named: 'recipes'),
      ),
    ).thenAnswer((invocation) async {
      final given = invocation.namedArguments[#recipes] as List<Recipe>;
      final week = invocation.namedArguments[#weekStart] as DateTime;
      return week == thisWeek
          ? (added: 3, overflowed: given.length - 3)
          : (added: given.length, overflowed: 0);
    });
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(planService);
  });

  tearDown(() async => TestServiceLocator.reset());

  Future<void> pickFridayMiddag(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byTooltip('Lägg till i veckomeny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fre').at(1)); // (fri, middag)
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is written until the rest has a decision', (
    tester,
  ) async {
    await pickFridayMiddag(tester);

    verifyNever(
      () => planService.bulkAssignRecipes(
        weekStart: any(named: 'weekStart'),
        startDay: any(named: 'startDay'),
        slot: any(named: 'slot'),
        recipes: any(named: 'recipes'),
      ),
    );
  });

  testWidgets('"Lägg 3 nu, 1 i v." places the tail from Monday next week '
      'and reports both weeks', (tester) async {
    await pickFridayMiddag(tester);

    await tester.tap(find.textContaining('Lägg 3 nu, 1 i v. '));
    await tester.pumpAndSettle();

    verify(
      () => planService.bulkAssignRecipes(
        weekStart: thisWeek,
        startDay: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipes: recipes,
      ),
    ).called(1);
    final tail =
        verify(
              () => planService.bulkAssignRecipes(
                weekStart: nextWeek,
                startDay: DayOfWeek.mon,
                slot: MealSlot.middag,
                recipes: captureAny(named: 'recipes'),
              ),
            ).captured.single
            as List<Recipe>;
    expect(tail.map((r) => r.id), ['r4']);
    expect(
      find.text(
        '3 recept i veckan, 1 i v. ${IsoWeekUtils.isoWeekNumber(nextWeek)}',
      ),
      findsOneWidget,
    );
    // The snackbar reports; it no longer offers a write.
    expect(find.text('Lägg de resterande nästa vecka'), findsNothing);
  });

  testWidgets('"Lägg bara de 3" writes one week and says the rest stayed '
      'out', (tester) async {
    await pickFridayMiddag(tester);

    await tester.tap(find.text('Lägg bara de 3'));
    await tester.pumpAndSettle();

    verify(
      () => planService.bulkAssignRecipes(
        weekStart: thisWeek,
        startDay: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipes: recipes,
      ),
    ).called(1);
    verifyNever(
      () => planService.bulkAssignRecipes(
        weekStart: nextWeek,
        startDay: any(named: 'startDay'),
        slot: any(named: 'slot'),
        recipes: any(named: 'recipes'),
      ),
    );
    expect(
      find.text('3 av 4 lades till — resten ryms inte i veckan'),
      findsOneWidget,
    );
  });

  testWidgets('a failed next-week write says the first week was saved and '
      'clears the selection, so a retry cannot place it twice', (
    tester,
  ) async {
    when(
      () => planService.bulkAssignRecipes(
        weekStart: nextWeek,
        startDay: any(named: 'startDay'),
        slot: any(named: 'slot'),
        recipes: any(named: 'recipes'),
      ),
    ).thenThrow(Exception('offline'));
    await pickFridayMiddag(tester);

    await tester.tap(find.textContaining('Lägg 3 nu, 1 i v. '));
    await tester.pumpAndSettle();

    verify(() => viewModel.clearSelection()).called(1);
    expect(
      find.text(
        '3 recept lades i veckan. Resten kunde inte läggas i '
        'v. ${IsoWeekUtils.isoWeekNumber(nextWeek)}.',
      ),
      findsOneWidget,
    );
  });
}
