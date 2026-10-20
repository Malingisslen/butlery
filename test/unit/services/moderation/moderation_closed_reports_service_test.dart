// BUT-1528: listClosedReports pages with the server's cursor and reopenReport
// maps its refusal codes.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockCallable callable;
  late _MockFunctions functions;
  late ModerationAppealsService service;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    service = ModerationAppealsService(functions: functions);
  });

  void stubData(Map<dynamic, dynamic> data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenAnswer((_) async => result);
  }

  group('listClosedReports', () {
    test('the first page sends no cursor and parses rows and cursor', () async {
      stubData({
        'reports': [
          {
            'reportId': 'a',
            'decision': 'no_action',
            'moderator': 'other',
            'history': [],
          },
          {'reportId': '', 'decision': 'no_action'},
          'junk',
        ],
        'nextCursor': 'c1',
      });

      final page = await service.listClosedReports();

      verify(
        () => functions.httpsCallable(
          'listClosedReports',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Map<dynamic, dynamic>>(<String, Object?>{}),
      ).called(1);
      expect(page.reports.map((r) => r.reportId), ['a']);
      expect(page.reports.single.decision, ModeratorDecision.noAction);
      expect(page.nextCursor, 'c1');
    });

    test('the next page sends the cursor back untouched', () async {
      stubData({'reports': <Object>[], 'nextCursor': null});

      final page = await service.listClosedReports(cursor: 'c1');

      verify(
        () => callable.call<Map<dynamic, dynamic>>({'cursor': 'c1'}),
      ).called(1);
      expect(page.nextCursor, isNull);
      expect(page.reports, isEmpty);
    });

    test('a malformed answer is an empty last page', () async {
      stubData({'reports': 'x', 'nextCursor': 5});

      final page = await service.listClosedReports();

      expect(page.reports, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('an empty cursor is the last page', () async {
      stubData({'reports': <Object>[], 'nextCursor': ''});

      expect((await service.listClosedReports()).nextCursor, isNull);
    });
  });

  group('reopenReport', () {
    test('sends only the report id', () async {
      stubData({'ok': true});

      await service.reopenReport('r1');

      verify(
        () => functions.httpsCallable(
          'reopenReport',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Map<dynamic, dynamic>>({'reportId': 'r1'}),
      ).called(1);
    });

    for (final block in ReopenBlock.values) {
      test('failed-precondition ${block.wireName} maps to $block', () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: block.wireName,
          ),
        );

        await expectLater(
          service.reopenReport('r1'),
          throwsA(
            isA<ReopenReportException>().having(
              (e) => e.block,
              'block',
              block,
            ),
          ),
        );
      });
    }

    const others = <(String, String)>[
      ('failed-precondition', 'something else'),
      ('permission-denied', 'admin_only'),
      ('unavailable', ''),
      // A block's wire name under another code is not a block.
      ('permission-denied', 'appealed'),
      ('unavailable', 'not_closed'),
    ];
    for (final (code, message) in others) {
      test('$code "$message" is a failure with no block', () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(code: code, message: message),
        );

        await expectLater(
          service.reopenReport('r1'),
          throwsA(
            isA<ReopenReportException>().having((e) => e.block, 'block', null),
          ),
        );
      });
    }
  });
}
