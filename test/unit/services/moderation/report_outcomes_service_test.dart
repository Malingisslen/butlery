// BUT-2222: the callable's rows are parsed defensively and no uid is sent.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockCallable callable;
  late ReportOutcomesService service;

  void stubData(Map<dynamic, dynamic> data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    final functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(
        any(),
        options: any(named: 'options'),
      ),
    ).thenReturn(callable);
    service = ReportOutcomesService(functions: functions);
  });

  test('valid rows become a map and the call carries no arguments', () async {
    stubData({
      'outcomes': [
        {'reportId': 'a', 'decision': 'content_removed'},
        {'reportId': 'b', 'decision': 'no_action'},
        {'reportId': 'c', 'decision': 'profile_hidden'},
      ],
    });

    final out = await service.getMyReportOutcomes();

    expect(out, {
      'a': ModeratorDecision.contentRemoved,
      'b': ModeratorDecision.noAction,
      'c': ModeratorDecision.profileHidden,
    });
    verify(() => callable.call<Map<dynamic, dynamic>>()).called(1);
  });

  test('unknown decision and empty or missing id are skipped', () async {
    stubData({
      'outcomes': [
        {'reportId': 'a', 'decision': 'banished'},
        {'reportId': '', 'decision': 'no_action'},
        {'decision': 'no_action'},
        {'reportId': 'ok', 'decision': 'no_action'},
        'junk',
      ],
    });

    expect(await service.getMyReportOutcomes(), {
      'ok': ModeratorDecision.noAction,
    });
  });

  test('a non-list outcomes value gives an empty map', () async {
    stubData({'outcomes': 'nope'});
    expect(await service.getMyReportOutcomes(), isEmpty);
  });

  test('a failing call throws', () async {
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenThrow(Exception('boom'));
    expect(service.getMyReportOutcomes(), throwsException);
  });

  group('details (BUT-2353)', () {
    test('rows carry motivation, dates and appeal', () async {
      stubData({
        'outcomes': [
          {
            'reportId': 'a',
            'decision': 'content_removed',
            'motivation': 'removed_spam',
            'decidedAt': '2026-10-10T08:00:00.000Z',
            'appealDeadline': '2027-04-11T08:00:00.000Z',
            'appeal': {
              'status': 'open',
              'text': 'Fel beslut',
              'submittedAt': '2026-10-11T08:00:00.000Z',
              'answeredAt': null,
            },
          },
        ],
      });

      final out = await service.getMyReportOutcomeDetails();

      final o = out['a']!;
      expect(o.motivationKey, 'removed_spam');
      expect(o.decidedAt, DateTime.utc(2026, 10, 10, 8));
      expect(o.appealDeadline, DateTime.utc(2027, 4, 11, 8));
      expect(o.appeal!.status, AppealStatus.open);
      expect(o.appeal!.text, 'Fel beslut');
      expect(o.appeal!.answeredAt, isNull);
    });

    test(
      'getMyContentDecisions reads decisions with type and reason',
      () async {
        stubData({
          'decisions': [
            {
              'reportId': 'd1',
              'decision': 'profile_hidden',
              'motivation': 'hidden_rules',
              'contentType': 'profile',
              'reason': 'spam',
            },
            {'reportId': 'bad', 'decision': 'nope'},
          ],
        });

        final out = await service.getMyContentDecisions();

        expect(out, hasLength(1));
        expect(out.single.contentType, ContentType.profile);
        expect(out.single.reason, 'spam');
        expect(out.single.decision, ModeratorDecision.profileHidden);
      },
    );

    test('an unknown appeal status gives no appeal', () async {
      stubData({
        'outcomes': [
          {
            'reportId': 'a',
            'decision': 'no_action',
            'appeal': {'status': 'weird', 'text': 'x'},
          },
        ],
      });

      expect((await service.getMyReportOutcomeDetails())['a']!.appeal, isNull);
    });
  });
}
