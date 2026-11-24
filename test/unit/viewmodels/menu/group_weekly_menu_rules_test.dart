// Intention: a group's fixed days are SHOWN in the group week and nothing is
// written until someone picks a dish. The week reads the group document only
// when the flag is on and the conversation has a chat group; a pick lands on
// the chosen place through the real service (trail 'added', no proposer),
// leaves a place a peer filled meanwhile alone, and builds a week nobody has
// planned with every participant as editor and the builder as admin.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements GroupWeeklyMenuPlanRepository {}

class _MockRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUsers extends Mock implements UserService {}

class _FakePlan extends Fake implements GroupWeeklyMenuPlan {}

const _conversationId = 'conv-1';
const _me = 'user-me';
const _other = 'user-other';
final _week = DateTime.utc(2026, 9, 2);

Recipe _recipe() => Recipe(
  core: RecipeCore(
    id: 'r-tacos',
    title: 'Tacos',
    description: '',
    ingredients: const ['x'],
    instructions: const ['y'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

RecurringDayRule _tacosFriday({bool paused = false}) {
  final rule = RecurringDayRule.create(
    day: DayOfWeek.fri,
    meal: MealSlot.middag,
    food: RecurringFood.tacos,
  );
  return paused ? rule.copyWith(paused: true) : rule;
}

ChatGroup _group(List<RecurringDayRule> rules) => ChatGroup(
  id: 'cg1',
  name: 'Familjen',
  memberIds: const [_me, _other],
  adminIds: const [_me],
  memberDisplayNames: const {},
  memberAvatarUrls: const {},
  conversationId: _conversationId,
  createdBy: _me,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  recurringDayRules: rules,
);

GroupWeeklyMenuPlan _plan({
  SharedListPermission permission = SharedListPermission.edit,
  List<WeeklyMenuPlanEntry> entries = const [],
}) => GroupWeeklyMenuPlan.empty(
  groupId: _conversationId,
  creatorId: _me,
  date: _week,
  initialParticipants: [
    GroupMenuParticipant(
      userId: _me,
      permission: permission,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
).copyWith(entries: entries);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakePlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  late _MockRepo plans;
  late MockChatGroupRepository groups;
  late StreamController<ChatGroup?> groupStream;
  late GroupWeeklyMenuViewModel vm;

  setUp(() {
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: _me);
    plans = _MockRepo();
    groups = MockChatGroupRepository();
    groupStream = StreamController<ChatGroup?>.broadcast();
    when(() => groups.watchGroup('cg1')).thenAnswer((_) => groupStream.stream);
    when(() => plans.save(any(), userId: any(named: 'userId'))).thenAnswer(
      (
        _,
      ) async {},
    );
    final realtime = _MockRealtime();
    when(
      () => realtime.subscribe(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
        onUpdate: any(named: 'onUpdate'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer(
      (_) => const Stream<GroupWeeklyMenuPlan?>.empty().listen(null),
    );
    final users = _MockUsers();
    when(() => users.getUserProfiles(any())).thenAnswer(
      (_) async => const ProfileBatchLookup(
        profiles: [],
        missingIds: {},
        unavailableIds: {},
      ),
    );
    _makeVm =
        ({
          String? chatGroupId = 'cg1',
          bool rulesEnabled = true,
        }) => vm = GroupWeeklyMenuViewModel(
          service: GroupWeeklyMenuPlanService(repository: plans),
          realtime: realtime,
          userService: users,
          groupId: _conversationId,
          currentUserId: _me,
          chatGroupId: chatGroupId,
          participantIds: const [_me, _other],
          chatGroupRepository: groups,
          rulesEnabled: rulesEnabled,
        );
  });

  tearDown(() async {
    vm.dispose();
    await groupStream.close();
  });

  void stubWeek(GroupWeeklyMenuPlan? plan) => when(
    () => plans.fetchForWeek(
      groupId: any(named: 'groupId'),
      weekStart: any(named: 'weekStart'),
    ),
  ).thenAnswer((_) async => plan);

  Future<void> load() async {
    await vm.loadWeek(_week);
    await Future<void>.delayed(Duration.zero);
  }

  group('reading the rules', () {
    test('no chat group: the group document is never read', () async {
      stubWeek(_plan());
      _makeVm(chatGroupId: null);
      await load();

      expect(vm.rules.active, isFalse);
      verifyNever(() => groups.watchGroup(any()));
    });

    test('flag off: the group document is never read', () async {
      stubWeek(_plan());
      _makeVm(rulesEnabled: false);
      await load();

      expect(vm.rules.active, isFalse);
      verifyNever(() => groups.watchGroup(any()));
    });

    test(
      'flag on: one watch, the active rule marks its place and day',
      () async {
        stubWeek(_plan());
        _makeVm();
        await load();
        groupStream.add(_group([_tacosFriday(), _tacosFriday(paused: true)]));
        await Future<void>.delayed(Duration.zero);

        verify(() => groups.watchGroup('cg1')).called(1);
        expect(vm.rules.ruleFor(DayOfWeek.fri, MealSlot.middag), isNotNull);
        expect(vm.rules.ruleFor(DayOfWeek.fri, MealSlot.lunch), isNull);
        expect(vm.rules.ruleDays, {DayOfWeek.fri});
        expect(vm.rules.isGroupAdmin(_me), isTrue);
        expect(vm.rules.isGroupAdmin(_other), isFalse);
      },
    );

    test('a paused rule marks nothing', () async {
      stubWeek(_plan());
      _makeVm();
      await load();
      groupStream.add(_group([_tacosFriday(paused: true)]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.rules.ruleDays, isEmpty);
      expect(vm.rules.ruleFor(DayOfWeek.fri, MealSlot.middag), isNull);
    });

    test('an empty week still shows the grid when a rule is active', () async {
      stubWeek(_plan());
      _makeVm();
      await load();
      expect(vm.isEmptyWeek, isTrue);

      groupStream.add(_group([_tacosFriday()]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.isEmptyWeek, isFalse);
    });
  });

  group('addDish', () {
    test('writes the dish on the place, trail "added", no proposer', () async {
      stubWeek(_plan());
      _makeVm();
      await load();

      final ok = await vm.addDish(
        day: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipe: _recipe(),
      );

      expect(ok, isTrue);
      final saved =
          verify(() => plans.save(captureAny(), userId: _me)).captured.single
              as GroupWeeklyMenuPlan;
      final entry = saved.entries.single;
      expect(entry.day, DayOfWeek.fri);
      expect(entry.slot, MealSlot.middag);
      expect(entry.recipeTitle, 'Tacos');
      expect(entry.proposedBy, isNull);
      expect(saved.editTrail.last.action, 'added');
    });

    test(
      'a place a peer filled meanwhile is left alone, nothing written',
      () async {
        final taken = WeeklyMenuPlanEntry.create(
          day: DayOfWeek.fri,
          slot: MealSlot.middag,
          recipeId: 'r-soup',
          recipeTitle: 'Soppa',
        );
        stubWeek(_plan(entries: [taken]));
        _makeVm();
        await load();

        final ok = await vm.addDish(
          day: DayOfWeek.fri,
          slot: MealSlot.middag,
          recipe: _recipe(),
        );

        expect(ok, isTrue);
        verifyNever(() => plans.save(any(), userId: any(named: 'userId')));
        expect(vm.plan!.entries.single.recipeTitle, 'Soppa');
      },
    );

    test('a viewer cannot add: refused, nothing written', () async {
      stubWeek(_plan(permission: SharedListPermission.view));
      _makeVm();
      await load();

      expect(vm.canPickForRule, isFalse);
      final ok = await vm.addDish(
        day: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipe: _recipe(),
      );

      expect(ok, isFalse);
      expect(vm.editNotice, GroupMenuEditProblem.notAnEditor);
      verifyNever(() => plans.save(any(), userId: any(named: 'userId')));
    });

    test(
      'a week nobody planned is built: participants edit, builder admin',
      () async {
        stubWeek(null);
        _makeVm();
        await load();
        expect(vm.canPickForRule, isTrue);

        final ok = await vm.addDish(
          day: DayOfWeek.fri,
          slot: MealSlot.middag,
          recipe: _recipe(),
        );

        expect(ok, isTrue);
        final saved =
            verify(() => plans.save(captureAny(), userId: _me)).captured.single
                as GroupWeeklyMenuPlan;
        expect(saved.id, 'conv-1_2026-W36');
        expect(
          saved.participantFor(_me)!.permission,
          SharedListPermission.admin,
        );
        expect(
          saved.participantFor(_other)!.permission,
          SharedListPermission.edit,
        );
        expect(saved.entries.single.recipeTitle, 'Tacos');
      },
    );

    test('a week that could not be read is never built over', () async {
      when(
        () => plans.fetchForWeek(
          groupId: any(named: 'groupId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenThrow(StateError('offline'));
      _makeVm();
      await load();

      final ok = await vm.addDish(
        day: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipe: _recipe(),
      );

      expect(ok, isFalse);
      verifyNever(() => plans.save(any(), userId: any(named: 'userId')));
    });

    test('övrigt takes no fixed-day pick', () async {
      stubWeek(_plan());
      _makeVm();
      await load();

      expect(
        await vm.addDish(
          day: DayOfWeek.fri,
          slot: MealSlot.ovrigt,
          recipe: _recipe(),
        ),
        isFalse,
      );
      verifyNever(() => plans.save(any(), userId: any(named: 'userId')));
    });
  });
}

late GroupWeeklyMenuViewModel Function({
  String? chatGroupId,
  bool rulesEnabled,
})
_makeVm;
