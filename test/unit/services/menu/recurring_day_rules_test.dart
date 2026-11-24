// BUT-2490: saved weekly rules ("Fasta dagar") — the model, the merge into
// a parsed prompt, generation and placement.
import 'dart:math';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/protein_category.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/config/reserved_tags.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';
import 'package:butlery/services/menu/recurring_rule_pins.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

Recipe _dish(String id, Set<String> tags, {int? minutes = 45}) {
  final base = RecipeFactory.build(
    id: id,
    title: id,
    mealType: 'middag',
    timeMinutes: minutes,
  );
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: tags,
        allergenStatus: const {},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026, 4, 1),
      ),
    ),
    type: base.type,
  );
}

RecurringDayRule _fishMonday({bool paused = false}) => RecurringDayRule.create(
  day: DayOfWeek.mon,
  meal: MealSlot.middag,
  food: RecurringFood.fisk,
).copyWith(paused: paused);

DayPin _pinFor(RecurringDayRule rule) => DayPin(
  weekdayIndex: rule.day.isoWeekday,
  mealType: rule.meal.name,
  constraint: rule.toConstraint(),
  fromRule: true,
  ruleId: rule.id,
);

void main() {
  late Lexicon lexicon;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    lexicon = await const CodeLexiconProvider().load();
  });

  ParsedMenuRequest parse(String prompt) =>
      MenuConstraintParser.parse(prompt, lexicon);

  group('RecurringDayRule storage', () {
    test('a rule survives a round trip through its stored map', () {
      final rule = RecurringDayRule.create(
        day: DayOfWeek.thu,
        meal: MealSlot.lunch,
        food: RecurringFood.soppa,
        quick: true,
      ).copyWith(paused: true);

      final back = RecurringDayRules.fromFirestoreList([rule.toFirestore()]);

      expect(back, [rule]);
      expect(back.single.toConstraint().requiredTags, {'soppa'});
      expect(back.single.toConstraint().maxTimeMinutes, 30);
    });

    test('every food chip names a value the recipes actually carry', () {
      for (final food in RecurringFood.values) {
        switch (food.kind) {
          case RecurringRuleKind.tag:
            expect(
              ReservedTags.all,
              contains(food.value),
              reason: '${food.name}: not a tag the tagger emits',
            );
          case RecurringRuleKind.dietary:
            expect(
              DietaryConfig.allKeys,
              contains(food.value),
              reason: '${food.name}: not a dietary key',
            );
          case RecurringRuleKind.proteinCategory:
            expect(
              const {ProteinCategory.fish, ProteinCategory.poultry},
              contains(food.value),
              reason: '${food.name}: not a protein category',
            );
          case RecurringRuleKind.quick:
            fail('${food.name}: a food chip is never the quick kind');
        }
      }
    });

    test('an unusable row is skipped and the others are kept', () {
      final good = _fishMonday().toFirestore();
      final rules = RecurringDayRules.fromFirestoreList([
        {'weekday': 9, 'meal': 'middag', 'kind': 'tag', 'value': 'soppa'},
        {'weekday': 2, 'meal': 'ovrigt', 'kind': 'tag', 'value': 'soppa'},
        {'weekday': 2, 'meal': 'middag', 'kind': 'tag', 'value': 'mysigt'},
        'not a map',
        good,
      ]);
      expect(rules, hasLength(1));
      expect(rules.single.food, RecurringFood.fisk);
    });

    test('one rule per day and meal: the first stored row wins', () {
      final soup = RecurringDayRule.create(
        day: DayOfWeek.mon,
        meal: MealSlot.middag,
        food: RecurringFood.soppa,
      );
      final rules = RecurringDayRules.fromFirestoreList([
        _fishMonday().toFirestore(),
        soup.toFirestore(),
      ]);
      expect(rules.single.food, RecurringFood.fisk);
    });

    test('saving on a taken day and meal replaces that rule', () {
      final soup = RecurringDayRule.create(
        day: DayOfWeek.mon,
        meal: MealSlot.middag,
        food: RecurringFood.soppa,
      );
      final rules = RecurringDayRules.upsert([_fishMonday()], soup)!;
      expect(rules.single.food, RecurringFood.soppa);
    });

    test('the list stops at 14 rules', () {
      var rules = <RecurringDayRule>[];
      for (final day in DayOfWeek.values) {
        for (final meal in [MealSlot.lunch, MealSlot.middag]) {
          rules = RecurringDayRules.upsert(
            rules,
            RecurringDayRule.create(day: day, meal: meal, quick: true),
          )!;
        }
      }
      expect(rules, hasLength(RecurringDayRules.maxRules));
    });
  });

  group('RecurringRulePins.merge', () {
    test('an active rule becomes a rule pin on its day', () {
      final merged = RecurringRulePins.merge(parse('3 middagar'), [
        _fishMonday(),
      ]);
      final pin = merged.dayPins.single;
      expect(pin.fromRule, isTrue);
      expect(pin.weekdayIndex, 1);
      expect(pin.constraint.proteinCategory, 'fish');
    });

    test('a paused rule makes no pin', () {
      final merged = RecurringRulePins.merge(parse('3 middagar'), [
        _fishMonday(paused: true),
      ]);
      expect(merged.dayPins, isEmpty);
    });

    test('a typed pin on the same day and meal wins that week', () {
      final friday = RecurringDayRule.create(
        day: DayOfWeek.fri,
        meal: MealSlot.middag,
        food: RecurringFood.soppa,
      );
      final merged = RecurringRulePins.merge(
        parse('tacofredag och 3 middagar'),
        [friday],
      );
      expect(merged.dayPins, hasLength(1));
      expect(merged.dayPins.single.fromRule, isFalse);
      expect(merged.dayPins.single.constraint.requiredTags, {'taco'});
    });

    test('a dinner rule adds nothing to a prompt asking only for lunch', () {
      final merged = RecurringRulePins.merge(parse('3 luncher'), [
        _fishMonday(),
      ]);
      expect(merged.dayPins, isEmpty);
    });
  });

  group('generation', () {
    final fishA = _dish('fish-a', {'lax'});
    final fishB = _dish('fish-b', {'torsk'});
    final others = [
      for (var i = 0; i < 6; i++) _dish('chicken-$i', {'kyckling'}),
    ];

    MenuService service(List<RecurringDayRule> rules, {int seed = 1}) =>
        MenuService(
          lexiconProvider: const CodeLexiconProvider(),
          random: Random(seed),
          recurringRules: () => rules,
        );

    test('a fish rule puts a fish dish in the menu', () async {
      final s = service([_fishMonday()]);
      final menu = await s.generateMenuFromPrompt('3 middagar', [
        fishA,
        ...others,
      ]);
      expect(menu['middag']!.map((r) => r.id), contains('fish-a'));
      expect(s.lastUnmatchedRuleIds, isEmpty);
    });

    test('a rule with no matching recipe is reported, the menu still '
        'fills', () async {
      final s = service([_fishMonday()]);
      final menu = await s.generateMenuFromPrompt('3 middagar', others);
      expect(menu['middag'], hasLength(3));
      expect(s.lastUnmatchedRuleIds, [_fishMonday().id]);
    });

    test('a paused rule is neither drawn nor reported', () async {
      final s = service([_fishMonday(paused: true)]);
      final menu = await s.generateMenuFromPrompt('3 middagar', others);
      expect(menu['middag'], hasLength(3));
      expect(s.lastUnmatchedRuleIds, isEmpty);
    });

    test('the dish from a recent week is not drawn again while another '
        'fits', () async {
      for (var seed = 0; seed < 25; seed++) {
        final s = service([_fishMonday()], seed: seed);
        final menu = await s.generateMenuFromPrompt(
          '1 middag',
          [
            fishA,
            fishB,
          ],
          recentlyUsedRecipeIds: {'fish-a'},
        );
        expect(menu['middag']!.first.id, 'fish-b', reason: 'seed $seed');
      }
    });

    test('with only the recent dish left, the rule still gets it', () async {
      final s = service([_fishMonday()]);
      final menu = await s.generateMenuFromPrompt(
        '1 middag',
        [
          fishA,
          ...others,
        ],
        recentlyUsedRecipeIds: {'fish-a'},
      );
      expect(menu['middag']!.first.id, 'fish-a');
    });

    test('the live-menu path leaves the saved rules out', () async {
      final s = service([_fishMonday()]);
      final menu = await s.generateMenuFromPromptWithoutRules('1 middag', [
        fishA,
        ...others,
      ]);
      expect(menu['middag'], hasLength(1));
    });

    test('parsePrompt carries the same rule pins generation used', () async {
      final parsed = await service([_fishMonday()]).parsePrompt('3 middagar');
      expect(parsed!.dayPins.single.ruleId, _fishMonday().id);
    });
  });

  group('placement', () {
    // Monday of week 15, 2026.
    final mon = DateTime(2026, 4, 6);
    late WeeklyMenuPlanService plans;

    setUp(() {
      final userService = _MockUserService();
      when(() => userService.currentUserProfile).thenReturn(null);
      plans = WeeklyMenuPlanService(
        repository: _MockRepo(),
        userService: userService,
      );
    });

    final rule = _fishMonday();
    final fish = _dish('fish', {'lax'});
    final fillers = [
      for (var i = 0; i < 3; i++) _dish('f$i', {'kyckling'}),
    ];

    test('the rule dish lands on its day', () {
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'middag': [fish, ...fillers],
        },
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: mon.subtract(const Duration(days: 3)),
        dayPins: [_pinFor(rule)],
      );
      expect(
        result.plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId,
        'fish',
      );
    });

    test('a day already passed drops the rule dish, never moves it', () {
      final wednesday = DateTime(2026, 4, 8, 10);
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'middag': [fish, ...fillers],
        },
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: wednesday,
        dayPins: [_pinFor(rule)],
      );
      final ids = result.plan.entries.map((e) => e.recipeId);
      expect(ids, isNot(contains('fish')));
      expect(ids, containsAll(['f0', 'f1', 'f2']));
      expect(result.overflow, isEmpty);
    });

    test(
      'the user\'s own dish on the day is kept and the rule dish dropped',
      () {
        final own = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
          entries: [
            WeeklyMenuPlanEntry.create(
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              recipeId: 'mine',
              recipeTitle: 'Min egen',
            ),
          ],
        );
        final result = plans.distributeFromGeneratedMenu(
          generated: {
            'middag': [fish, ...fillers],
          },
          weekStart: mon,
          existing: own,
          now: mon.subtract(const Duration(days: 3)),
          dayPins: [_pinFor(rule)],
        );
        expect(
          result.plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId,
          'mine',
        );
        expect(
          result.plan.entries.map((e) => e.recipeId),
          isNot(contains('fish')),
        );
      },
    );

    test('a lunchbox is that day\'s lunch, so a lunch rule is dropped', () {
      final lunchRule = RecurringDayRule.create(
        day: DayOfWeek.mon,
        meal: MealSlot.lunch,
        food: RecurringFood.fisk,
      );
      final boxed = WeeklyMenuPlan.empty(userId: 'u', date: mon).withLunchbox(
        DayOfWeek.mon,
        const Lunchbox(
          source: LunchboxSource.prepDay,
          recipeId: 'chili',
          recipeTitle: 'Chili',
        ),
      );
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'lunch': [fish, ...fillers],
        },
        weekStart: mon,
        existing: boxed,
        now: mon.subtract(const Duration(days: 3)),
        dayPins: [_pinFor(lunchRule)],
      );
      expect(result.plan.entryAt(DayOfWeek.mon, MealSlot.lunch), isNull);
      expect(
        result.plan.entries.map((e) => e.recipeId),
        isNot(contains('fish')),
      );
    });

    test('a typed pin that cannot be placed still falls through', () {
      // Control for the test above: the drop is a rule-pin rule only.
      final wednesday = DateTime(2026, 4, 8, 10);
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'middag': [fish],
        },
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: wednesday,
        dayPins: const [
          DayPin(
            weekdayIndex: 1,
            mealType: 'middag',
            constraint: RecipeConstraint(count: 1),
          ),
        ],
      );
      expect(result.plan.entries.map((e) => e.recipeId), contains('fish'));
    });

    test('an allergen block on the picked dish tries the next fish', () {
      final otherFish = _dish('fish-2', {'torsk'});
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'middag': [fish, fillers[0], otherFish],
        },
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: mon.subtract(const Duration(days: 3)),
        dayPins: [_pinFor(rule)],
        allowedAt: (recipe, day, slot) =>
            !(recipe.id == 'fish' && day == DayOfWeek.mon),
      );
      expect(
        result.plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId,
        'fish-2',
      );
      expect(
        result.plan.entries.map((e) => e.recipeId),
        isNot(contains('fish')),
      );
    });

    test('a full week sends no dish to the tray because of a rule', () {
      // Seven dinners asked for, one per day, plus the rule's own dish.
      final seven = [
        for (var i = 0; i < 7; i++) _dish('d$i', {'kyckling'}),
      ];
      final result = plans.distributeFromGeneratedMenu(
        generated: {
          'middag': [fish, ...seven],
        },
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: mon.subtract(const Duration(days: 3)),
        dayPins: [_pinFor(rule)],
      );
      expect(
        result.plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId,
        'fish',
      );
      expect(result.plan.entries, hasLength(7));
      expect(result.overflow, isEmpty);
      expect(result.overflowReason, isNull);
    });

    test('without a rule the same surplus still goes to the tray', () {
      final eight = [
        for (var i = 0; i < 8; i++) _dish('d$i', {'kyckling'}),
      ];
      final result = plans.distributeFromGeneratedMenu(
        generated: {'middag': eight},
        weekStart: mon,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: mon),
        now: mon.subtract(const Duration(days: 3)),
      );
      expect(result.overflow, hasLength(1));
    });
  });
}
