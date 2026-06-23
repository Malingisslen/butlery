/// BUT-953: pin that ImportBaseViewModel.saveImportedRecipe consumes any
/// pending HeirloomBridge draft, uploads the scan, attaches HeirloomMetadata
/// to the parsed recipe, and blocks the save on upload failure.
///
/// Without this wiring, PhotoImportView's heirloom form silently dropped on
/// every save — `uploadHeirloomImage` had zero callers and metadata never
/// reached Firestore. The two tests below verify the success and the
/// upload-failure paths.
// ignore_for_file: invalid_use_of_protected_member

library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/repositories/mock_storage_repository.dart';

class _TestImportViewModel extends ImportBaseViewModel {
  _TestImportViewModel({required super.importManager});

  @override
  Future<void> performImport() async {}

  @override
  String get importType => 'test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImportManager mockImportManager;
  late MockStorageRepository mockStorage;
  late FakePermissionService fakePermission;
  late HeirloomBridge bridge;
  late _TestImportViewModel vm;

  final imported = RecipeFactory.build(
    id: 'recipe-123',
    title: 'Pannkakor',
  );

  setUpAll(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    // Local per-test register/unregister: `StorageRepository` and
    // `HeirloomBridge` aren't in `TestServiceLocator.initialize()` because
    // the heirloom bridge is the only consumer (BUT-953) and adding it
    // there would bind every unrelated test to that wiring. If a third
    // user appears, promote to TestServiceLocator.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<StorageRepository>()) {
      getIt.unregister<StorageRepository>();
    }
    if (getIt.isRegistered<HeirloomBridge>()) {
      getIt.unregister<HeirloomBridge>();
    }

    mockStorage = MockStorageRepository();
    bridge = HeirloomBridge();
    getIt.registerSingleton<StorageRepository>(mockStorage);
    getIt.registerSingleton<HeirloomBridge>(bridge);

    // PermissionService is registered by TestServiceLocator — grab the
    // existing instance and configure it for our user.
    fakePermission = getIt<PermissionService>() as FakePermissionService;
    fakePermission.setPermissionState(currentUserId: 'user-abc');

