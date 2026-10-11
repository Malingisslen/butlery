/// BUT-2289: a week save from outside the calendar returns once Firestore has
/// it on the device, and a conflict reported after that still reaches the
/// week menu instead of the log.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

WeeklyMenuPlan _week(String revId) => WeeklyMenuPlan(
  id: 'u_2026-W42',
  userId: 'u',
  weekStartDate: DateTime(2026, 10, 12),
  entries: const [],
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  revId: revId,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeWeeklyMenuPlan()));

  late _MockRepo repo;
  late WeeklyMenuPlanService service;
  late Completer<void> serverAnswer;

  setUp(() {
    repo = _MockRepo();
    service = WeeklyMenuPlanService(
      repository: repo,
      userService: _MockUserService(),
    );
  });

  // Created inside each fakeAsync zone: a future made outside it settles on
  // the real microtask queue, which flushMicrotasks never reaches.
  void serverNeverAnswersYet() {
    serverAnswer = Completer<void>();
    when(() => repo.save(any())).thenAnswer((_) => serverAnswer.future);
  }

  test('save returns after the patience when the server never answers, and '
      'tells weekWrites', () {
    fakeAsync((async) {
      serverNeverAnswersYet();
      final written = <String?>[];
      service.weekWrites.listen(written.add);
      var returned = false;
      service.save(_week('rev-1')).then((_) => returned = true);

      async.elapse(queuedWritePatience - const Duration(milliseconds: 1));
      expect(returned, isFalse);
      async.elapse(const Duration(milliseconds: 1));
      expect(returned, isTrue);
      expect(written, ['u_2026-W42']);
    });
  });

  test('saveRevisionQueued returns after the patience', () {
    fakeAsync((async) {
      serverNeverAnswersYet();
      var returned = false;
      service
          .saveRevisionQueued(_week('rev-1').nextRevision())
          .then((_) => returned = true);
      async.elapse(queuedWritePatience);
      expect(returned, isTrue);
    });
  });

  test('a conflict inside the patience is thrown to the caller, not put on '
      'lateConflicts', () {
    fakeAsync((async) {
      serverNeverAnswersYet();
      final late = <Object>[];
      service.lateConflicts.listen(late.add);
      Object? thrown;
      service.save(_week('rev-1')).catchError((Object e) => thrown = e);

      serverAnswer.completeError(WeekPlanConflictException(_week('rev-other')));
      async.flushMicrotasks();

      expect(thrown, isA<WeekPlanConflictException>());
      expect(late, isEmpty);
    });
  });

  test('a conflict after the patience goes to lateConflicts with the week '
      'that was sent', () {
    fakeAsync((async) {
      serverNeverAnswersYet();
      final late = <LateWeekConflict>[];
      service.lateConflicts.listen(late.add);
      Object? thrown;
      service.save(_week('rev-1')).catchError((Object e) => thrown = e);
      async.elapse(queuedWritePatience);

      final remote = _week('rev-other');
      serverAnswer.completeError(WeekPlanConflictException(remote));
      async.flushMicrotasks();

      expect(thrown, isNull);
      expect(late, hasLength(1));
      final sent =
          verify(() => repo.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(late.single.sent, same(sent));
      expect(late.single.remote, same(remote));
    });
  });

  test(
    'any other refusal after the patience is not reported as a conflict',
    () {
      fakeAsync((async) {
        serverNeverAnswersYet();
        final late = <Object>[];
        service.lateConflicts.listen(late.add);
        Object? thrown;
        service.save(_week('rev-1')).catchError((Object e) => thrown = e);
        async.elapse(queuedWritePatience);

        serverAnswer.completeError(StateError('permission-denied'));
        async.flushMicrotasks();

        expect(thrown, isNull);
        expect(late, isEmpty);
      });
    },
  );
}
