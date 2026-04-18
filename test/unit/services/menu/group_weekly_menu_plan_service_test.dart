/// Tests for `GroupWeeklyMenuPlanService` — focused on the fetch-or-build
/// contract. `getOrBuildWeek` must NOT persist an empty plan on cache miss;
/// callers own the write and bundle it with the first meaningful mutation.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';

class _MockRepo extends Mock implements GroupWeeklyMenuPlanRepository {}

class _FakeGroupPlan extends Fake implements GroupWeeklyMenuPlan {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeGroupPlan());
  });

  group('GroupWeeklyMenuPlanService.getOrBuildWeek', () {
    late _MockRepo repo;
    late GroupWeeklyMenuPlanService service;

    const groupId = 'fam-abc';
    const creatorId = 'user-alpha';
    final date = DateTime(2026, 4, 15);

    setUp(() {
      repo = _MockRepo();
      service = GroupWeeklyMenuPlanService(repository: repo);
    });

    test(
        'returns the existing plan when one is persisted for the ISO week, '
        'and does NOT issue a save() call', () async {
      final existing = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );
      when(() => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => existing);

      final result = await service.getOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );

      expect(result.groupId, groupId);
      verifyNever(() => repo.save(any(), userId: any(named: 'userId')));
    });

    test(
        'builds an in-memory plan (does NOT persist) when no plan exists for '
        'the week — callers own the single downstream save', () async {
      when(() => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => null);

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
