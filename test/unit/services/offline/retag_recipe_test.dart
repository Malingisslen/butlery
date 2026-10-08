// BUT-2296: retagging calls the network between reading the device's copy
// and writing the tags back. Whatever the user did to the copy in that gap
// wins over the tags.

import 'dart:async';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  const uid = 'u1';
  late AppDatabase db;
  late OfflineUserStorage storage;
  late Recipe recipe;

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
  });

  tearDown(() => db.close());

  Future<int> queued() async =>
      (await db.select(db.syncQueueEntries).get()).length;

  test('an unchanged copy gets the tags and a queued update', () async {
    final retagged = await storage.retagRecipeForUser(
      recipe.id,
      uid,
      (_) async => TagResult.empty(),
    );

    expect(retagged, isTrue);
    expect(await queued(), 2);
    final stored = await storage.getRecipeForUser(recipe.id, uid);
    expect(stored?.core.tagResult, isNotNull);
  });

  test('a recipe thrown away while tagging stays thrown away', () async {
    final tagging = Completer<TagResult?>();
    final retag = storage.retagRecipeForUser(
      recipe.id,
      uid,
      (_) => tagging.future,
    );
    await Future<void>.delayed(Duration.zero);
    await db.clearUserData(uid);
    tagging.complete(TagResult.empty());

    expect(await retag, isFalse);
    expect(await storage.getRecipeForUser(recipe.id, uid), isNull);
    expect(await queued(), 0);
  });

  test('an edit made while tagging is not overwritten', () async {
    final tagging = Completer<TagResult?>();
    final retag = storage.retagRecipeForUser(
      recipe.id,
      uid,
      (_) => tagging.future,
    );
    await Future<void>.delayed(Duration.zero);
    final edited = RecipeFactory.build(id: recipe.id, title: 'Ändrad titel');
    await storage.saveRecipeForUser(edited, uid, queueTagging: false);
    tagging.complete(TagResult.empty());

    expect(await retag, isFalse);
    final stored = await storage.getRecipeForUser(recipe.id, uid);
    expect(stored?.title, 'Ändrad titel');
  });
}
