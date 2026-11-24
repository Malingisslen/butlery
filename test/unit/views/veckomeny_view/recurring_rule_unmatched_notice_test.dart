import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';

void main() {
  final sv = AppLocalizationsSv();
  RecurringDayRule rule(
    DayOfWeek day, {
    RecurringFood? food,
    bool quick = false,
  }) => RecurringDayRule.create(
    day: day,
    meal: MealSlot.middag,
    food: food,
    quick: quick,
  );

  test('one unmatched rule names its food and its day', () {
    expect(
      recurringRuleUnmatchedNotice(sv, [
        rule(DayOfWeek.mon, food: RecurringFood.fisk),
      ], DayOfWeek.mon),
      'Inget fiskrecept hittades för måndag',
    );
  });

  test('a quick rule says snabbt, with or without a food', () {
    expect(
      recurringRuleUnmatchedNotice(sv, [
        rule(DayOfWeek.fri, food: RecurringFood.tacos, quick: true),
      ], DayOfWeek.mon),
      'Inget snabbt tacorecept hittades för fredag',
    );
    expect(
      recurringRuleUnmatchedNotice(sv, [
        rule(DayOfWeek.sun, quick: true),
      ], DayOfWeek.mon),
      'Inget snabbt recept hittades för söndag',
    );
  });

  test('a rule on a day that has passed says nothing', () {
    expect(
      recurringRuleUnmatchedNotice(sv, [
        rule(DayOfWeek.mon, food: RecurringFood.fisk),
      ], DayOfWeek.tue),
      isNull,
    );
    expect(recurringRuleUnmatchedNotice(sv, const [], DayOfWeek.mon), isNull);
  });

  test('several unmatched rules get one notice', () {
    expect(
      recurringRuleUnmatchedNotice(sv, [
        rule(DayOfWeek.mon, food: RecurringFood.fisk),
        rule(DayOfWeek.wed, food: RecurringFood.soppa),
      ], DayOfWeek.mon),
      'Några fasta dagar fick inget recept den här veckan',
    );
  });
}
