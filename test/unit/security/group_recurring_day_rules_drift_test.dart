/// BUT-2490: a group's fixed days are checked by the
/// `setGroupRecurringDayRules` callable against a table in
/// `functions/src/groups/recurring-day-rules.ts`, and parsed by the app with
/// `RecurringDayRule.fromFirestore`. This reads the TypeScript as text and
/// fails when the two copies disagree: a food the app offers that the server
/// refuses makes every save of it fail, and one the server accepts that the
/// app drops makes a stored rule invisible.
///
/// It also pins the stored row's keys, so a row never gains an author, a uid
/// or a timestamp without this file going red.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

import 'rules_source.dart';

const _tsPath = 'functions/src/groups/recurring-day-rules.ts';

const _sevenKeys = {
  'id',
  'weekday',
  'meal',
  'kind',
  'value',
  'quick',
  'paused',
};

/// The quoted strings in the `[...] as const` array named [name].
Set<String> _tsStringArray(String ts, String name) {
  final match = RegExp(
    r'export\s+const\s+' + name + r'\s*=\s*\[([\s\S]*?)\]\s*as\s+const',
  ).firstMatch(ts);
  expect(match, isNotNull, reason: '$name is gone from $_tsPath');
  return RegExp(
    r'"([^"]*)"',
  ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
}

void main() {
  final ts = withoutCStyleComments(File(_tsPath).readAsStringSync());

  test('a stored rule row has exactly the seven keys, and no author, uid '
      'or timestamp', () {
    final food = RecurringDayRule.create(
      day: DayOfWeek.fri,
      meal: MealSlot.middag,
      food: RecurringFood.tacos,
    );
    final quick = RecurringDayRule.create(
      day: DayOfWeek.mon,
      meal: MealSlot.lunch,
      quick: true,
    );

    expect(food.toFirestore().keys.toSet(), _sevenKeys);
    expect(quick.toFirestore().keys.toSet(), _sevenKeys);
  });

  test('the server accepts exactly the keys the app writes', () {
    expect(_tsStringArray(ts, 'RECURRING_RULE_KEYS'), _sevenKeys);
  });

  test('the server bound equals RecurringDayRules.maxRules', () {
    final match = RegExp(
      r'export\s+const\s+MAX_RECURRING_DAY_RULES\s*=\s*(\d+)\s*;',
    ).firstMatch(ts);
    expect(match, isNotNull, reason: 'MAX_RECURRING_DAY_RULES is gone');
    expect(int.parse(match!.group(1)!), RecurringDayRules.maxRules);
  });

  test('the server kinds equal RecurringRuleKind', () {
    expect(
      _tsStringArray(ts, 'RECURRING_RULE_KINDS'),
      RecurringRuleKind.values.map((k) => k.name).toSet(),
    );
  });

  test('the server meals are lunch and middag', () {
    expect(_tsStringArray(ts, 'RECURRING_RULE_MEALS'), {
      MealSlot.lunch.name,
      MealSlot.middag.name,
    });
  });

  test('the server food table equals RecurringFood, kind and value', () {
    final block = RegExp(
      r'export\s+const\s+RECURRING_FOODS\s*=\s*\[([\s\S]*?)\]\s*as\s+const',
    ).firstMatch(ts);
    expect(block, isNotNull, reason: 'RECURRING_FOODS is gone from $_tsPath');
    final server = RegExp(r'\{\s*kind:\s*"(\w+)",\s*value:\s*"([^"]*)"\s*\}')
        .allMatches(block!.group(1)!)
        .map((m) => '${m.group(1)}/${m.group(2)}')
        .toList();

    expect(server, hasLength(RecurringFood.values.length));
    expect(
      server.toSet(),
      RecurringFood.values.map((f) => '${f.kind.name}/${f.value}').toSet(),
    );
  });
}
