/// Tests for `GroupWeeklyMenuPlanService`.
///
/// `readOrBuildWeek` must NOT persist an empty plan when the week has none —
/// callers own the write and bundle it with the first meaningful mutation.
/// `initialParticipants` decides the roster when supplied, and the creator
/// becomes sole admin when it is not. `save` must propagate a refusal rather
/// than swallowing it.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements GroupWeeklyMenuPlanRepository {}

class _FakeGroupPlan extends Fake implements GroupWeeklyMenuPlan {}

void main() {
  // `readOrBuildWeek` goes through `executeServiceOperation`, whose auth
  // pre-flight reads the PRODUCTION ServiceLocator. Without this harness the
  // pre-flight fails and the wrapped closure never runs.
  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeGroupPlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  group('GroupWeeklyMenuPlanService', () {
    late _MockRepo repo;
    late GroupWeeklyMenuPlanService service;

    const groupId = 'fam-abc';
    const creatorId = 'user-alpha';
    final date = DateTime(2026, 4, 15);

    setUp(() {
      repo = _MockRepo();
      (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
          .setAuthState(userId: creatorId);
      service = GroupWeeklyMenuPlanService(repository: repo);
    });

    // BUT-1962: `save` wrapped the repository in `executeServiceOperation`,
    // which answers a failure with a default instead of rethrowing. A refused
    // write therefore looked identical to a completed one. On the only live
    // caller — closing a meal poll — that burned a one-way close with the
    // winner never written into anyone's week.
    test('save propagates a refusal instead of swallowing it', () async {
      final plan = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );
      when(
        () => repo.save(any(), userId: any(named: 'userId')),
      ).thenThrow(StateError('refused by the repository'));

      await expectLater(
        service.save(plan: plan, actorId: creatorId),
        throwsA(isA<StateError>()),
      );
    });

    test('returns the existing plan when one is persisted for the ISO week, '
        'and does NOT issue a save() call', () async {
      final existing = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );
      when(
        () => repo.fetchForWeek(
          groupId: any(named: 'groupId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => existing);

      final read = await service.readOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );

      // `same` is what proves the repo was actually consulted: a fabricated
      // empty plan would satisfy `plan.groupId == groupId` just as well.
      expect(read.readFailed, isFalse);
      expect(read.plan, same(existing));
      verifyNever(() => repo.save(any(), userId: any(named: 'userId')));
    });

    test('builds an in-memory plan (does NOT persist) when no plan exists for '
        'the week — callers own the single downstream save', () async {
      when(
        () => repo.fetchForWeek(
          groupId: any(named: 'groupId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => null);

      final read = await service.readOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
        // Deliberately a participant `GroupWeeklyMenuPlan.empty` could not have
        // synthesised on its own: a different uid AND a non-admin permission.
        // Seeded with the creator-as-admin default instead, this assertion is
        // satisfied by the fallback too and proves nothing about the argument
        // ever reaching the model.
        initialParticipants: [
          GroupMenuParticipant(
            userId: 'user-beta',
            permission: SharedListPermission.edit,
            addedAt: DateTime.now(),
          ),
        ],
      );

      expect(read.readFailed, isFalse);
      final built = read.plan!;
      expect(built.groupId, groupId);
      expect(built.participants, hasLength(1));
      expect(built.participants.single.userId, 'user-beta');
      expect(built.participants.single.permission, SharedListPermission.edit);

      // Critical contract: nothing was persisted.
      verifyNever(() => repo.save(any(), userId: any(named: 'userId')));
    });

    test(
      'with no participants supplied, the creator is seeded as sole admin',
      () async {
        // Together with the supplied-participants case, these pin that the argument
        // decides the roster when given and the creator default fills in when
        // not — neither case can be satisfied by the other's outcome.
        when(
          () => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          ),
        ).thenAnswer((_) async => null);

        final read = await service.readOrBuildWeek(
          groupId: groupId,
          creatorId: creatorId,
          date: date,
        );

        expect(read.readFailed, isFalse);
        final built = read.plan!;
        expect(built.participants, hasLength(1));
        expect(built.participants.single.userId, creatorId);
        expect(
          built.participants.single.permission,
          SharedListPermission.admin,
        );
        verifyNever(() => repo.save(any(), userId: any(named: 'userId')));
      },
    );
  });
}
