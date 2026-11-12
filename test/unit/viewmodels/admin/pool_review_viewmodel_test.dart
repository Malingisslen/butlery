// BUT-1517: the "Betyg" tab's lookup and quarantine changes.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/admin/pool_inspection.dart';
import 'package:butlery/services/moderation/pool_moderation_service.dart';
import 'package:butlery/viewmodels/admin/pool_review_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements PoolModerationService {}

const _key = 'v1:0123456789abcdef';

PoolInspection _pool({bool quarantined = false, int count = 10}) =>
    PoolInspection(
      poolKey: _key,
      quarantined: quarantined,
      reason: quarantined ? QuarantineReason.brigading : null,
      count: count,
      average: 4.5,
      distribution: const [0, 0, 1, 4, 5],
      votes24h: 2,
      votes7d: 6,
      sampled: 10,
      youngAccountShare: 0.1,
      unverifiedShare: 0.2,
    );

void main() {
  setUpAll(BaseUnitTest.setupUnit);

  late _MockService service;
  late PoolReviewViewModel vm;

  setUp(() {
    service = _MockService();
    vm = PoolReviewViewModel(service: service);
  });

  tearDown(() => vm.dispose());

  group('load', () {
    test('a key of the wrong shape is refused without a call', () async {
      expect(await vm.load('v1:XYZ'), isFalse);

      expect(vm.failure, PoolModerationFailure.invalidKey);
      verifyNever(() => service.inspect(any()));
    });

    test('a good key is trimmed and read', () async {
      when(() => service.inspect(_key)).thenAnswer((_) async => _pool());

      expect(await vm.load('  $_key \n'), isTrue);

      expect(vm.inspection?.count, 10);
      expect(vm.failure, isNull);
    });

    test('a refusal keeps its kind and shows no old numbers', () async {
      when(() => service.inspect(_key)).thenAnswer((_) async => _pool());
      await vm.load(_key);
      when(() => service.inspect(_key)).thenThrow(
        const PoolModerationException(PoolModerationFailure.notAllowed),
      );

      expect(await vm.load(_key), isFalse);

      expect(vm.failure, PoolModerationFailure.notAllowed);
      expect(vm.inspection, isNull);
    });

    test('any other read error is a generic failure, never a blank', () async {
      when(() => service.inspect(_key)).thenThrow(Exception('boom'));

      expect(await vm.load(_key), isFalse);

      expect(vm.failure, PoolModerationFailure.other);
      expect(vm.inspection, isNull);
    });
  });

  group('changing the quarantine', () {
    setUp(() async {
      when(() => service.inspect(_key)).thenAnswer((_) async => _pool());
      await vm.load(_key);
    });

    test('sends the reason and then reads the numbers again', () async {
      when(
        () => service.setQuarantine(
          poolKey: _key,
          quarantined: true,
          reason: QuarantineReason.badMerge,
        ),
      ).thenAnswer((_) async {});
      when(
        () => service.inspect(_key),
      ).thenAnswer((_) async => _pool(quarantined: true, count: 11));

      expect(await vm.quarantine(QuarantineReason.badMerge), isTrue);

      expect(vm.inspection?.quarantined, isTrue);
      expect(vm.inspection?.count, 11);
      verify(() => service.inspect(_key)).called(2);
    });

    test('turning it back on sends quarantined false and reloads', () async {
      when(
        () => service.setQuarantine(poolKey: _key, quarantined: false),
      ).thenAnswer((_) async {});

      expect(await vm.lift(), isTrue);

      verify(
        () => service.setQuarantine(poolKey: _key, quarantined: false),
      ).called(1);
      verify(() => service.inspect(_key)).called(2);
    });

    test('a refused change keeps the numbers and does not reload', () async {
      when(
        () => service.setQuarantine(
          poolKey: any(named: 'poolKey'),
          quarantined: any(named: 'quarantined'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        const PoolModerationException(PoolModerationFailure.rateLimited),
      );

      expect(await vm.quarantine(QuarantineReason.other), isFalse);

      expect(vm.failure, PoolModerationFailure.rateLimited);
      expect(vm.inspection?.count, 10);
      expect(vm.isChanging, isFalse);
      verify(() => service.inspect(_key)).called(1);
    });

    test('an unexpected error is a generic failure', () async {
      when(
        () => service.setQuarantine(
          poolKey: any(named: 'poolKey'),
          quarantined: any(named: 'quarantined'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(Exception('boom'));

      expect(await vm.quarantine(QuarantineReason.other), isFalse);
      expect(vm.failure, PoolModerationFailure.other);
    });
  });

  test('nothing is changed before a pool has been read', () async {
    expect(await vm.lift(), isFalse);
    verifyNever(
      () => service.setQuarantine(
        poolKey: any(named: 'poolKey'),
        quarantined: any(named: 'quarantined'),
        reason: any(named: 'reason'),
      ),
    );
  });
}
