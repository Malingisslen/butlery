// BUT-1508: the offline store reaches the tagging service and the realtime
// service through its links, not through the global locator.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';
import 'offline_links_support.dart';

class _Auth extends Mock implements AuthRepository {}

class _Tagging extends Mock implements TaggingService {}

class _Realtime extends Mock implements RealtimeSyncService {}

void main() {
  setUpAll(() => registerFallbackValue(RecipeFactory.build()));

  const uid = 'u1';
  late AppDatabase db;
  late OfflineUserStorage storage;
  late Recipe recipe;
  late OfflineService offline;

  setUpAll(() async => BaseUnitTest.setupUnit());

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = OfflineUserStorage(database: db);
    recipe = RecipeFactory.build();
    await storage.saveRecipeForUser(
      recipe,
      uid,
      operation: SyncOperation.create,
      queueTagging: false,
    );
    OfflineService.resetForTesting();
    offline = OfflineService(authRepository: _Auth())
      ..attachUserStorageForTesting(storage);
  });

  tearDown(() async {
    OfflineService.resetForTesting();
    await db.close();
  });

  test('a recipe is retagged by the tagging service the links name', () async {
    final tagging = _Tagging();
    when(() => tagging.generateTags(any())).thenAnswer(
      (_) async => TagResult.empty(),
    );
    offline.links = testLinks(tagging: () => tagging);

    await offline.retagRecipe(recipe.id, uid);

    verify(() => tagging.generateTags(any())).called(1);
    expect(
      (await storage.getRecipeForUser(recipe.id, uid))?.core.tagResult,
      isNotNull,
    );
  });

  test('without links a retag is a failure the sync manager retries', () async {
    await expectLater(
      offline.retagRecipe(recipe.id, uid),
      throwsA(isA<StateError>()),
    );
  });

  test('a queued recipe conflict is announced by the realtime service the '
      'links name', () async {
    final realtime = _Realtime();
    final remote = RecipeFactory.build();
    when(
      () => realtime.announceQueuedRecipeConflict(any(), any()),
    ).thenAnswer((_) async {});
    offline.links = testLinks(realtimeSync: () => realtime);

    offline.announceQueuedConflict(recipe, remote);

    verify(
      () => realtime.announceQueuedRecipeConflict(recipe, remote),
    ).called(1);
  });

  test('a conflict with no realtime service registered is dropped', () {
    offline.links = testLinks();

    expect(
      () => offline.announceQueuedConflict(recipe, recipe),
      returnsNormally,
    );
  });
}
