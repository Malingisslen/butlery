/// This guard reads the RULES number and compares it to the Dart constant, so
/// an edit to either side alone reddens here. Whether some OTHER suite also
/// reddens is not a claim this file makes.
///
/// Comment-stripped for the same reason the allowlist guard is: the rules file
/// is read as raw text, so a commented-out cap would satisfy a naive match
/// while enforcing nothing.
///
/// Whether a capped function is APPLIED to both the create and the update limb
/// is a rules-behaviour question, proven on the emulator by
/// `functions/src/__tests__/weekly-menu-plans-rules.test.ts`; asserting it here
/// would make one red mean two things.
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
  /// Both bounds are read the same way: pull the number out of the rules
  /// function's body, compare it to the Dart constant. Kept as one helper so a
  /// third capped array does not arrive with a third spelling of the check.
  void expectRulesCapMatches({
    required String rules,
    required String function,
    required int dartConstant,
    required String whatBreaks,
  }) {
    // RAW strings concatenated around the name, not an interpolated one. A
    // non-raw Dart string eats `\s` down to a bare `s`, which silently turns
    // this guard into a search for `functions+...` that matches nothing — and
    // an unmatched pattern reads as "the rule is gone", not as "the test is
    // broken".
    final match = RegExp(
      r'function\s+' +
          function +
          r'\s*\(\s*\)\s*\{[^}]*?\.size\(\)\s*<=\s*(\d+)',
    ).firstMatch(rules);

    expect(
      match,
      isNotNull,
      reason:
          '$function is gone from firestore.rules, or its body no longer '
          'bounds `.size()` with `<=`. Either the cap was removed or it was '
          'rewritten into a shape this guard cannot read. Do not delete this '
          'expectation to go green.',
    );

    expect(
      int.parse(match!.group(1)!),
      dartConstant,
      reason:
          'the two copies of this cap have drifted. Dart holds '
          '$dartConstant; firestore.rules accepts at most ${match.group(1)}. '
          '$whatBreaks',
    );
  }

  test('the contributor cap in firestore.rules matches the Dart constant', () {
    // Nothing in `lib/` reads this constant — unlike `maxEditTrailRows`, which
    // the service prunes to — so raising it denies nothing today.
    final rules = _withoutComments(File('firestore.rules').readAsStringSync());

    expectRulesCapMatches(
      rules: rules,
      function: 'groupMenuContributorsWithinCap',
      dartConstant: GroupWeeklyMenuPlan.maxContributorUserIds,
      whatBreaks:
          'If the rules number is the smaller one, a plan whose contributor '
          'trail has grown past it can no longer be saved at all — and that '
          'array is what account erasure finds a departed member by.',
    );
  });

  test('the edit-trail cap in firestore.rules matches the Dart constant', () {
    final rules = _withoutComments(File('firestore.rules').readAsStringSync());

    expectRulesCapMatches(
      rules: rules,
      function: 'groupMenuTrailWithinCap',
      dartConstant: GroupWeeklyMenuPlan.maxEditTrailRows,
      whatBreaks:
          'If the rules number is the smaller one, every save of a week past '
          'that many edits is DENIED and nothing else in the suite says so.',
    );
  });
}
