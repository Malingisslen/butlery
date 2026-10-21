// BUT-2294: a profile picture that waits in the queue is one item the list
// names, and throwing it away leaves messages and the profile alone.

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
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
  late _MockMessaging messaging;
  late OfflineSyncQueueSource source;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final offline = _MockOffline();
    final auth = _MockAuth();
    messaging = _MockMessaging();
    when(() => offline.isInitialized).thenReturn(true);
    when(() => offline.isOnline).thenReturn(false);
    when(() => offline.currentUserId).thenReturn(null);
    when(() => offline.database).thenReturn(db);
    when(() => offline.refreshSyncState()).thenAnswer((_) async {});
    when(() => auth.currentUserId).thenReturn('u1');
    TestServiceLocator.registerMock<MessagingRepository>(messaging);
    source = OfflineSyncQueueSource(
      offlineService: offline,
      authRepository: auth,
    );
    await db.uploadQueueDao.queueUpload(
      id: 'row-1',
      userId: 'u1',
      localPath: '/photo.jpg',
      targetPath: 'users/u1/avatars',
      fileSizeBytes: 1,
      entityId: 'u1',
      entityType: SyncQueueEntityType.avatar,
    );
  });

  tearDown(() async {
    await db.close();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test('the list shows one new profile picture', () async {
    final change = (await source.watchChanges().first).draining.single;

    expect(change.isAvatar, isTrue);
    expect(change.isImageGroup, isFalse);
    expect(change.isChatImage, isFalse);
    expect(describeQueuedChange(AppLocalizationsSv(), change), 'Ny profilbild');
  });

  test('a picture that failed says so in one sentence whatever the '
      'cause', () async {
    await db.uploadQueueDao.markPermanentlyFailed(
      'row-1',
      reason: 'permission-denied',
    );

    final change = (await source.watchChanges().first).needsUser.single;

    expect(
      describeQueuedReason(AppLocalizationsSv(), change),
      'Profilbilden kunde inte bytas.',
    );
  });

  test('Släng removes the picture and touches no message', () async {
    await db.uploadQueueDao.markPermanentlyFailed('row-1');
    final change = (await source.watchChanges().first).needsUser.single;

    await source.discard(change);

    expect((await source.watchChanges().first).isEmpty, isTrue);
    verifyZeroInteractions(messaging);
  });
}
