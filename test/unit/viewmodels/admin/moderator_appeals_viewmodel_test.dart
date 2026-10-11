// BUT-2353: the moderator's appeal queue.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAppeals extends Mock implements ModerationAppealsService {}

OpenAppeal _appeal(String id) => OpenAppeal(
  appealId: id,
  reportId: 'r',
  role: AppealRole.owner,
  decision: ModeratorDecision.contentRemoved,
  text: 'x',
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(AppealStatus.upheld);
  });

  late _MockAppeals service;
  late ModeratorAppealsViewModel vm;

  setUp(() {
    service = _MockAppeals();
    vm = ModeratorAppealsViewModel(service: service);
  });

  test('load lists the open appeals; a failure is an error state', () async {
    when(
      () => service.listOpenAppeals(),
    ).thenAnswer((_) async => [_appeal('a'), _appeal('b')]);
    expect(await vm.load(), isTrue);
    expect(vm.appeals, hasLength(2));

    when(() => service.listOpenAppeals()).thenThrow(Exception('x'));
    expect(await vm.load(), isFalse);
    expect(vm.hasError, isTrue);
  });

  test('answering removes the appeal from the queue', () async {
    when(
      () => service.listOpenAppeals(),
    ).thenAnswer((_) async => [_appeal('a'), _appeal('b')]);
    when(
      () => service.answerAppeal(
        appealId: any(named: 'appealId'),
        outcome: any(named: 'outcome'),
      ),
    ).thenAnswer((_) async {});
    await vm.load();

    expect(
      await vm.answer(vm.appeals.first, AppealStatus.upheld),
      AppealAnswerOutcome.answered,
    );

    expect(vm.appeals.map((a) => a.appealId), ['b']);
    verify(
      () => service.answerAppeal(appealId: 'a', outcome: AppealStatus.upheld),
    ).called(1);
  });

  for (final failure in [AnswerFailure.alreadyAnswered, AnswerFailure.gone]) {
    test(
      '$failure removes the row and is reported as already answered',
      () async {
        when(
          () => service.listOpenAppeals(),
        ).thenAnswer((_) async => [_appeal('a'), _appeal('b')]);
        when(
          () => service.answerAppeal(
            appealId: any(named: 'appealId'),
            outcome: any(named: 'outcome'),
          ),
        ).thenThrow(AnswerAppealException(failure));
        await vm.load();

        expect(
          await vm.answer(vm.appeals.first, AppealStatus.upheld),
          AppealAnswerOutcome.alreadyAnswered,
        );
        expect(vm.appeals.map((a) => a.appealId), ['b']);
      },
    );
  }

  test('a refused service answer (other) leaves the row and fails', () async {
    when(
      () => service.listOpenAppeals(),
    ).thenAnswer((_) async => [_appeal('a')]);
    when(
      () => service.answerAppeal(
        appealId: any(named: 'appealId'),
        outcome: any(named: 'outcome'),
      ),
    ).thenThrow(const AnswerAppealException(AnswerFailure.other));
    await vm.load();

    expect(
      await vm.answer(vm.appeals.single, AppealStatus.upheld),
      AppealAnswerOutcome.failed,
    );
    expect(vm.appeals, hasLength(1));
  });

  test('a refused answer leaves the appeal in the queue', () async {
    when(
      () => service.listOpenAppeals(),
    ).thenAnswer((_) async => [_appeal('a')]);
    when(
      () => service.answerAppeal(
        appealId: any(named: 'appealId'),
        outcome: any(named: 'outcome'),
      ),
    ).thenThrow(Exception('denied'));
    await vm.load();

    expect(
      await vm.answer(vm.appeals.single, AppealStatus.reversed),
      AppealAnswerOutcome.failed,
    );
    expect(vm.appeals, hasLength(1));
  });
}
