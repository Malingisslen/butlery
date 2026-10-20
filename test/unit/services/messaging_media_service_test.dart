import 'dart:io';

import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/services/messaging_media_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockAuthRepository extends Mock implements auth_repo.AuthRepository {}

class _MockUploadService extends Mock implements ImageUploadService {}

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

    expect(ok, isTrue);
    final captured = verify(
      () => messaging.sendImageMessage(
        conversationId: 'c1',
        imageUrl: 'https://x/y.jpg',
        caption: captureAny(named: 'caption'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });
}
