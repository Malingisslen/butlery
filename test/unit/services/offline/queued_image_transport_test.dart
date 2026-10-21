// BUT-2294: the glue between the offline queue and StorageService. The queue
// names the Storage object after its row; if this glue dropped the name, every
// retry would leave another copy in Storage.

import 'dart:io';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/services/offline/queued_image_transport.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/fallback_values.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  late MockStorageService storage;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerAllFallbackValues();
    registerFallbackValue(File('/fallback.jpg'));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    storage = MockStorageService();
    GetIt.instance.unregister<StorageService>();
    GetIt.instance.registerSingleton<StorageService>(storage);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  test('the upload carries the row id as the object name and returns both '
      'addresses', () async {
    when(
      () => storage.uploadImageFile(
        any(),
        any(),
        objectId: any(named: 'objectId'),
      ),
    ).thenAnswer(
      (_) async => const ImageUploadResult(
        imageUrl: 'https://img/row-1.jpg',
        thumbnailUrl: 'https://img/row-1_thumb.jpg',
      ),
    );

    final uploaded = await uploadQueuedImage(
      '/device/a.jpg',
      'u1',
      'row-1',
      'users/u1/recipes',
    );

    expect(uploaded, (
      url: 'https://img/row-1.jpg',
      thumbnailUrl: 'https://img/row-1_thumb.jpg',
    ));
    final call = verify(
      () => storage.uploadImageFile(
        captureAny(),
        'u1',
        objectId: captureAny(named: 'objectId'),
      ),
    ).captured;
    expect((call[0] as File).path, '/device/a.jpg');
    expect(call[1], 'row-1');
  });

  test(
    'an upload that returns nothing is a failure the queue retries',
    () async {
      when(
        () => storage.uploadImageFile(
          any(),
          any(),
          objectId: any(named: 'objectId'),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => uploadQueuedImage(
          '/device/a.jpg',
          'u1',
          'row-1',
          'users/u1/recipes',
        ),
        throwsStateError,
      );
    },
  );

  test('a comment photo goes to the comment folder under the row id, with no '
      'thumbnail', () async {
    when(
      () => storage.uploadQueuedCommentImage(
        any(),
        any(),
        objectId: any(named: 'objectId'),
      ),
    ).thenAnswer((_) async => 'https://img/row-2.jpg');

    final uploaded = await uploadQueuedImage(
      '/device/b.jpg',
      'u1',
      'row-2',
      'users/u1/comment_images',
    );

    expect(uploaded, (url: 'https://img/row-2.jpg', thumbnailUrl: null));
    verify(
      () => storage.uploadQueuedCommentImage(
        any(that: isA<File>()),
        'u1',
        objectId: 'row-2',
      ),
    ).called(1);
    verifyNever(
      () => storage.uploadImageFile(
        any(),
        any(),
        objectId: any(named: 'objectId'),
      ),
    );
  });

  test('a folder that is not one of the user\'s own image folders uploads '
      'nothing', () async {
    for (final folder in [
      'users/u2/recipes',
      'users/u2/chat_images',
      'users/u2/comment_images',
      'users/u1/avatars',
      '',
    ]) {
      await expectLater(
        () => uploadQueuedImage('/device/a.jpg', 'u1', 'row-1', folder),
        throwsStateError,
      );
    }
    verifyZeroInteractions(storage);
  });

  test('taking an image back asks the storage service to delete its '
      'address and passes its answer on', () async {
    when(() => storage.deleteImage(any())).thenAnswer((_) async => false);

    final gone = await deleteQueuedImage((
      url: 'https://img/row-1.jpg',
      thumbnailUrl: null,
    ));

    expect(gone, isFalse);
    verify(() => storage.deleteImage('https://img/row-1.jpg')).called(1);
  });

  test('a chat photo goes to the chat folder under the row id, with no '
      'thumbnail', () async {
    when(
      () => storage.uploadQueuedChatImage(
        any(),
        any(),
        objectId: any(named: 'objectId'),
      ),
    ).thenAnswer((_) async => 'https://img/row-3.jpg');

    final uploaded = await uploadQueuedImage(
      '/device/c.jpg',
      'u1',
      'row-3',
      'users/u1/chat_images',
    );

    expect(uploaded, (url: 'https://img/row-3.jpg', thumbnailUrl: null));
    verify(
      () => storage.uploadQueuedChatImage(
        any(that: isA<File>()),
        'u1',
        objectId: 'row-3',
      ),
    ).called(1);
  });

  test(
    'a chat photo that returns nothing is a failure the queue retries',
    () async {
      when(
        () => storage.uploadQueuedChatImage(
          any(),
          any(),
          objectId: any(named: 'objectId'),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => uploadQueuedImage(
          '/device/c.jpg',
          'u1',
          'row-3',
          'users/u1/chat_images',
        ),
        throwsStateError,
      );
    },
  );
}
