/// BUT-941: PhotoImportViewModel.loadImagesFromPaths — seeding the import from
/// OS-shared photo file paths.
///
/// Intent: shared photos become OCR pages via the existing multi-page pipeline,
/// the batch is resilient to bad files, the page cap holds with a non-silent
/// note, and an all-unreadable batch surfaces an error.

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

http.ByteStream _byteStream(String data) =>
    http.ByteStream.fromBytes(utf8.encode(data));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhotoImportViewModel vm;
  late MockPersonalRecipeOperations mockPersonalOps;
  late MockHttpClient mockClient;
  late Directory tmpDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('but941_');

    // OCR mock: any send → an OCR.space success body. registerAsInstance wires
    // it as the singleton the VM reads via OCRExtractionService.instance.
    mockClient = MockHttpClient();
    final response = MockStreamedResponse();
    when(() => response.statusCode).thenReturn(200);
    when(() => response.stream).thenAnswer(
      (_) => _byteStream(OCRProviderResponses.ocrSpaceSuccess),
    );
    when(() => mockClient.send(any())).thenAnswer((_) async => response);
    OCRExtractionService.createForTesting(
      testHttpClient: mockClient,
      testOcrApiKey: 'test-key',
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

  /// Write a distinct-content, gate-passing image file (the OCR service
  /// hard-rejects tiny blobs before the mocked HTTP, so this uses the ~60KB
  /// fixture image — one mock send per distinct page).
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
    verifyNever(() => mockClient.send(any()));
  });
}
