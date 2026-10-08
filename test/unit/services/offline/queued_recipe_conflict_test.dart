// BUT-2213: a queued recipe edit carries the revision it was built on. The
// server takes it only on that revision; otherwise the edit is not written,
// the device takes the server's recipe, and the conflict is handed on
// (TR::FLOW::08::ko::toms::konfliktbanner).
//
// A real in-memory queue and user storage; the server is a writer that keeps
// one revision per recipe and refuses a write built on another.

import 'dart:convert';

import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/recipe_revision_record.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import 'queue_harness.dart';

/// A server with one revision per recipe. An update built on another
/// revision is refused with the server's recipe, as the repository does.
class _RevisionServer implements QueuedRecipeWriter {
  final Map<String, Recipe> recipes = {};
  final List<Recipe> updates = [];

  /// Runs inside the next update, before the server answers.
  Future<void> Function()? duringNextUpdate;

  /// A create that finds the recipe already there (sent again after its
  /// answer was lost) is done when the server holds what is sent at
  /// revision 0, and a conflict otherwise.
  @override
  Future<int> create(Recipe recipe) async {
    final server = recipes[recipe.id];
    if (server != null) {
      if ((server.rev ?? 0) == 0 && server.title == recipe.title) return 0;
      throw RecipeRevisionConflictException(server);
    }
    recipes[recipe.id] = _withRev(recipe, 0);
    return 0;
  }

  @override
  Future<int> update(Recipe recipe) async {
    final during = duringNextUpdate;
    duringNextUpdate = null;
    if (during != null) await during();
    updates.add(recipe);
    final server = recipes[recipe.id]!;
    final serverRev = server.rev ?? 0;
    if (recipe.rev != null && recipe.rev != serverRev) {
      throw RecipeRevisionConflictException(server);
    }
    recipes[recipe.id] = _withRev(recipe, serverRev + 1);
    return serverRev + 1;
  }

  @override
  Future<void> delete(String recipeId) async => recipes.remove(recipeId);
}

Recipe _withRev(Recipe r, int? rev) => Recipe(
  core: r.core,
  type: r.type,
  socialData: r.socialData,
  realtimeData: r.realtimeData,
  rev: rev,
);

