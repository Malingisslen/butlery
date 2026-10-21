// BUT-2294: the seam between the queue and the app. The completion class is
// tested with a stub author and announcer; this pins the real lookups that a
// queued snap goes through, because a snap is public and cannot be taken back.

import 'dart:io';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/messaging/pending_image_status.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline/chat_image_queue_metadata.dart';
import 'package:butlery/services/offline/cook_snap_queue_metadata.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/upload_queue_wiring.dart';
import 'package:butlery/services/user_service.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _Repository extends Fake implements CookSnapRepository {
  final List<CookSnap> created = [];

  @override
  Future<bool> ownSnapExists(String snapId) async => false;

  @override
  Future<CookSnap> addCookSnap(CookSnap snap) async {
    created.add(snap);
    return snap;
  }
}

class _Messaging extends Fake implements MessagingRepository {
  final List<String> attached = [];

  @override
  Future<PendingImageStatus> pendingImageStatus({
    required String messageId,
    required String userId,
    required String conversationId,
  }) async => const PendingImageStatus(PendingImageState.waiting);

  @override
  Future<void> attachPendingImage({
    required String messageId,
    required String imageUrl,
  }) async => attached.add('$messageId:$imageUrl');
}

class _Announcer extends Fake implements CookSnapService {
  final List<String> announced = [];

  @override
  void announceCookSnap(
    CookSnap snap, {
    required String recipeAuthorId,
    required String recipeName,
    required String senderName,
  }) => announced.add('${snap.id}:$recipeAuthorId:$recipeName:$senderName');
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
  });

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late _Repository repository;
  late _Announcer announcer;
  late _Messaging messaging;
  late MockUserService userService;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('upload_wiring');
    storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    repository = _Repository();
    announcer = _Announcer();
    messaging = _Messaging();
    userService = MockUserService();
    TestServiceLocator.registerMock<CookSnapRepository>(repository);
    TestServiceLocator.registerMock<CookSnapService>(announcer);
    TestServiceLocator.registerMock<UserService>(userService);
    TestServiceLocator.registerMock<MessagingRepository>(messaging);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  /// Queues a one-photo snap whose photo is already in Storage, so the pass
  /// goes straight to creating the snap.
  Future<String> queueUploadedSnap() async {
    final file = File('${root.path}/photo.jpg')..writeAsBytesSync([1]);
    final ids = await withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: [file.path],
        entityType: SyncQueueEntityType.cookSnap,
        entityId: 'snap-1',
        userId: uid,
        targetPath: 'users/$uid/recipes',
        metadata: cookSnapQueueMetadata(
          recipeId: 'recipe-1',
          recipeAuthorId: 'author-1',
          recipeName: 'Kladdkaka',
          visibility: CookSnapVisibility.onlyMe,
        ),
      ),
    );
    await db.uploadQueueDao.markUploaded(
      ids.single,
      url: 'https://img/${ids.single}.jpg',
      thumbnailUrl: 'https://img/${ids.single}_thumb.jpg',
    );
    return ids.single;
  }

  Future<void> pass() => withClock(
    Clock.fixed(t0),
    () => buildUploadQueueProcessor(database: db, storage: storage).runPass(
      uid,
      now: t0,
      isCurrentUser: () => true,
      force: true,
    ),
  );

  test('a snap is not published while the loaded profile is missing or '
      'belongs to another account', () async {
    final rowId = await queueUploadedSnap();

    when(() => userService.currentUserProfile).thenReturn(null);
    await pass();
    expect(repository.created, isEmpty);

    when(() => userService.currentUserProfile).thenReturn(
      WidgetMockFactory.createTestUserProfile(id: 'someone-else'),
    );
    await pass();

    expect(repository.created, isEmpty);
    expect(announcer.announced, isEmpty);
    expect((await db.uploadQueueDao.getUpload(rowId))!.status, 'uploaded');
  });

  test('a snap is published under the name and picture of the signed-in '
      'profile and announced through the cook snap service', () async {
    await queueUploadedSnap();
    when(() => userService.currentUserProfile).thenReturn(
      WidgetMockFactory.createTestUserProfile(
        id: uid,
        displayName: 'Malin',
        avatarUrl: 'https://img/me',
      ),
    );

    await pass();

    final snap = repository.created.single;
    expect(snap.userDisplayName, 'Malin');
    expect(snap.userAvatarUrl, 'https://img/me');
    expect(announcer.announced, ['snap-1:author-1:Kladdkaka:Malin']);
  });

  test('a chat image is handed to the messaging repository under its message '
      'id', () async {
    final file = File('${root.path}/chat.jpg')..writeAsBytesSync([1]);
    final ids = await withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: [file.path],
        entityType: SyncQueueEntityType.chatImage,
        entityId: 'msg-7',
        userId: uid,
        targetPath: 'users/$uid/chat_images',
        metadata: chatImageQueueMetadata(conversationId: 'conv-1'),
      ),
    );
    final rowId = ids.single;
    await db.uploadQueueDao.markUploaded(
      rowId,
      url: 'https://img/$rowId.jpg',
      thumbnailUrl: null,
    );

    await pass();

    expect(messaging.attached, ['msg-7:https://img/$rowId.jpg']);
    expect(await db.uploadQueueDao.getUpload(rowId), isNull);
  });
}
