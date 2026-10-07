// BUT-2162: recipe writes go through the offline queue, and the queue sends
// them through the recipe repository, the collection's one write chokepoint
// (sanitizing, normalizing and the share cap live there; BUT-1819, BUT-955).
//
// A real in-memory queue; the repository is the mock, the queue and the
// adapter are real.

import 'dart:async';
import 'dart:math';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart';

void main() {
  const uid = QueueHarness.uid;
  late AppDatabase db;
  late MockRecipeRepository repository;
  late OfflineUserStorage storage;
  late OfflineSyncManager manager;
  late List<String> tagged;
  late List<String> settled;
  late FakeAuthRepository auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MockRecipeRepository();
    when(() => repository.create(any())).thenAnswer(
      (inv) async => inv.positionalArguments.first as Recipe,
    );
    when(() => repository.update(any())).thenAnswer((_) async {});
    when(() => repository.delete(any())).thenAnswer((_) async {});
    when(() => repository.read(any())).thenAnswer((_) async => null);
    storage = OfflineUserStorage(database: db);
    tagged = [];
    settled = [];
    auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    manager = OfflineSyncManager(
      database: db,
      authRepository: auth,
      isOnlineNow: () => false,
      random: MidRandom(),
      onTagRecipe: (id, userId) async => tagged.add('$id@$userId'),
      recipeWriter: RecipeServiceAdapter(recipeRepository: repository),
      onRecipeSent: settled.add,
      sendTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    manager.dispose();
    await db.close();
  });

  Future<void> pass() => withClock(
    Clock.fixed(QueueHarness.t0),
    () => manager.syncPendingChanges(isOnline: true),
  );

  Recipe recipe(String id, {String title = 'Köttbullar'}) =>
      RecipeFactory.build(id: id, title: title, createdBy: uid);

  test('a create is sent with the repository create, once', () async {
    await storage.saveRecipeForUser(
      recipe('r1'),
      uid,
      operation: SyncOperation.create,
    );

    await pass();

    final sent = verify(() => repository.create(captureAny())).captured;
    expect(sent.single, isA<Recipe>().having((r) => r.id, 'id', 'r1'));
    verifyNever(() => repository.update(any()));
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  test(
    'edits queued behind a create are sent as the latest copy, once',
    () async {
      await storage.saveRecipeForUser(
        recipe('r1', title: 'Första'),
        uid,
        operation: SyncOperation.create,
      );
      await storage.saveRecipeForUser(recipe('r1', title: 'Andra'), uid);
      await storage.saveRecipeForUser(recipe('r1', title: 'Tredje'), uid);

      await pass();

      final sent = verify(() => repository.create(captureAny())).captured;
      expect((sent.single as Recipe).title, 'Tredje');
      verifyNever(() => repository.update(any()));
      expect(await db.syncQueueDao.countPending(uid), 0);
    },
  );

  test('a later edit names the unsent create in dependsOn', () async {
    final createOp = await storage.saveRecipeForUser(
      recipe('r1'),
      uid,
      operation: SyncOperation.create,
    );
    final updateOp = await storage.saveRecipeForUser(recipe('r1'), uid);

    final rows = {
      for (final e in await db.select(db.syncQueueEntries).get()) e.opId: e,
    };
    expect(SyncQueueDao.dependsOnOf(rows[updateOp]!), [createOp]);
  });

  test('a save made while the write is on its way is sent after it', () async {
    await storage.saveRecipeForUser(recipe('r1', title: 'Första'), uid);
    when(() => repository.update(any())).thenAnswer((_) async {
      // The user saves again before the server has answered.
      when(() => repository.update(any())).thenAnswer((_) async {});
      await storage.saveRecipeForUser(recipe('r1', title: 'Andra'), uid);
    });

    await pass();
    expect(
      await db.syncQueueDao.countPending(uid),
      1,
      reason: 'the second save waits for its own send',
    );
    final device = await db.recipeDao.getRecipe('r1', uid);
    expect(device!.needsSync, isTrue);

    await pass();
    final sent = verify(() => repository.update(captureAny())).captured;
    expect((sent.last as Recipe).title, 'Andra');
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  test('a delete leaves the device and is sent with the repository', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    await pass();

    await storage.queueDeleteForUser('r1', uid);
    expect(await db.recipeDao.getRecipe('r1', uid), isNull);
    expect(await storage.hasUnsentWrite('r1', uid), isTrue);

    await pass();
    verify(() => repository.delete('r1')).called(1);
    expect(await storage.hasUnsentWrite('r1', uid), isFalse);
  });

  test('deleting a recipe the server never had sends nothing to create, '
      'and the delete finds nothing to remove', () async {
    await storage.saveRecipeForUser(
      recipe('r1'),
      uid,
      operation: SyncOperation.create,
    );
    await storage.queueDeleteForUser('r1', uid);
    when(
      () => repository.delete('r1'),
    ).thenThrow(ResourceNotFoundException('Recipe not found'));

    await pass();

    verifyNever(() => repository.create(any()));
    expect(await db.syncQueueDao.countPending(uid), 0);
    expect(await db.syncQueueDao.getPermanentFailures(uid), isEmpty);
  });

  test('a repository refusal waits for the user, with its cause', () async {
    final op = await storage.saveRecipeForUser(recipe('r1'), uid);
    when(
      () => repository.update(any()),
    ).thenThrow(PermissionDeniedException('not the owner'));

    await pass();

    final failures = await db.syncQueueDao.getPermanentFailures(uid);
    expect(failures.single.opId, op);
    expect(
      QueuedChangeReason.parse(failures.single.lastError),
      QueuedChangeReason.permissionDenied,
    );
  });

  test('an edit of a recipe the server does not have is "not found"', () {
    expect(
      permanentFailureReason(ResourceNotFoundException('Recipe not found')),
      QueuedChangeReason.notFound,
    );
  });

  test('a failed tagging is queued behind the recipe write', () async {
    final failed = recipe('r1').copyWith();
    final withFailedTags = Recipe(
      core: failed.core.copyWith(
        tagResult: TagResult(
          tags: const {},
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: 0,
          unknownIngredients: const [],
          generatedAt: QueueHarness.t0,
          generatorVersion: 'failed',
        ),
      ),
      type: failed.type,
    );
    final writeOp = await storage.saveRecipeForUser(
      withFailedTags,
      uid,
      operation: SyncOperation.create,
    );

    final tagRow = (await db.select(db.syncQueueEntries).get()).singleWhere(
      (e) => e.operation == SyncOperation.tag.name,
    );
    expect(SyncQueueDao.dependsOnOf(tagRow), [writeOp]);

    await pass();
    verify(() => repository.create(any())).called(1);
    expect(tagged, ['r1@$uid']);
  });

  test('recipe entries wait untouched until a writer is attached', () async {
    manager.recipeWriter = null;
    await storage.saveRecipeForUser(recipe('r1'), uid);

    await pass();

    final row = (await db.select(db.syncQueueEntries).get()).single;
    expect(row.retryCount, 0);
    expect(row.permanentlyFailed, isFalse);
    expect(await db.recipeDao.getRecipe('r1', uid), isNotNull);
  });

  test('the screen is told when a write and a deletion have gone', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    await pass();
    await storage.queueDeleteForUser('r1', uid);
    await pass();

    expect(settled, ['r1', 'r1']);
  });

  test('a pass stops when another account signs in, and leaves the first '
      "account's entries for its own next pass", () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    await storage.saveRecipeForUser(recipe('r2'), uid);
    when(() => repository.update(any())).thenAnswer((inv) async {
      // The first send is on its way when the user switches account.
      auth.setAuthState(user: FakeUser(), userId: 'u2', isAuthenticated: true);
    });

    await pass();

    final sent = verify(() => repository.update(captureAny())).captured;
    expect(sent.map((r) => (r as Recipe).id), ['r1']);
    final left = await db.syncQueueDao.getPendingForUser(uid);
    expect(left.map((e) => e.recipeId), ['r2']);
    expect(left.single.retryCount, 0);
    expect(left.single.permanentlyFailed, isFalse);
  });

  test('a send that never completes is a failure the queue retries', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    when(
      () => repository.update(any()),
    ).thenAnswer((_) => Completer<void>().future);

    await pass();

    final row = (await db.select(db.syncQueueEntries).get()).single;
    expect(row.retryCount, 1);
    expect(row.permanentlyFailed, isFalse);
    expect(row.nextAttemptAt, isNotNull);
    expect(manager.isSyncing, isFalse);
  });

  test('a second delete of a queued deletion queues nothing', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    await pass();

    expect(await storage.queueDeleteForUser('r1', uid), isTrue);
    expect(await storage.queueDeleteForUser('r1', uid), isFalse);

    final deletes = (await db.select(db.syncQueueEntries).get()).where(
      (e) => e.operation == SyncOperation.delete.name,
    );
    expect(deletes, hasLength(1));
  });

  test('passes asked for while one runs go one at a time', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    final gate = Completer<void>();
    var inFlight = 0;
    var most = 0;
    when(() => repository.update(any())).thenAnswer((_) async {
      inFlight++;
      most = max(most, inFlight);
      await gate.future;
      inFlight--;
    });

    final first = pass();
    await pumpEventQueue();
    await storage.saveRecipeForUser(recipe('r2'), uid);
    final waiting = [pass(), pass()];
    gate.complete();
    await Future.wait([first, ...waiting]);

    expect(most, 1);
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  test('a pass waiting when the manager is disposed does not run', () async {
    await storage.saveRecipeForUser(recipe('r1'), uid);
    final gate = Completer<void>();
    when(() => repository.update(any())).thenAnswer((_) => gate.future);

    final first = pass();
    await pumpEventQueue();
    final waiting = pass();
    manager.dispose();
    await db.close();
    gate.complete();

    await expectLater(waiting, completes);
    await first.catchError((_) {});
  });
}
