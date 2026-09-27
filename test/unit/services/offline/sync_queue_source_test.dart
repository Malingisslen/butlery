// P4-U19: the real queue source finds the signed-in user the way the sync
// manager does (AuthRepository.currentUserId), not through
// OfflineService.currentUserId, which the app never sets. Otherwise the view
// would say "Allt är sparat" while changes wait (produktregler.md:191).

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOffline extends Mock implements OfflineService {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  late AppDatabase db;
  late _MockOffline offline;
  late _MockAuth auth;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offline = _MockOffline();
    auth = _MockAuth();
    when(() => offline.isInitialized).thenReturn(true);
    when(() => offline.isOnline).thenReturn(true);
    // As in the shipped app: nothing ever sets it.
    when(() => offline.currentUserId).thenReturn(null);
    when(() => offline.database).thenReturn(db);
    when(() => offline.refreshSyncState()).thenAnswer((_) async {});
    await db.syncQueueDao.enqueue(
      userId: 'u1',
      recipeId: 'r1',
      operation: SyncOperation.update,
      opId: 'op-1',
    );
  });

  tearDown(() => db.close());

  test('counts and changes come from the signed-in user', () async {
    when(() => auth.currentUserId).thenReturn('u1');
    final source = OfflineSyncQueueSource(
      offlineService: offline,
      authRepository: auth,
    );

    final counts = await source.watchCounts().first;
    expect(counts.waiting, 1);
    final queue = await source.watchChanges().first;
    expect(queue.total, 1);
    expect(queue.draining.single.id, 'op-1');
  });

  test('nobody signed in reads as nothing waiting', () async {
    when(() => auth.currentUserId).thenReturn(null);
    final source = OfflineSyncQueueSource(
      offlineService: offline,
      authRepository: auth,
    );

    expect(await source.watchCounts().first, QueueCounts.empty);
    expect((await source.watchChanges().first).isEmpty, isTrue);
  });

  test('discard acts on the signed-in user', () async {
    when(() => auth.currentUserId).thenReturn('u1');
    final source = OfflineSyncQueueSource(
      offlineService: offline,
      authRepository: auth,
    );
    final change = (await source.watchChanges().first).draining.single;

    await source.discard(change);

    expect((await source.watchChanges().first).isEmpty, isTrue);
    verify(() => offline.refreshSyncState()).called(1);
  });
}
