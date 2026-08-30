/// One number, two languages, nothing tying them.
///
/// The group weekly-menu edit trail is capped in Dart
/// ([GroupWeeklyMenuPlan.maxEditTrailRows], which the service prunes to) and
/// again in `firestore.rules` (`groupMenuTrailWithinCap`, which bounds what a
/// hand-rolled client may send). Both copies are needed — a client-side prune
/// is not a bound — but nothing makes them move together.
///
/// This guard reads the RULES number and compares it to the Dart constant, so
/// an edit to either side alone reddens here. Whether some OTHER suite also
/// reddens is not a claim this file makes.
///
/// Comment-stripped for the same reason the allowlist guard is: the rules file
/// is read as raw text, so a commented-out cap would satisfy a naive match
/// while enforcing nothing.
///
/// Scope is deliberately one number. Whether the function is APPLIED to both
/// the create and the update limb is a rules-behaviour question, proven on the
/// emulator by `functions/src/__tests__/weekly-menu-plans-rules.test.ts`; a
/// second assertion here would make one red mean two things.
library;

import 'dart:io';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:flutter_test/flutter_test.dart';

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAllMapped(
      RegExp(r'(^|[^:])//.*$', multiLine: true),
      (m) => m.group(1)!,
    );

void main() {
  test('the edit-trail cap in firestore.rules matches the Dart constant', () {
    final rules = _withoutComments(File('firestore.rules').readAsStringSync());

    final match = RegExp(
      r'function\s+groupMenuTrailWithinCap\s*\(\s*\)\s*\{[^}]*?\.size\(\)\s*<=\s*(\d+)',
    ).firstMatch(rules);

    expect(
      match,
      isNotNull,
      reason:
          'groupMenuTrailWithinCap is gone from firestore.rules, or its body no '
          'longer bounds `.size()` with `<=`. Either the cap was removed — in '
          'which case a hand-rolled client can grow the document without limit '
          '— or it was rewritten into a shape this guard cannot read. Do not '
          'delete this expectation to go green.',
    );

    expect(
      int.parse(match!.group(1)!),
      GroupWeeklyMenuPlan.maxEditTrailRows,
      reason:
          'the two copies of the edit-trail cap have drifted. Dart prunes to '
          '${GroupWeeklyMenuPlan.maxEditTrailRows} rows; firestore.rules '
          'accepts at most ${match.group(1)}. If the rules number is the '
          'smaller one, every save of a week past that many edits is DENIED '
          'and nothing else in the suite says so.',
    );
  });
}
