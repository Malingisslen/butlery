// BUT-2329: the Sparade tab's stream, extend and release.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/freeze_result.dart';
import 'package:butlery/viewmodels/admin/moderator_frozen_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockReports extends Mock implements ReportService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

ReportEvidence _copy(String id) => ReportEvidence(
  reportId: id,
  outcome: EvidenceOutcome.captured,
  frozen: FrozenEvidence(
    reason: FreezeReason.police,
    until: DateTime.utc(2027, 10, 9),
  ),
);

void main() {
  setUpAll(BaseUnitTest.setupUnit);
  setUpAll(() => registerFallbackValue(FreezeAction.freeze));

  late _MockReports reports;
  late _MockAppeals appeals;
  late StreamController<List<ReportEvidence>> stream;
  late ModeratorFrozenViewModel vm;

  setUp(() {
    reports = _MockReports();
    appeals = _MockAppeals();
    stream = StreamController<List<ReportEvidence>>.broadcast();
    when(() => reports.watchFrozenEvidence()).thenAnswer((_) => stream.stream);
    when(
      () => reports.forgetReportEvidence(any(), round: any(named: 'round')),
    ).thenReturn(null);
    vm = ModeratorFrozenViewModel(
      reportService: reports,
      appealsService: appeals,
    );
  });

  tearDown(() async {
    vm.dispose();
    await stream.close();
  });

  test('subscribes once and holds what the stream sends', () async {
    vm.startListening();
    vm.startListening();
    expect(vm.hasLoaded, isFalse);
    stream.add([_copy('a'), _copy('b')]);
    await pumpEventQueue();
    expect(vm.hasLoaded, isTrue);
    expect(vm.items.map((e) => e.reportId), ['a', 'b']);
    verify(() => reports.watchFrozenEvidence()).called(1);
  });

  test(
    'a stream error becomes the error state and retry listens again',
    () async {
      vm.startListening();
      stream.addError(Exception('denied'));
      await pumpEventQueue();
      expect(vm.hasError, isTrue);
      vm.retry();
      expect(vm.hasError, isFalse);
      verify(() => reports.watchFrozenEvidence()).called(2);
    },
  );

  test('extend sends the reason and drops the cached copy', () async {
    when(
      () => appeals.freezeEvidence(
        'a',
        action: FreezeAction.extend,
        reason: FreezeReason.threat,
      ),
    ).thenAnswer(
      (_) async => FreezeOutcome(until: DateTime.utc(2028, 10, 9)),
    );
    final result = await vm.extend(_copy('a'), FreezeReason.threat);
    expect(result, isA<FreezeSucceeded>());
    expect(
      (result as FreezeSucceeded).outcome.until,
      DateTime.utc(2028, 10, 9),
    );
    verify(() => reports.forgetReportEvidence('a')).called(1);
  });

  test('release reports whether the copy was deleted', () async {
    when(
      () => appeals.freezeEvidence('a', action: FreezeAction.release),
    ).thenAnswer((_) async => const FreezeOutcome(deleted: true));
    final result = await vm.release(_copy('a'));
    expect((result as FreezeSucceeded).outcome.deleted, isTrue);
  });

  test('a refusal with a known block is a block, nothing else', () async {
    when(
      () => appeals.freezeEvidence(
        any(),
        action: any(named: 'action'),
        reason: any(named: 'reason'),
      ),
    ).thenThrow(const FreezeEvidenceException(FreezeBlock.atCap));
    final result = await vm.extend(_copy('a'), FreezeReason.police);
    expect(result, isA<FreezeBlocked>());
    expect((result as FreezeBlocked).block, FreezeBlock.atCap);
    // A refusal usually means the copy changed under the moderator, so the
    // cached copy is dropped just as after a success.
    verify(() => reports.forgetReportEvidence('a')).called(1);
  });

  test('any other failure is a failure and the cache is kept', () async {
    when(
      () => appeals.freezeEvidence(
        any(),
        action: any(named: 'action'),
        reason: any(named: 'reason'),
      ),
    ).thenThrow(Exception('network'));
    final result = await vm.release(_copy('a'));
    expect(result, isA<FreezeFailed>());
    verifyNever(
      () => reports.forgetReportEvidence(any(), round: any(named: 'round')),
    );
  });
}
