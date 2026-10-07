/// Flow 08's offline queue, from the write a screen makes to the server.
///
/// The recipe module, the device database, the user storage and the sync
/// manager are the real ones. What stands in is the edge: the server's
/// recipe writer, the image uploader, the connectivity flag, and the
/// [OfflineService] shell, which cannot open its own database on a test
/// machine (it opens an encrypted file) and so hands the module the same
/// calls over the real parts.
library;

import 'dart:async';
import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:clock/clock.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../unit/services/offline/queue_harness.dart'
    show MidRandom, QueueHarness;

/// What reached the server, with the recipe as sent, and the failure the
/// next write of a recipe id throws.
class RecordingWriter implements QueuedRecipeWriter {
  final List<(String, Recipe?, String)> writes = [];
  final Map<String, Object> failWith = {};

  Future<void> _write(String op, String id, Recipe? recipe) async {
    final failure = failWith[id];
    if (failure != null) throw failure;
    writes.add((op, recipe, id));
  }

  @override
  Future<void> create(Recipe recipe) => _write('create', recipe.id, recipe);

  @override
  Future<void> update(Recipe recipe) => _write('update', recipe.id, recipe);

  @override
  Future<void> delete(String recipeId) => _write('delete', recipeId, null);

  List<String> get ops => [for (final w in writes) '${w.$1}:${w.$3}'];
}

