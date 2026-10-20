// BUT-2294 PR 5a: adding a cook-snap album with no connection keeps the photos
// on the device as one queued group; the snap is created later by the queue.
// The real CookSnapService, the real content filter and a real in-memory queue
// run; only the picker, connectivity and the repository are fakes.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _Repository extends Fake implements CookSnapRepository {
  final List<CookSnap> saved = [];

  @override
  Future<CookSnap> addCookSnap(CookSnap snap) async {
    saved.add(snap);
    return snap;
  }
}

class _FakeFriendsRepository extends Fake implements FriendsRepository {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

/// The queue side of OfflineService: a ready flag and the real storage.
class _FakeOfflineService extends Fake implements OfflineService {
  _FakeOfflineService(this.userStorage, {this.isQueueReady = true});

  @override
  final OfflineUserStorage userStorage;

  @override
  final bool isQueueReady;

  int refreshes = 0;

  @override
  Future<void> refreshSyncState() async => refreshes++;
}

const _uid = 'test-user-123';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(ImageSource.gallery);
  });

  late AppDatabase db;
  late Directory root;
  late _Repository repository;
  late _MockImageUploadService uploads;
  late MockImagePickerService picker;
  late MockConnectivityMonitoringService connectivity;
  late CookSnapService service;
  late List<File> picked;

  Future<void> useOfflineService({bool ready = true}) async {
    final storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    TestServiceLocator.registerMock<OfflineService>(
      _FakeOfflineService(storage, isQueueReady: ready),
    );
  }

  Future<List<UploadQueueEntry>> queued() =>
      db.select(db.uploadQueueEntries).get();

  Future<CookSnapAddResult?> add({String? caption, bool multiple = true}) {
    return service.addCookSnap(
      recipeId: 'recipe-1',
      recipeAuthorId: 'author-1',
      recipeName: 'Köttbullar',
      source: ImageSource.gallery,
      allowMultiple: multiple,
      caption: caption,
      visibility: CookSnapVisibility.onlyMe,
    );
  }

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cook_snap_service_offline');

    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(isAuthenticated: true, userId: _uid),
    );
    connectivity = MockConnectivityMonitoringService();
    when(() => connectivity.isConnectedToInternet).thenReturn(false);
    TestServiceLocator.registerMock<ConnectivityMonitoringService>(
      connectivity,
    );

    picked = [
      for (var i = 0; i < 3; i++)
        File('${root.path}/pick-$i.jpg')..writeAsBytesSync([i]),
    ];
    picker = MockImagePickerService();
    when(
      () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
    ).thenAnswer((_) async => picked);
    when(() => picker.pickImage(any())).thenAnswer((_) async => picked.first);
    TestServiceLocator.registerMock<ImagePickerService>(picker);

    uploads = _MockImageUploadService();
    when(
      () => uploads.uploadImage(
        file: any(named: 'file'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => UploadResult.success('https://img/online.jpg'));
    TestServiceLocator.registerMock<ImageUploadService>(uploads);

    final userService = MockUserService();
    when(() => userService.currentUserProfile).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(userService);
    TestServiceLocator.registerMock<ContentFilterService>(
      ContentFilterService(),
    );

    await useOfflineService();
    repository = _Repository();
    service = CookSnapService(
      repository: repository,
      friendsRepository: _FakeFriendsRepository(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('offline', () {
    test('queues the picked photos as one group, in pick order, and '
        'creates nothing now', () async {
      // Proves: the user's album survives a missing connection as ONE queued
      // group whose rows keep the pick order (the first is the cover).
      final result = await add(caption: 'Gott!');

      expect(result?.queued, isTrue);
      expect(result?.snap, isNull);
      expect(repository.saved, isEmpty);
      verifyNever(
        () => uploads.uploadImage(
          file: any(named: 'file'),
          userId: any(named: 'userId'),
        ),
      );
      final rows = await queued();
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.entityType).toSet(), {
        SyncQueueEntityType.cookSnap,
      });
      expect(rows.map((r) => r.entityId).toSet(), hasLength(1));
      expect(rows.every((r) => r.userId == _uid), isTrue);
      final byOrder = [...rows]
        ..sort((a, b) => a.metadata!.compareTo(b.metadata!));
      for (var i = 0; i < 3; i++) {
        expect(byOrder[i].metadata, contains('"order":$i'));
        expect(File(byOrder[i].localPath).readAsBytesSync(), [i]);
      }
    });

    test('keeps what the completion needs, and no author name or picture, '
        'in the rows', () async {
      // Proves: recipe, audience, caption travel with the photos, while the
      // author's name and avatar are left for the completion to read from the
      // profile at that time.
      await add(caption: 'Gott!');

      final meta = (await queued()).first.metadata!;
      expect(meta, contains('"recipeId":"recipe-1"'));
      expect(meta, contains('"recipeAuthorId":"author-1"'));
      expect(meta, contains('"recipeName":"Köttbullar"'));
      expect(meta, contains('"visibility":"onlyMe"'));
      expect(meta, contains('"caption":"Gott!"'));
      expect(meta.toLowerCase(), isNot(contains('displayname')));
      expect(meta.toLowerCase(), isNot(contains('avatar')));
    });

    test('a caption the content filter refuses stops the add at queue time '
        'and queues nothing', () async {
      // Proves: the same filter and failure as online; a refused caption
      // never waits in the queue to be published later.
      final filter = ContentFilterService();
      const bad = 'fuck';
      expect(
        filter.ensureClean(bad, fieldName: 'x').isClean,
        isFalse,
        reason: 'premise: the filter refuses this caption',
      );

      // executeServiceOperation turns the exception into a null result for a
      // service without a listener; either way nothing may be queued.
      Object? thrown;
      CookSnapAddResult? result;
      try {
        result = await add(caption: bad);
      } catch (e) {
        thrown = e;
      }

      expect(result?.queued, isNot(true));
      expect(thrown != null || result == null, isTrue);
      expect(await queued(), isEmpty);
      verifyNever(
        () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
      );
    });

    test(
      'with no queue (the web) the add is refused before the picker opens',
      () async {
        // Proves: photos are never picked only to be lost.
        await useOfflineService(ready: false);

        Object? thrown;
        CookSnapAddResult? result;
        try {
          result = await add();
        } catch (e) {
          thrown = e;
        }

        expect(thrown != null || result == null, isTrue);
        expect(result?.queued, isNot(true));
        expect(await queued(), isEmpty);
        verifyNever(
          () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
        );
      },
    );

    test('adding the same recipe twice offline makes two albums', () async {
      // Proves: each add is its own snap, so a second album is not merged into
      // the first through the recipe id.
      await add();
      await add();

      final rows = await queued();
      expect(rows, hasLength(6));
      expect(rows.map((r) => r.entityId).toSet(), hasLength(2));
    });

    test('a cancelled pick queues nothing', () async {
      picked = [];
      final result = await add();

      expect(result, isNull);
      expect(await queued(), isEmpty);
    });
  });

  group('online', () {
    test('uploads and creates the snap now, and queues nothing', () async {
      // Proves: the online path is the one it was before this change.
      when(() => connectivity.isConnectedToInternet).thenReturn(true);

      final result = await add(multiple: false);

      expect(result?.queued, isFalse);
      expect(result?.snap, isNotNull);
      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.photoUrls, ['https://img/online.jpg']);
      expect(await queued(), isEmpty);
    });
  });
}
