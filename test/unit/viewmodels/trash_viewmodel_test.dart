/// BUT-907: the trash view model's contract with the view: what it shows, what
/// it selects, and that it hands each change to the service as the user asked.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';

import '../../infrastructure/fakes/scripted_trash_service.dart';

void main() {
  late ScriptedTrashService service;
  late TrashViewModel vm;

  final a = trashItemFor('a');
  final b = trashItemFor('b');
  final c = trashItemFor('c');

  setUp(() {
    service = ScriptedTrashService();
    vm = TrashViewModel(service: service)..start();
  });

  tearDown(() {
    if (!vm.isDisposed) vm.dispose();
  });

  Future<void> push(List items) async {
    service.list.add(List.of(items.cast()));
    await pumpEventQueue();
  }

  test('is loading until the first list arrives, then shows it', () async {
    expect(vm.isLoading, isTrue);
    await push([a, b]);
    expect(vm.isLoading, isFalse);
    expect(vm.items.map((i) => i.id), ['a', 'b']);
  });

  test('an empty list is empty, not an error', () async {
    await push([]);
    expect(vm.isEmpty, isTrue);
    expect(vm.hasError, isFalse);
  });

  test('a stream error is an error, and start() listens afresh', () async {
    service.list.addError(StateError('signed out'));
    await pumpEventQueue();
    expect(vm.hasError, isTrue);
    expect(vm.isLoading, isFalse);

    vm.start();
    expect(vm.hasError, isFalse);
    expect(service.watched, 2);
    await push([a]);
    expect(vm.items, hasLength(1));
  });

  test('toggle selects and unselects one row', () async {
    await push([a, b]);
    vm.toggle('a');
    expect(vm.selectedIds, {'a'});
    vm.toggle('a');
    expect(vm.hasSelection, isFalse);
  });

  test(
    'toggleAll selects every row, then clears when all are selected',
    () async {
      await push([a, b, c]);
      vm.toggleAll();
      expect(vm.selectedCount, 3);
      expect(vm.allSelected, isTrue);
      vm.toggleAll();
      expect(vm.selectedCount, 0);
    },
  );

  test('a row that leaves the list leaves the selection', () async {
    await push([a, b]);
    vm.toggleAll();
    await push([b]);
    expect(vm.selectedIds, {'b'});
  });

  test('restoreSelected restores exactly the selected rows', () async {
    await push([a, b, c]);
    vm.toggle('a');
    vm.toggle('c');
    final result = await vm.restoreSelected();
    expect(service.restored.single, ['a', 'c']);
    expect(result!.action, TrashAction.restore);
    expect(result.requested, 2);
    expect(result.outcome.isComplete, isTrue);
    expect(vm.hasSelection, isFalse);
  });

  test('a row that failed stays selected', () async {
    await push([a, b]);
    vm.toggleAll();
    service.next = const TrashOutcome(
      doneIds: ['a'],
      failures: {'b': TrashFailure.gone},
    );
    final result = await vm.restoreSelected();
    expect(result!.outcome.isComplete, isFalse);
    expect(vm.selectedIds, {'b'});
  });

  test('deleteSelected deletes the selected ids for good', () async {
    await push([a, b]);
    vm.toggle('b');
    final result = await vm.deleteSelected();
    expect(service.deleted.single, ['b']);
    expect(result!.action, TrashAction.deleteForever);
  });

  test('emptyTrash empties and reports every row as requested', () async {
    await push([a, b]);
    final result = await vm.emptyTrash();
    expect(service.emptied, 1);
    expect(result!.requested, 2);
  });

  test('with nothing selected, restore and delete do nothing', () async {
    await push([a]);
    expect(await vm.restoreSelected(), isNull);
    expect(await vm.deleteSelected(), isNull);
    expect(service.restored, isEmpty);
    expect(service.deleted, isEmpty);
  });

  test('stays unusable while a change runs', () async {
    await push([a, b]);
    vm.toggle('a');
    final first = vm.restoreSelected();
    expect(vm.isWorking, isTrue);
    expect(await vm.restoreSelected(), isNull);
    await first;
    expect(vm.isWorking, isFalse);
    expect(service.restored, hasLength(1));
  });

  test('disposing cancels the stream subscription', () async {
    expect(service.list.hasListener, isTrue);
    vm.dispose();
    await pumpEventQueue();
    expect(service.list.hasListener, isFalse);
  });

  group('time left', () {
    final now = DateTime.utc(2026, 10, 9);

    test('counts whole days, rounding a started day up', () {
      expect(
        TrashViewModel.daysLeft(trashItemFor('x', now: now), now),
        30,
      );
      expect(
        TrashViewModel.daysLeft(
          trashItemFor('x', now: now, age: const Duration(days: 28, hours: 1)),
          now,
        ),
        2,
      );
    });

    test('is zero at and after expiry', () {
      final expired = trashItemFor(
        'x',
        now: now,
        age: const Duration(days: 31),
      );
      expect(TrashViewModel.daysLeft(expired, now), 0);
      expect(TrashViewModel.fractionLeft(expired, now), 0);
    });

    test('fraction is the share of the 30 days left', () {
      final half = trashItemFor('x', now: now, age: const Duration(days: 15));
      expect(TrashViewModel.fractionLeft(half, now), closeTo(0.5, 1e-9));
    });
  });
}
