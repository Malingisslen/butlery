import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// Offline, only the steps that need the network refuse. The phone's own
/// reading of a photo is covered in photo_import_loadfrompaths_test.dart.
void main() {
  // ImagePicker plugin lookups + OCR service construction require the binding
  // to exist before any VM (which captures it) is built.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoImportViewModel offline', () {
    late MockImportManager mockImportManager;
    late MockConnectivityMonitoringService mockConnectivity;
    late PhotoImportViewModel viewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // PhotoImportViewModel touches SharedPreferences during construction
      // (OcrUsageTracker / OCRExtractionService). Stub it so getInstance()
      // succeeds.
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
      'handwriting offline says so and asks for neither consent nor AI',
      () async {
        // Nothing on the phone reads handwriting, so offline there is no
        // step to try first.
        viewModel.stagePageForTesting(Uint8List.fromList([1, 2, 3]));
        viewModel.setHandwritten(true);

        await viewModel.readPages();

        expect(viewModel.error, AppLocale.current.importOfflineMessage);
        expect(viewModel.aiOffer, isNull);
        expect(viewModel.unreadPageCount, 1);
        verifyNever(
          () => mockImportManager.importSinglePhoto(
            any(),
            options: any(named: 'options'),
          ),
        );
      },
    );
  });
}
