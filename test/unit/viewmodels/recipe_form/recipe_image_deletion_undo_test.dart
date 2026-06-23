// BUT-932: deferred Firebase Storage deletion + undo contract for
// RecipeImageManager. Covers the new wave-17 surface area:
//   - removeImageAndCleanup must NOT call StorageService synchronously
//   - restoreLastImageDeletion walks LIFO and cancels the pending delete
//   - commitPendingStorageDeletes drains the queue exactly once and resets
//     undo history
//
// These behaviors protect the user's Storage bytes from mis-taps on the
// trash icon and prevent orphaned deletes when the form is abandoned
// without saving.

import 'dart:io';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';

class _MockImageUploadService extends Mock implements ImageUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeImageManager imageManager;
  late StorageService mockStorageService;
  late _MockImageUploadService mockUploadService;

  setUpAll(() async {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    mockStorageService = MockFactory.createStorageService();
    mockUploadService = _MockImageUploadService();
    when(
      () => mockStorageService.deleteRecipeImage(any()),
    ).thenAnswer((_) async {});

    imageManager = RecipeImageManager(
      uploadService: mockUploadService,
      storageService: mockStorageService,
      imagePickerService: MockFactory.createImagePickerService(),
    );
  });

  tearDown(() async {
    try {
      imageManager.dispose();
    } catch (_) {
      // Already disposed in a test that exercises lifecycle.
    }
    await TestServiceLocator.reset();
  });

  group('removeImageAndCleanup defers Storage deletion (BUT-932)', () {
    test('does not call deleteRecipeImage synchronously', () async {
      const url = 'https://firebase.com/storage/img.jpg';
      imageManager.addUploadedImageUrl(url);

      await imageManager.removeImageAndCleanup(url);

      // The whole point of the wave-17 change — Storage stays intact until
      // commit. A mis-tapped trash icon must not destroy real bytes.
      verifyNever(() => mockStorageService.deleteRecipeImage(any()));
      expect(imageManager.imageUrls, isEmpty); // UI update still immediate
      expect(imageManager.pendingDeleteCount, 1);
    });

    test('local file removals do not enqueue a Storage delete', () async {
      // Pending file paths never reached Storage; nothing to schedule.
      const localPath = '/tmp/pending.jpg';
      imageManager.addPendingImage(File(localPath));

      await imageManager.removeImageAndCleanup(localPath);

      // pendingDeleteCount still increments (the status was snapshotted for
      // undo), but the Storage queue stays empty — commit will be a no-op
      // for this entry.
      expect(imageManager.pendingDeleteCount, 1);
      // Force a commit; nothing should be sent to Storage.
      await imageManager.commitPendingStorageDeletes();
      verifyNever(() => mockStorageService.deleteRecipeImage(any()));
    });
  });

  group('restoreLastImageDeletion LIFO contract (BUT-932)', () {
    test('remove A, remove B, undo → B restored, A still pending', () async {
      const urlA = 'https://firebase.com/storage/a.jpg';
      const urlB = 'https://firebase.com/storage/b.jpg';
      imageManager.addUploadedImageUrl(urlA);
      imageManager.addUploadedImageUrl(urlB);

      await imageManager.removeImageAndCleanup(urlA);
      await imageManager.removeImageAndCleanup(urlB);
      expect(imageManager.pendingDeleteCount, 2);

      final restored = imageManager.restoreLastImageDeletion();
      expect(restored, isTrue);

      // B comes back, A stays gone (and stays queued for delete).
      expect(imageManager.imageUrls, [urlB]);
      expect(imageManager.pendingDeleteCount, 1);

      // Commit must now delete only A, not B.
      await imageManager.commitPendingStorageDeletes();
      verify(() => mockStorageService.deleteRecipeImage(urlA)).called(1);
      verifyNever(() => mockStorageService.deleteRecipeImage(urlB));
    });

    test(
      'undo twice when only one removal: second call returns false',
      () async {
        const urlA = 'https://firebase.com/storage/a.jpg';
        imageManager.addUploadedImageUrl(urlA);

        await imageManager.removeImageAndCleanup(urlA);

        expect(imageManager.restoreLastImageDeletion(), isTrue);
        expect(imageManager.imageUrls, [urlA]);
        expect(imageManager.pendingDeleteCount, 0);

        // Second undo has nothing to walk back — must not throw, must not
        // restore phantom state, must signal "nothing to do" to the UI.
        expect(imageManager.restoreLastImageDeletion(), isFalse);
        expect(imageManager.imageUrls, [urlA]);
      },
    );

    test('restore removes the URL from the pending-delete queue', () async {
      const url = 'https://firebase.com/storage/img.jpg';
      imageManager.addUploadedImageUrl(url);

      await imageManager.removeImageAndCleanup(url);
      imageManager.restoreLastImageDeletion();

      // After restore the URL is no longer queued; a save flow should not
      // accidentally delete the bytes the user just undid.
      await imageManager.commitPendingStorageDeletes();
      verifyNever(() => mockStorageService.deleteRecipeImage(any()));
    });

    test('restore re-emits a listener notification', () async {
      const url = 'https://firebase.com/storage/img.jpg';
      imageManager.addUploadedImageUrl(url);
      await imageManager.removeImageAndCleanup(url);

      var notifications = 0;
      imageManager.addListener(() => notifications++);

      imageManager.restoreLastImageDeletion();
      expect(notifications, greaterThanOrEqualTo(1));
    });
  });

  group('commitPendingStorageDeletes (BUT-932)', () {
    test(
      'drains the queue and calls Storage for each URL exactly once',
      () async {
        const urlA = 'https://firebase.com/storage/a.jpg';
        const urlB = 'https://firebase.com/storage/b.jpg';
        imageManager.addUploadedImageUrl(urlA);
        imageManager.addUploadedImageUrl(urlB);
        await imageManager.removeImageAndCleanup(urlA);
        await imageManager.removeImageAndCleanup(urlB);

        await imageManager.commitPendingStorageDeletes();

        verify(() => mockStorageService.deleteRecipeImage(urlA)).called(1);
        verify(() => mockStorageService.deleteRecipeImage(urlB)).called(1);
        // Undo history reset after commit — no more "undo last delete" once
        // bytes are actually gone.
        expect(imageManager.pendingDeleteCount, 0);

        // A second commit must be a no-op (queue already drained).
        await imageManager.commitPendingStorageDeletes();
        verifyNoMoreInteractions(mockStorageService);
      },
    );

    test('per-URL Storage failures never throw (orphan tolerated)', () async {
      // Contract: save flow must never fail because Storage delete failed.
      // The recipe doc already excludes the URL — worst case is an unused
      // blob in Storage, which is recoverable later.
      const url = 'https://firebase.com/storage/img.jpg';
      imageManager.addUploadedImageUrl(url);
      await imageManager.removeImageAndCleanup(url);
      when(
        () => mockStorageService.deleteRecipeImage(any()),
      ).thenThrow(Exception('Permission denied'));

      // Must not throw.
      await imageManager.commitPendingStorageDeletes();

      verify(() => mockStorageService.deleteRecipeImage(url)).called(1);
      expect(imageManager.pendingDeleteCount, 0);
    });

    test(
      'empty queue commit clears undo history without hitting Storage',
      () async {
        const localPath = '/tmp/pending.jpg';
        imageManager.addPendingImage(File(localPath));
        await imageManager.removeImageAndCleanup(localPath);
        // Local-file removal: undo history present, Storage queue empty.
        expect(imageManager.pendingDeleteCount, 1);

        await imageManager.commitPendingStorageDeletes();

        verifyNever(() => mockStorageService.deleteRecipeImage(any()));
        expect(imageManager.pendingDeleteCount, 0); // undo cleared too
      },
    );
  });
}
