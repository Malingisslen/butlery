// P6-U08b: a real in-memory queue driven through OfflineSyncManager, with a
// recipe writer the test can make fail per recipe.

import 'dart:convert';
import 'dart:math';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// Records what reached the "server" and throws the failure the test set for
/// a recipe id.
class HarnessWriter implements QueuedRecipeWriter {
  HarnessWriter(this._harness);

  final QueueHarness Function() _harness;

  Future<void> _write(String recipeId) async {
    final failure = _harness().failWith[recipeId];
    if (failure != null) throw failure;
    _harness().sent.add(recipeId);
  }

  @override
  Future<void> create(Recipe recipe) => _write(recipe.id);

  @override
  Future<void> update(Recipe recipe) => _write(recipe.id);

  @override
  Future<void> delete(String recipeId) async {
    await _write(recipeId);
    _harness().deleted.add(recipeId);
  }
}

/// Jitter at the middle of the band, so every delay is its schedule step.
class MidRandom implements Random {
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => max ~/ 2;
  @override
  bool nextBool() => false;
}

/// A Firestore error with [code], as the SDK throws it.
FirebaseException firestoreError(String code, {String? message}) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

class QueueHarness {
  QueueHarness._(this.db, this.manager);

  static const String uid = 'u1';
  static final DateTime t0 = DateTime(2026, 9, 27, 12);

  final AppDatabase db;
  final OfflineSyncManager manager;

  /// The recipe ids the server received, in order.
  final List<String> sent = [];

  /// The recipe ids the server deleted, in order (also in [sent]).
  final List<String> deleted = [];

  /// The error the next write of a recipe id throws, if any. A failure stays
  /// until removed.
  final Map<String, Object> failWith = {};

  static void registerFallbacks() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  static QueueHarness create() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    late QueueHarness harness;
    final manager = OfflineSyncManager(
      database: db,
      authRepository: auth,
      // A timer that fires during a test never sends: passes are explicit.
      isOnlineNow: () => false,
      random: MidRandom(),
      recipeWriter: HarnessWriter(() => harness),
    );
    return harness = QueueHarness._(db, manager);
  }

  Future<void> dispose() async {
    manager.dispose();
    await db.close();
  }

  /// A recipe on the device that waits to be saved, and its queue entry.
  Future<void> queueRecipe(
    String opId,
    String recipeId, {
    SyncOperation operation = SyncOperation.update,
    List<String> dependsOn = const [],
    DateTime? at,
  }) async {
    final recipe = RecipeFactory.build(id: recipeId, createdBy: uid);
    await db.recipeDao.upsertRecipe(
      id: recipeId,
      userId: uid,
      recipeJson: jsonEncode(recipe.toJson()),
      needsSync: true,
    );
    await withClock(
      Clock.fixed(at ?? t0),
      () => db.syncQueueDao.enqueue(
        userId: uid,
        recipeId: recipeId,
        operation: operation,
        opId: opId,
        dependsOn: dependsOn,
      ),
    );
  }

  /// One pass at [at] (default [t0]).
  Future<void> pass({DateTime? at, bool force = false}) => withClock(
    Clock.fixed(at ?? t0),
    () => manager.syncPendingChanges(isOnline: true, force: force),
  );

  /// The queue's rows by opId.
  Future<Map<String, SyncQueueEntry>> rows() async => {
    for (final e in await db.select(db.syncQueueEntries).get()) e.opId: e,
  };
}
