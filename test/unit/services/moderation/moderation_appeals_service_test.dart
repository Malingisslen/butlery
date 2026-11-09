// BUT-2353: the appeal callables send what the contract says and map its
// error codes.
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/moderation_outcome.dart';
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

  test(
    'submitAppeal sends report, role and trimmed text, and no uid',
    () async {
      stubData({'ok': true});

      await service.submitAppeal(
        reportId: 'r1',
        role: AppealRole.owner,
        text: '  Receptet är mitt eget  ',
      );

      verify(
        () => functions.httpsCallable(
          'submitAppeal',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Map<dynamic, dynamic>>({
          'reportId': 'r1',
          'role': 'owner',
          'text': 'Receptet är mitt eget',
        }),
      ).called(1);
    },
  );

  const cases = <(String, String?, AppealFailure)>[
    ('permission-denied', null, AppealFailure.notAllowed),
    ('not-found', null, AppealFailure.notFound),
    ('already-exists', 'appeal_exists', AppealFailure.alreadyAppealed),
    ('invalid-argument', null, AppealFailure.invalidText),
    ('failed-precondition', 'appeal_window_closed', AppealFailure.windowClosed),
    ('failed-precondition', 'something else', AppealFailure.other),
    ('unavailable', null, AppealFailure.other),
  ];
  for (final (code, message, failure) in cases) {
    test('$code ${message ?? ''} maps to $failure', () async {
      when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(code: code, message: message ?? ''),
      );

      await expectLater(
        service.submitAppeal(
          reportId: 'r',
          role: AppealRole.reporter,
          text: 'tio tecken eller mer',
        ),
        throwsA(
          isA<AppealException>().having((e) => e.failure, 'failure', failure),
        ),
      );
    });
  }

  test('listOpenAppeals parses rows and skips broken ones', () async {
    stubData({
      'appeals': [
        {
          'appealId': 'r_reporter',
          'reportId': 'r',
          'role': 'reporter',
          'decision': 'no_action',
          'text': 'Det bryter mot reglerna',
        },
        {'appealId': 'broken'},
      ],
    });

    final list = await service.listOpenAppeals();

    expect(list, hasLength(1));
    expect(list.single.appealId, 'r_reporter');
  });

  test(
    'getQuarantinedImages sends the appeal id and decodes the images',
    () async {
      stubData({
        'images': [
          {
            'contentType': 'image/png',
            'base64': base64Encode([1, 2, 3]),
          },
          {'contentType': 'image/png', 'base64': '%%not base64%%'},
          {'contentType': 'image/png'},
        ],
        'omitted': 2,
      });

      final result = await service.getQuarantinedImages('r_owner');

      expect(result.images, [
        [1, 2, 3],
      ]);
      expect(result.omitted, 2);
      verify(
        () => functions.httpsCallable(
          'getQuarantinedImages',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Map<dynamic, dynamic>>({
          'appealId': 'r_owner',
          'offset': 0,
        }),
      ).called(1);
    },
  );

  test(
    'getQuarantinedImages fetches every page, so the appeal can be granted',
    () async {
      Map<dynamic, dynamic> page(List<int> bytes, int? next) => {
        'images': [
          {'contentType': 'image/jpeg', 'base64': base64Encode(bytes)},
        ],
        'omitted': 1,
        'nextOffset': next,
      };
      when(() => callable.call<Map<dynamic, dynamic>>(any())).thenAnswer((
        invocation,
      ) async {
        final args =
            invocation.positionalArguments.first as Map<dynamic, dynamic>;
        final result = _MockResult();
        when(
          () => result.data,
        ).thenReturn(args['offset'] == 0 ? page([1], 1) : page([2], null));
        return result;
      });

      final result = await service.getQuarantinedImages('r_owner');

      expect(result.images, [
        [1],
        [2],
      ]);
      expect(result.omitted, 2);
      verify(
        () => callable.call<Map<dynamic, dynamic>>({
          'appealId': 'r_owner',
          'offset': 1,
        }),
      ).called(1);
    },
  );

  test('getQuarantinedImages tolerates a missing body', () async {
    stubData({});
    final result = await service.getQuarantinedImages('r_owner');
    expect(result.images, isEmpty);
    expect(result.omitted, 0);
  });

  const answerCases = <(String, String?, AnswerFailure)>[
    ('failed-precondition', 'appeal_not_open', AnswerFailure.alreadyAnswered),
    ('failed-precondition', 'something else', AnswerFailure.other),
    ('not-found', null, AnswerFailure.gone),
    ('permission-denied', null, AnswerFailure.other),
    ('unavailable', null, AnswerFailure.other),
  ];
  for (final (code, message, failure) in answerCases) {
    test('answerAppeal $code ${message ?? ''} maps to $failure', () async {
      when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(code: code, message: message ?? ''),
      );

      await expectLater(
        service.answerAppeal(appealId: 'a', outcome: AppealStatus.upheld),
        throwsA(
          isA<AnswerAppealException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
    });
  }

  test('answerAppeal sends the appeal id and the outcome key', () async {
    stubData({'ok': true});

    await service.answerAppeal(
      appealId: 'r_owner',
      outcome: AppealStatus.reversed,
    );

    verify(
      () => callable.call<Map<dynamic, dynamic>>({
        'appealId': 'r_owner',
        'outcome': 'reversed',
      }),
    ).called(1);
  });
}
