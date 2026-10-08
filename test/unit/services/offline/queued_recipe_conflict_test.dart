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
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
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

  @override
  Future<void> create(Recipe recipe) async => recipes[recipe.id] = recipe;

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

  group('the revision a queued write is built on is never lowered', () {
    setUp(() async {
      await db.recipeDao.upsertRecipe(
        id: 'r1',
        userId: uid,
        recipeJson: jsonEncode(recipe('På enheten', rev: 5).toJson()),
        needsSync: false,
      );
    });

    test('an edit built on an older copy takes the device copy\'s', () async {
      await storage.saveRecipeForUser(recipe('Äldre kopia', rev: 3), uid);
      expect((await onDevice()).rev, 5);
      expect((await onDevice()).title, 'Äldre kopia');
    });

    test('an edit that lost its revision takes the device copy\'s', () async {
      await storage.saveRecipeForUser(recipe('Utan revision'), uid);
      expect((await onDevice()).rev, 5);
    });

    test('an edit built on a newer one keeps its own', () async {
      await storage.saveRecipeForUser(recipe('Nyare', rev: 7), uid);
      expect((await onDevice()).rev, 7);
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
