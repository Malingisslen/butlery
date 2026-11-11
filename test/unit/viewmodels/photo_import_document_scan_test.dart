/// The camera button opens the native document scanner when the
/// `enable_document_scanner` flag is on, and every failure except a refused
/// camera permission falls back to today's plain camera pick. Pages from both
/// routes are held to the AI reader's size limit (S1, S2).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/services/import/document_scan_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../fixtures/ocr_test_data.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _FakeScanner implements DocumentScanner {
  _FakeScanner({this.paths, this.error});
  List<String>? paths;
  final Object? error;
  int scanCalls = 0;
  int? lastMaxPages;
  int cleanUps = 0;

  @override
  Future<List<String>?> scan({required int maxPages}) async {
    scanCalls++;
    lastMaxPages = maxPages;
    if (error != null) throw error!;
    return paths;
  }

  @override
  Future<void> cleanUp() async => cleanUps++;
}

class _FakePickerPlatform extends ImagePickerPlatform {
  _FakePickerPlatform(this.file);
  final XFile? file;
  int calls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late PhotoImportViewModel vm;
  late MockPersonalRecipeOperations mockPersonalOps;
  late _FakePickerPlatform picker;
  late ImagePickerPlatform originalPicker;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
    originalPicker = ImagePickerPlatform.instance;
  });

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('scan_');
    OCRExtractionService.createForTesting(
      testDeviceRecognizer: FakeDeviceTextRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      ),
      testOnDeviceEnabled: () => true,
      registerAsInstance: true,
    );
    mockPersonalOps = MockPersonalRecipeOperations();
    when(
      () => mockPersonalOps.addUnifiedRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
    final pickerFile = File('${tmpDir.path}/picked.jpg')
      ..writeAsBytesSync(OCRTestImages.uniqueImage(99));
    picker = _FakePickerPlatform(XFile(pickerFile.path));
    ImagePickerPlatform.instance = picker;
  });

  tearDown(() async {
    vm.dispose();
    ImagePickerPlatform.instance = originalPicker;
    OCRExtractionService.resetForTesting();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  String writeImage(int seed, {int? bytes}) {
    final f = File('${tmpDir.path}/scan_$seed.jpg');
    f.writeAsBytesSync(
      bytes == null
          ? OCRTestImages.uniqueImage(seed)
          : (Uint8List(bytes)..fillRange(0, bytes, seed % 256)),
    );
    return f.path;
  }

  PhotoImportViewModel makeVm(_FakeScanner scanner, {bool flagOn = true}) {
    vm = PhotoImportViewModel(
      importManager: ImportManager.withStrategies(mockPersonalOps, [
        TextImportStrategy(),
      ]),
      documentScanner: DocumentScanService(
        scanner: scanner,
        isEnabled: () => flagOn,
        platformSupported: true,
        resizer: (b) async => b,
      ),
    );
    return vm;
  }

  test('flag off: the plain picker is used and the scanner untouched', () async {
    final scanner = _FakeScanner(paths: [writeImage(1)]);
    makeVm(scanner, flagOn: false);

    await vm.pickImageFromCamera();

    expect(scanner.scanCalls, 0);
    expect(picker.calls, 1);
    expect(vm.pageCount, 1);
  });

  test('gallery never opens the scanner', () async {
    final scanner = _FakeScanner(paths: [writeImage(1)]);
    makeVm(scanner);

    await vm.pickImageFromGallery();

    expect(scanner.scanCalls, 0);
  });

  test('flag on: two scanned pages are staged and the cache cleaned', () async {
    final scanner = _FakeScanner(paths: [writeImage(1), writeImage(2)]);
    makeVm(scanner);

    await vm.pickImageFromCamera();

    expect(vm.pageCount, 2);
    expect(vm.hasError, isFalse);
    expect(picker.calls, 0);
    expect(scanner.lastMaxPages, PhotoImportViewModel.maxPages);
    expect(scanner.cleanUps, 1);
  });

  test('add page: the scanner is limited to the free slots', () async {
    final scanner = _FakeScanner(paths: [writeImage(3)]);
    makeVm(scanner);
    scanner.paths = [writeImage(1), writeImage(2)];
    await vm.pickImageFromCamera();
    scanner.paths = [writeImage(3)];

    await vm.addPageFromCamera();

    expect(scanner.lastMaxPages, PhotoImportViewModel.maxPages - 2);
    expect(vm.pageCount, 3);
  });

  test('cancel stages nothing and behaves like a cancelled picker', () async {
    final scanner = _FakeScanner(paths: null);
    makeVm(scanner);

    await vm.pickImageFromCamera();

    expect(vm.pageCount, 0);
    expect(picker.calls, 0, reason: 'a cancel must not reopen the camera');
  });

  test('a generic scanner failure falls back to the plain camera', () async {
    final scanner = _FakeScanner(error: StateError('no play services'));
    makeVm(scanner);

    await vm.pickImageFromCamera();

    expect(picker.calls, 1);
    expect(vm.pageCount, 1);
    expect(vm.hasError, isFalse);
  });

  test('a plugin that is missing falls back to the plain camera', () async {
    final scanner = _FakeScanner(error: MissingPluginException());
    makeVm(scanner);

    await vm.pickImageFromCamera();

    expect(picker.calls, 1);
    expect(vm.pageCount, 1);
  });

  test('permission_denied reuses the camera-denied notice', () async {
    final scanner = _FakeScanner(error: const DocumentScanPermissionDenied());
    makeVm(scanner);

    await vm.pickImageFromCamera();

    expect(vm.pageCount, 0);
    expect(picker.calls, 0);
    expect(vm.permissionNotice?.source, ImageSource.camera);
    expect(vm.permissionNotice?.outcome, OsPermissionOutcome.denied);
  });

  test('more pages than slots: capped with the over-cap message', () async {
    final paths = List.generate(
      PhotoImportViewModel.maxPages + 2,
      (i) => writeImage(i + 1),
    );
    makeVm(_FakeScanner(paths: paths));

    await vm.pickImageFromCamera();

    expect(vm.pageCount, PhotoImportViewModel.maxPages);
    expect(vm.consumeInfoMessage(), isNotNull);
  });

  test('handwritten mode asks the scanner for one page', () async {
    final scanner = _FakeScanner(paths: [writeImage(1), writeImage(2)]);
    makeVm(scanner);
    vm.setHandwritten(true);

    await vm.pickImageFromCamera();

    expect(scanner.lastMaxPages, 1);
    expect(vm.pageCount, 1);
    expect(vm.consumeInfoMessage(), isNull);
  });

  group('page size limit (S2)', () {
    const limit = UploadConstants.maxAiReaderPageBytes;

    test('limit is the server base64 ceiling expressed in binary', () {
      makeVm(_FakeScanner());
      // 10 MiB of base64 decodes to 7 864 320 bytes; ocrRecipeImage refuses
      // anything longer, so the app must refuse it first.
      expect(limit, 7864320);
    });

    test('an oversize picked photo is rejected with the size message', () async {
      ImagePickerPlatform.instance = _FakePickerPlatform(
        XFile(writeImage(5, bytes: limit + 1)),
      );
      makeVm(_FakeScanner(), flagOn: false);

      await vm.pickImageFromCamera();

      expect(vm.pageCount, 0);
      expect(vm.hasError, isTrue);
    });

    test('an oversize scanned page is rejected with the size message', () async {
      makeVm(_FakeScanner(paths: [writeImage(1, bytes: limit + 1)]));

      await vm.pickImageFromCamera();

      expect(vm.pageCount, 0);
      expect(vm.hasError, isTrue);
    });

    test('a page exactly at the limit is accepted', () async {
      makeVm(_FakeScanner(paths: [writeImage(1, bytes: limit)]));

      await vm.pickImageFromCamera();

      expect(vm.pageCount, 1);
    });

    test('shared images over the limit are skipped, others kept', () async {
      makeVm(_FakeScanner());

      await vm.loadImagesFromPaths([
        writeImage(1, bytes: limit + 1),
        writeImage(2),
      ]);

      expect(vm.pageCount, 1);
    });

    test('a shared batch of only oversize images errors', () async {
      makeVm(_FakeScanner());

      await vm.loadImagesFromPaths([writeImage(1, bytes: limit + 1)]);

      expect(vm.pageCount, 0);
      expect(vm.hasError, isTrue);
    });
  });

  group('downscaleToJpeg', () {
    setUp(() {
      vm = PhotoImportViewModel(
        importManager: ImportManager.withStrategies(mockPersonalOps, [
          TextImportStrategy(),
        ]),
        documentScanner: DocumentScanService(),
      );
    });

    test('caps the long edge at 2048 and keeps colour', () {
      final big = img.Image(width: 3000, height: 1500);
      img.fill(big, color: img.ColorRgb8(200, 30, 30));
      final out = DocumentScanService.downscaleToJpeg(
        Uint8List.fromList(img.encodeJpg(big)),
      );
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 2048);
      expect(decoded.height, 1024);
      final p = decoded.getPixel(10, 10);
      expect(p.r, greaterThan(p.g + 50));
    });

    test('a small page keeps its size', () {
      final small = img.Image(width: 400, height: 600);
      final out = DocumentScanService.downscaleToJpeg(
        Uint8List.fromList(img.encodeJpg(small)),
      );
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 400);
      expect(decoded.height, 600);
    });
  });
}
