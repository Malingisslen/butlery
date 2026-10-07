// BUT-2296: "Logga ut och släng" and account deletion empty the device
// through OfflineUserStorage.clearUserData. A failure there must reach the
// caller, and a success must leave nothing of the user behind.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  late AppDatabase db;
  late Directory root;

  setUpAll(() async => BaseUnitTest.setupUnit());

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('uploads');
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> seed(OfflineUserStorage storage, String uid) async {
    await storage.saveRecipeForUser(
      RecipeFactory.build(id: 'r-$uid'),
      uid,
      operation: SyncOperation.create,
      queueTagging: false,
    );
    await db
        .into(db.jsonCacheEntries)
        .insert(
          JsonCacheEntriesCompanion.insert(
            boxName: 'box',
            userId: uid,
            key: 'json',
            value: '{}',
            cachedAt: DateTime(2026, 10, 7),
          ),
        );
    await db
        .into(db.parseCacheEntries)
        .insert(
          ParseCacheEntriesCompanion.insert(
            cacheKey: 'parse-$uid',
            userId: uid,
            recipeJson: '{}',
            parserVersion: '1',
            source: 'text',
            cachedAt: DateTime(2026, 10, 7),
          ),
        );
  }

  test('clears every table and the image copies of that user only', () async {
    final storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => root,
    );
    await seed(storage, 'anna');
    await seed(storage, 'bo');
    final copies = Directory('${root.path}/anna')..createSync();
    File('${copies.path}/a.jpg').writeAsBytesSync([1]);

    await storage.clearUserData('anna');

    final owners = {
      'recipes': (await db.select(db.offlineRecipes).get()).map(
        (r) => r.userId,
      ),
      'sync': (await db.select(db.syncQueueEntries).get()).map((r) => r.userId),
      'json': (await db.select(db.jsonCacheEntries).get()).map((r) => r.userId),
      'parse':
          (await db
                  .select(
                    db.parseCacheEntries,
                  )
                  .get())
              .map((r) => r.userId),
    };
    owners.forEach(
      (table, uids) => expect(uids.toSet(), {'bo'}, reason: table),
    );
    expect(copies.existsSync(), isFalse);
  });

  test('a failed image delete reaches the caller', () async {
    final storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => throw const FileSystemException('denied'),
    );

    await expectLater(
      storage.clearUserData('anna'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'a failed database delete reaches the caller and clears nothing',
    () async {
      final storage = OfflineUserStorage(
        database: db,
        uploadsRoot: () async => root,
      );
      await seed(storage, 'anna');
      await db.customStatement(
        'DROP TABLE ${db.parseCacheEntries.actualTableName}',
      );

      await expectLater(storage.clearUserData('anna'), throwsA(anything));
      expect(await db.select(db.offlineRecipes).get(), isNotEmpty);
      expect(await db.select(db.syncQueueEntries).get(), isNotEmpty);
    },
  );
}
