// BUT-1517: the two admin pool callables and how their refusals are mapped.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/admin/pool_inspection.dart';
import 'package:butlery/services/moderation/pool_moderation_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

const _key = 'v1:0123456789abcdef';

void main() {
  late _MockCallable callable;
  late _MockFunctions functions;
  late PoolModerationService service;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    service = PoolModerationService(functions: functions);
  });

  void stubData(Map<dynamic, dynamic> data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenAnswer((_) async => result);
  }

  void stubFailure(String code) => when(
    () => callable.call<Map<dynamic, dynamic>>(any()),
  ).thenThrow(FirebaseFunctionsException(code: code, message: 'x'));

  test('inspect sends the key and parses the answer', () async {
    stubData({'poolKey': _key, 'count': 3});

    final p = await service.inspect(_key);

    verify(
      () => functions.httpsCallable(
        'adminInspectPool',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(
      () => callable.call<Map<dynamic, dynamic>>({'poolKey': _key}),
    ).called(1);
    expect(p.count, 3);
  });

  test('an answer that is no inspection is a failure', () async {
    stubData({'something': 'else'});

    await expectLater(
      service.inspect(_key),
      throwsA(
        isA<PoolModerationException>().having(
          (e) => e.failure,
          'failure',
          PoolModerationFailure.other,
        ),
      ),
    );
  });

  test('turning the rating off sends the reason code', () async {
    stubData({'ok': true});

    await service.setQuarantine(
      poolKey: _key,
      quarantined: true,
      reason: QuarantineReason.brigading,
    );

    verify(
      () => functions.httpsCallable(
        'adminSetPoolQuarantine',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(
      () => callable.call<Map<dynamic, dynamic>>({
        'poolKey': _key,
        'quarantined': true,
        'reasonCode': 'brigading',
      }),
    ).called(1);
  });

  test('turning it back on sends no reason code', () async {
    stubData({'ok': true});

    await service.setQuarantine(poolKey: _key, quarantined: false);

    verify(
      () => callable.call<Map<dynamic, dynamic>>({
        'poolKey': _key,
        'quarantined': false,
      }),
    ).called(1);
  });

  group('failure mapping', () {
    final cases = {
      'invalid-argument': PoolModerationFailure.invalidKey,
      'permission-denied': PoolModerationFailure.notAllowed,
      'unauthenticated': PoolModerationFailure.notAllowed,
      'resource-exhausted': PoolModerationFailure.rateLimited,
      'internal': PoolModerationFailure.other,
    };
    for (final entry in cases.entries) {
      test('${entry.key} on inspect and on change', () async {
        stubFailure(entry.key);

        await expectLater(
          service.inspect(_key),
          throwsA(
            isA<PoolModerationException>().having(
              (e) => e.failure,
              'failure',
              entry.value,
            ),
          ),
        );
        await expectLater(
          service.setQuarantine(poolKey: _key, quarantined: false),
          throwsA(
            isA<PoolModerationException>().having(
              (e) => e.failure,
              'failure',
              entry.value,
            ),
          ),
        );
      });
    }
  });
}