void main() {
  const uid = QueueHarness.uid;
  late AppDatabase db;
  late OfflineUserStorage storage;
  late OfflineSyncManager manager;
  late _RevisionServer server;
  late List<(Recipe, Recipe)> conflicts;
  late List<String> settled;

  setUpAll(QueueHarness.registerFallbacks);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = OfflineUserStorage(database: db);
    server = _RevisionServer();
    conflicts = [];
    settled = [];
    manager = OfflineSyncManager(
      database: db,
      authRepository: FakeAuthRepository()
        ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true),
      isOnlineNow: () => false,
      random: MidRandom(),
      recipeWriter: server,
      onRecipeSent: settled.add,
      onRecipeConflict: (local, remote) => conflicts.add((local, remote)),
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

  Recipe recipe(String title, {int? rev}) => _withRev(
    RecipeFactory.build(id: 'r1', title: title, createdBy: uid),
    rev,
  );

  Future<Recipe> onDevice() async => Recipe.fromJson(
    jsonDecode((await db.recipeDao.getRecipe('r1', uid))!.recipeJson)
        as Map<String, dynamic>,
  );

  group('a queued edit that meets a newer server version', () {
    setUp(() {
      server.recipes['r1'] = recipe('Från min andra enhet', rev: 3);
    });

    test('leaves the queue without failing, the device takes the server\'s '
        'recipe, and the conflict is handed on once', () async {
      await storage.saveRecipeForUser(recipe('Min ändring', rev: 2), uid);

      await pass();

      expect(await db.syncQueueDao.countPending(uid), 0);
      expect(await db.syncQueueDao.getPermanentFailures(uid), isEmpty);
      final device = await db.recipeDao.getRecipe('r1', uid);
      expect(device!.needsSync, isFalse);
      expect((await onDevice()).title, 'Från min andra enhet');
      expect((await onDevice()).rev, 3);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.$1.title, 'Min ändring');
      expect(conflicts.single.$2.title, 'Från min andra enhet');
      expect(server.recipes['r1']!.title, 'Från min andra enhet');
      expect(settled, ['r1'], reason: 'the screen takes the server\'s copy');
    });

    test('a later edit of the same recipe queued behind it is not sent over '
        'the server\'s version', () async {
      await storage.saveRecipeForUser(recipe('Min ändring', rev: 2), uid);
      await storage.saveRecipeForUser(recipe('Min andra ändring', rev: 2), uid);

      await pass();

      expect(await db.syncQueueDao.countPending(uid), 0);
      expect(server.recipes['r1']!.title, 'Från min andra enhet');
      expect(conflicts, hasLength(1));
    });
  });

  test('a send the server took moves the device copy to the server\'s new '
      'revision', () async {
    server.recipes['r1'] = recipe('Linsgryta', rev: 2);
    await storage.saveRecipeForUser(
      recipe('Linsgryta med spenat', rev: 2),
      uid,
    );

    await pass();

    expect((await onDevice()).rev, 3);
    expect((await db.recipeDao.getRecipe('r1', uid))!.needsSync, isFalse);
    expect(conflicts, isEmpty);
  });

  test('an edit saved while the first was on its way is sent on the new '
      'revision, with no conflict', () async {
    server.recipes['r1'] = recipe('Linsgryta', rev: 2);
    await storage.saveRecipeForUser(recipe('Första', rev: 2), uid);
    // The screen still holds the copy from before the send (rev 2).
    server.duringNextUpdate = () async {
      await storage.saveRecipeForUser(recipe('Andra', rev: 2), uid);
    };

    await pass();
    expect(await db.syncQueueDao.countPending(uid), 1);
    await pass();

    expect(server.updates.map((r) => (r.title, r.rev)), [
      ('Första', 2),
      ('Andra', 3),
    ]);
    expect(server.recipes['r1']!.title, 'Andra');
    expect(conflicts, isEmpty);
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  Future<void> storeOnDevice(Recipe recipe) => db.recipeDao.upsertRecipe(
    id: recipe.id,
    userId: uid,
    recipeJson: jsonEncode(recipe.toJson()),
    needsSync: false,
  );

  group('a device copy whose revision the device did not produce', () {
    setUp(() => storeOnDevice(recipe('På enheten', rev: 5)));

    test('an edit built on an older copy keeps its own base', () async {
      await storage.saveRecipeForUser(recipe('Äldre kopia', rev: 3), uid);
      expect((await onDevice()).rev, 3);
      expect((await onDevice()).title, 'Äldre kopia');
    });

    test('an edit built on a newer one keeps its own', () async {
      await storage.saveRecipeForUser(recipe('Nyare', rev: 7), uid);
      expect((await onDevice()).rev, 7);
    });

    test('an edit without a revision is not given the copy\'s: its base is '
        'unknown', () async {
      await storage.saveRecipeForUser(recipe('Utan revision'), uid);
      expect((await onDevice()).rev, RecipeRevisionRecord.unknownBase);
    });

    test('a new recipe has none: the server has not seen it', () async {
      await storage.saveRecipeForUser(
        recipe('Kopia', rev: 4),
        uid,
        operation: SyncOperation.create,
      );
      expect((await onDevice()).rev, isNull);
    });
  });

  test('an edit without a revision on a recipe the device holds no copy of '
      'has an unknown base', () async {
    await storage.saveRecipeForUser(recipe('Utan revision'), uid);
    expect((await onDevice()).rev, RecipeRevisionRecord.unknownBase);
  });

  test('an edit of a recipe whose create is still queued is sent without '
      'comparing', () async {
    await storage.saveRecipeForUser(
      recipe('Ny'),
      uid,
      operation: SyncOperation.create,
    );
    await storage.saveRecipeForUser(recipe('Ny, ändrad'), uid);
    expect((await onDevice()).rev, isNull);
  });

  test('retagging the device copy keeps the revision the copy is built '
      'on', () async {
    await storeOnDevice(recipe('På enheten', rev: 5));

    final retagged = await storage.retagRecipeForUser(
      'r1',
      uid,
      (_) async => TagResult(
        tags: const {},
        allergenStatus: const {},
        dietaryStatus: const {},
        coverage: 1,
        unknownIngredients: const [],
        generatedAt: QueueHarness.t0,
        generatorVersion: 'test',
      ),
    );

    expect(retagged, isTrue);
    expect((await onDevice()).rev, 5);
  });

  group('an edit with an unknown base', () {
    test('meets a conflict when the server holds something else', () async {
      server.recipes['r1'] = recipe('Från min andra enhet', rev: 5);
      await storage.saveRecipeForUser(recipe('Min ändring'), uid);

      await pass();

      expect(server.recipes['r1']!.title, 'Från min andra enhet');
      expect(conflicts.single.$1.title, 'Min ändring');
      expect((await onDevice()).rev, 5);
    });
  });

  group('a base is raised only over revisions this device produced', () {
    test('an edit from a copy read before the device\'s own send is sent on '
        'the revision that send produced', () async {
      server.recipes['r1'] = recipe('Linsgryta', rev: 2);
      await storage.saveRecipeForUser(recipe('Första', rev: 2), uid);
      await pass();
      expect(server.recipes['r1']!.rev, 3);

      // The editor still holds the copy it opened, at revision 2.
      await storage.saveRecipeForUser(recipe('Andra', rev: 2), uid);
      await pass();

      expect(server.updates.last.rev, 3);
      expect(server.recipes['r1']!.title, 'Andra');
      expect(conflicts, isEmpty);
    });

    test('an edit without a revision, built on the device\'s own create, is '
        'sent on the create\'s revision', () async {
      await storage.saveRecipeForUser(
        recipe('Ny'),
        uid,
        operation: SyncOperation.create,
      );
      await pass();

      await storage.saveRecipeForUser(recipe('Ny, ändrad'), uid);
      expect((await onDevice()).rev, 0);
      await pass();

      expect(server.recipes['r1']!.title, 'Ny, ändrad');
      expect(conflicts, isEmpty);
    });

    test(
      'after a conflict, an edit from the copy read before it is not '
      'raised to the server\'s revision and meets the conflict too',
      () async {
        server.recipes['r1'] = recipe('Från min andra enhet', rev: 3);
        await storage.saveRecipeForUser(recipe('Min ändring', rev: 2), uid);
        await pass();
        expect((await onDevice()).rev, 3, reason: "the server's recipe");

        // An editor opened before the conflict saves again, on revision 2.
        await storage.saveRecipeForUser(recipe('Gammal skärm', rev: 2), uid);
        expect((await onDevice()).rev, 2);
        await pass();

        expect(server.recipes['r1']!.title, 'Från min andra enhet');
        expect(conflicts.map((c) => c.$1.title), [
          'Min ändring',
          'Gammal skärm',
        ]);
      },
    );

    test('a save and the end of a send cannot interleave into a base the '
        'device did not mean', () async {
      server.recipes['r1'] = recipe('Linsgryta', rev: 3);
      await storeOnDevice(recipe('Första', rev: 2));

      await Future.wait([
        storage.saveRecipeForUser(recipe('Andra', rev: 2), uid),
        db.recipeDao.advanceRev('r1', uid, sentRev: 2, newRev: 3),
      ]);

      expect((await onDevice()).rev, 3);
      expect((await onDevice()).title, 'Andra');
    });
  });

  test('a conflict met while a newer edit was saved leaves that edit queued, '
      'and it is the one handed on when it meets the conflict', () async {
    server.recipes['r1'] = recipe('Från min andra enhet', rev: 3);
    await storage.saveRecipeForUser(recipe('Första', rev: 2), uid);
    server.duringNextUpdate = () async {
      await storage.saveRecipeForUser(recipe('Andra', rev: 2), uid);
    };

    await pass();

    expect((await onDevice()).title, 'Andra');
    expect((await db.recipeDao.getRecipe('r1', uid))!.needsSync, isTrue);
    expect(await db.syncQueueDao.countPending(uid), 1);
    expect(conflicts, isEmpty);
    expect(settled, isEmpty);

    await pass();

    expect(conflicts.single.$1.title, 'Andra');
    expect((await onDevice()).title, 'Från min andra enhet');
    expect(server.recipes['r1']!.title, 'Från min andra enhet');
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  test('a create sent again that finds another device\'s save takes the '
      'server\'s recipe and hands on the conflict', () async {
    server.recipes['r1'] = recipe('Från min andra enhet', rev: 1);
    await storage.saveRecipeForUser(
      recipe('Min nya'),
      uid,
      operation: SyncOperation.create,
    );

    await pass();

    expect(server.recipes['r1']!.title, 'Från min andra enhet');
    expect(conflicts.single.$1.title, 'Min nya');
    expect((await onDevice()).rev, 1);
    expect(await db.syncQueueDao.countPending(uid), 0);
  });

  test('a create that reached the server leaves the device copy on revision '
      '0', () async {
    await storage.saveRecipeForUser(
      recipe('Ny'),
      uid,
      operation: SyncOperation.create,
    );

    await pass();

    expect((await onDevice()).rev, 0);
  });
}
