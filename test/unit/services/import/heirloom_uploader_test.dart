import 'dart:typed_data';

import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/services/import/heirloom_uploader.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/repositories/mock_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageRepository storage;
  late FakePermissionService permission;
  late HeirloomUploader uploader;

  final jpegBytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
  final pngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D,
  ]);

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    storage = MockStorageRepository();
    permission = FakePermissionService()
      ..setPermissionState(currentUserId: 'user-abc');
    uploader = HeirloomUploader(storage: storage, permission: permission);
  });

  void stubUpload(String? url) {
    when(
      () => storage.uploadImageData(
        imageData: any(named: 'imageData'),
        userId: any(named: 'userId'),
        path: any(named: 'path'),
        metadata: any(named: 'metadata'),
        cacheControl: any(named: 'cacheControl'),
      ),
    ).thenAnswer((_) async => url);
  }

  group('BUT-2280: HeirloomUploader', () {
    test('uploads under the recipe and returns its metadata', () async {
      stubUpload('https://storage/heirloom/abc.jpg');
      final now = DateTime(2026, 10, 7, 8);

      final heirloom = await withClock(
        Clock.fixed(now),
        () => uploader.upload(
          HeirloomDraft(
            imageBytes: jpegBytes,
            writerName: 'Farmor Elsa',
            year: 1972,
            note: 'Från receptboken',
          ),
          'recipe-1',
        ),
      );

      expect(heirloom, isNotNull);
      expect(heirloom!.sourceImageUrl, 'https://storage/heirloom/abc.jpg');
      expect(heirloom.writerName, 'Farmor Elsa');
      expect(heirloom.year, 1972);
      expect(heirloom.note, 'Från receptboken');
      expect(heirloom.addedByUserId, 'user-abc');
      expect(heirloom.addedAt, now);

      final captured = verify(
        () => storage.uploadImageData(
          imageData: any(named: 'imageData'),
          userId: captureAny(named: 'userId'),
          path: captureAny(named: 'path'),
          metadata: captureAny(named: 'metadata'),
          cacheControl: captureAny(named: 'cacheControl'),
        ),
      ).captured;
      expect(captured[0], 'user-abc');
      expect(
        captured[1] as String,
        matches(
          RegExp(
            r'^users/user-abc/recipes/recipe-1/heirloom/[0-9a-f]{16}\.jpg$',
          ),
        ),
      );
      expect(captured[2], {'purpose': 'heirloom', 'recipeId': 'recipe-1'});
      expect(captured[3], 'public, max-age=31536000, immutable');
    });

    test('BUT-1161: PNG bytes get a .png path', () async {
      stubUpload('https://storage/heirloom/abc.png');

      await uploader.upload(HeirloomDraft(imageBytes: pngBytes), 'recipe-1');

      final path = verify(
        () => storage.uploadImageData(
          imageData: any(named: 'imageData'),
          userId: any(named: 'userId'),
          path: captureAny(named: 'path'),
          metadata: any(named: 'metadata'),
          cacheControl: any(named: 'cacheControl'),
        ),
      ).captured.single;
      expect(path, endsWith('.png'));
    });

    test('an upload without a URL returns null', () async {
      stubUpload(null);

      expect(
        await uploader.upload(HeirloomDraft(imageBytes: jpegBytes), 'r'),
        isNull,
      );
    });

    test('an unauthenticated session uploads nothing', () async {
      permission.setPermissionState(
        currentUserId: 'user-abc',
        isAuthenticated: false,
      );

      expect(
        await uploader.upload(HeirloomDraft(imageBytes: jpegBytes), 'r'),
        isNull,
      );
      verifyNever(
        () => storage.uploadImageData(
          imageData: any(named: 'imageData'),
          userId: any(named: 'userId'),
          path: any(named: 'path'),
          metadata: any(named: 'metadata'),
          cacheControl: any(named: 'cacheControl'),
        ),
      );
    });

    test('signed out returns null and uploads nothing', () async {
      permission.setPermissionState(currentUserId: null);

      expect(
        await uploader.upload(HeirloomDraft(imageBytes: jpegBytes), 'r'),
        isNull,
      );
      verifyNever(
        () => storage.uploadImageData(
          imageData: any(named: 'imageData'),
          userId: any(named: 'userId'),
          path: any(named: 'path'),
          metadata: any(named: 'metadata'),
          cacheControl: any(named: 'cacheControl'),
        ),
      );
    });
  });
}
