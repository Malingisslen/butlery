// BUT-2294: a chat image sent without a connection. The placeholder message is
// created through Firestore's own queue; this step fills in the picture once it
// is in Storage.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/messaging/pending_image_status.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/offline/chat_image_queue_metadata.dart';
import 'package:butlery/services/offline/chat_image_upload_completion.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom, firestoreError;

class _Repository extends Fake implements MessagingRepository {
  PendingImageStatus status = const PendingImageStatus(
    PendingImageState.waiting,
  );
  final List<({String messageId, String imageUrl})> attached = [];
  final List<String> deleted = [];
  final List<String> askedAbout = [];

  /// Thrown by the next status read, once.
  Object? statusFailure;

  /// Thrown by the next attach, once.
  Object? attachFailure;
  bool deleteFails = false;

  /// Runs while the server is asked what it holds.
  Future<void> Function()? whileAsking;

  @override
  Future<PendingImageStatus> pendingImageStatus({
    required String messageId,
    required String userId,
    required String conversationId,
  }) async {
    askedAbout.add(conversationId);
    await whileAsking?.call();
    final failure = statusFailure;
    if (failure != null) {
      statusFailure = null;
      throw failure;
    }
    return status;
  }

  @override
  Future<void> attachPendingImage({
    required String messageId,
    required String imageUrl,
  }) async {
    final failure = attachFailure;
    if (failure != null) {
      attachFailure = null;
      throw failure;
    }
    attached.add((messageId: messageId, imageUrl: imageUrl));
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    if (deleteFails) throw firestoreError('unavailable');
    deleted.add(messageId);
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'u1';
  const messageId = 'm-1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late _Repository repository;
  late List<String> taken;
  late List<String> uploadFolders;
  late UploadQueueProcessor processor;
  late String rowId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('chat_image_queue');
    storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    repository = _Repository();
    taken = [];
    uploadFolders = [];
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
            return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
          },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return true;
      },
      completions: {
        SyncQueueEntityType.chatImage: ChatImageUploadCompletion(
          database: db,
          storage: storage,
          repository: () => repository,
        ),
      },
      random: MidRandom(),
    );

    final file = File('${root.path}/photo.jpg')..writeAsBytesSync([1]);
    final ids = await withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: [file.path],
        entityType: SyncQueueEntityType.chatImage,
        entityId: messageId,
        userId: uid,
        targetPath: 'users/$uid/chat_images',
        metadata: chatImageQueueMetadata(conversationId: 'conv-1'),
      ),
    );
    rowId = ids.single;
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<int> pass({Duration after = Duration.zero}) => withClock(
    Clock.fixed(t0.add(after)),
    () => processor.runPass(
      uid,
      now: t0.add(after),
      isCurrentUser: () => true,
      force: true,
    ),
  );

  Future<UploadQueueEntry?> row() => db.uploadQueueDao.getUpload(rowId);

  test('the picture is set on the waiting placeholder once, from the chat '
      'folder, and the row is gone', () async {
    await pass();

    // The cleanup that erases a user's photos only looks under their folder.
    expect(uploadFolders, ['users/$uid/chat_images']);
    expect(repository.askedAbout, ['conv-1']);
    expect(repository.attached, [
      (messageId: messageId, imageUrl: 'https://img/$rowId.jpg'),
    ]);
    expect(await row(), isNull);
  });

  test('a placeholder still in Firestore\'s own queue waits without counting '
      'as a failed attempt', () async {
    repository.status = const PendingImageStatus(
      PendingImageState.writePending,
    );

    await pass();

    expect(repository.attached, isEmpty);
    final waiting = (await row())!;
    expect(waiting.status, 'uploaded');
    expect(waiting.retryCount, 0);
    expect(waiting.nextAttemptAt, isNotNull);

    repository.status = const PendingImageStatus(PendingImageState.waiting);
    await pass(after: const Duration(minutes: 1));

    expect(repository.attached, hasLength(1));
    expect(await row(), isNull);
  });

  test('a picture already set to this address is not set twice', () async {
    repository.status = PendingImageStatus(
      PendingImageState.filled,
      imageUrl: 'https://img/$rowId.jpg',
    );

    await pass();

    expect(repository.attached, isEmpty);
    expect(await row(), isNull);
  });

  test('a picture set to another address means the message is no longer '
      'ours to fill: the upload is taken back', () async {
    repository.status = const PendingImageStatus(
      PendingImageState.filled,
      imageUrl: 'https://img/other.jpg',
    );

    await pass();

    expect(repository.attached, isEmpty);
    expect(taken, ['https://img/$rowId.jpg']);
    expect(await row(), isNull);
  });

  for (final state in [PendingImageState.absent, PendingImageState.notMine]) {
    test('a placeholder that is $state takes the upload back and drops the '
        'row', () async {
      repository.status = PendingImageStatus(state);

      await pass();

      expect(repository.attached, isEmpty);
      expect(taken, ['https://img/$rowId.jpg']);
      expect(await row(), isNull);
    });
  }

  test('a refusal by the rules takes the placeholder down and keeps the '
      'failure', () async {
    repository.attachFailure = firestoreError('permission-denied');

    await pass();

    expect(repository.deleted, [messageId]);
    expect(repository.attached, isEmpty);
    expect((await row())!.permanentlyFailed, isTrue);
  });

  test('a refusal is still reported when the placeholder cannot be taken '
      'down', () async {
    repository.attachFailure = firestoreError('permission-denied');
    repository.deleteFails = true;

    await pass();

    expect(repository.deleted, isEmpty);
    // The refusal is what is recorded, not the failed clean-up after it.
    expect((await row())!.permanentlyFailed, isTrue);
  });

  test('a failure that may pass leaves the placeholder alone', () async {
    repository.attachFailure = firestoreError('unavailable');

    await pass();

    expect(repository.deleted, isEmpty);
    expect(repository.attached, isEmpty);

    await pass(after: const Duration(hours: 1));

    expect(repository.attached, hasLength(1));
    expect(await row(), isNull);
  });

  test('a discard while the server is asked publishes nothing', () async {
    repository.whileAsking = () => db.uploadQueueDao.cancelUpload(rowId);

    await pass();

    expect(repository.attached, isEmpty);
    expect(repository.deleted, isEmpty);
  });

  test('a refusal at the status read takes the placeholder down too', () async {
    repository.statusFailure = firestoreError('permission-denied');

    await pass();

    expect(repository.deleted, [messageId]);
    expect((await row())!.permanentlyFailed, isTrue);
  });

  test('a status read that cannot reach the server leaves the placeholder '
      'alone', () async {
    repository.statusFailure = firestoreError('unavailable');

    await pass();

    expect(repository.deleted, isEmpty);
    expect((await row())!.permanentlyFailed, isFalse);
  });

  test('a row without its conversation cannot be placed: the upload is taken '
      'back', () async {
    await (db.update(db.uploadQueueEntries)..where((e) => e.id.equals(rowId)))
        .write(const UploadQueueEntriesCompanion(metadata: Value(null)));

    await pass();

    expect(repository.askedAbout, isEmpty);
    expect(taken, ['https://img/$rowId.jpg']);
    expect(await row(), isNull);
  });
}
