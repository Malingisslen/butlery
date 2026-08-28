/// Tests for `GroupWeeklyMenuPlanService`.
///
/// `getOrBuildWeek` must NOT persist an empty plan on cache miss; callers own
/// the write and bundle it with the first meaningful mutation. `save` must
/// propagate a refusal rather than swallowing it.
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
  // `getOrBuildWeek` goes through `executeServiceOperation`, whose auth
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

      final result = await service.getOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );

      // `same` is what proves the repo was actually consulted: a fabricated
      // empty plan would satisfy `result.groupId == groupId` just as well.
      expect(result, same(existing));
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

      final result = await service.getOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
        initialParticipants: [
          GroupMenuParticipant(
            userId: creatorId,
            permission: SharedListPermission.admin,
            addedAt: DateTime.now(),
          ),
        ],
      );

      expect(result.groupId, groupId);
      expect(result.participants, hasLength(1));
      expect(result.participants.single.userId, creatorId);

      // Critical contract: nothing was persisted. This is the whole point
      // of the rename from `getOrCreateWeek` — one Firestore write, not two.
      verifyNever(() => repo.save(any(), userId: any(named: 'userId')));
    });
  });
}
