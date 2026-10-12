/// BUT-2376: an assigned calendar cell's border follows the theme's
/// brightness, instead of the light-mode colour in both modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {
  @override
  Stream<String?> get weekWrites => const Stream.empty();

  @override
  Stream<LateWeekConflict> get lateConflicts => const Stream.empty();
}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('an assigned cell is framed in the $mode colour', (
      tester,
    ) async {
      final monday = DateTime(2026, 4, 13);
      final plan = WeeklyMenuPlan(
        id: 'u1_2026-W16',
        userId: 'u1',
        weekStartDate: monday,
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r1',
            recipeTitle: 'Köttbullar',
          ),
        ],
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final service = _MockService();
      final recipes = _MockRecipes();
      when(() => recipes.stateStream).thenAnswer((_) => const Stream.empty());
      when(() => recipes.getRecipeById(any())).thenReturn(null);
      when(() => service.overflowTrayOwnerId).thenReturn(null);
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
      );
      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipes,
        shoppingListGenerator: _MockShopping(),
        allergenScope: (_) async => MealAllergenScope(
          household: const UserAllergenPreferences(
            trackedAllergens: {},
            trackedDietary: {},
          ),
        ),
        allergenScopeOn: () => false,
      );
      addTearDown(vm.dispose);
      await vm.loadWeek(monday);

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: Theme(
            data: theme,
            child: CalendarWeekTable(
              vm: vm,
              plan: vm.plan!,
              todayIndex: -1,
              onTapEmptySlot: (_, _) {},
              onTapRecipe: (_, {presentServings}) {},
              onTapOvrigt: (_) {},
              roster: const [],
              onTapPresence: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Premise: the light and dark values differ, so the check below can
      // tell the two modes apart.
      expect(
        AppTheme.lightTheme.colorScheme.outlineVariant,
        isNot(AppTheme.darkTheme.colorScheme.outlineVariant),
      );
      expect(find.text('Köttbullar'), findsOneWidget);

      final frame = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Köttbullar'),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (frame.decoration! as BoxDecoration).border! as Border;
      expect(border.bottom.color, theme.colorScheme.outlineVariant);
    });
  }
}
