// BUT-2329: freezeEvidence sends the right payload per action, parses the
// answer, and maps the callable's refusals.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/report_evidence.dart';
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

  group('freezeEvidence', () {
    test(
      'freeze calls freezeReportEvidence with the reason wire name',
      () async {
        stubData({'action': 'freeze', 'until': '2027-10-09T08:30:00.000Z'});

        final outcome = await service.freezeEvidence(
          'r1',
          action: FreezeAction.freeze,
          reason: FreezeReason.legalClaim,
        );

        verify(
          () => functions.httpsCallable(
            'freezeReportEvidence',
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(
          () => callable.call<Map<dynamic, dynamic>>({
            'reportId': 'r1',
            'action': 'freeze',
            'reason': 'legal_claim',
          }),
        ).called(1);
        expect(outcome.until, DateTime.utc(2027, 10, 9, 8, 30));
        expect(outcome.deleted, isFalse);
      },
    );

    test('extend sends the reason too', () async {
      stubData({'action': 'extend', 'until': '2028-10-09T00:00:00.000Z'});

      await service.freezeEvidence(
        'r1',
        action: FreezeAction.extend,
        reason: FreezeReason.threat,
      );

      verify(
        () => callable.call<Map<dynamic, dynamic>>({
          'reportId': 'r1',
          'action': 'extend',
          'reason': 'threat',
        }),
      ).called(1);
    });

    test('release sends no reason key and reads deleted', () async {
      stubData({'action': 'release', 'deleted': true});

      final outcome = await service.freezeEvidence(
        'r1',
        action: FreezeAction.release,
      );

      verify(
        () => callable.call<Map<dynamic, dynamic>>({
          'reportId': 'r1',
          'action': 'release',
        }),
      ).called(1);
      expect(outcome.deleted, isTrue);
      expect(outcome.until, isNull);
    });

    test('an unparsable until reads as null, not a throw', () async {
      stubData({'action': 'freeze', 'until': 'not a date'});

      final outcome = await service.freezeEvidence(
        'r1',
        action: FreezeAction.freeze,
        reason: FreezeReason.police,
      );

      expect(outcome.until, isNull);
    });

    for (final block in FreezeBlock.values) {
      test('failed-precondition ${block.wireName} maps to $block', () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: block.wireName,
          ),
        );

        await expectLater(
          service.freezeEvidence(
            'r1',
            action: FreezeAction.release,
          ),
          throwsA(
            isA<FreezeEvidenceException>().having(
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
      ('invalid-argument', 'reason'),
      ('permission-denied', 'at_cap'),
      ('unavailable', ''),
    ];
    for (final (code, message) in others) {
      test('$code "$message" is a failure with no block', () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(code: code, message: message),
        );

        await expectLater(
          service.freezeEvidence(
            'r1',
            action: FreezeAction.freeze,
            reason: FreezeReason.police,
          ),
          throwsA(
            isA<FreezeEvidenceException>().having(
              (e) => e.block,
              'block',
              null,
            ),
          ),
        );
      });
    }
  });
}
