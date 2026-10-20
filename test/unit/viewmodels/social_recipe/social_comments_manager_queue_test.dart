/// BUT-2294 PR 7: a comment with photos written without a connection waits on
/// the device with them. These tests run the real manager over a real
/// in-memory upload queue: what is queued, what the user is told when a second
/// comment would follow, and that a refused text never reaches the queue.
library;

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/social_recipe/social_comments_manager.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/synthetic_jpeg.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialOps extends Mock implements SocialRecipeOperations {}

class _Permission extends Fake implements PermissionService {
  @override
  String? get currentUserId => 'u1';
}

class _RefusingFilter extends Fake implements ContentFilterService {
  @override
  ContentFilterResult ensureClean(String text, {required String fieldName}) =>
      ContentFilterResult.rejected(reason: 'Inte okej', fieldName: fieldName);
}

class _Offline extends Fake implements OfflineService {
  _Offline(this.userStorage);

  @override
  final OfflineUserStorage userStorage;

  bool queueReady = true;

  @override
  bool get isQueueReady => queueReady;

  int refreshed = 0;

  @override
  Future<void> refreshSyncState() async => refreshed++;
}

void main() {
  const uid = 'u1';
  late AppDatabase db;
  late Directory dir;
  late _Offline offline;
  late _MockRecipeService recipeService;
  late _MockSocialOps social;
  late List<String> photos;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
    await BaseUnitTest.setupUnit();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('comment_queue_manager');
    offline = _Offline(
      OfflineUserStorage(database: db, uploadsRoot: () async => dir),
    );
    TestServiceLocator.registerMock<PermissionService>(_Permission());
    TestServiceLocator.registerMock<OfflineService>(offline);

    photos = [
      for (var i = 0; i < 3; i++)
        (File(
          '${dir.path}/pick$i.jpg',
        )..writeAsBytesSync(syntheticJpeg())).path,
    ];

    recipeService = _MockRecipeService();
    social = _MockSocialOps();
    when(() => recipeService.social).thenReturn(social);
    when(
      () => social.addComment(
        recipeId: any(named: 'recipeId'),
        content: any(named: 'content'),
        parentCommentId: any(named: 'parentCommentId'),
        imageUrls: any(named: 'imageUrls'),
      ),
    ).thenAnswer((_) async => 'comment-1');
    when(
      () => social.getComments(
        recipeId: any(named: 'recipeId'),
        limit: any(named: 'limit'),
        before: any(named: 'before'),
        includeReplies: any(named: 'includeReplies'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  SocialCommentsManager manager({String text = 'Mycket gott!'}) {
    final m = SocialCommentsManager(
      recipeService,
      maturityHelper: FakeMaturedAccountHelper(),
    );
    m.updateNewCommentText(text);
    return m;
  }

  Future<List<UploadQueueEntry>> rows() =>
      db.select(db.uploadQueueEntries).get();

  test('the photos and the text are queued as ONE comment, '
      'for the signed-in user', () async {
    final m = manager()..setReplyTo('parent-1');

    await m.queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(2).toList(),
    );

    final queued = await rows();
    expect(queued, hasLength(2));
    expect(
      queued.map((r) => r.entityType).toSet(),
      {SyncQueueEntityType.comment},
    );
    expect(queued.map((r) => r.entityId).toSet(), hasLength(1));
    expect(queued.every((r) => r.userId == uid), isTrue);
    expect(
      queued.every((r) => r.targetPath == 'users/$uid/comment_images'),
      isTrue,
    );
    final first = queued.firstWhere((r) => r.metadata!.contains('"order":0'));
    expect(first.metadata, contains('"recipeId":"r1"'));
    expect(first.metadata, contains('"text":"Mycket gott!"'));
    expect(first.metadata, contains('"parentCommentId":"parent-1"'));
    expect(first.metadata, contains('"recipeName":"Kladdkaka"'));
    expect(offline.refreshed, 1);
    final list = await readQueuedChanges(db, uid);
    expect(list.single.isCommentGroup, isTrue);
    expect(list.single.photoCount, 2);
    verifyNever(
      () => social.addComment(
        recipeId: any(named: 'recipeId'),
        content: any(named: 'content'),
        parentCommentId: any(named: 'parentCommentId'),
        imageUrls: any(named: 'imageUrls'),
      ),
    );
  });

  test('the form is emptied once the comment is queued', () async {
    final m = manager()..setReplyTo('parent-1');

    await m.queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos,
    );

    expect(m.newCommentText, isEmpty);
    expect(m.isReplying, isFalse);
  });

  test('a second comment waits: while one is queued, another with photos '
      'and a text-only comment both get the waiting notice and queue '
      'nothing', () async {
    await manager().queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );
    final before = (await rows()).length;

    await expectLater(
      manager().queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: photos.take(1).toList(),
      ),
      throwsA(isA<CommentAwaitingSendException>()),
    );
    await expectLater(
      manager().postComment('r1'),
      throwsA(isA<CommentAwaitingSendException>()),
    );

    expect((await rows()).length, before);
    verifyNever(
      () => social.addComment(
        recipeId: any(named: 'recipeId'),
        content: any(named: 'content'),
        parentCommentId: any(named: 'parentCommentId'),
        imageUrls: any(named: 'imageUrls'),
      ),
    );
  });

  test('once the queued comment is thrown away the user can comment '
      'again', () async {
    await manager().queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );
    final queued = (await readQueuedChanges(db, uid)).single;
    for (final row in await rows()) {
      await db.uploadQueueDao.markPermanentlyFailed(row.id, reason: 'x');
    }
    await discardQueuedChange(
      db,
      uid,
      (await readQueuedChanges(db, uid)).single,
    );
    expect(queued.isCommentGroup, isTrue);

    await manager().postComment('r1');

    verify(
      () => social.addComment(
        recipeId: 'r1',
        content: 'Mycket gott!',
        parentCommentId: null,
        imageUrls: const [],
      ),
    ).called(1);
  });

  test('a comment discarded after one of its photos was uploaded no longer '
      'holds the user, though the uploaded photo\'s row stays for its '
      'take-back', () async {
    await manager().queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(2).toList(),
    );
    final ids = [for (final r in await rows()) r.id];
    await db.uploadQueueDao.markUploaded(ids.first, url: 'https://img/0.jpg');
    await db.uploadQueueDao.markPermanentlyFailed(ids.last, reason: 'x');
    await discardQueuedChange(
      db,
      uid,
      (await readQueuedChanges(db, uid)).single,
    );
    final left = await rows();
    expect(left.single.status, 'cancelled');
    expect(left.single.uploadedUrl, 'https://img/0.jpg');

    await manager().postComment('r1');

    verify(
      () => social.addComment(
        recipeId: 'r1',
        content: 'Mycket gott!',
        parentCommentId: null,
        imageUrls: const [],
      ),
    ).called(1);
  });

  test(
    'a comment whose photos are all done no longer holds the user',
    () async {
      await manager().queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: photos.take(2).toList(),
      );
      for (final row in await rows()) {
        await db.uploadQueueDao.markCompleted(row.id);
      }

      await manager().postComment('r1');

      verify(
        () => social.addComment(
          recipeId: 'r1',
          content: 'Mycket gott!',
          parentCommentId: null,
          imageUrls: const [],
        ),
      ).called(1);
    },
  );

  test('where the device has no queue (the web) a text comment is not held '
      'by one', () async {
    await manager().queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );
    offline.queueReady = false;

    await manager().postComment('r1');

    verify(
      () => social.addComment(
        recipeId: 'r1',
        content: 'Mycket gott!',
        parentCommentId: null,
        imageUrls: const [],
      ),
    ).called(1);
  });

  test('a recipe image waiting in the queue does not hold a comment', () async {
    await db.uploadQueueDao.queueUpload(
      id: 'img-1',
      userId: uid,
      localPath: '/x/img-1.jpg',
      targetPath: 'users/$uid/recipes',
      fileSizeBytes: 1,
      entityId: 'r9',
      entityType: SyncQueueEntityType.recipe,
    );

    await manager().postComment('r1');

    verify(
      () => social.addComment(
        recipeId: 'r1',
        content: 'Mycket gott!',
        parentCommentId: null,
        imageUrls: const [],
      ),
    ).called(1);
  });

  test('another user\'s queued comment does not hold this user\'s', () async {
    await db.uploadQueueDao.queueUpload(
      id: 'row-x',
      userId: 'u2',
      localPath: '/x/row-x.jpg',
      targetPath: 'users/u2/comment_images',
      fileSizeBytes: 1,
      entityId: 'c9',
      entityType: SyncQueueEntityType.comment,
    );

    await manager().queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );

    expect(await rows(), hasLength(2));
  });

  test('an empty text queues nothing', () async {
    final m = manager(text: '   ');

    await m.queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );

    expect(await rows(), isEmpty);
    expect(offline.refreshed, 0);
  });

  test('a text the content filter refuses is not queued, and the form says '
      'why', () async {
    // Same line of defence as online: the text must be clean when it is
    // written, not when the queue sends it.
    TestServiceLocator.registerMock<ContentFilterService>(_RefusingFilter());
    final m = manager();

    await m.queueCommentOffline(
      'r1',
      recipeName: 'Kladdkaka',
      imagePaths: photos.take(1).toList(),
    );

    expect(await rows(), isEmpty);
    expect(m.commentsError, 'Inte okej');
    expect(m.newCommentText, 'Mycket gott!', reason: 'the text is kept');
  });

  test('a comment with no photo is not queued', () async {
    await expectLater(
      manager().queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: const [],
      ),
      throwsArgumentError,
    );

    expect(await rows(), isEmpty);
  });

  test('an over-long text or a fourth photo is refused before anything is '
      'copied or queued', () async {
    final long = 'a' * (RecipeComment.maxContentLength + 1);
    await expectLater(
      manager(text: long).queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: photos.take(1).toList(),
      ),
      throwsArgumentError,
    );
    await expectLater(
      manager().queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: [...photos, photos.first],
      ),
      throwsArgumentError,
    );

    expect(await rows(), isEmpty);
    expect(dir.listSync().whereType<Directory>(), isEmpty);
  });
}
