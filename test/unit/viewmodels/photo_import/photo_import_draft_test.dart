import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/draft_image_store_io.dart'
    as image_store;

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// BUT-910 — the photo-import draft must survive what kills the ViewModel
/// (nav-away disposes it) and die on what the user explicitly ends (clear,
/// post-save). These tests pin that contract end to end: codec shape, on-disk
/// image staging, and the VM persist → dispose → restore round-trip.
void main() {
  const recipeText = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.''';

  group('PhotoImportDraft codec', () {
    test('encode returns null when there is no OCR text — key gets removed',
        () {
      expect(
        encodePhotoImportDraft(const PhotoImportDraft(ocrText: '')),
        isNull,
      );
    });

    test('round-trips text, image path and timestamp', () {
      const draft = PhotoImportDraft(
        ocrText: recipeText,
        imagePath: '/tmp/photo_import_draft.img.gz',
        savedAtMs: 1234567890,
      );
      final decoded = decodePhotoImportDraft(encodePhotoImportDraft(draft)!);
      expect(decoded!.ocrText, recipeText);
      expect(decoded.imagePath, draft.imagePath);
      expect(decoded.savedAtMs, draft.savedAtMs);
    });

    test('decode treats a blob without OCR text as no-draft', () {
      expect(decodePhotoImportDraft('{"imagePath":"/tmp/x"}'), isNull);
    });
  });

  group('draft image store (io)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('butlery_draft_test');
      image_store.debugDraftImageDirOverride = tempDir;
    });

    tearDown(() {
      image_store.debugDraftImageDirOverride = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('stage → read round-trips the exact bytes through gzip', () async {
      final bytes = Uint8List.fromList(List.generate(4096, (i) => i % 251));
      final path = await image_store.stageDraftImage(bytes);
      expect(path, isNotNull);
      final restored = await image_store.readDraftImage(path);
      expect(restored, bytes);
    });

    test('delete removes the staged file; read of a gone file is null',
        () async {
      final path =
          await image_store.stageDraftImage(Uint8List.fromList([1, 2, 3]));
      await image_store.deleteDraftImage(path);
      expect(File(path!).existsSync(), isFalse);
      expect(await image_store.readDraftImage(path), isNull);
    });
  });

  group('PhotoImportViewModel draft persistence', () {
    late Directory tempDir;
    late MockPersonalRecipeOperations mockPersonalOps;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      // The VM constructor fires OCR-service init, which reads
      // SharedPreferences via OCRUsageTracker — mock it so the
      // fire-and-forget init doesn't throw. Fresh values per test also
      // isolate the draft key between tests.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      tempDir = Directory.systemTemp.createTempSync('butlery_draft_vm_test');
      image_store.debugDraftImageDirOverride = tempDir;
      mockPersonalOps = MockPersonalRecipeOperations();
      when(() => mockPersonalOps.addUnifiedRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success('Added'));
    });

    tearDown(() async {
      image_store.debugDraftImageDirOverride = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    PhotoImportViewModel makeVm() => PhotoImportViewModel(
          // Real ImportManager (single TextImportStrategy) so restoreDraft's
          // re-parse exercises the actual parser, not a DI mock.
          importManager: ImportManager.withStrategies(
            mockPersonalOps,
            [TextImportStrategy()],
          ),
        );

    test(
        'draft survives VM disposal and restores image + text + parse '
        'into a fresh VM (the nav-away rescue)', () async {
      final bytes = Uint8List.fromList(List.generate(512, (i) => i % 7));
      final vm1 = makeVm();
      await vm1.persistPhotoDraft(imageBytes: bytes, ocrText: recipeText);
      vm1.dispose();

      final vm2 = makeVm();
      expect(await vm2.restoreDraft(), isTrue);
      expect(vm2.ocrText, recipeText);
      expect(vm2.imageBytes, bytes);
      // The re-parse repopulated the recipe state the user saw before nav
      // (title fidelity is the parser's own test suite's job).
      expect(vm2.parsedRecipe, isNotNull);
      vm2.dispose();
    });

    test('clearPhoto (explicit user clear) discards draft and staged image',
        () async {
      final vm = makeVm();
      await vm.persistPhotoDraft(
        imageBytes: Uint8List.fromList([9, 9, 9]),
        ocrText: recipeText,
      );
      final staged = (await vm.loadPersistedDraft())!.imagePath;
      expect(File(staged!).existsSync(), isTrue);

      vm.clearPhoto();
      await pumpEventQueue();

      expect(await vm.loadPersistedDraft(), isNull);
      expect(File(staged).existsSync(), isFalse);
      vm.dispose();
    });

    test('restoreDraft returns false when nothing was persisted', () async {
      final vm = makeVm();
      expect(await vm.restoreDraft(), isFalse);
      expect(vm.hasOcrResult, isFalse);
      vm.dispose();
    });

    test(
        'restoreDraft degrades to text-only when the OS purged the staged '
        'image', () async {
      final vm1 = makeVm();
      await vm1.persistPhotoDraft(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        ocrText: recipeText,
      );
      final staged = (await vm1.loadPersistedDraft())!.imagePath;
      File(staged!).deleteSync();
      vm1.dispose();

      final vm2 = makeVm();
      expect(await vm2.restoreDraft(), isTrue);
      expect(vm2.ocrText, recipeText);
      expect(vm2.imageBytes, isNull);
      vm2.dispose();
    });
  });
}