    mockImportManager = MockFactory.createImportManager();
    when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
      (inv) async => ImportManagerResult.success(
        inv.positionalArguments.first as dynamic,
        strategy: 'test',
      ),
    );

    vm = _TestImportViewModel(importManager: mockImportManager);
    vm.setParsedRecipe(imported);
  });

  tearDown(() {
    vm.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  group('BUT-953: heirloom draft → upload → attach → save', () {
    test(
      'pending draft + upload OK → recipe saved with HeirloomMetadata attached',
      () async {
        bridge.setDraft(
          HeirloomDraft(
            imageBytes: Uint8List.fromList(List<int>.generate(64, (i) => i)),
            writerName: 'Farmor Elsa',
            year: 1972,
            note: 'Från receptboken',
          ),
        );
        when(
          () => mockStorage.uploadImageData(
            imageData: any(named: 'imageData'),
            userId: any(named: 'userId'),
            path: any(named: 'path'),
            metadata: any(named: 'metadata'),
            cacheControl: any(named: 'cacheControl'),
          ),
        ).thenAnswer((_) async => 'https://storage/heirloom/abc.jpg');

        final ok = await vm.saveImportedRecipe();

        expect(ok, isTrue);
        expect(vm.hasError, isFalse);
        expect(
          vm.parsedRecipe?.heirloom,
          isNotNull,
          reason: 'metadata must be stitched onto the recipe before save',
        );
        expect(
          vm.parsedRecipe!.heirloom!.sourceImageUrl,
          'https://storage/heirloom/abc.jpg',
        );
        expect(vm.parsedRecipe!.heirloom!.writerName, 'Farmor Elsa');
        expect(vm.parsedRecipe!.heirloom!.year, 1972);
        expect(vm.parsedRecipe!.heirloom!.addedByUserId, 'user-abc');
        // Bridge must be drained — a second save shouldn't re-upload.
        expect(bridge.hasPending, isFalse);
        verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
      },
    );

    test(
      'pending draft + upload returns null → save blocked, error surfaced',
      () async {
        bridge.setDraft(
          HeirloomDraft(
            imageBytes: Uint8List.fromList([1, 2, 3, 4]),
          ),
        );
        when(
          () => mockStorage.uploadImageData(
            imageData: any(named: 'imageData'),
            userId: any(named: 'userId'),
            path: any(named: 'path'),
            metadata: any(named: 'metadata'),
            cacheControl: any(named: 'cacheControl'),
          ),
        ).thenAnswer((_) async => null);

        final ok = await vm.saveImportedRecipe();

        expect(
          ok,
          isFalse,
          reason: 'save must fail if heirloom upload returns null',
        );
        expect(vm.hasError, isTrue);
        expect(
          vm.parsedRecipe?.heirloom,
          isNull,
          reason: 'no metadata when upload failed',
        );
        // Save must NOT have been called — the user sees the upload error
        // instead of a false success toast.
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
        // Draft is restored on failure so the user can retry without
        // re-filling the heirloom form (post-review: was previously consumed).
        expect(
          bridge.hasPending,
          isTrue,
          reason: 'failed upload restores the draft for retry',
        );
      },
    );

    test(
      'pending draft + currentUserId null → save blocked, no upload attempted',
      () async {
        // Regression guard (review finding): if the auth guard is removed or
        // moved after the storage call, this test catches it.
        fakePermission.setPermissionState(currentUserId: null);
        bridge.setDraft(
          HeirloomDraft(
            imageBytes: Uint8List.fromList([1, 2, 3]),
          ),
        );

        final ok = await vm.saveImportedRecipe();

        expect(ok, isFalse);
        expect(vm.hasError, isTrue);
        verifyNever(
          () => mockStorage.uploadImageData(
            imageData: any(named: 'imageData'),
            userId: any(named: 'userId'),
            path: any(named: 'path'),
            metadata: any(named: 'metadata'),
            cacheControl: any(named: 'cacheControl'),
          ),
        );
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
        // Draft restored — sign-in then retry should pick up where we left off.
        expect(bridge.hasPending, isTrue);
      },
    );

    test(
      'BUT-1161: PNG draft uploads to a .png path (not hardcoded .jpg)',
      () async {
        // 8-byte PNG magic header + filler so ImageFormatUtils.detectFormat
        // classifies these bytes as PNG, not JPEG.
        final pngBytes = Uint8List.fromList(<int>[
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
          0x00, 0x00, 0x00, 0x0D, // filler beyond the 12-byte sniff window
        ]);
        bridge.setDraft(HeirloomDraft(imageBytes: pngBytes));
        when(
          () => mockStorage.uploadImageData(
            imageData: any(named: 'imageData'),
            userId: any(named: 'userId'),
            path: any(named: 'path'),
            metadata: any(named: 'metadata'),
            cacheControl: any(named: 'cacheControl'),
          ),
        ).thenAnswer((_) async => 'https://storage/heirloom/abc.png');

        final ok = await vm.saveImportedRecipe();

        expect(ok, isTrue);
        final captured = verify(
          () => mockStorage.uploadImageData(
            imageData: any(named: 'imageData'),
            userId: any(named: 'userId'),
            path: captureAny(named: 'path'),
            metadata: any(named: 'metadata'),
            cacheControl: any(named: 'cacheControl'),
          ),
        ).captured;
        expect(
          captured.single,
          endsWith('.png'),
          reason: 'PNG bytes must produce a .png suffix, not hardcoded .jpg',
        );
      },
    );

    test('no pending draft → save proceeds normally with no upload', () async {
      // Bridge intentionally empty.
      final ok = await vm.saveImportedRecipe();

      expect(ok, isTrue);
      expect(vm.parsedRecipe?.heirloom, isNull);
      verifyNever(
        () => mockStorage.uploadImageData(
          imageData: any(named: 'imageData'),
          userId: any(named: 'userId'),
          path: any(named: 'path'),
          metadata: any(named: 'metadata'),
          cacheControl: any(named: 'cacheControl'),
        ),
      );
      verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
    });
  });
}
