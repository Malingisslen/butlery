// BUT-2294: a chat image that waits in the queue is one item the list names,
// and throwing it away takes the message it belongs to down with it.

import 'dart:io';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/sync/sync_queue_row.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockOffline extends Mock implements OfflineService {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockMessaging extends Mock implements MessagingRepository {}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
  });

  late AppDatabase db;
  late _MockOffline offline;
  late _MockAuth auth;
  late _MockMessaging messaging;
  late OfflineSyncQueueSource source;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offline = _MockOffline();
    auth = _MockAuth();
    messaging = _MockMessaging();
    when(() => offline.isInitialized).thenReturn(true);
    when(() => offline.isOnline).thenReturn(false);
    when(() => offline.currentUserId).thenReturn(null);
    when(() => offline.database).thenReturn(db);
    when(() => offline.refreshSyncState()).thenAnswer((_) async {});
    when(() => auth.currentUserId).thenReturn('u1');
    when(() => messaging.deleteMessage(any())).thenAnswer((_) async {});
    TestServiceLocator.registerMock<MessagingRepository>(messaging);
    source = OfflineSyncQueueSource(
      offlineService: offline,
      authRepository: auth,
    );
    await db.uploadQueueDao.queueUpload(
      id: 'row-1',
      userId: 'u1',
      localPath: '/photo.jpg',
      targetPath: 'users/u1/chat_images',
      fileSizeBytes: 1,
      entityId: 'msg-1',
      entityType: SyncQueueEntityType.chatImage,
    );
  });

  tearDown(() async {
    await db.close();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<QueuedChange> theItem() async =>
      (await source.watchChanges().first).draining.single;

  test('the list shows one chat image under a name that does not need the '
      'conversation', () async {
    final change = await theItem();

    expect(change.isChatImage, isTrue);
    expect(change.isImageGroup, isFalse);
    expect(
      describeQueuedChange(AppLocalizationsSv(), change),
      'En bild i en chatt',
    );
  });

  test('a chat image that failed says so in one sentence whatever the '
      'cause, so a block is not explained', () async {
    await db.uploadQueueDao.markPermanentlyFailed(
      'row-1',
      reason: 'permission-denied',
    );

    final change = (await source.watchChanges().first).needsUser.single;

    expect(
      describeQueuedReason(AppLocalizationsSv(), change),
      'Bilden kunde inte skickas.',
    );
  });

  test('Släng takes the message down and removes the picture', () async {
    await db.uploadQueueDao.markPermanentlyFailed('row-1');
    final change = (await source.watchChanges().first).needsUser.single;

    await source.discard(change);

    verify(() => messaging.deleteMessage('msg-1')).called(1);
    expect((await source.watchChanges().first).isEmpty, isTrue);
  });

  test('a message that cannot be taken down does not keep the picture in '
      'the list', () async {
    when(
      () => messaging.deleteMessage(any()),
    ).thenAnswer((_) async => throw StateError('offline'));
    await db.uploadQueueDao.markPermanentlyFailed('row-1');
    final change = (await source.watchChanges().first).needsUser.single;

    await source.discard(change);

    expect((await source.watchChanges().first).isEmpty, isTrue);
  });

  test('throwing away something that is not a chat image leaves messages '
      'alone', () async {
    await db.syncQueueDao.enqueue(
      userId: 'u1',
      recipeId: 'r1',
      operation: SyncOperation.update,
      opId: 'op-1',
    );
    final recipe = (await source.watchChanges().first).draining.firstWhere(
      (c) => c.id == 'op-1',
    );

    await source.discard(recipe);

    verifyNever(() => messaging.deleteMessage(any()));
  });

  group('the sender\'s own copy', () {
    late Directory root;
    late OfflineUserStorage storage;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('chat_image_copy');
      storage = OfflineUserStorage(database: db);
    });

    tearDown(() => root.delete(recursive: true));

    Future<void> queue(String id, String path, {String user = 'u1'}) =>
        db.uploadQueueDao.queueUpload(
          id: id,
          userId: user,
          localPath: path,
          targetPath: 'users/$user/chat_images',
          fileSizeBytes: 1,
          entityId: 'msg-2',
          entityType: SyncQueueEntityType.chatImage,
        );

    test('is found by the message while the queue holds it', () async {
      final copy = File('${root.path}/a.jpg')..writeAsBytesSync([1]);
      await queue('row-2', copy.path);

      expect(await storage.chatImageCopyPath('msg-2', 'u1'), copy.path);
    });

    test('is not handed to another account', () async {
      final copy = File('${root.path}/a.jpg')..writeAsBytesSync([1]);
      await queue('row-2', copy.path);

      expect(await storage.chatImageCopyPath('msg-2', 'u2'), isNull);
    });

    test('is gone once the file or the row is', () async {
      await queue('row-2', '${root.path}/missing.jpg');
      expect(await storage.chatImageCopyPath('msg-2', 'u1'), isNull);

      final copy = File('${root.path}/b.jpg')..writeAsBytesSync([1]);
      await queue('row-3', copy.path);
      await db.uploadQueueDao.markCompleted('row-3');
      expect(await storage.chatImageCopyPath('msg-2', 'u1'), isNull);
    });
  });
}
