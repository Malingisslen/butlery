/// BUT-1928 PRODUCER coverage: the `readFailed` sentinel itself.
///
/// The consumer half (poll-close refusing to save on a failed read) is pinned
/// in the messaging suites against a stubbed `readWeek`. Nothing pinned the
/// side that MINTS the flag, so inverting the sentinel in either direction
/// stayed green. These tests enter the real wrapper, which means they need the
/// DI `ServiceLocator` wired with an authenticated `AuthRepository` — without
/// it `executeServiceOperation`'s auth pre-flight short-circuits and the
/// wrapped closure never runs.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockGroupRepo extends Mock implements GroupWeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

UserProfile _profile(String uid) => UserProfile(
  uid: uid,
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
);

void main() {
  // Wednesday of ISO week 16, 2026 — deliberately not a Monday, so the
  // normalization inside readWeek is exercised too.
  final date = DateTime(2026, 4, 15);
  final weekStart = DateTime(2026, 4, 13);

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  void authenticateAs(String? userId) {
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: userId);
  }

  group('WeeklyMenuPlanService.readWeek mints readFailed', () {
    late _MockRepo repo;
    late _MockUserService userService;
    late WeeklyMenuPlanService service;

    setUp(() {
      repo = _MockRepo();
      userService = _MockUserService();
      when(() => userService.currentUserProfile).thenReturn(_profile('u'));
      authenticateAs('u');
      service = WeeklyMenuPlanService(
        repository: repo,
        userService: userService,
      );
    });

    test('a throwing repository reports readFailed: true with an empty plan '
        '— the state the caller must refuse to save on', () async {
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenThrow(Exception('offline'));

      final read = await service.readWeek(date);

      expect(read.readFailed, isTrue);
      expect(read.plan.entries, isEmpty);
    });

    test('a persisted week reports readFailed: false and hands back THAT plan '
        '— not a rebuilt empty one', () async {
      final existing = WeeklyMenuPlan.empty(userId: 'u', date: weekStart)
          .copyWith(
            entries: [
              WeeklyMenuPlanEntry.create(
                day: DayOfWeek.tue,
                slot: MealSlot.middag,
                recipeId: 'r-1',
                recipeTitle: 'Köttbullar',
              ),
            ],
          );
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => existing);

      final read = await service.readWeek(date);

      expect(read.readFailed, isFalse);
      expect(read.plan, same(existing));
      verify(
        () => repo.fetchForWeek(userId: 'u', weekStart: weekStart),
      ).called(1);
    });

    test('a week with nothing saved reports readFailed: false with a built '
        'empty plan — a genuine empty week is still safe to save', () async {
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => null);

      final read = await service.readWeek(date);

      expect(read.readFailed, isFalse);
      expect(read.plan.entries, isEmpty);
      expect(read.plan.userId, 'u');
    });

    test('a failed auth pre-flight reports readFailed: true without ever '
        'reaching the repository', () async {
      authenticateAs(null);

      final read = await service.readWeek(date);

      expect(read.readFailed, isTrue);
      verifyNever(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      );
    });
  });

  group('GroupWeeklyMenuPlanService.readWeek mints readFailed', () {
    late _MockGroupRepo repo;
    late GroupWeeklyMenuPlanService service;

    const groupId = 'fam-abc';
    const creatorId = 'user-alpha';

    setUp(() {
      repo = _MockGroupRepo();
      authenticateAs(creatorId);
      service = GroupWeeklyMenuPlanService(repository: repo);
    });

    test(
      'a throwing repository reports readFailed: true with a null plan',
      () async {
        when(
          () => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          ),
        ).thenThrow(Exception('offline'));

        final read = await service.readWeek(groupId: groupId, date: date);

        expect(read.readFailed, isTrue);
        expect(read.plan, isNull);
      },
    );

    test(
      'a persisted week reports readFailed: false and hands back THAT plan',
      () async {
        final existing = GroupWeeklyMenuPlan.empty(
          groupId: groupId,
          creatorId: creatorId,
          date: weekStart,
        );
        when(
          () => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          ),
        ).thenAnswer((_) async => existing);

        final read = await service.readWeek(groupId: groupId, date: date);

        expect(read.readFailed, isFalse);
        expect(read.plan, same(existing));
        verify(
          () => repo.fetchForWeek(groupId: groupId, weekStart: weekStart),
        ).called(1);
      },
    );

    test(
      'a week with nothing saved reports readFailed: false with a null plan',
      () async {
        when(
          () => repo.fetchForWeek(
            groupId: any(named: 'groupId'),
            weekStart: any(named: 'weekStart'),
          ),
        ).thenAnswer((_) async => null);

        final read = await service.readWeek(groupId: groupId, date: date);

        expect(read.readFailed, isFalse);
        expect(read.plan, isNull);
      },
    );

    test('readOrBuildWeek refuses to build on a FAILED read — the whole point '
        'of BUT-1928, since the built plan carries the same doc id', () async {
      when(
        () => repo.fetchForWeek(
          groupId: any(named: 'groupId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenThrow(Exception('offline'));

      final read = await service.readOrBuildWeek(
        groupId: groupId,
        creatorId: creatorId,
        date: date,
      );

      expect(read.readFailed, isTrue);
      expect(read.plan, isNull);
    });

    test('readOrBuildWeek DOES build on a genuinely empty week', () async {
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
      expect(read.plan, isNotNull);
      expect(read.plan!.groupId, groupId);
    });
  });
}
