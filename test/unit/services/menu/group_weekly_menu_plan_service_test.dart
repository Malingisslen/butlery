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

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

Recipe _recipe(String id, String title) => Recipe(
  core: RecipeCore(
    id: id,
    title: title,
    description: '',
    ingredients: const ['x'],
    instructions: const ['y'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

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
    // write therefore looked identical to a completed one. On the meal-poll
    // close that burned a one-way close with the winner never written into
    // anyone's week.
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

  // BUT-1971. The trail is a reading aid, not evidence — but it has to record
  // the thing it claims to, and the undo path is the one the plan nearly left
  // out because it reached no mutator at all.
  group('the edit trail', () {
    late GroupWeeklyMenuPlanService service;
    const groupId = 'fam-trail';
    const alice = 'user-alice';
    const bob = 'user-bob';
    final date = DateTime(2026, 4, 15);

    setUp(() {
      service = GroupWeeklyMenuPlanService(repository: _MockRepo());
    });

    GroupWeeklyMenuPlan planWith(List<WeeklyMenuPlanEntry> entries) {
      return GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: alice,
        date: date,
      ).copyWith(entries: entries);
    }

    WeeklyMenuPlanEntry entry(String id, {String? proposedBy}) =>
        WeeklyMenuPlanEntry(
          id: id,
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'r-$id',
          recipeTitle: 'Linsgryta',
          proposedBy: proposedBy,
        );

    test('a removal records who did it and whose dish it was', () {
      final plan = planWith([entry('e1', proposedBy: bob)]);

      final updated = service.removeEntry(
        plan: plan,
        actorId: alice,
        entryId: 'e1',
      );

      expect(updated.editTrail, hasLength(1));
      final row = updated.editTrail.single;
      expect(row.actorId, alice);
      expect(
        row.subjectId,
        bob,
        reason: 'without the subject the Art. 15 export cannot find this row',
      );
      expect(row.entryId, 'e1');
      expect(row.action, 'removed');
    });

    // The path that reached no mutator before this change: the ViewModel
    // rebuilt the plan itself, so the trail would have carried every action
    // except an undo.
    test('an undo records itself', () {
      final removed = entry('e1', proposedBy: bob);
      final plan = planWith(const []);

      final updated = service.restoreEntry(
        plan: plan,
        actorId: alice,
        entry: removed,
      );

      expect(updated.entries.map((e) => e.id), ['e1']);
      expect(updated.editTrail.single.action, 'undone');
      expect(updated.editTrail.single.subjectId, bob);
    });

    // The discriminating control for the two above: a mutator that changes
    // nothing must not grow the trail, or every tap on an already-gone row
    // becomes a real write and the screen's save-skip stops working.
    test('a removal that changes nothing records nothing', () {
      final plan = planWith([entry('e1')]);

      final updated = service.removeEntry(
        plan: plan,
        actorId: alice,
        entryId: 'not-here',
      );

      expect(identical(updated, plan), isTrue);
      expect(updated.editTrail, isEmpty);
    });

    test('a restore of a dish already present records nothing', () {
      final present = entry('e1');
      final plan = planWith([present]);

      final updated = service.restoreEntry(
        plan: plan,
        actorId: alice,
        entry: present,
      );

      expect(identical(updated, plan), isTrue);
      expect(updated.editTrail, isEmpty);
    });

    // The one data-loss path in the whole provenance change. `copyWith` lists
    // every field explicitly rather than spreading `this`, so a field missing a
    // line there is dropped silently on every move — including on the dish that
    // gets pushed aside by a swap, which no other test reaches.
    test(
      'a move preserves provenance, including on the swapped-aside dish',
      () {
        final moved = WeeklyMenuPlanEntry(
          id: 'e1',
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'r1',
          recipeTitle: 'Linsgryta',
          proposedBy: alice,
          votedInBy: const [alice, bob],
        );
        final occupant = WeeklyMenuPlanEntry(
          id: 'e2',
          day: DayOfWeek.tue,
          slot: MealSlot.middag,
          recipeId: 'r2',
          recipeTitle: 'Ugnsbakad lax',
          proposedBy: bob,
          votedInBy: const [bob],
        );

        final updated = service.moveEntry(
          plan: planWith([moved, occupant]),
          actorId: alice,
          entryId: 'e1',
          toDay: DayOfWeek.tue,
          toSlot: MealSlot.middag,
        );

        final after = {for (final e in updated.entries) e.id: e};
        expect(after['e1']!.proposedBy, alice);
        expect(after['e1']!.votedInBy, [alice, bob]);
        expect(
          after['e2']!.day,
          DayOfWeek.mon,
          reason:
              'without this the swap branch can be deleted and the dish keeps '
              'its provenance for the wrong reason — never rebuilt at all',
        );
        expect(
          after['e2']!.proposedBy,
          bob,
          reason: 'the swapped-aside dish is rebuilt through copyWith too',
        );
        expect(after['e2']!.votedInBy, [bob]);
      },
    );

    // Nothing in the repo pinned any of this service's permission gates: they
    // could all be deleted and every suite stayed green. `firestore.rules`
    // refuses the write and the widget hides the control, so the harm is
    // bounded — but a client-side gate that nothing exercises is not a gate.
    test('a view-only member cannot add a dish', () {
      final viewer = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: alice,
        date: date,
        initialParticipants: [
          GroupMenuParticipant(
            userId: alice,
            permission: SharedListPermission.view,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(
        () => service.addEntry(
          plan: viewer,
          actorId: alice,
          day: DayOfWeek.wed,
          slot: MealSlot.middag,
          recipe: _recipe('r1', 'Linsgryta'),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a view-only member cannot restore a dish', () {
      final viewer = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: alice,
        date: date,
        initialParticipants: [
          GroupMenuParticipant(
            userId: alice,
            permission: SharedListPermission.view,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(
        () => service.restoreEntry(
          plan: viewer,
          actorId: alice,
          entry: entry('e1'),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    // `addEntry` had no coverage at all: the roster intersection, its editor
    // gate and the derived action could each be deleted with every suite green.
    // The hazard is live — a plan's roster is a snapshot from when the week was
    // built, so somebody who joined the group later can vote into a dish whose
    // uid no erasure query reaches, leaving it neither erasable nor
    // exportable.
    test('a vote from someone off the plan roster is not stored', () {
      final plan = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: alice,
        date: date,
        initialParticipants: [
          GroupMenuParticipant(
            userId: alice,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
          GroupMenuParticipant(
            userId: bob,
            permission: SharedListPermission.edit,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      final updated = service.addEntry(
        plan: plan,
        actorId: alice,
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipe: _recipe('r1', 'Linsgryta'),
        // Off-roster in BOTH positions: with an on-roster proposer the
        // proposer filter and a bare pass-through are the same literal, and
        // the mutant is analytically invisible.
        proposedBy: 'user-cara',
        votedInBy: const [alice, bob, 'user-cara'],
      );

      expect(
        updated.entries.single.votedInBy,
        [alice, bob],
        reason:
            'user-cara is not on this plan, so no erasure query can reach '
            'a uid stored for them',
      );
      expect(updated.entries.single.proposedBy, isNull);
      expect(
        updated.editTrail.single.subjectId,
        isNull,
        reason: 'the trail row derives its subject from the filtered value',
      );
    });

    // The control: without it, "always store nothing" satisfies the test above.
    test('votes from members on the roster are stored intact', () {
      final plan = GroupWeeklyMenuPlan.empty(
        groupId: groupId,
        creatorId: alice,
        date: date,
        initialParticipants: [
          GroupMenuParticipant(
            userId: alice,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
          GroupMenuParticipant(
            userId: bob,
            permission: SharedListPermission.edit,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      final updated = service.addEntry(
        plan: plan,
        actorId: alice,
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipe: _recipe('r1', 'Linsgryta'),
        proposedBy: alice,
        votedInBy: const [alice, bob],
      );

      expect(updated.entries.single.votedInBy, [alice, bob]);
      expect(updated.entries.single.proposedBy, alice);
      expect(updated.editTrail.single.action, 'pollWinner');
      expect(updated.editTrail.single.subjectId, alice);
      expect(updated.editTrail.single.entryId, updated.entries.single.id);
    });

    // The other half of the derived action.
    test('an add with no provenance records itself as a plain add', () {
      final updated = service.addEntry(
        plan: planWith(const []),
        actorId: alice,
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipe: _recipe('r1', 'Linsgryta'),
      );

      expect(updated.editTrail.single.action, 'added');
      expect(updated.entries.single.proposedBy, isNull);
    });

    test('the trail keeps the NEWEST 50 rows, not the oldest', () {
      var plan = planWith([]);
      for (var i = 0; i < 55; i++) {
        plan = plan.copyWith(entries: [entry('e$i')]);
        plan = service.removeEntry(
          plan: plan,
          actorId: alice,
          entryId: 'e$i',
        );
      }

      expect(plan.editTrail, hasLength(GroupWeeklyMenuPlan.maxEditTrailRows));
      expect(
        plan.editTrail.last.entryId,
        'e54',
        reason: 'pruning from the wrong end throws away what just happened',
      );
      expect(plan.editTrail.first.entryId, 'e5');
    });
  });
}