/// The calls [PersonalRecipeModule] and the queue screens make on
/// [OfflineService], over a real database, storage and sync manager.
class QueueBackedOfflineService extends ChangeNotifier
    implements OfflineService {
  QueueBackedOfflineService(this._db, this._storage);

  final AppDatabase _db;
  final OfflineUserStorage _storage;
  late final OfflineSyncManager manager;
  bool online = false;

  /// The connection drops, as the connectivity monitor reports it.
  void goOffline() {
    online = false;
    notifyListeners();
  }

  /// The connection returns: the monitor's reconnect callback sends the
  /// queue (OfflineService.initialize, onReconnected). Resolves when that
  /// pass is over.
  Future<void> reconnect() {
    online = true;
    notifyListeners();
    _inFlight = manager.syncPendingChanges(isOnline: true);
    return _inFlight;
  }

  Future<void> _inFlight = Future<void>.value();

  /// Resolves when the send the last write started is over.
  Future<void> settle() => _inFlight;

  void _sendWhenOnline() {
    if (online) {
      _inFlight = manager.syncPendingChanges(isOnline: true);
    }
  }

  @override
  bool get isOnline => online;

  @override
  bool get isInitialized => true;

  @override
  bool get isQueueReady => true;

  @override
  String? get currentUserId => null;

  @override
  AppDatabase get database => _db;

  @override
  Future<void> refreshSyncState() async => notifyListeners();

  @override
  Future<String> queueRecipeWrite(
    Recipe recipe,
    String userId, {
    required SyncOperation operation,
    bool queueTagging = false,
  }) async {
    final opId = await _storage.saveRecipeForUser(
      recipe,
      userId,
      operation: operation,
      queueTagging: queueTagging,
    );
    await refreshSyncState();
    _sendWhenOnline();
    return opId;
  }

  @override
  Future<bool> queueRecipeDelete(String recipeId, String userId) async {
    final queued = await _storage.queueDeleteForUser(recipeId, userId);
    await refreshSyncState();
    _sendWhenOnline();
    return queued;
  }

  @override
  Future<void> queueRecipeImage(
    String imagePath,
    String recipeId,
    String userId,
  ) async {
    await _storage.queueRecipeImageForUser(imagePath, recipeId, userId);
    await refreshSyncState();
    _sendWhenOnline();
  }

  @override
  Future<SyncResult> syncNow() async {
    final pass = manager.syncNow(isOnline: online);
    _inFlight = pass.then((_) {});
    final result = await pass;
    await refreshSyncState();
    return result;
  }

  @override
  Future<void> clearUserData(String userId) async {
    await _storage.clearUserData(userId);
    await refreshSyncState();
  }

  @override
  Future<bool> hasUnsentRecipeWrite(String recipeId, String userId) =>
      _storage.hasUnsentWrite(recipeId, userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueueJourney {
  QueueJourney._();

  static const String uid = QueueHarness.uid;
  static final DateTime t0 = QueueHarness.t0;

  late final AppDatabase db;
  late final Directory uploads;
  late final QueueBackedOfflineService offline;
  late final FakeAuthRepository auth;
  late final PersonalRecipeModule recipes;
  final RecordingWriter writer = RecordingWriter();
  final List<String> uploaded = [];
  final List<String> errors = [];

  static Future<QueueJourney> open() async {
    QueueHarness.registerFallbacks();
    final j = QueueJourney._();
    j.db = AppDatabase.forTesting(NativeDatabase.memory());
    j.uploads = await Directory.systemTemp.createTemp('flow08-uploads');
    final storage = OfflineUserStorage(
      database: j.db,
      uploadsRoot: () async => j.uploads,
    );
    j.auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    j.offline = QueueBackedOfflineService(j.db, storage);
    j.offline.manager = OfflineSyncManager(
      database: j.db,
      authRepository: j.auth,
      isOnlineNow: () => j.offline.online,
      random: MidRandom(),
      recipeWriter: j.writer,
      uploadImage: (localPath, userId) async {
        j.uploaded.add(localPath);
        final name = localPath.split('/').last;
        return (url: 'https://img/$name', thumbnailUrl: 'https://thumb/$name');
      },
      userStorage: storage,
    );
    j.recipes = PersonalRecipeModule(
      recipeRepository: MockRecipeRepository(),
      userRepository: MockUserRepository(),
      getCacheHelper: FakeJsonCacheHelper.new,
      getCurrentUserId: () => uid,
      getCurrentUserDisplayName: () => 'Anna',
      setError: j.errors.add,
      notifyListeners: () {},
      getServiceAdapter: MockRecipeServiceAdapter.new,
      getOfflineQueue: () => j.offline,
    );
    return j;
  }

  Future<void> close() async {
    offline.manager.dispose();
    offline.dispose();
    await db.close();
    await uploads.delete(recursive: true);
  }

  /// A reconnect pass at [at]: the queue sends what is due.
  Future<void> pass({DateTime? at, bool force = false}) => withClock(
    Clock.fixed(at ?? t0),
    () => offline.manager.syncPendingChanges(isOnline: true, force: force),
  );

  /// A recipe written through the module at [at]; returns its id.
  Future<String> write(String title, {DateTime? at}) => withClock(
    Clock.fixed(at ?? t0),
    () async {
      final id = await recipes.createPersonalRecipe(
        title: title,
        ingredients: ['1 gul lök'],
        instructions: ['Koka'],
      );
      await offline.settle();
      return id!;
    },
  );

  /// The recipe the last [write] created, as the module kept it.
  Recipe? get lastCreated => recipes.popLastCreatedRecipe();

  /// A picked image outside the queue's folder.
  File pickedImage(String name) {
    final dir = Directory.systemTemp.createTempSync(name);
    return File('${dir.path}/$name.jpg')..writeAsBytesSync([1, 2]);
  }

  Future<List<QueueEntryRow>> queued() async => [
    for (final e in await db.select(db.syncQueueEntries).get())
      QueueEntryRow(e.opId, e.recipeId, e.operation, e.permanentlyFailed),
  ];
}

class QueueEntryRow {
  QueueEntryRow(this.opId, this.recipeId, this.operation, this.failed);

  final String opId;
  final String recipeId;
  final String operation;
  final bool failed;
}

class JourneyAuthService implements AuthService {
  int signOuts = 0;

  @override
  String? get currentUserId => QueueJourney.uid;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class JourneyProfileViewModel implements ProfileViewModel {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class JourneyDiModule implements DIModule {
  JourneyDiModule(this.auth, this.profile, this.offline);

  final JourneyAuthService auth;
  final JourneyProfileViewModel profile;
  final OfflineService offline;

  @override
  String get name => 'Flow08QueueModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [
    AuthService,
    ProfileViewModel,
    OfflineService,
  ];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<AuthService>(auth);
    container.registerSingleton<ProfileViewModel>(profile);
    container.registerSingleton<OfflineService>(offline);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
