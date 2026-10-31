/// BUT-941: PhotoImportViewModel.loadImagesFromPaths — seeding the import from
/// OS-shared photo file paths.
///
/// Intent: shared photos become OCR pages via the existing multi-page pipeline,
/// the batch is resilient to bad files, the page cap holds with a non-silent
/// note, and an all-unreadable batch surfaces an error.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../fixtures/ocr_test_data.dart';

class _OfflineConnectivity extends Fake
    implements ConnectivityMonitoringService {
  @override
  bool get isConnectedToInternet => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhotoImportViewModel vm;
  late MockPersonalRecipeOperations mockPersonalOps;
  late FakeDeviceTextRecognizer recognizer;
  late Directory tmpDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('but941_');

    // registerAsInstance wires the service as the singleton the VM reads via
    // OCRExtractionService.instance.
    recognizer = FakeDeviceTextRecognizer(
      text: OCRExpectedResults.swedishRecipeText,
    );
    OCRExtractionService.createForTesting(
      testDeviceRecognizer: recognizer,
      testOnDeviceEnabled: () => true,
      registerAsInstance: true,
    );

    mockPersonalOps = MockPersonalRecipeOperations();
    when(
      () => mockPersonalOps.addUnifiedRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('Added'));

    vm = PhotoImportViewModel(
      importManager: ImportManager.withStrategies(
        mockPersonalOps,
        [TextImportStrategy()],
      ),
    );
  });

  tearDown(() async {
    vm.dispose();
    OCRExtractionService.resetForTesting();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  /// Write a distinct-content, gate-passing image file.
  String writeImage(int seed) {
    final f = File('${tmpDir.path}/img_$seed.jpg');
    f.writeAsBytesSync(OCRTestImages.uniqueImage(seed));
    return f.path;
  }

  test('two shared photos become two import pages', () async {
    await vm.loadImagesFromPaths([writeImage(1), writeImage(2)]);

    expect(vm.pageCount, 2);
    expect(vm.hasMultiplePages, isTrue);
    expect(vm.consumeInfoMessage(), isNull, reason: 'under the cap');
  });

  test('empty path list is a no-op (no pages, no error)', () async {
    await vm.loadImagesFromPaths(const []);

    expect(vm.pageCount, 0);
    expect(vm.hasError, isFalse);
  });

  test('over the page cap: keeps maxPages and reports a note', () async {
    final paths = List.generate(
      PhotoImportViewModel.maxPages + 2,
      (i) => writeImage(i + 1),
    );

    await vm.loadImagesFromPaths(paths);

    expect(vm.pageCount, PhotoImportViewModel.maxPages);
    expect(
      vm.consumeInfoMessage(),
      isNotNull,
      reason: 'truncation must not be silent',
    );
  });

  test('all-unreadable batch surfaces an error, no pages', () async {
    await vm.loadImagesFromPaths([
      '${tmpDir.path}/missing_a.jpg',
      '${tmpDir.path}/missing_b.jpg',
    ]);

    expect(vm.pageCount, 0);
    expect(vm.hasError, isTrue);
  });

  test('a bad file is skipped but good ones still import', () async {
    await vm.loadImagesFromPaths([
      '${tmpDir.path}/missing.jpg', // unreadable → skipped
      writeImage(7), // readable → appended
    ]);

    expect(vm.pageCount, 1);
    expect(vm.hasError, isFalse);
  });

  test('offline: surfaces the offline error, no OCR, no pages', () async {
    final offlineVm = PhotoImportViewModel(
      importManager: ImportManager.withStrategies(
        mockPersonalOps,
        [TextImportStrategy()],
      ),
      connectivity: _OfflineConnectivity(),
    );
    addTearDown(offlineVm.dispose);

    await offlineVm.loadImagesFromPaths([writeImage(1)]);

    expect(offlineVm.pageCount, 0);
    expect(offlineVm.hasError, isTrue);
    expect(recognizer.calls, 0);
  });

  test('shared pages wait unread until readPages, then read once', () async {
    await vm.loadImagesFromPaths([writeImage(21), writeImage(22)]);

    expect(vm.pageCount, 2);
    expect(vm.unreadPageCount, 2);
    expect(vm.canReadPages, isTrue);
    expect(vm.hasOcrResult, isFalse);
    expect(recognizer.calls, 0);

    await vm.readPages();

    expect(vm.unreadPageCount, 0);
    expect(vm.hasOcrResult, isTrue);
    expect(recognizer.calls, 2);
  });

  test(
    'a page added after reading waits for its own "Läs av 1 sida"',
    () async {
      await vm.loadImagesFromPaths([writeImage(31)]);
      await vm.readPages();
      expect(vm.hasOcrResult, isTrue);

      vm.stagePageForTesting(OCRTestImages.uniqueImage(32));

      expect(vm.unreadPageCount, 1);
      expect(
        vm.hasOcrResult,
        isFalse,
        reason: 'the text of one page must not stand in for two',
      );

      await vm.readPages();
      expect(vm.unreadPageCount, 0);
      expect(vm.hasOcrResult, isTrue);
    },
  );

  test('offline: Läs av says so and reads nothing', () async {
    final offlineVm = PhotoImportViewModel(
      importManager: ImportManager.withStrategies(
        mockPersonalOps,
        [TextImportStrategy()],
      ),
      connectivity: _OfflineConnectivity(),
    );
    addTearDown(offlineVm.dispose);
    offlineVm.stagePageForTesting(OCRTestImages.uniqueImage(41));

    await offlineVm.readPages();

    expect(offlineVm.hasError, isTrue);
    expect(offlineVm.unreadPageCount, 1);
    expect(recognizer.calls, 0);
  });

  group('gallery multi-select', () {
    XFile pick(int seed, {String ext = 'jpg'}) {
      final path = writeImage(seed);
      if (ext == 'jpg') return XFile(path);
      return XFile(File(path).renameSync('${tmpDir.path}/img_$seed.$ext').path);
    }

    test('several photos picked at once become pages in pick order', () async {
      vm.galleryPickerOverride = (_) async => [pick(3), pick(1), pick(2)];
      await vm.pickImageFromGallery();
      expect(vm.pageCount, 3);
      expect(
        vm.pageImages.first,
        File('${tmpDir.path}/img_3.jpg').readAsBytesSync(),
      );
    });

    test('adding pages appends and trims to the remaining slots', () async {
      vm.galleryPickerOverride = (_) async => [pick(1), pick(2), pick(3)];
      await vm.pickImageFromGallery();
      vm.galleryPickerOverride = (limit) async {
        expect(limit, PhotoImportViewModel.maxPages - 3);
        return [pick(4), pick(5), pick(6)];
      };
      await vm.addPageFromGallery();
      expect(vm.pageCount, PhotoImportViewModel.maxPages);
      expect(vm.consumeInfoMessage(), isNotNull);
    });

    test('one unsupported file does not discard the others', () async {
      vm.galleryPickerOverride = (_) async => [pick(1), pick(2, ext: 'gif')];
      await vm.pickImageFromGallery();
      expect(vm.pageCount, 1);
    });

    test('a bad photo never costs a good one its slot', () async {
      vm.galleryPickerOverride = (_) async => [pick(1), pick(2)];
      await vm.pickImageFromGallery();
      vm.galleryPickerOverride = (_) async => [
        pick(3, ext: 'gif'),
        pick(4),
        pick(5),
        pick(6),
      ];
      await vm.addPageFromGallery();
      expect(vm.pageCount, 5);
      expect(vm.consumeInfoMessage(), isNull);
    });

    test('cancelling the picker adds nothing', () async {
      vm.galleryPickerOverride = (_) async => [pick(1), pick(2)];
      await vm.pickImageFromGallery();
      vm.galleryPickerOverride = (_) async => [];
      await vm.addPageFromGallery();
      expect(vm.pageCount, 2);
      expect(vm.hasError, isTrue);
    });
  });
}
