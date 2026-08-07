import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// BUT-610: the photo-import offline pre-check must fail fast BEFORE the
/// multi-provider OCR cascade (OCR.space → Google Vision → Tesseract), which
/// otherwise spins 30–90s on provider timeouts when offline. We assert the
/// offline error is set and that no parse (the step downstream of OCR) runs.
void main() {
  // ImagePicker plugin lookups + OCR service construction require the binding
  // to exist before any VM (which captures it) is built.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoImportViewModel offline pre-check (BUT-610)', () {
    late MockImportManager mockImportManager;
    late MockConnectivityMonitoringService mockConnectivity;
    late PhotoImportViewModel viewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // PhotoImportViewModel touches SharedPreferences during construction
      // (OcrUsageTracker / OCRExtractionService). Stub it so getInstance()
      // succeeds even though we never reach OCR in these offline tests.
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockImportManager = MockImportManager();
      mockConnectivity = MockConnectivityMonitoringService();
      when(() => mockConnectivity.isConnectedToInternet).thenReturn(false);

      viewModel = PhotoImportViewModel(
        importManager: mockImportManager,
        connectivity: mockConnectivity,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'camera capture sets the offline message before the OCR/parse pipeline',
      () async {
        await viewModel.pickImageFromCamera();

        expect(viewModel.error, AppLocale.current.importOfflineMessage);
        expect(viewModel.hasOcrResult, isFalse);
        // No parse is attempted — the guard returns before OCR even runs.
        verifyNever(
          () => mockImportManager.autoParseMulti(
            any(),
            layout: any(named: 'layout'),
          ),
        );
      },
    );

    // NOTE (2026-08-07): every `verifyNever` below names `layout:`
    // explicitly. mocktail matches on the named-argument KEY SET, so a
    // bare `autoParseMulti(any())` stops matching the production call the
    // moment that call gains a named argument — and `verifyNever` passes
    // when nothing matches, so the suite stays green while the assertion
    // means nothing. That is what happened when the geometry parameter
    // landed. The `error` assertions beside these are what actually
    // guard the offline behaviour; these are belt and braces, and they
    // have to keep matching to be worth their line.
    test('gallery capture sets the offline message before OCR/parse', () async {
      await viewModel.pickImageFromGallery();

      expect(viewModel.error, AppLocale.current.importOfflineMessage);
      verifyNever(
        () => mockImportManager.autoParseMulti(
          any(),
          layout: any(named: 'layout'),
        ),
      );
    });

    test(
      'retryOcr fails fast offline instead of re-running the OCR cascade',
      () async {
        // An image is in memory (prior capture) so retry passes its own guard
        // and reaches the offline pre-check rather than the "no image" branch.
        viewModel.setImageBytesForTesting(Uint8List.fromList([1, 2, 3]));

        await viewModel.retryOcr();

        expect(viewModel.error, AppLocale.current.importOfflineMessage);
        verifyNever(
          () => mockImportManager.autoParseMulti(
            any(),
            layout: any(named: 'layout'),
          ),
        );
      },
    );
  });
}
