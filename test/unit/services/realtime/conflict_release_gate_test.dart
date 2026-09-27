// P6-U08b: "Konfliktbannern visas när kön töms, inte medan appen är
// offline" (produktregler.md:189; TR::FLOW::08::ko::toms::konfliktbanner).

import 'dart:async';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/conflict_release_gate.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

ConflictEvent _event(String docId) {
  final at = DateTime(2026, 9, 27, 12);
  RealtimeRecipe version(String by, int count) => RealtimeRecipe(
    id: docId,
    ownerId: 'u1',
    ownerDisplayName: 'Malin',
    participants: const {'u1': ResourcePermission.owner},
    lastEditedAt: at,
    lastEditedBy: by,
    lastEditedByDisplayName: by,
    editCount: count,
    recipe: RecipeFactory.build(id: docId, title: 'Citronrisotto'),
  );
  final local = version('u1', 1);
  final remote = version('anna', 2);
  return ConflictEvent(
    collectionPath: 'recipes',
    docId: docId,
    localValue: local,
    remoteValue: remote,
    chosenStrategy: ConflictResolutionStrategy.remoteWon,
    entity: ConflictEntity.recipeOwn,
    occurredAt: at,
  );
}

void main() {
  late StreamController<bool> queue;
  late bool current;
  late List<ConflictEvent> shown;
  late ConflictReleaseGate gate;
  late int reads;

  setUp(() {
    queue = StreamController<bool>.broadcast();
    current = false;
    shown = [];
    reads = 0;
    gate = ConflictReleaseGate(
      settled: () async* {
        reads++;
        yield current;
        yield* queue.stream;
      },
      release: shown.add,
    );
  });

  tearDown(() => queue.close());

  test('a notice raised while the queue waits is held, then shown when it '
      'empties, in order', () async {
    gate
      ..offer(_event('a'))
      ..offer(_event('b'));
    await pumpEventQueue();
    expect(shown, isEmpty);
    expect(gate.heldCount, 2);

    current = true;
    queue.add(true);
    await pumpEventQueue();

    expect(shown.map((e) => e.docId), ['a', 'b']);
    expect(gate.heldCount, 0);
    expect(reads, 1, reason: 'one wait, one read');
  });

  test('online with an empty queue a notice is shown at once', () async {
    current = true;
    gate.offer(_event('a'));
    await pumpEventQueue();
    expect(shown.map((e) => e.docId), ['a']);
  });

  test('reconnecting alone is not enough: it waits for the queue', () async {
    gate.offer(_event('a'));
    await pumpEventQueue();
    // Online again, but the queue still has changes: settled stays false.
    queue.add(false);
    await pumpEventQueue();
    expect(shown, isEmpty);
    queue.add(true);
    await pumpEventQueue();
    expect(shown, hasLength(1));
  });

  test('a notice is never lost: a failing or ending queue state lets it '
      'through', () async {
    final failing = ConflictReleaseGate(
      settled: () => Stream<bool>.error(StateError('database closed')),
      release: shown.add,
    );
    failing.offer(_event('a'));
    await pumpEventQueue();
    expect(shown, hasLength(1));

    final ending = ConflictReleaseGate(
      settled: () => Stream<bool>.value(false),
      release: shown.add,
    );
    ending.offer(_event('b'));
    await pumpEventQueue();
    expect(shown.map((e) => e.docId), ['a', 'b']);

    final throwing = ConflictReleaseGate(
      settled: () => throw StateError('no queue'),
      release: shown.add,
    );
    throwing.offer(_event('c'));
    expect(shown.map((e) => e.docId), ['a', 'b', 'c']);
  });

  test('dispose lets through what is held', () async {
    gate.offer(_event('a'));
    await pumpEventQueue();
    gate.dispose();
    expect(shown, hasLength(1));
  });
}
