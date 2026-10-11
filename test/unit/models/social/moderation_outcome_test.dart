// BUT-2353: motivation keys match the server contract, and outcome rows are
// parsed defensively.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/models/social/moderation_outcome.dart';

void main() {
  group('ModerationMotivation', () {
    test('wire keys are exactly the contract keys', () {
      expect(ModerationMotivation.values.map((m) => m.wireName), [
        'removed_copyright',
        'removed_spam',
        'removed_abuse',
        'removed_harassment',
        'removed_other',
        'hidden_rules',
        'hidden_spam',
        'kept_no_breach',
        'kept_already_gone',
        'kept_unclear',
        'misattribution_name_removed',
      ]);
    });

    test('choices are filtered by decision and defaults are in them', () {
      for (final d in ModeratorDecision.values) {
        final choices = ModerationMotivation.choicesFor(d);
        expect(choices, isNotEmpty);
        expect(choices.every((m) => m.decision == d), isTrue);
        expect(choices, contains(ModerationMotivation.defaultFor(d)));
      }
      expect(
        ModerationMotivation.choicesFor(ModeratorDecision.contentRemoved),
        hasLength(5),
      );
      expect(
        ModerationMotivation.choicesFor(ModeratorDecision.noAction),
        isNot(contains(ModerationMotivation.misattributionNameRemoved)),
      );
    });

    test('defaults follow the contract', () {
      expect(
        ModerationMotivation.defaultFor(ModeratorDecision.contentRemoved),
        ModerationMotivation.removedOther,
      );
      expect(
        ModerationMotivation.defaultFor(ModeratorDecision.profileHidden),
        ModerationMotivation.hiddenRules,
      );
      expect(
        ModerationMotivation.defaultFor(ModeratorDecision.noAction),
        ModerationMotivation.keptNoBreach,
      );
    });

    test('an unknown key is null', () {
      expect(ModerationMotivation.fromWire('made_up'), isNull);
      expect(ModerationMotivation.fromWire(null), isNull);
    });
  });

  group('ModerationOutcome', () {
    ModerationOutcome outcome({DateTime? deadline, ModerationAppeal? appeal}) =>
        ModerationOutcome(
          reportId: 'r',
          decision: ModeratorDecision.noAction,
          appealDeadline: deadline,
          appeal: appeal,
        );

    test('can be appealed until the deadline, once', () {
      final deadline = DateTime.utc(2027, 4, 10);
      expect(
        outcome(deadline: deadline).canAppeal(DateTime.utc(2027, 4, 9)),
        isTrue,
      );
      expect(
        outcome(deadline: deadline).canAppeal(DateTime.utc(2027, 4, 11)),
        isFalse,
      );
      expect(
        outcome(
          deadline: deadline,
          appeal: const ModerationAppeal(status: AppealStatus.open, text: 'x'),
        ).canAppeal(DateTime.utc(2027, 1, 1)),
        isFalse,
      );
    });

    test('rows without id or a known decision are dropped', () {
      expect(ModerationOutcome.fromMap({'decision': 'no_action'}), isNull);
      expect(
        ModerationOutcome.fromMap({'reportId': 'a', 'decision': 'x'}),
        isNull,
      );
      expect(ModerationOutcome.fromMap('junk'), isNull);
    });

    test('an unparsable date is null, not a crash', () {
      final o = ModerationOutcome.fromMap({
        'reportId': 'a',
        'decision': 'no_action',
        'decidedAt': 'yesterday',
      })!;
      expect(o.decidedAt, isNull);
    });
  });

  group('OpenAppeal', () {
    test('parses a row and rejects one without a role', () {
      final a = OpenAppeal.fromMap({
        'appealId': 'r_owner',
        'reportId': 'r',
        'role': 'owner',
        'decision': 'content_removed',
        'text': 'Mitt recept',
        'contentType': 'recipe',
        'reason': 'copyright',
      })!;
      expect(a.role, AppealRole.owner);
      expect(a.decision, ModeratorDecision.contentRemoved);
      expect(
        OpenAppeal.fromMap({
          'appealId': 'x',
          'reportId': 'r',
          'role': 'admin',
          'decision': 'no_action',
        }),
        isNull,
      );
    });
  });
}
