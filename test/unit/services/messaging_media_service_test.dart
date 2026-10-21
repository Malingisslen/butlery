import 'dart:io';

import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/services/messaging_media_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockAuthRepository extends Mock implements auth_repo.AuthRepository {}

class _MockUploadService extends Mock implements ImageUploadService {}

class _MockOfflineService extends Mock implements OfflineService {}

class _MockUserStorage extends Mock implements OfflineUserStorage {}

class _FakeFile extends Fake implements File {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeFile()));

  test('chat image is sent without the device file name as caption', () async {
    final messaging = _MockMessagingService();
    final auth = _MockAuthRepository();
    final upload = _MockUploadService();
    when(() => auth.currentUserId).thenReturn('u1');
    when(
      () => upload.uploadImage(
        file: any(named: 'file'),
        userId: any(named: 'userId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => const UploadResult(success: true, url: 'https://x/y.jpg'),
    );
    when(
      () => messaging.sendImageMessage(
        conversationId: any(named: 'conversationId'),
        imageUrl: any(named: 'imageUrl'),
        caption: any(named: 'caption'),
      ),
    ).thenAnswer((_) async {});

    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/IMG_20261019_1432.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0]);

    final ok = await MessagingMediaService(
      messagingService: messaging,
      authRepository: auth,
      uploadService: upload,
    ).uploadAndSendImage(conversationId: 'c1', imagePath: file.path);

    expect(ok, ImageSendOutcome.sent);
    final captured = verify(
      () => messaging.sendImageMessage(
        conversationId: 'c1',
        imageUrl: 'https://x/y.jpg',
        caption: captureAny(named: 'caption'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });

  group('without a connection (BUT-2294)', () {
    late _MockMessagingService messaging;
    late _MockAuthRepository auth;
    late _MockUploadService upload;
    late _MockOfflineService offline;
    late _MockUserStorage storage;
    late File photo;
    var online = false;

    setUp(() {
      messaging = _MockMessagingService();
      auth = _MockAuthRepository();
      upload = _MockUploadService();
      offline = _MockOfflineService();
      storage = _MockUserStorage();
      online = false;
      when(() => auth.currentUserId).thenReturn('u1');
      when(() => offline.isOnline).thenAnswer((_) => online);
      when(() => offline.isQueueReady).thenReturn(true);
      when(() => offline.userStorage).thenReturn(storage);
      when(() => offline.refreshSyncState()).thenAnswer((_) async {});
      when(
        () => messaging.sendPendingImageMessage(
          conversationId: any(named: 'conversationId'),
          messageId: any(named: 'messageId'),
        ),
      ).thenAnswer((_) async {});
      when(() => messaging.deleteMessage(any())).thenAnswer((_) async {});
      when(
        () => storage.queueImageGroupForUser(
          imagePaths: any(named: 'imagePaths'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          userId: any(named: 'userId'),
          targetPath: any(named: 'targetPath'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer((_) async => ['row-1']);
      final dir = Directory.systemTemp.createTempSync();
      addTearDown(() => dir.deleteSync(recursive: true));
      photo = File('${dir.path}/a.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0]);
    });

    MessagingMediaService service() => MessagingMediaService(
      messagingService: messaging,
      authRepository: auth,
      uploadService: upload,
      offlineService: () => offline,
    );

    test('the message is created first and the picture queued under its id, '
        'with nothing uploaded', () async {
      final outcome = await service().uploadAndSendImage(
        conversationId: 'c1',
        imagePath: photo.path,
      );

      expect(outcome, ImageSendOutcome.queued);
      final calls = verifyInOrder([
        () => messaging.sendPendingImageMessage(
          conversationId: 'c1',
          messageId: captureAny(named: 'messageId'),
        ),
        () => storage.queueImageGroupForUser(
          imagePaths: [photo.path],
          entityType: 'chat_image',
          entityId: captureAny(named: 'entityId'),
          userId: 'u1',
          targetPath: 'users/u1/chat_images',
          metadata: {'conversationId': 'c1'},
        ),
      ]);
      // The row is named after the message the picture belongs to.
      expect(calls[0].captured.single, calls[1].captured.single);
      verifyZeroInteractions(upload);
      verifyNever(
        () => messaging.sendImageMessage(
          conversationId: any(named: 'conversationId'),
          imageUrl: any(named: 'imageUrl'),
          caption: any(named: 'caption'),
        ),
      );
    });

    test('a message that cannot be created queues nothing', () async {
      when(
        () => messaging.sendPendingImageMessage(
          conversationId: any(named: 'conversationId'),
          messageId: any(named: 'messageId'),
        ),
      ).thenThrow(StateError('not a participant'));

      final outcome = await service().uploadAndSendImage(
        conversationId: 'c1',
        imagePath: photo.path,
      );

      expect(outcome, ImageSendOutcome.notSent);
      verifyNever(
        () => storage.queueImageGroupForUser(
          imagePaths: any(named: 'imagePaths'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          userId: any(named: 'userId'),
          targetPath: any(named: 'targetPath'),
          metadata: any(named: 'metadata'),
        ),
      );
    });

    test(
      'a picture that cannot be queued takes its message down again',
      () async {
        when(
          () => storage.queueImageGroupForUser(
            imagePaths: any(named: 'imagePaths'),
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            userId: any(named: 'userId'),
            targetPath: any(named: 'targetPath'),
            metadata: any(named: 'metadata'),
          ),
        ).thenThrow(const FileSystemException('disk full'));

        final outcome = await service().uploadAndSendImage(
          conversationId: 'c1',
          imagePath: photo.path,
        );

        expect(outcome, ImageSendOutcome.notSent);
        verify(() => messaging.deleteMessage(any())).called(1);
      },
    );

    test('an upload that fails because the connection went is queued '
        'instead', () async {
      online = true;
      when(
        () => upload.uploadImage(
          file: any(named: 'file'),
          userId: any(named: 'userId'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        online = false;
        return const UploadResult(success: false, error: 'network');
      });

      final outcome = await service().uploadAndSendImage(
        conversationId: 'c1',
        imagePath: photo.path,
      );

      expect(outcome, ImageSendOutcome.queued);
    });

    test('an upload that fails while online is not queued', () async {
      online = true;
      when(
        () => upload.uploadImage(
          file: any(named: 'file'),
          userId: any(named: 'userId'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const UploadResult(success: false, error: 'rejected'),
      );

      final outcome = await service().uploadAndSendImage(
        conversationId: 'c1',
        imagePath: photo.path,
      );

      expect(outcome, ImageSendOutcome.notSent);
      verifyNever(
        () => messaging.sendPendingImageMessage(
          conversationId: any(named: 'conversationId'),
          messageId: any(named: 'messageId'),
        ),
      );
    });
  });
}
