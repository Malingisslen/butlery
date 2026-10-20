// BUT-1528: the closed-report rows and the review fields are parsed the way
// the server contract sends them, and defensively.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_outcome.dart';

Map<String, Object?> _row({Map<String, Object?> overrides = const {}}) => {
  'reportId': 'r1',
  'decision': 'profile_hidden',
  'rule': 'harassment',
  'decidedAt': '2026-10-18T14:02:00.000Z',
  'moderator': 'self',
  'contentType': 'profile',
  'revision': 1,
  'history': [
    {
      'decision': 'content_removed',
      'rule': 'harassment',
      'decidedAt': '2026-10-12T08:31:00.000Z',
      'moderator': 'other',
    },
    {'decision': 'nonsense'},
  ],
  'appealed': false,
  'reopenBlock': null,
  ...overrides,
};

void main() {
  group('ClosedReport.fromMap', () {
    test('reads every field of the contract', () {
      final r = ClosedReport.fromMap(_row())!;

      expect(r.reportId, 'r1');
      expect(r.decision, ModeratorDecision.profileHidden);
      expect(r.rule, 'harassment');
      expect(r.decidedAt, DateTime.utc(2026, 10, 18, 14, 2));
      expect(r.moderator, DecisionMaker.self);
      expect(r.contentType, ContentType.profile);
      expect(r.revision, 1);
      expect(r.appealed, isFalse);
      expect(r.reopenBlock, isNull);
    });

    test('history keeps the valid entries, oldest first', () {
      final r = ClosedReport.fromMap(_row())!;

      expect(r.wasRevised, isTrue);
      expect(r.history, hasLength(1));
      expect(r.history.single.decision, ModeratorDecision.contentRemoved);
      expect(r.history.single.moderator, DecisionMaker.other);
    });

    test('a row without a history is not revised', () {
      final r = ClosedReport.fromMap(_row(overrides: {'history': <Object>[]}))!;

      expect(r.wasRevised, isFalse);
    });

    test('every reopenBlock code parses; an unknown one is no block', () {
      for (final b in ReopenBlock.values) {
        expect(
          ClosedReport.fromMap(
            _row(overrides: {'reopenBlock': b.wireName}),
          )!.reopenBlock,
          b,
        );
      }
      expect(
        ClosedReport.fromMap(
          _row(overrides: {'reopenBlock': 'made_up'}),
        )!.reopenBlock,
        isNull,
      );
    });

    test('a row without an id or a known decision is dropped', () {
      expect(ClosedReport.fromMap(_row(overrides: {'reportId': ''})), isNull);
      expect(
        ClosedReport.fromMap(_row(overrides: {'decision': 'banned'})),
        isNull,
      );
      expect(ClosedReport.fromMap('x'), isNull);
    });

    test('missing optional fields fall back instead of throwing', () {
      final r = ClosedReport.fromMap({
        'reportId': 'r2',
        'decision': 'no_action',
      })!;

      expect(r.rule, isNull);
      expect(r.decidedAt, isNull);
      expect(r.moderator, DecisionMaker.auto);
      expect(r.contentType, isNull);
      expect(r.revision, 0);
      expect(r.appealed, isFalse);
    });

    test('withReopenBlock keeps the row and sets the block', () {
      final r = ClosedReport.fromMap(_row())!.withReopenBlock(
        ReopenBlock.appealed,
      );

      expect(r.reopenBlock, ReopenBlock.appealed);
      expect(r.appealed, isTrue);
      expect(r.reportId, 'r1');
    });
  });

  group('ContentReport review fields', () {
    Future<ContentReport?> parse(Map<String, Object?> extra) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reports').doc('r').set({
        'reporterId': 'a',
        'contentType': 'recipe',
        'contentId': 'c',
        'reason': 'spam',
        'status': 'actioned',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        ...extra,
      });
      return ContentReport.fromFirestore(
        await firestore.collection('reports').doc('r').get(),
      );
    }

    test('a reopened report carries its round and time', () async {
      final r = await parse({
        'reviewRound': 2,
        'reopenedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20, 10)),
        'moderatorAction': 'profile_hidden',
        'reopenedDecision': 'no_action',
      });

      expect(r!.reviewRound, 2);
      expect(r.reopenedDecision, ModeratorDecision.noAction);
      expect(r.isReopened, isTrue);
      expect(r.reopenedAt!.toUtc(), DateTime.utc(2026, 10, 20, 10));
      expect(r.moderatorAction, ModeratorDecision.profileHidden);
    });

    test('a report never reopened is in round 0', () async {
      final r = await parse({});

      expect(r!.reviewRound, 0);
      expect(r.isReopened, isFalse);
      expect(r.reopenedAt, isNull);
      expect(r.reopenedDecision, isNull);
    });

    test(
      'a malformed round reads as 0 and copyWith keeps the round and time',
      () async {
        final r = await parse({'reviewRound': 'two'});
        expect(r!.reviewRound, 0);

        final reopened = (await parse({
          'reviewRound': 3,
          'reopenedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
          'reopenedDecision': 'content_removed',
        }))!;
        final copy = reopened.copyWith(status: ReportStatus.closed);
        expect(copy.reviewRound, 3);
        expect(copy.reopenedDecision, ModeratorDecision.contentRemoved);
        expect(copy.reopenedAt?.toUtc(), DateTime.utc(2026, 10, 20));
      },
    );

    test('the round is never written back by the client', () async {
      final r = (await parse({
        'reviewRound': 3,
        'reopenedDecision': 'no_action',
      }))!;

      expect(r.toFirestore().containsKey('reviewRound'), isFalse);
      expect(r.toFirestore().containsKey('reopenedAt'), isFalse);
      expect(r.toFirestore().containsKey('reopenedDecision'), isFalse);
    });
  });

  group('ModerationOutcome.revised', () {
    test('parses true and defaults to false when absent or odd', () {
      ModerationOutcome? parse(Object? revised) => ModerationOutcome.fromMap({
        'reportId': 'r',
        'decision': 'no_action',
        'revised': ?revised,
      });

      expect(parse(true)!.revised, isTrue);
      expect(parse(false)!.revised, isFalse);
      expect(parse(null)!.revised, isFalse);
      expect(parse('yes')!.revised, isFalse);
    });

    test('withAppeal keeps the flag', () {
      final o = ModerationOutcome.fromMap({
        'reportId': 'r',
        'decision': 'no_action',
        'revised': true,
      })!;

      expect(
        o
            .withAppeal(
              const ModerationAppeal(status: AppealStatus.open, text: 'x'),
            )
            .revised,
        isTrue,
      );
    });
  });
}
