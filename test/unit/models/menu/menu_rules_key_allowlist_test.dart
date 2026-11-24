import 'dart:io';

import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:flutter_test/flutter_test.dart';

/// BUT-2522: `firestore.rules` refuses a `menus` write carrying a key outside
/// `menuKeys()`, and that refusal is silent in the app. These tests tie the
/// rules list, the model's write and the rules-test fixture to one set, so a
/// field added to `SharedMenu.toFirestore()` fails here instead of in use.
void main() {
  // Keys the app writes beside `toFirestore()`: `saveWeekTemplate` adds
  // `sharedToUserIds`, `markMenuAsModified` writes the other two.
  const extraWrittenKeys = {'sharedToUserIds', 'isModified', 'modifiedAt'};

  Set<String> rulesMenuKeys() {
    final rules = File('firestore.rules').readAsStringSync();
    final body = RegExp(
      r'function menuKeys\(\)\s*\{\s*return\s*\[([^\]]*)\]',
    ).firstMatch(rules);
    expect(body, isNotNull, reason: 'menuKeys() not found in firestore.rules');
    return RegExp(
      r"'(\w+)'",
    ).allMatches(body!.group(1)!).map((m) => m.group(1)!).toSet();
  }

  SharedMenu fullTemplate() => SharedMenu(
    id: 't1',
    sharedByUserId: 'u1',
    sharedByDisplayName: 'Malin',
    sharedAt: DateTime.utc(2026, 11, 1),
    shareMessage: 'hej',
    menuTitle: 'Vardagsvecka',
    menuSnapshot: const {},
    realtimeMenuId: 'rt-1',
    originalOwnerStaticCopyId: 'copy-1',
    templateKind: SharedMenu.weekTemplateKind,
    templateEntries: const [
      WeekTemplateEntry(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r1',
        recipeTitle: 'Pasta',
      ),
    ],
  );

  test('the rules list is exactly what the app writes to menus', () {
    final written = {...fullTemplate().toFirestore().keys, ...extraWrittenKeys};
    expect(rulesMenuKeys(), written);
  });

  test('the rules-test fixture sends the app\'s real template write', () {
    final source = File(
      'functions/src/__tests__/menus-rules.test.ts',
    ).readAsStringSync();
    final start = source.indexOf('function fullTemplateBody(');
    expect(start, isNot(-1), reason: 'fullTemplateBody not found');
    final end = source.indexOf('\n}\n', start);
    final fixtureKeys = RegExp(
      r'^    (\w+):',
      multiLine: true,
    ).allMatches(source.substring(start, end)).map((m) => m.group(1)!).toSet();
    expect(fixtureKeys, {
      ...fullTemplate().toFirestore().keys,
      'sharedToUserIds',
    });
  });
}
