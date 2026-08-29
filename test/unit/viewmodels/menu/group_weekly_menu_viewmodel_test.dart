/// Tests for `GroupWeeklyMenuViewModel` (BUT-1971).
///
/// The product condition BUT-1971 was bound by: a permission refusal and a
/// transient outage must be DISTINGUISHABLE, because the screen offers a retry
/// on one and not the other. Both directions are pinned here.
///
/// The write path inherits BUT-1975's shape: publish, then persist.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';

class _MockService extends Mock implements GroupWeeklyMenuPlanService {}

class _MockRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUserService extends Mock implements UserService {}

class _FakePlan extends Fake implements GroupWeeklyMenuPlan {}

/// A week whose `copyWith` throws, so the undo's closure dies BEFORE `_edit`
/// publishes anything and the edit counter never moves.
class _CopyWithThrowsPlan extends Mock implements GroupWeeklyMenuPlan {}

/// Delegating subscription that records its own cancellation.
///
/// `stream.hasListener` cannot see a re-subscribe leak: the replacement
/// listener keeps the broadcast controller busy either way.
class _CountingSubscription
    implements StreamSubscription<GroupWeeklyMenuPlan?> {
  final StreamSubscription<GroupWeeklyMenuPlan?> _inner;
  bool cancelled = false;

  _CountingSubscription(this._inner);

  @override
  Future<void> cancel() {
    cancelled = true;
    return _inner.cancel();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _groupId = 'group-1';
const _alice = 'user-alice';
final _week = DateTime.utc(2026, 9, 2);

GroupWeeklyMenuPlan _plan({
  List<WeeklyMenuPlanEntry> entries = const [],
  SharedListPermission permission = SharedListPermission.edit,
}) {
  final base = GroupWeeklyMenuPlan.empty(
    groupId: _groupId,
    creatorId: _alice,
    date: _week,
    initialParticipants: [
      GroupMenuParticipant(
        userId: _alice,
        permission: permission,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  return base.copyWith(entries: entries);
}

WeeklyMenuPlanEntry _entry(String id, {MealSlot slot = MealSlot.middag}) =>
    WeeklyMenuPlanEntry(
      id: id,
      day: DayOfWeek.mon,
      slot: slot,
      recipeId: 'r-$id',
      recipeTitle: 'Linsgryta',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePlan());
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  late _MockService service;
  late _MockRealtime realtime;
  late _MockUserService userService;
  late StreamController<GroupWeeklyMenuPlan?> stream;
  late List<_CountingSubscription> subscriptions;
  late GroupWeeklyMenuViewModel vm;
  // One test disposes the viewmodel as its subject; ChangeNotifier throws on a
  // second dispose, which would fail that test in tearDown after it passed.
  var disposedByTest = false;

  setUp(() {
    disposedByTest = false;
    service = _MockService();
    realtime = _MockRealtime();
    userService = _MockUserService();
    when(() => userService.getUserProfiles(any())).thenAnswer((_) async => []);
    stream = StreamController<GroupWeeklyMenuPlan?>.broadcast();
    subscriptions = [];

    when(
      () => realtime.subscribe(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
        onUpdate: any(named: 'onUpdate'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((invocation) {
      final onUpdate =
          invocation.namedArguments[#onUpdate]
              as void Function(GroupWeeklyMenuPlan?);
      final onError =
          invocation.namedArguments[#onError] as void Function(Object)?;
      final sub = _CountingSubscription(
        stream.stream.listen(onUpdate, onError: onError),
      );
      subscriptions.add(sub);
      return sub;
    });

    vm = GroupWeeklyMenuViewModel(
      service: service,
      realtime: realtime,
      userService: userService,
      groupId: _groupId,
      currentUserId: _alice,
    );
  });

  tearDown(() async {
    if (!disposedByTest) vm.dispose();
    await stream.close();
  });

  void stubRead(GroupWeeklyMenuPlan? plan, {bool readFailed = false}) {
    when(
      () => service.readWeek(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => GroupWeeklyMenuPlanRead(plan: plan, readFailed: readFailed),
    );
  }

  group('a refusal and an outage are different screens', () {
    test('a permission-denied stream error is NOT transient', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);

      stream.addError(
        FirebaseException(plugin: 'x', code: 'permission-denied'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.failure, GroupMenuFailure.permissionDenied);
    });

    test('the project exception classifies the same way', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);

      stream.addError(PermissionDeniedException('nope'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.failure, GroupMenuFailure.permissionDenied);
    });

    // The discriminating control for the two cases above ('a permission-denied
    // stream error is NOT transient' and 'the project exception classifies the
    // same way'): same delivery path, same shape of error, differing ONLY in
    // the code. Without it both would pass on a classifier that answered
    // `permissionDenied` unconditionally.
    test('any other stream error IS transient', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);

      stream.addError(FirebaseException(plugin: 'x', code: 'unavailable'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.failure, GroupMenuFailure.transient);
    });

    test('a failed read is transient, not a refusal', () async {
      stubRead(null, readFailed: true);
      await vm.loadWeek(_week);

      expect(vm.failure, GroupMenuFailure.transient);
      expect(vm.plan, isNull);
      // A failed read is not an empty week: `isEmptyWeek` carries the
      // `_failure == none` conjunct precisely so the two cannot be confused.
      expect(vm.isEmptyWeek, isFalse);
    });
  });

  group('reading the week', () {
    test('an empty week is not a failure', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);

      expect(vm.failure, GroupMenuFailure.none);
      expect(vm.isEmptyWeek, isTrue);
    });

    test('a week with entries is not empty', () async {
      stubRead(_plan(entries: [_entry('e1')]));
      await vm.loadWeek(_week);

      expect(vm.isEmptyWeek, isFalse);
      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
      expect(vm.entriesFor(DayOfWeek.tue), isEmpty);
    });

    test('a day with two meals comes back in MealSlot order', () async {
      stubRead(
        _plan(
          entries: [
            _entry('lunch', slot: MealSlot.lunch),
            _entry('middag'),
          ],
        ),
      );
      await vm.loadWeek(_week);

      expect(
        vm.entriesFor(DayOfWeek.mon).map((e) => e.slot),
        [MealSlot.lunch, MealSlot.middag],
        reason:
            'the enum declares lunch before middag, and the getter sorts '
            'on that index',
      );
    });
  });

  group('editing', () {
    test('the edit is on screen before the save completes', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));

      // A save that never acks — the offline shape measured in BUT-1975.
      final never = Completer<void>();
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) => never.future);

      unawaited(vm.removeEntry('e1'));
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.entriesFor(DayOfWeek.mon),
        isEmpty,
        reason: 'the removal must be visible without waiting for the server',
      );
    });

    test('a refused save rolls the week back and does NOT blank it', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenThrow(PermissionDeniedException('not an editor'));

      final ok = await vm.removeEntry('e1');

      expect(ok, isFalse);
      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
      expect(vm.editNotice, GroupMenuEditProblem.notAnEditor);
      expect(vm.failure, GroupMenuFailure.none);
    });

    test('a viewer is refused before anything is published', () async {
      final loaded = _plan(
        entries: [_entry('e1')],
        permission: SharedListPermission.view,
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenThrow(PermissionDeniedException('view only'));

      final ok = await vm.removeEntry('e1');

      expect(ok, isFalse);
      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
      expect(vm.editNotice, GroupMenuEditProblem.notAnEditor);
      verifyNever(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    });

    test('canEdit follows the participant permission', () async {
      stubRead(_plan(permission: SharedListPermission.view));
      await vm.loadWeek(_week);
      expect(vm.canEdit, isFalse);

      stubRead(_plan(permission: SharedListPermission.edit));
      await vm.loadWeek(_week);
      expect(vm.canEdit, isTrue);
    });
  });

  group('undoing a removal', () {
    void stubRemoveAndSave(GroupWeeklyMenuPlan loaded) {
      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        return loaded.copyWith(
          entries: loaded.entries.where((e) => e.id != id).toList(),
        );
      });
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});
    }

    test('puts the dish back on the same week', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      stubRemoveAndSave(loaded);

      await vm.removeEntry('e1');
      expect(vm.entriesFor(DayOfWeek.mon), isEmpty);

      expect(await vm.undoLastRemoval(), isTrue);
      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
    });

    // The plan's document id derives from its OWN weekStartDate, so an undo
    // taken after the arrows would write a pre-removal snapshot of the old week
    // over whatever anyone else had put there since.
    test('refuses once the screen has moved to another week', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      stubRemoveAndSave(loaded);

      await vm.removeEntry('e1');
      clearInteractions(service);
      stubRead(
        GroupWeeklyMenuPlan.empty(
          groupId: _groupId,
          creatorId: _alice,
          date: _week.add(const Duration(days: 7)),
        ),
      );
      await vm.goToNextWeek();

      expect(vm.canUndoRemoval, isFalse);
      expect(await vm.undoLastRemoval(), isFalse);
      verifyNever(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    });

    test('the newest removal is the one the undo puts back', () async {
      final loaded = _plan(
        entries: [
          _entry('e1'),
          _entry('e2', slot: MealSlot.lunch),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      final saveGate = Completer<void>();
      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        return (vm.plan ?? loaded).copyWith(
          entries: (vm.plan ?? loaded).entries
              .where((e) => e.id != id)
              .toList(),
        );
      });
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) => saveGate.future);

      final first = vm.removeEntry('e1');
      await Future<void>.delayed(Duration.zero);
      // A second removal publishes while the first is still saving.
      final second = vm.removeEntry('e2');
      saveGate.complete();
      await first;
      await second;

      // Both removals resolve after the gate opens, so the FIRST one's trailing
      // arm runs with a later edit already published.
      expect(await vm.undoLastRemoval(), isTrue);
      final ids = vm.entriesFor(DayOfWeek.mon).map((e) => e.id).toList();
      expect(ids, ['e2'], reason: 'only the last removal is undone');
    });
  });

  group('undo and a peer', () {
    // A dish that arrives meanwhile must survive, and the meal-poll close that
    // writes one is a one-way door (BUT-1928) — it could not be written again.
    test('a dish that arrived meanwhile survives the undo', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('e1');

      // A peer's poll close lands between the removal and the undo, on the
      // day's other meal so both can legitimately coexist.
      stream.add(_plan(entries: [_entry('poll-winner', slot: MealSlot.lunch)]));
      await Future<void>.delayed(Duration.zero);

      expect(await vm.undoLastRemoval(), isTrue);

      final ids = vm.entriesFor(DayOfWeek.mon).map((e) => e.id).toSet();
      expect(ids, {'e1', 'poll-winner'});

      final saved = verify(
        () => service.save(
          plan: captureAny(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).captured.cast<GroupWeeklyMenuPlan>();
      expect(
        saved.last.entries.map((e) => e.id).toSet(),
        {'e1', 'poll-winner'},
        reason:
            "the peer's dish must reach the document too, not just the "
            'screen',
      );
    });

    test('a refused undo says so instead of doing nothing', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('e1');
      stubRead(
        GroupWeeklyMenuPlan.empty(
          groupId: _groupId,
          creatorId: _alice,
          date: _week.add(const Duration(days: 7)),
        ),
      );
      await vm.goToNextWeek();

      expect(await vm.undoLastRemoval(), isFalse);
      expect(vm.editNotice, GroupMenuEditProblem.undoUnavailable);
    });
  });

  group('undo and the single-occupancy rule', () {
    Future<void> removeThen(GroupWeeklyMenuPlan loaded, String id) async {
      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(
        loaded.copyWith(
          entries: loaded.entries.where((e) => e.id != id).toList(),
        ),
      );
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});
      await vm.removeEntry(id);
    }

    // Appending beside the peer's dish would put two entries in one middag —
    // a state no other path can create, and one the NEXT add deletes both
    // halves of, because `addEntry` clears the slot first.
    test('refuses when a peer has refilled the same slot', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      await removeThen(loaded, 'e1');

      stream.add(_plan(entries: [_entry('peer')]));
      await Future<void>.delayed(Duration.zero);

      expect(await vm.undoLastRemoval(), isFalse);
      expect(vm.editNotice, GroupMenuEditProblem.undoUnavailable);
      expect(
        vm.entriesFor(DayOfWeek.mon).map((e) => e.id),
        ['peer'],
        reason: 'one middag holds one dish',
      );
    });

    // The undo owns ONE dish, not the diff against the week: a dish a peer
    // deleted in the meantime must stay deleted.
    test('does not resurrect a dish someone else deleted', () async {
      final loaded = _plan(
        entries: [
          _entry('e1'),
          _entry('e2', slot: MealSlot.lunch),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);
      await removeThen(loaded, 'e1');

      // The peer drops e2, which this removal never touched.
      stream.add(_plan(entries: const []));
      await Future<void>.delayed(Duration.zero);

      expect(await vm.undoLastRemoval(), isTrue);
      expect(vm.entriesFor(DayOfWeek.mon).map((e) => e.id), ['e1']);
    });
  });

  group('undo is idempotent on a multi slot', () {
    // `ovrigt` holds several dishes, so the occupancy refusal does not apply and
    // the restore really can append. If the peer's snapshot already brought the
    // dish back, appending again would show it twice.
    test('does not duplicate a dish the peer already restored', () async {
      final loaded = _plan(entries: [_entry('e1', slot: MealSlot.ovrigt)]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('e1');
      stream.add(loaded);
      await Future<void>.delayed(Duration.zero);

      expect(await vm.undoLastRemoval(), isTrue);
      expect(vm.entriesFor(DayOfWeek.mon).map((e) => e.id), ['e1']);
    });
  });

  group('a tap on a row that is already gone', () {
    test('disarms the undo instead of offering the previous dish', () async {
      final loaded = _plan(
        entries: [
          _entry('first'),
          _entry('gone', slot: MealSlot.lunch),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        final base = vm.plan ?? loaded;
        final filtered = base.entries.where((e) => e.id != id).toList();
        // The service returns the plan ITSELF when the id is missing, and that
        // identity return is the whole precondition of this bug. A stub that
        // always calls `copyWith` makes `identical(updated, current)` false,
        // `_editSeq` advance, and the test pass on the unfixed code.
        return filtered.length == base.entries.length
            ? base
            : base.copyWith(entries: filtered);
      });
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('first');
      expect(vm.canUndoRemoval, isTrue);

      // A peer's snapshot takes 'gone' away, then the user taps ITS control —
      // one frame before it disappears from the screen.
      stream.add(_plan(entries: const []));
      await Future<void>.delayed(Duration.zero);
      await vm.removeEntry('gone');

      expect(
        vm.canUndoRemoval,
        isFalse,
        reason:
            'an undo here would put back "first", which this tap never '
            'touched',
      );
    });
  });

  group('a failed undo', () {
    // The undo consumes `_undoEntry` before awaiting the save, and a refusal
    // rolls the week back to WITHOUT the dish. Without a re-arm the dish is in
    // no variable anywhere and the snackbar that offered it is gone.
    test('keeps the dish recoverable when the save is refused', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));

      var saves = 0;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {
        // Only the FIRST undo attempt fails, so the retry can prove the dish
        // really was still recoverable.
        if (saves++ == 1) throw Exception('offline');
      });

      await vm.removeEntry('e1');
      expect(await vm.undoLastRemoval(), isFalse);

      expect(
        vm.canUndoRemoval,
        isTrue,
        reason: 'the dish exists nowhere else; losing the arm loses the dish',
      );
      expect(vm.entriesFor(DayOfWeek.mon), isEmpty);

      // And the second attempt actually works.
      expect(await vm.undoLastRemoval(), isTrue);
      expect(vm.entriesFor(DayOfWeek.mon).map((e) => e.id), ['e1']);
    });

    // `_plan == null` reaches `_edit`, which returns false WITHOUT a notice.
    test('says so when the week itself could not be read', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('e1');
      expect(vm.canUndoRemoval, isTrue);

      // A refusal drops the week from the screen; the arm survives it. (A
      // transient error deliberately KEEPS the week, so it cannot stage this.)
      stream.addError(
        FirebaseException(plugin: 'x', code: 'permission-denied'),
      );
      await Future<void>.delayed(Duration.zero);
      vm.clearEditNotice();

      expect(await vm.undoLastRemoval(), isFalse);
      expect(
        vm.editNotice,
        GroupMenuEditProblem.undoUnavailable,
        reason: 'silence here is the dish disappearing with no explanation',
      );
    });
  });

  // `undoFailed` exists so the widget can put a retry on exactly this notice.
  // The cheap alternative — `saveFailed && canUndoRemoval` read in the widget —
  // is what the second test here refutes.
  group('the notice a failed undo leaves behind', () {
    /// Removes the only dish (the removal's save succeeds), then undoes it
    /// against a save that throws [undoError].
    Future<void> armThenFailUndo(Object undoError) async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));

      var saves = 0;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {
        if (saves++ == 1) throw undoError;
      });

      await vm.removeEntry('e1');
      expect(await vm.undoLastRemoval(), isFalse);
    }

    test(
      'is undoFailed when the save died and the dish is recoverable',
      () async {
        await armThenFailUndo(Exception('offline'));

        expect(vm.canUndoRemoval, isTrue);
        expect(vm.editNotice, GroupMenuEditProblem.undoFailed);
      },
    );

    // A REFUSAL keeps its own notice: the screen must never offer a retry on
    // something deterministic, and the widget keys that off this value.
    test('is notAnEditor when the save was refused', () async {
      await armThenFailUndo(PermissionDeniedException('view only'));

      expect(vm.canUndoRemoval, isTrue);
      expect(vm.editNotice, GroupMenuEditProblem.notAnEditor);
    });

    // The refutation of the derived condition. An unrelated edit whose COMPUTE
    // throws sets `saveFailed` before `_edit` publishes anything, so the undo
    // from an earlier removal is still armed — `saveFailed && canUndoRemoval`
    // is true here, and a retry built on it would put back the removed dish
    // instead of redoing the move.
    test('stays saveFailed when it was another edit that failed', () async {
      final loaded = _plan(entries: [_entry('e1'), _entry('e2')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: [_entry('e2')]));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});
      await vm.removeEntry('e1');
      expect(vm.canUndoRemoval, isTrue);

      when(
        () => service.moveEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
          toDay: any(named: 'toDay'),
          toSlot: any(named: 'toSlot'),
        ),
      ).thenThrow(Exception('compute blew up'));

      expect(
        await vm.moveEntry(
          entryId: 'e2',
          toDay: DayOfWeek.tue,
          toSlot: MealSlot.middag,
        ),
        isFalse,
      );

      expect(
        vm.canUndoRemoval,
        isTrue,
        reason: 'a compute that never published leaves the arm standing',
      );
      expect(
        vm.editNotice,
        GroupMenuEditProblem.saveFailed,
        reason:
            'the failure was the move; a retry here must not resurrect the '
            'dish an earlier removal took',
      );
    });
  });

  // The undo consumes the dish before it computes. A closure that throws on
  // its way to the screen therefore spends the dish without anything ever
  // publishing, and the edit counter never moves — so the re-arm has to accept
  // an UNCHANGED counter as well as an incremented one.
  group('an undo whose computation dies before it reaches the screen', () {
    test('still leaves the dish recoverable', () async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) async {});

      await vm.removeEntry('e1');
      expect(vm.canUndoRemoval, isTrue);

      // Swap the week for one that cannot be copied. Nothing else in the repo
      // can make the undo's closure throw — `entries.any` and `copyWith` are
      // all it runs — which is why this arm is defensive rather than live.
      final hostile = _CopyWithThrowsPlan();
      when(() => hostile.entries).thenReturn(const []);
      when(() => hostile.participantUserIds).thenReturn(const []);
      when(() => hostile.participants).thenReturn(const []);
      when(
        () => hostile.copyWith(entries: any(named: 'entries')),
      ).thenThrow(StateError('cannot copy'));
      stream.add(hostile);
      await Future<void>.delayed(Duration.zero);

      expect(await vm.undoLastRemoval(), isFalse);
      expect(
        vm.canUndoRemoval,
        isTrue,
        reason:
            'the dish never reached the screen, so nothing consumed it but '
            'this call',
      );
    });
  });

  group('a refused undo that lost its race', () {
    // The re-arm exists; this pins its SEQUENCE condition. A newer edit
    // publishing while the refused undo is in flight must not have its arm
    // overwritten by the older entry — the same straggler class `removeEntry`
    // is already guarded against.
    test('does not re-arm behind a newer edit', () async {
      final loaded = _plan(
        entries: [
          _entry('e1'),
          _entry('e2', slot: MealSlot.lunch),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        final base = vm.plan ?? loaded;
        final filtered = base.entries.where((e) => e.id != id).toList();
        return filtered.length == base.entries.length
            ? base
            : base.copyWith(entries: filtered);
      });
      when(
        () => service.moveEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
          toDay: any(named: 'toDay'),
          toSlot: any(named: 'toSlot'),
        ),
      ).thenAnswer(
        (_) => (vm.plan ?? loaded).copyWith(
          entries: [_entry('e2', slot: MealSlot.ovrigt)],
        ),
      );

      // Save 0 is the removal. Save 1 is the undo, and it hangs, then fails.
      // Save 2 is the move that publishes behind it.
      final undoGate = Completer<void>();
      var saves = 0;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) {
        final call = saves++;
        if (call == 1) return undoGate.future;
        return Future<void>.value();
      });

      await vm.removeEntry('e1');
      final undo = vm.undoLastRemoval();
      await Future<void>.delayed(Duration.zero);

      await vm.moveEntry(
        entryId: 'e2',
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.ovrigt,
      );
      undoGate.completeError(Exception('offline'));
      expect(await undo, isFalse);

      expect(
        vm.canUndoRemoval,
        isFalse,
        reason:
            'the move published after the undo, so re-arming would hand '
            'the user an undo built on a base the move has already replaced',
      );
    });
  });

  group('undo arming', () {
    test('a non-removal edit during the save disarms the undo', () async {
      final loaded = _plan(entries: [_entry('e1'), _entry('e2')]);
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: [_entry('e2')]));
      when(
        () => service.moveEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
          toDay: any(named: 'toDay'),
          toSlot: any(named: 'toSlot'),
        ),
      ).thenReturn(
        loaded.copyWith(
          entries: [_entry('e2', slot: MealSlot.lunch)],
        ),
      );

      // Only the FIRST save hangs; the move that follows completes at once.
      final gate = Completer<void>();
      var saves = 0;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) => saves++ == 0 ? gate.future : Future<void>.value());

      final removal = vm.removeEntry('e1');
      await Future<void>.delayed(Duration.zero);
      await vm.moveEntry(
        entryId: 'e2',
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.lunch,
      );
      gate.complete();
      await removal;

      // Without the sequence check the removal's trailing arm re-arms a base
      // taken TWO edits ago, and undoing it would silently revert the move.
      expect(vm.canUndoRemoval, isFalse);
    });
  });

  group('a straggler save', () {
    // An older removal resolving AFTER a newer edit must not touch the undo
    // state. Clearing unconditionally wiped a newer, legitimate arm and left
    // the user's "Ångra" landing on undoUnavailable.
    test('does not wipe a newer undo', () async {
      final loaded = _plan(
        entries: [
          _entry('old'),
          _entry('new', slot: MealSlot.lunch),
        ],
      );
      stubRead(loaded);
      await vm.loadWeek(_week);

      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenAnswer((invocation) {
        final id = invocation.namedArguments[#entryId] as String;
        final base = vm.plan ?? loaded;
        return base.copyWith(
          entries: base.entries.where((e) => e.id != id).toList(),
        );
      });

      // Only the FIRST save hangs, so the second removal finishes first and is
      // the one armed when the straggler finally lands.
      final gate = Completer<void>();
      var saves = 0;
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenAnswer((_) => saves++ == 0 ? gate.future : Future<void>.value());

      final first = vm.removeEntry('old');
      await Future<void>.delayed(Duration.zero);
      await vm.removeEntry('new');
      expect(vm.canUndoRemoval, isTrue);

      gate.complete();
      await first;

      expect(vm.canUndoRemoval, isTrue);
      expect(await vm.undoLastRemoval(), isTrue);
      expect(
        vm.entriesFor(DayOfWeek.mon).map((e) => e.id),
        ['new'],
        reason: 'the straggler must not have replaced the newer undo',
      );
    });
  });

  group('the notice tells outage from refusal', () {
    Future<void> removeWith(Object saveError) async {
      final loaded = _plan(entries: [_entry('e1')]);
      stubRead(loaded);
      await vm.loadWeek(_week);
      when(
        () => service.removeEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          entryId: any(named: 'entryId'),
        ),
      ).thenReturn(loaded.copyWith(entries: const []));
      when(
        () => service.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenThrow(saveError);
      await vm.removeEntry('e1');
    }

    test('a plain failure is saveFailed', () async {
      await removeWith(Exception('offline'));
      expect(vm.editNotice, GroupMenuEditProblem.saveFailed);
    });

    // Single-variable control: same path, different exception type.
    test('a refusal is notAnEditor', () async {
      await removeWith(PermissionDeniedException('view only'));
      expect(vm.editNotice, GroupMenuEditProblem.notAnEditor);
    });
  });

  group('participant names', () {
    test('a resolved profile reaches the face row', () async {
      when(() => userService.getUserProfiles(any())).thenAnswer(
        (_) async => [
          UserProfile(
            uid: _alice,
            displayName: 'Malin Gisslén',
            email: 'm@example.com',
            joinedAt: DateTime.utc(2026, 1, 1),
            lastActiveAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      stubRead(_plan());
      await vm.loadWeek(_week);
      await Future<void>.delayed(Duration.zero);

      expect(vm.displayNameFor(_alice), 'Malin Gisslén');
    });
  });

  group('live sync', () {
    test('an incoming snapshot reaches the screen', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      expect(vm.entriesFor(DayOfWeek.mon), isEmpty);

      stream.add(_plan(entries: [_entry('e1')]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
    });

    test('a snapshot clears a failure the screen was showing', () async {
      stubRead(null, readFailed: true);
      await vm.loadWeek(_week);
      expect(vm.failure, GroupMenuFailure.transient);

      stream.add(_plan(entries: [_entry('e1')]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.failure, GroupMenuFailure.none);
      expect(vm.entriesFor(DayOfWeek.mon), hasLength(1));
    });

    // The two error arms differ in exactly this: a refusal invalidates the
    // week, an outage does not.
    test('a transient error KEEPS the week that is on screen', () async {
      stubRead(_plan(entries: [_entry('e1')]));
      await vm.loadWeek(_week);

      stream.addError(FirebaseException(plugin: 'x', code: 'unavailable'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.failure, GroupMenuFailure.transient);
      expect(vm.plan, isNotNull);
    });

    test('a refusal DROPS the week', () async {
      stubRead(_plan(entries: [_entry('e1')]));
      await vm.loadWeek(_week);

      stream.addError(
        FirebaseException(plugin: 'x', code: 'permission-denied'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.plan, isNull);
    });

    test('nothing arrives after dispose', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      vm.dispose();
      disposedByTest = true;

      stream.add(_plan(entries: [_entry('e1')]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.plan?.entries ?? const [], isEmpty);
      // Asserted separately because the state check above passes on the
      // `isDisposed` guard alone: dropping the cancel leaks a listener that no
      // observable state reveals. Measured — without this line, removing
      // `_subscription?.cancel()` from dispose left the whole suite green.
      expect(stream.hasListener, isFalse);
    });

    test('changing week re-subscribes on the new week', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      await vm.goToNextWeek();

      final dates = verify(
        () => realtime.subscribe(
          groupId: any(named: 'groupId'),
          date: captureAny(named: 'date'),
          onUpdate: any(named: 'onUpdate'),
          onError: any(named: 'onError'),
        ),
      ).captured.cast<DateTime>();

      expect(dates, hasLength(2));
      expect(dates.last.difference(dates.first).inDays, 7);
      // The OLD subscription must go. A leak here is invisible to state — both
      // listeners write the same `_plan` — but costs a Firestore read per
      // snapshot, per abandoned week, for the life of the screen.
      expect(subscriptions.first.cancelled, isTrue);
      expect(subscriptions.last.cancelled, isFalse);
    });
  });

  group('out-of-order reads', () {
    test('a late read for an abandoned week is dropped', () async {
      final first = Completer<GroupWeeklyMenuPlanRead>();
      final second = Completer<GroupWeeklyMenuPlanRead>();
      final pending = <Completer<GroupWeeklyMenuPlanRead>>[first, second];

      when(
        () => service.readWeek(
          groupId: any(named: 'groupId'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) => pending.removeAt(0).future);

      final weekOne = vm.loadWeek(_week);
      final weekTwo = vm.loadWeek(_week.add(const Duration(days: 7)));

      // The SECOND week answers first, then the abandoned one arrives.
      second.complete(
        GroupWeeklyMenuPlanRead(plan: _plan(), readFailed: false),
      );
      await weekTwo;
      first.complete(
        GroupWeeklyMenuPlanRead(
          plan: _plan(entries: [_entry('stale')]),
          readFailed: false,
        ),
      );
      await weekOne;

      expect(
        vm.entriesFor(DayOfWeek.mon),
        isEmpty,
        reason: "the abandoned week's meals must not land under the new header",
      );
    });
  });

  group('costs', () {
    test('a uid whose profile cannot be read is asked for once', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);

      stream.add(_plan(entries: [_entry('e1')]));
      await Future<void>.delayed(Duration.zero);
      stream.add(_plan(entries: [_entry('e2')]));
      await Future<void>.delayed(Duration.zero);

      // The stub returns no profiles, so the uid never lands in the name map.
      // Without the attempted-set it would be re-fetched on every snapshot of
      // a live-synced screen.
      verify(() => userService.getUserProfiles(any())).called(1);
    });
  });

  group('week navigation', () {
    test('the arrows move a whole ISO week', () async {
      stubRead(_plan());
      await vm.loadWeek(_week);
      final start = vm.weekStart;

      await vm.goToNextWeek();
      expect(vm.weekStart.difference(start).inDays, 7);

      await vm.goToPreviousWeek();
      expect(vm.weekStart, start);
    });
  });
}
