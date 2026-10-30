// Sign-out removes cached reads but never the offline write queue.

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/read_cache_sweep.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seed(AppDatabase db, String userId) async {
  await db.customStatement(
    'INSERT INTO json_cache_entries (box_name, user_id, key, value, cached_at) '
    "VALUES ('recipes', '$userId', 'k', '{}', 1700000000)",
  );
  await db.customStatement(
    'INSERT INTO json_cache_entries (box_name, user_id, key, value, cached_at) '
    "VALUES ('shopping', '$userId', 'k', '{}', 1700000000)",
  );
  await db.customStatement(
    'INSERT INTO parse_cache_entries (cache_key, user_id, recipe_json, '
    "parser_version, source, cached_at) VALUES ('c-$userId', '$userId', "
    "'{}', '1', 'url', 1700000000)",
  );
  await db.customStatement(
    'INSERT INTO sync_queue_entries (user_id, recipe_id, operation, queued_at, '
    "op_id) VALUES ('$userId', 'r1', 'update', 1700000000, 'op-$userId')",
  );
  await db.customStatement(
    'INSERT INTO upload_queue_entries (id, user_id, local_path, target_path, '
    'file_size_bytes, queued_at) VALUES '
    "('up-$userId', '$userId', '/a.jpg', 'users/x', 10, 1700000000)",
  );
}

Future<int> _count(AppDatabase db, String table, [String? userId]) async {
  final where = userId == null ? '' : " WHERE user_id = '$userId'";
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table$where')
      .getSingle();
  return row.read<int>('n');
}

class _SignedIn implements AuthRepository {
  _SignedIn(this.currentUserId);

  @override
  final String? currentUserId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seed(db, 'u1');
    await _seed(db, 'u2');
  });

  tearDown(() => db.close());

  test('clearUserReadCaches removes every box for that user only', () async {
    await db.cacheDao.clearUserReadCaches('u1');

    expect(await _count(db, 'json_cache_entries', 'u1'), 0);
    expect(await _count(db, 'parse_cache_entries', 'u1'), 0);
    expect(await _count(db, 'json_cache_entries', 'u2'), 2);
    expect(await _count(db, 'parse_cache_entries', 'u2'), 1);
  });

  test('the write queue survives a read-cache clear', () async {
    await db.cacheDao.clearUserReadCaches('u1');

    expect(await _count(db, 'sync_queue_entries', 'u1'), 1);
    expect(await _count(db, 'upload_queue_entries', 'u1'), 1);
  });

  test('clearReadCachesExcept keeps only the signed-in user', () async {
    await db.cacheDao.clearReadCachesExcept('u2');

    expect(await _count(db, 'json_cache_entries', 'u1'), 0);
    expect(await _count(db, 'parse_cache_entries', 'u1'), 0);
    expect(await _count(db, 'json_cache_entries', 'u2'), 2);
    expect(await _count(db, 'sync_queue_entries'), 2);
  });

  test('clearReadCachesExcept(null) drops every account', () async {
    await db.cacheDao.clearReadCachesExcept(null);

    expect(await _count(db, 'json_cache_entries'), 0);
    expect(await _count(db, 'parse_cache_entries'), 0);
    expect(await _count(db, 'upload_queue_entries'), 2);
  });

  test(
    'the start-up sweep keeps the signed-in user and drops the rest',
    () async {
      await sweepReadCaches(db, _SignedIn('u2'));

      expect(await _count(db, 'json_cache_entries', 'u1'), 0);
      expect(await _count(db, 'json_cache_entries', 'u2'), 2);
    },
  );

  test(
    'the start-up sweep does nothing while nobody is known to be signed in',
    () async {
      await sweepReadCaches(db, _SignedIn(null));

      expect(await _count(db, 'json_cache_entries'), 4);
    },
  );
}
