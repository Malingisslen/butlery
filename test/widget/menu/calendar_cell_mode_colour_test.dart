/// BUT-2376: an assigned calendar cell's underline follows the theme's
/// brightness (context.modeColors), as the feed card does, instead of the
/// light-mode colour in both modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
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

  for (final (mode, theme, expected) in [
    ('light', AppTheme.lightTheme, AppColors.recipeCardBottomBorder),
    ('dark', AppTheme.darkTheme, AppColorsDark.recipeCardBottomBorder),
  ]) {
    testWidgets('an assigned cell is underlined in the $mode colour', (
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
            child: DayCell(
              vm: vm,
              plan: vm.plan!,
              day: DayOfWeek.mon,
              isToday: false,
              onTapEmptySlot: (_, _) {},
              onTapRecipe: (_, {presentServings}) {},
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
        AppColors.recipeCardBottomBorder,
        isNot(AppColorsDark.recipeCardBottomBorder),
      );
      expect(find.text('köttbullar'), findsOneWidget);

      final underlines = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          .where((b) => b.bottom.width == 2)
          .map((b) => b.bottom.color)
          .toList();
      expect(underlines, [expected]);
    });
  }
}
