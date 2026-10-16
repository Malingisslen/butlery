/// BUT-907: the trash view model's contract with the view: what it shows
/// and that it hands each change to the service as the user asked.
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

  test('restoreOne restores exactly that row', () async {
    await push([a, b, c]);
    final result = await vm.restoreOne('c');
    expect(service.restored.single, ['c']);
    expect(result!.action, TrashAction.restore);
    expect(result.requested, 1);
    expect(result.outcome.isComplete, isTrue);
  });

  test('restoreAll restores every row', () async {
    await push([a, b]);
    final result = await vm.restoreAll();
    expect(service.restored.single, ['a', 'b']);
    expect(result!.requested, 2);
  });

  test('a row that failed is reported as not done', () async {
    await push([a, b]);
    service.next = const TrashOutcome(
      doneIds: ['a'],
      failures: {'b': TrashFailure.gone},
    );
    final result = await vm.restoreAll();
    expect(result!.outcome.isComplete, isFalse);
    expect(result.outcome.failures.keys, ['b']);
  });

  test('deleteOne deletes that id for good', () async {
    await push([a, b]);
    final result = await vm.deleteOne('b');
    expect(service.deleted.single, ['b']);
    expect(result!.action, TrashAction.deleteForever);
  });

  test('emptyTrash empties and reports every row as requested', () async {
    await push([a, b]);
    final result = await vm.emptyTrash();
    expect(service.emptied, 1);
    expect(result!.requested, 2);
  });

  test('an unknown id or an empty trash does nothing', () async {
    await push([a]);
    expect(await vm.restoreOne('zzz'), isNull);
    expect(await vm.deleteOne('zzz'), isNull);
    await push([]);
    expect(await vm.restoreAll(), isNull);
    expect(service.restored, isEmpty);
    expect(service.deleted, isEmpty);
  });

  test('stays unusable while a change runs', () async {
    await push([a, b]);
    final first = vm.restoreOne('a');
    expect(vm.isWorking, isTrue);
    expect(await vm.restoreOne('b'), isNull);
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
    });
  });
}
