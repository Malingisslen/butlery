/// The LAST hop of the geometry chain, and the only one no other test reaches:
/// `_ocrAppendOne` reading `OCRResult.layout` onto the page it appends.
///
/// Every other hop is pinned where it lives — the recogniser seam in
/// `device_text_recognizer_mlkit_test`, the field and the flag gate in
/// `ocr_extraction_service_test`, the document build in
/// `photo_import_viewmodel_multi_test` (which injects pages directly), and the
/// split itself in `multi_recipe_splitter_layout_test`. Two of those need
/// qualifying, both measured 2026-08-07: the multi suite's fail-closed test
/// pins the mixed-provenance SCENARIO but discriminates no document-BUILD
/// mutant (it does still catch a weakened `DocumentLayout.isComplete`, the rule
/// it names, which belongs to `text_layout_test`), and what actually pins the
/// document
/// BUILD there is the reorder test, not the single-page ones. This file is the
/// one place the chain runs END TO END from a file on disk: real OCR service,
/// real on-device tier, real viewmodel, real `ImportManager`, real splitter.
/// In the READ path the recogniser is the only fake — the share path takes
/// file paths, so no image picker is involved, and the mock recipe-operations
/// inside the `ImportManager` is never reached because nothing here saves.
///
/// It exists because `addPageForTesting` — what the multi-page suite uses —
/// hands the layout straight to `_PhotoPage`, skipping the one line that reads
/// it off the OCR result. Deleting `layout: ocrResult.layout` leaves every
/// other suite in the repo green: measured 2026-08-07 at +67 -1 over every
/// suite that drives `_ocrAppendOne`, and this is the only file in `test/`
/// besides `ocr_extraction_service_test` that builds a `RecognitionResult`
/// carrying geometry at all — so nowhere else can a non-null
/// `OCRResult.layout` ever reach the viewmodel.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../fixtures/ocr_test_data.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('the geometry survives the OCR service into the page list', () {
    late PhotoImportViewModel vm;
    var vmBuilt = false;
    late MockPersonalRecipeOperations mockPersonalOps;
    late Directory tmpDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      vmBuilt = false;
      tmpDir = Directory.systemTemp.createTempSync('layout_thread_');
      mockPersonalOps = MockPersonalRecipeOperations();
      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
    });

    tearDown(() async {
      // Guarded: a test that fails before `buildVm` would otherwise surface a
      // LateInitializationError here and bury the real failure.
      if (vmBuilt) vm.dispose();
      OCRExtractionService.resetForTesting();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    /// One line the way a reader hands it over — a box per WORD, because the
    /// line box is not a type size and the detector refuses to read it as one.
    OcrLine row(String text, double height) => OcrLine(
      text: text,
      box: LayoutBox(left: 0, top: 0, width: text.length * 18, height: height),
      words: [
        for (final w in text.split(' '))
          OcrWord(
            text: w,
            box: LayoutBox(left: 0, top: 0, width: 40, height: height),
          ),
      ],
    );

    /// Prose with no ingredient list and no quantity anywhere: the page shape
    /// the whole layout path exists for, and the one where no rewording of the
    /// text rules could ever find the second recipe.
    List<OcrLine> body(String dish) => [
      row('Lagg kokta skalade agg i en ratatouille och servera', 70),
      row('med brod till eller med raris och en fransk gronsaksrora', 70),
      row('Vispa ihop smeten och grada den i ugnen tills $dish ar klar', 70),
      row('Koka upp och lat sjuda under lock i ungefar tjugo minuter', 70),
    ];

    PageLayout spread() => PageLayout(
      lines: [
        row('Italiensk frittata', 167),
        ...body('ratten'),
        row('Fransk omelett', 167),
        ...body('omeletten'),
      ],
    );

    String writeImage() {
      final f = File('${tmpDir.path}/page.jpg');
      f.writeAsBytesSync(OCRTestImages.mediumQuality);
      return f.path;
    }

    void buildVm({required PageLayout page, required bool layoutFlag}) {
      OCRExtractionService.createForTesting(
        testDeviceRecognizer: _FakeRecognizer(page),
        testOnDeviceEnabled: () => true,
        testLayoutEnabled: () => layoutFlag,
        registerAsInstance: true,
      );
      vm = PhotoImportViewModel(
        importManager: ImportManager.withStrategies(mockPersonalOps, [
          TextImportStrategy(),
        ]),
      );
      vmBuilt = true;
    }

    test('a shared photo of a prose spread becomes TWO recipes', () async {
      final page = spread();
      buildVm(page: page, layoutFlag: true);

      await vm.loadImagesFromPaths([writeImage()]);

      expect(
        vm.ocrText,
        equals(page.text),
        reason:
            'premise: the stored text must be the LAYOUT string, or the '
            'row-count precondition would refuse the geometry and this test '
            'would pass for the wrong reason',
      );
      expect(vm.parsedRecipes.length, 2);
    });

    test('with the flag off the same photo stays ONE recipe', () async {
      // The rollback, through the real chain rather than at the seam. The
      // recogniser still measures the page; the service must not carry what it
      // measured, so nothing downstream can split on it.
      final page = spread();
      buildVm(page: page, layoutFlag: false);

      await vm.loadImagesFromPaths([writeImage()]);

      // Asserted on the STRING, not only the count: the fake's two strings
      // differ by a trailing row, so this says the flag really selected the
      // provider's assembly. A count alone would also pass if the layout
      // string had been stored and merely failed to split.
      expect(vm.ocrText, equals('${page.text}\n'));
      expect(vm.parsedRecipes.length, 1);
    });
  });
}

/// Returns geometry for every call, so the flag — never the recogniser — is
/// what decides whether the page splits.
class _FakeRecognizer implements DeviceTextRecognizer {
  _FakeRecognizer(this.page);

  final PageLayout page;

  @override
  bool get isAvailable => true;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async =>
      // The two strings must DIFFER, or nothing downstream can show which one
      // the flag selected — the trap the sibling fake in
      // `ocr_extraction_service_test` documents. A trailing row is the cheapest
      // difference that changes the row count without changing the words.
      RecognitionResult(providerText: '${page.text}\n', layout: page);

  @override
  Future<void> dispose() async {}
}
