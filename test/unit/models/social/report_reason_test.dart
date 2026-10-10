/// BUT-2154: `reports/*.reason` must be an id the Firestore rule admits; the
/// app used to send the Swedish label and every report was denied.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/social/report_reason.dart';

void main() {
  group('ReportReason', () {
    test('fromWire round-trips every value', () {
      for (final reason in ReportReason.values) {
        expect(ReportReason.fromWire(reason.wireName), equals(reason));
      }
    });

    test('fromWire returns null for text that is not an id', () {
      // Reports saved before BUT-2154 hold the label; those must not be
      // mistaken for an id.
      expect(ReportReason.fromWire(null), isNull);
      expect(ReportReason.fromWire(''), isNull);
      expect(ReportReason.fromWire('Spam'), isNull);
      expect(ReportReason.fromWire('Olämpligt innehåll'), isNull);
      expect(ReportReason.fromWire('SPAM'), isNull, reason: 'case-sensitive');
    });

    test('the dialog offers exactly these ids, in this order', () {
      expect(
        ReportReason.offered.map((r) => r.wireName).toList(),
        equals(['abuse', 'spam', 'harassment', 'copyright', 'other']),
      );
    });

    test('misattribution exists but is never offered in the dialog', () {
      expect(
        ReportReason.fromWire('misattribution'),
        ReportReason.misattribution,
      );
      expect(
        ReportReason.offered,
        isNot(contains(ReportReason.misattribution)),
      );
    });

    test('every wireName is one the create rule on reports admits', () {
      // Read from the rule itself, so an edit to either side reddens here.
      // A value the rule does not list is denied exactly as the labels were.
      final rules = File('firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('match /reports/{reportId}'));
      final list = RegExp(
        r'request\.resource\.data\.reason in \[([^\]]*)\]',
      ).firstMatch(block)!.group(1)!;
      final ruleAdmits = RegExp(
        r"'([a-z_]+)'",
      ).allMatches(list).map((m) => m.group(1)).toSet();

      expect(ruleAdmits, isNotEmpty);
      for (final reason in ReportReason.values) {
        expect(
          ruleAdmits,
          contains(reason.wireName),
          reason: '${reason.name} would be denied by the reports create rule',
        );
      }
    });
  });
}
