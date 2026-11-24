/// BUT-2522: the preview of a week template. What each dish says about the
/// people eating it, which choice in the overlap question writes what, and
/// that the receipt with "Ångra" comes even when the sheet is gone before the
/// save answers.
///
/// The calendar and the week service are the real ones over a mocked
/// repository, so a test reads what was actually saved.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/week_template_apply.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/manual_add_check.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/templates/week_template_preview_sheet.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: home),
);

Recipe _recipe(String id, {TriState gluten = TriState.free}) {
  final base = RecipeFactory.build(id: id, title: 'Nu $id', mealType: 'middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: {'gluten': gluten},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

WeekTemplateEntry _entry(DayOfWeek day, String id) => WeekTemplateEntry(
  day: day,
  slot: MealSlot.middag,
  recipeId: id,
  recipeTitle: 'Sparat $id',
);

TemplatePreviewRow _row({
  TemplateDishState state = TemplateDishState.found,
  List<String> contains = const [],
  List<String> unchecked = const [],
  bool disliked = false,
}) {
  final recipe = state == TemplateDishState.found ? _recipe('r') : null;
  return TemplatePreviewRow(
    dish: TemplateDish(
      entry: _entry(DayOfWeek.mon, 'r'),
      state: state,
      recipe: recipe,
    ),
    finding: recipe == null
        ? null
        : ManualAddFinding(
            recipe: recipe,
            containsAllergens: contains,
            uncheckedAllergens: unchecked,
            disliked: disliked,
          ),
  );
}

void main() {
  final mon = DateTime(2026, 4, 6);

  group('a dish row', () {
    Future<void> pumpRow(WidgetTester tester, TemplatePreviewRow row) =>
        tester.pumpWidget(_app(TemplatePreviewRowView(row: row)));

    testWidgets('names the allergen and that it does not suit everyone', (
      tester,
    ) async {
      await pumpRow(tester, _row(contains: ['gluten']));

      expect(find.text('Innehåller gluten'), findsOneWidget);
      expect(find.text('Passar inte alla'), findsOneWidget);
      expect(find.text('Ej kontrollerat'), findsNothing);
    });

    testWidgets('a deleted recipe is missing, not unchecked', (tester) async {
      await pumpRow(tester, _row(state: TemplateDishState.missing));

      expect(find.text('Saknas'), findsOneWidget);
      expect(
        find.text('Receptet är raderat, välj nytt i kalendern'),
        findsOneWidget,
      );
      expect(find.text('Ej kontrollerat'), findsNothing);
    });

    testWidgets('an unreadable recipe and an unknown allergen are unchecked', (
      tester,
    ) async {
      await pumpRow(tester, _row(state: TemplateDishState.unverified));
      expect(find.text('Ej kontrollerat'), findsOneWidget);

      await pumpRow(tester, _row(unchecked: ['gluten']));
      expect(find.text('Ej kontrollerat'), findsOneWidget);
    });

    testWidgets('a dislike is named', (tester) async {
      await pumpRow(tester, _row(disliked: true));

      expect(find.text('Någon ogillar den'), findsOneWidget);
    });

    testWidgets('a dish everyone can eat has no pill', (tester) async {
      await pumpRow(tester, _row());

      for (final pill in [
        'Saknas',
        'Passar inte alla',
        'Ej kontrollerat',
        'Någon ogillar den',
      ]) {
        expect(find.text(pill), findsNothing);
      }
      expect(find.textContaining('Innehåller'), findsNothing);
    });
  });

  group('the sheet', () {
    late _MockRepo repo;
    late _MockRecipes recipes;
    late WeeklyMenuPlanService service;
    WeeklyMenuPlan? stored;

    setUpAll(() async {
      await BaseUnitTest.setupUnitWithProductionLocator();
      registerFallbackValue(_FakeWeeklyMenuPlan());
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    setUp(() {
      stored = null;
      repo = _MockRepo();
      final userService = _MockUserService();
      when(() => userService.currentUserProfile).thenReturn(
        UserProfile(
          uid: 'u',
          displayName: 'Test',
          email: 't@example.com',
          joinedAt: DateTime(2026, 1, 1),
          lastActiveAt: DateTime(2026, 1, 1),
        ),
      );
      when(() => repo.save(any())).thenAnswer((inv) async {
        stored = inv.positionalArguments.first as WeeklyMenuPlan;
      });
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => stored);
      (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
          .setAuthState(userId: 'u');
      service = WeeklyMenuPlanService(
        repository: repo,
        userService: userService,
      );

      recipes = _MockRecipes();
      when(() => recipes.stateStream).thenAnswer((_) => const Stream.empty());
      when(() => recipes.getRecipeById(any())).thenReturn(null);
      when(() => recipes.getRecipeById('soup')).thenReturn(_recipe('soup'));
      when(() => recipes.getRecipeById('pizza')).thenReturn(_recipe('pizza'));
    });

    tearDown(() => service.onDispose());

    WeeklyMenuPlanViewModel calendar(WidgetTester tester) {
      final calendar = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipes,
        shoppingListGenerator: _MockShopping(),
        readDislikes: () async => const {},
      );
      addTearDown(calendar.dispose);
      return calendar;
    }

    WeekTemplateViewModel vmFor(WeeklyMenuPlanViewModel calendar) =>
        WeekTemplateViewModel(
          calendar: calendar,
          weekService: service,
          recipes: recipes,
          currentUserId: () => 'u',
          allergenScope: (_) async => MealAllergenScope(
            household: const UserAllergenPreferences(
              trackedAllergens: {'gluten'},
              trackedDietary: {},
            ),
          ),
          readDislikes: () async => const {},
        );

    /// Pumps the sheet on its own and records each mode it asks to apply.
    Future<List<WeekTemplateApplyMode>> pumpSheet(
      WidgetTester tester,
      WeeklyMenuPlanViewModel calendar,
    ) async {
      final asked = <WeekTemplateApplyMode>[];
      final vm = vmFor(calendar);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        _app(
          WeekTemplatePreviewSheet(
            viewModel: vm,
            name: 'Sommarveckan',
            entries: [_entry(DayOfWeek.mon, 'soup')],
            onApply: (mode) async {
              asked.add(mode);
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return asked;
    }

    Future<WeeklyMenuPlanViewModel> calendarWithMonday(
      WidgetTester tester,
    ) async {
      final cal = calendar(tester);
      await tester.runAsync(() async {
        await cal.loadWeek(mon);
        await cal.assignRecipe(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipe: _recipe('pizza'),
        );
        // The calendar finishes its own save in the background.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      return cal;
    }

    testWidgets('on a week with a dish in the way, "Ersätt allt" asks to '
        'replace', (tester) async {
      final cal = await calendarWithMonday(tester);
      final asked = await pumpSheet(tester, cal);

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-template-replace')));
      await tester.pumpAndSettle();

      expect(asked, [WeekTemplateApplyMode.replace]);
    });

    testWidgets('on a week with a dish in the way, "Fyll tomma platser" asks '
        'to fill', (tester) async {
      final cal = await calendarWithMonday(tester);
      final asked = await pumpSheet(tester, cal);

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-template-fill')));
      await tester.pumpAndSettle();

      expect(asked, [WeekTemplateApplyMode.fillEmpty]);
    });

    testWidgets('cancelling the question applies nothing', (tester) async {
      final cal = await calendarWithMonday(tester);
      final asked = await pumpSheet(tester, cal);

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(asked, isEmpty);
    });

    testWidgets('an empty week fills without asking', (tester) async {
      final asked = await pumpSheet(tester, calendar(tester));

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('week-template-replace')), findsNothing);
      expect(asked, [WeekTemplateApplyMode.fillEmpty]);
    });

    testWidgets('a failed apply says so and keeps the sheet open', (
      tester,
    ) async {
      await pumpSheet(tester, calendar(tester));

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Mallen kunde inte läggas på'),
        findsOneWidget,
      );
      expect(find.text('Sommarveckan'), findsOneWidget);
    });

    testWidgets('a sheet closed before the save answers still ends in a '
        'receipt, and "Ångra" takes the dishes back', (tester) async {
      final cal = calendar(tester);
      final saving = Completer<void>();
      when(() => repo.save(any())).thenAnswer((inv) async {
        if (!saving.isCompleted) await saving.future;
        stored = inv.positionalArguments.first as WeeklyMenuPlan;
      });
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showWeekTemplatePreview(
                context,
                calendar: cal,
                name: 'Sommarveckan',
                entries: [_entry(DayOfWeek.mon, 'soup')],
                createViewModel: vmFor,
              ),
              child: const Text('Öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öppna'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('week-template-apply')));
      await tester.pump();
      // Taken away the way a drag does, past the sheet's own pop guard.
      Navigator.of(
        tester.element(find.byType(WeekTemplatePreviewSheet)),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byType(WeekTemplatePreviewSheet), findsNothing);

      saving.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 rätt lades på vecka'), findsOneWidget);
      expect(stored!.entries.map((e) => e.recipeId), ['soup']);

      await tester.tap(find.text('Ångra'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(stored!.entries, isEmpty);
    });
  });
}
