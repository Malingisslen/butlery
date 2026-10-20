// BUT-2294: a queued comment. Each photo is a row of one group named after the
// comment; the comment is created once, when every photo is in Storage.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/services/offline/comment_queue_metadata.dart';
import 'package:butlery/services/offline/comment_upload_completion.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom, firestoreError;

typedef _Created = ({
  String commentId,
  String recipeId,
  String content,
  String? parent,
  List<String> imageUrls,
});

class _Repository extends Fake implements CommentsRepository {
  final List<_Created> created = [];
  final Set<String> onServer = {};

  /// Thrown by the next creates, one per call, until empty.
  final List<Object> failures = [];

  /// Creates before this time are refused, as the five-second guard does.
  DateTime? refuseUntil;

  /// Whether a create that throws has reached the server all the same.
  bool landsDespiteFailure = false;

  @override
  Future<bool> ownCommentExists(String commentId) async =>
      onServer.contains(commentId);

  @override
  Future<RecipeComment> createQueuedComment({
    required String commentId,
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
    List<String> imageUrls = const [],
  }) async {
    final guard = refuseUntil;
    if (guard != null && clock.now().isBefore(guard)) {
      throw firestoreError('permission-denied');
    }
    if (failures.isNotEmpty) {
      if (landsDespiteFailure) onServer.add(commentId);
      throw failures.removeAt(0);
    }
    created.add((
      commentId: commentId,
      recipeId: recipeId,
      content: content,
      parent: parentCommentId,
      imageUrls: imageUrls,
    ));
    onServer.add(commentId);
    return RecipeComment(
      id: commentId,
      recipeId: recipeId,
      authorId: userId,
      authorDisplayName: 'Malin',
      text: content,
      createdAt: clock.now(),
    );
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late _Repository repository;
  late List<String> taken;
  late List<String> uploadFolders;
  late Set<String> uploadFails;
  late UploadQueueProcessor processor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('comment_queue');
    storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    repository = _Repository();
    taken = [];
    uploadFolders = [];
    uploadFails = {};
    processor = UploadQueueProcessor(
      database: db,
      storage: storage,
      upload:
          (
            String localPath,
            String userId,
            String objectId,
            String targetPath,
          ) async {
            uploadFolders.add(targetPath);
            if (uploadFails.contains(objectId)) {
              throw firestoreError('unavailable');
            }
            return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
          },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return true;
      },
      completions: {
        SyncQueueEntityType.comment: CommentUploadCompletion(
          database: db,
          storage: storage,
          repository: () => repository,
        ),
      },
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<List<String>> queueComment(
    String commentId, {
    int photos = 2,
    String text = 'Så gott!',
    String? parent,
  }) async {
    final sources = <String>[];
    for (var i = 0; i < photos; i++) {
      final file = File('${root.path}/$commentId-$i.jpg');
      await file.writeAsBytes([i]);
      sources.add(file.path);
    }
    return withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: sources,
        entityType: SyncQueueEntityType.comment,
        entityId: commentId,
        userId: uid,
        targetPath: 'users/$uid/comment_images',
        metadata: commentQueueMetadata(
          recipeId: 'recipe-1',
          recipeName: 'Kladdkaka',
          text: text,
          parentCommentId: parent,
        ),
      ),
    );
  }

  Future<int> pass({Duration after = Duration.zero}) => withClock(
    Clock.fixed(t0.add(after)),
    () => processor.runPass(
      uid,
      now: t0.add(after),
      isCurrentUser: () => true,
      force: true,
    ),
  );

  Future<UploadQueueEntry?> row(String id) => db.uploadQueueDao.getUpload(id);

  test('a comment is created once, under its own id, with its text, parent '
      'and the photos in the order they were picked', () async {
    final ids = await queueComment('c-1', photos: 3, parent: 'parent-1');
    for (var i = 0; i < ids.length; i++) {
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(ids[i]))).write(
        UploadQueueEntriesCompanion(
          queuedAt: Value(t0.subtract(Duration(seconds: i))),
        ),
      );
    }

    await pass();

    // The cleanup that erases a user's comment photos only looks in this
    // folder, so a photo uploaded elsewhere would outlive the account.
    expect(uploadFolders, everyElement('users/$uid/comment_images'));
    expect(uploadFolders, hasLength(3));
    expect(repository.created, hasLength(1));
    final comment = repository.created.single;
    expect(comment.commentId, 'c-1');
    expect(comment.recipeId, 'recipe-1');
    expect(comment.content, 'Så gott!');
    expect(comment.parent, 'parent-1');
    expect(comment.imageUrls, [for (final id in ids) 'https://img/$id.jpg']);
    for (final id in ids) {
      expect(await row(id), isNull);
    }
  });

  test('nothing is created while a photo is still on its way', () async {
    final ids = await queueComment('c-1');
    uploadFails.add(ids.last);

    await pass();

    expect(repository.created, isEmpty);
    expect((await row(ids.first))!.status, 'uploaded');

    uploadFails.clear();
    await pass(after: const Duration(minutes: 1));

    expect(repository.created, hasLength(1));
    expect(repository.created.single.imageUrls, hasLength(2));
  });

  test('a comment already on the server is not created again and its photos '
      'stay', () async {
    final ids = await queueComment('c-1');
    repository.onServer.add('c-1');

    await pass();

    expect(repository.created, isEmpty);
    expect(taken, isEmpty);
    for (final id in ids) {
      expect(await row(id), isNull);
    }
  });

  test(
    'a try that reached the server although it threw is a success',
    () async {
      final ids = await queueComment('c-1', photos: 1);
      repository.failures.add(firestoreError('permission-denied'));
      repository.landsDespiteFailure = true;

      await pass();

      expect(repository.created, isEmpty);
      expect(await row(ids.single), isNull);
      expect(taken, isEmpty);
    },
  );

  test('a refusal that may be the five-second guard is given one more try '
      'after the spacing', () async {
    final ids = await queueComment('c-1', photos: 1);
    repository.refuseUntil = t0.add(const Duration(seconds: 3));

    await pass();

    expect(repository.created, isEmpty);
    final waiting = (await row(ids.single))!;
    expect(waiting.permanentlyFailed, isFalse, reason: 'deferred, not failed');

    await pass(after: const Duration(seconds: 10));

    expect(repository.created, hasLength(1));
  });

  test('an unknown recipe ownership is retried, never published: nothing is '
      'created and the comment does not need the user', () async {
    final ids = await queueComment('c-1', photos: 1);
    repository.failures.add(StateError('ownership unknown'));

    await pass();

    final waiting = (await row(ids.single))!;
    expect(waiting.permanentlyFailed, isFalse);
    expect(waiting.retryCount, 1);
    expect(repository.created, isEmpty);

    await pass(after: const Duration(minutes: 5));

    expect(repository.created, hasLength(1));
  });

  test('throwing one photo away throws the whole comment away, takes its '
      'photos back out of Storage and never creates it', () async {
    final ids = await queueComment('c-1', photos: 3);
    uploadFails.add(ids.last);
    await pass();
    await db.uploadQueueDao.cancelUpload(ids.last);
    uploadFails.clear();

    await pass(after: const Duration(minutes: 1));
    await pass(after: const Duration(minutes: 2));

    expect(repository.created, isEmpty);
    expect(
      taken,
      unorderedEquals([
        'https://img/${ids[0]}.jpg',
        'https://img/${ids[1]}.jpg',
      ]),
    );
  });

  test('a photo thrown away after the comment reached the server does not '
      'take the rest with it', () async {
    final ids = await queueComment('c-1', photos: 3);
    repository.onServer.add('c-1');
    await db.uploadQueueDao.cancelUpload(ids.last);

    await pass();

    expect(repository.created, isEmpty);
    expect(taken, isEmpty);
    for (final id in ids) {
      expect(await row(id), isNull);
    }
  });

  test(
    'a comment and a cook snap of the same id are different groups',
    () async {
      await queueComment('same-id', photos: 1);
      final other = File('${root.path}/other.jpg')..writeAsBytesSync([9]);
      await storage.queueImageGroupForUser(
        imagePaths: [other.path],
        entityType: SyncQueueEntityType.cookSnap,
        entityId: 'same-id',
        userId: uid,
        targetPath: 'users/$uid/recipes',
        metadata: const {},
      );

      expect(
        await db.uploadQueueDao.getGroup(
          uid,
          SyncQueueEntityType.comment,
          'same-id',
        ),
        hasLength(1),
      );
    },
  );
}
