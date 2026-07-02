import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/services/permission_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/repositories/mock_storage_repository.dart';

// Using centralized mocks from production_mocks.dart:
// - MockImportManager
// - MockImagePicker
// - MockXFile

// Using local mock patterns that follow centralized architecture
class MockHttpClient extends Mock implements http.Client {}

// Fake for BaseRequest
class FakeBaseRequest extends Fake implements http.BaseRequest {}

// Mock for HTTP StreamedResponse
class MockStreamedResponse extends Mock implements http.StreamedResponse {
  final String _body;
  final int _statusCode;

  MockStreamedResponse(this._body, this._statusCode);

  @override
  int get statusCode => _statusCode;

  @override
  http.ByteStream get stream => http.ByteStream.fromBytes(utf8.encode(_body));
}

// Testable version that allows dependency injection.
//
// BUT-1171: drives the REAL backing fields (`_ocrText` / `_imageBytes`) via the
// production `@visibleForTesting` seams instead of shadow fields + getter
// overrides. The previous double diverged from production state — `ocrText`
// returned the shadow value while `performImport` / `saveImportedRecipe` read
// the empty real field — so those paths never ran against the data the test
// set. Now `ocrText`, `hasOcrResult`, `imageBytes`, `hasImage`, `clearPhoto`
// and `debugState` are all inherited from production and observe the same
// state the pipeline does. Only the camera/gallery pickers stay stubbed to keep
// the OCR service and platform channels out of a unit test.
class TestablePhotoImportViewModel extends PhotoImportViewModel {
  TestablePhotoImportViewModel({
    required super.importManager,
  });

  void setTestImageBytes(Uint8List? bytes) => setImageBytesForTesting(bytes);

  void setTestOcrText(String text) => setOcrTextForTesting(text);

  @override
  Future<void> pickImageFromCamera() async {
    await Future.delayed(Duration.zero); // Ensure async behavior
  }

  @override
  Future<void> pickImageFromGallery() async {
    await Future.delayed(Duration.zero); // Ensure async behavior
  }
}

void main() {
  // ImagePicker plugin lookups require the test binding to be initialized
  // before any service that captures it is constructed.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoImportViewModel', () {
    late TestablePhotoImportViewModel viewModel;
    late MockImportManager mockImportManager;
    late MockImagePicker mockImagePicker;
    late MockHttpClient mockHttpClient;

    // Test image bytes
    final testImageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    // Test OCR text
    const testOcrText = '''
          Pannkakor
          
          Ingredienser:
          - 3 ägg
          - 3 dl mjölk
          - 2 dl vetemjöl
          - 1 tsk salt
          
          Instruktioner:
          1. Vispa ihop ägg och mjölk
          2. Tillsätt mjöl och salt
          3. Låt smeten svälla 10 minuter
          4. Stek tunna pannkakor
          
          Portioner: 4
          Tid: 20 minuter
        ''';

    // Test OCR response
    final Map<String, dynamic> testOcrResponse = {
      'IsErroredOnProcessing': false,
      'ParsedResults': [
        {'ParsedText': testOcrText},
      ],
    };

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // PhotoImportViewModel touches SharedPreferences during construction
      // (via OcrUsageTracker / OCRExtractionService). Stub the platform
      // channel with empty initial values so getInstance() succeeds.
      SharedPreferences.setMockInitialValues({});
      registerFallbackValue(ImageSource.camera);
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(FakeBaseRequest());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // BUT-953: saveImportedRecipe() on the shared base VM calls
      // ServiceLocator.get<HeirloomBridge>() (fail-loud by design — not
      // tryGet). It's intentionally not in TestServiceLocator (the bridge is
      // its only consumer). Register an empty bridge here: no pending heirloom
      // → _attachHeirloomIfPending early-returns → the save path proceeds.
      final getIt = GetIt.instance;
      if (getIt.isRegistered<HeirloomBridge>()) {
        getIt.unregister<HeirloomBridge>();
      }
      getIt.registerSingleton<HeirloomBridge>(HeirloomBridge());

      // BUT-1171: bridge the PRODUCTION ServiceLocator (application_provider) to
      // GetIt.instance so ImportBaseViewModel.saveImportedRecipe's
      // `ServiceLocator.get<HeirloomBridge>()` resolves the bridge registered
      // above. Without this the production ServiceLocator is uninitialized, so
      // the lookup threw "not initialized" — executeAsyncVoid swallowed it into
      // a generic error, masking the real save flow and keeping the three save
      // tests permanently red. DIContainer().get<T>() reads the same
      // GetIt.instance, so the registration above is what gets resolved.
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockImportManager = MockImportManager();
      mockImagePicker = MockImagePicker();
      mockHttpClient = MockHttpClient();

      // Configure ImportManager mock using centralized setImportManagerState()
      final mockTextStrategy = MockTextImportStrategy();
      when(
        () => mockTextStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer((_) async {
        return ImportResult.success(
          RecipeFactory.build(
            title: 'Parsed from OCR',
            description: 'Recipe parsed from OCR text',
          ),
        );
      });

      mockImportManager.setImportManagerState(
        textImportStrategy: mockTextStrategy,
      );

      when(() => mockImportManager.autoImport(any())).thenAnswer((_) async {
        return ImportManagerResult.success(
          RecipeFactory.build(
            title: 'Pannkakor',
            description: 'Klassiska pannkakor',
            ingredients: ['3 ägg', '3 dl mjölk', '2 dl vetemjöl', '1 tsk salt'],
            instructions: [
              'Vispa ihop',
              'Tillsätt mjöl',
              'Låt svälla',
              'Stek pannkakor',
            ],
            portions: 4,
            timeMinutes: 20,
          ),
          strategy: 'text',
        );
      });

      when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer((
        _,
      ) async {
        return ImportManagerResult.success(
          RecipeFactory.build(),
          strategy: 'photo',
        );
      });

      // Configure ImagePicker mock
      final mockXFile = MockXFile();
      when(
        () => mockXFile.readAsBytes(),
      ).thenAnswer((_) async => testImageBytes);

      when(
        () => mockImagePicker.pickImage(source: any(named: 'source')),
      ).thenAnswer((_) async => mockXFile);

      // Configure HTTP Client mock for OCR
      when(() => mockHttpClient.send(any())).thenAnswer(
        (_) async => MockStreamedResponse(
          jsonEncode(testOcrResponse),
          200,
        ),
      );

      // Create viewModel
      viewModel = TestablePhotoImportViewModel(
        importManager: mockImportManager,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      // BUT-1171: tear down the production ServiceLocator bridge so it doesn't
      // leak a stale DIContainer into sibling test files.
      app_provider.ServiceLocator.reset();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.imageBytes, isNull);
        expect(viewModel.ocrText, isEmpty);
        expect(viewModel.hasImage, isFalse);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(viewModel.isProcessing, isFalse);
        expect(viewModel.canImport, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should have correct import type', () {
        // Assert
        expect(viewModel.importType, equals('photo'));
      });
    });

    group('Camera Image Capture', () {
      test('should capture image from camera successfully', () async {
        // Arrange - simulate successful image capture and OCR
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);

        // Act - simulate auto-parse
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.imageBytes, equals(testImageBytes));
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.ocrText, contains('Pannkakor'));
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe?.title, equals('Pannkakor'));
        expect(viewModel.error, isNull);
      });

      test('should handle camera cancellation', () async {
        // Arrange - simulate no image selected
        // Don't set any test data

        // Act
        // ignore: invalid_use_of_protected_member
        await viewModel.pickImageFromCamera();
        // ignore: invalid_use_of_protected_member
        viewModel.setError('Ingen bild vald');

        // Assert
        expect(viewModel.hasImage, isFalse);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Ingen bild vald'));
      });

      test('should handle camera error', () async {
        // Arrange - simulate camera error
        // Don't set any test data

        // Act
        await viewModel.pickImageFromCamera();
        // ignore: invalid_use_of_protected_member
        viewModel.setError('Kunde inte bearbeta bild: Camera error');

        // Assert
        expect(viewModel.hasImage, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Kunde inte bearbeta bild'));
      });
    });

    group('Gallery Image Selection', () {
      test('should select image from gallery successfully', () async {
        // Arrange - simulate successful image selection and OCR
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);

        // Act - simulate auto-parse
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.imageBytes, equals(testImageBytes));
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.ocrText, contains('Pannkakor'));
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle gallery cancellation', () async {
        // Arrange - simulate no image selected
        // Don't set any test data

        // Act
        await viewModel.pickImageFromGallery();
        // ignore: invalid_use_of_protected_member
        viewModel.setError('Ingen bild vald');

        // Assert
        expect(viewModel.hasImage, isFalse);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Ingen bild vald'));
      });
    });

    group('OCR Processing', () {
      test('should perform OCR successfully', () async {
        // Arrange - simulate OCR processing
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);

        // Act - nothing to do, data is set

        // Assert
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.ocrText, contains('Ingredienser'));
        expect(viewModel.ocrText, contains('Instruktioner'));
        expect(viewModel.ocrText, contains('Pannkakor'));
      });

      test('should handle OCR API error', () async {
        // Arrange - simulate OCR API error
        viewModel.setTestImageBytes(testImageBytes);
        // Don't set OCR text to simulate failure
        // ignore: invalid_use_of_protected_member
        viewModel.setError('OCR API-fel: 500');

        // Act - nothing to do, error is set

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('OCR API-fel'));
      });

      test('should handle OCR processing error', () async {
        // Arrange - simulate OCR processing error
        viewModel.setTestImageBytes(testImageBytes);
        // Don't set OCR text to simulate processing failure
        // ignore: invalid_use_of_protected_member
        viewModel.setError(
          'OCR-bearbetningsfel: Invalid image format, Processing failed',
        );

        // Act - nothing to do, error is set

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('OCR-bearbetningsfel'));
      });

      test('should handle empty OCR result', () async {
        // Arrange - simulate empty OCR result
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(''); // Empty OCR text

        // Act - nothing to do, data is set

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
      });

      test('should handle null parsed text', () async {
        // Arrange - simulate null parsed text
        viewModel.setTestImageBytes(testImageBytes);
        // Don't set OCR text (leaving it as null/empty)

        // Act - nothing to do, data is set

        // Assert
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.hasOcrResult, isFalse);
      });
    });

    group('Auto-Parse Functionality', () {
      test('should auto-parse OCR text to recipe', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);

        // Act - perform auto-parse
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Assert
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe?.title, equals('Pannkakor'));
        expect(viewModel.parsedRecipe?.ingredients.length, equals(4));
        expect(viewModel.parsedRecipe?.instructions.length, equals(4));
        expect(viewModel.parsedRecipe?.portions, equals(4));
        expect(viewModel.parsedRecipe?.timeMinutes, equals(20));
      });

      test('should handle auto-parse failure gracefully', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        when(
          () => mockImportManager.autoImport(any()),
        ).thenThrow(Exception('Parse failed'));

        // Act - try auto-parse (will fail)
        try {
          await mockImportManager.autoImport(viewModel.ocrText);
        } catch (e) {
          // Graceful failure - don't set parsed recipe
        }

        // Assert
        expect(viewModel.hasOcrResult, isTrue); // OCR still succeeded
        expect(viewModel.hasParsedRecipe, isFalse); // But auto-parse failed
        expect(
          viewModel.hasError,
          isFalse,
        ); // No error shown (graceful failure)
      });

      test('should handle unsuccessful import result', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        when(() => mockImportManager.autoImport(any())).thenAnswer((_) async {
          return ImportManagerResult.failure(
            'Could not parse recipe',
            strategy: 'text',
          );
        });

        // Act - try auto-parse (will fail)
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Assert
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.hasParsedRecipe, isFalse);
      });

      test('should handle empty import result', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        when(() => mockImportManager.autoImport(any())).thenAnswer((_) async {
          return ImportManagerResult.success(
            null, // No recipe
            strategy: 'text',
          );
        });

        // Act - try auto-parse (will return empty)
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Assert
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.hasParsedRecipe, isFalse);
      });
    });

    group('Manual Import', () {
      test('should perform manual import from OCR text', () async {
        // Arrange
        viewModel.setTestOcrText('Recipe text from OCR');
        final localMockTextStrategy = MockTextImportStrategy();
        when(
          () => localMockTextStrategy.import(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async {
          return ImportResult.success(
            RecipeFactory.build(
              title: 'Manual Import',
              description: 'Manually imported recipe',
            ),
          );
        });

        mockImportManager.setImportManagerState(
          textImportStrategy: localMockTextStrategy,
        );

        // Act
        await viewModel.performImport();

        // Assert
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe, isNotNull);
        expect(viewModel.error, isNull);
      });

      test('should not import without OCR result', () async {
        // Arrange - no OCR text set

        // Act
        await viewModel.performImport();

        // Assert
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals('Vänligen ange text att tolka'));
      });
    });

    group('State Management', () {
      test('should clear photo and OCR data', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }
        expect(viewModel.hasImage, isTrue);
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);

        // Act
        viewModel.clearPhoto();

        // Assert
        expect(viewModel.hasImage, isFalse);
        expect(viewModel.hasOcrResult, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.imageBytes, isNull);
        expect(viewModel.ocrText, isEmpty);
        expect(viewModel.parsedRecipe, isNull);
      });

      test('should track processing state', () async {
        // Arrange
        bool wasProcessing = false;
        viewModel.addListener(() {
          if (viewModel.isProcessing) wasProcessing = true;
        });

        // Act - simulate processing
        // ignore: invalid_use_of_protected_member
        viewModel.setLoading(true);
        await Future.delayed(Duration(milliseconds: 10));
        // ignore: invalid_use_of_protected_member
        viewModel.setLoading(false);

        // Assert
        expect(wasProcessing, isTrue);
        expect(
          viewModel.isProcessing,
          isFalse,
        ); // Should be false after completion
      });

      test('should update canImport based on OCR result', () {
        // Initially cannot import
        expect(viewModel.canImport, isFalse);

        // Set OCR text
        viewModel.setTestOcrText('Some OCR text');

        // Now can import
        expect(viewModel.canImport, isTrue);

        // Clear OCR text
        viewModel.setTestOcrText('');

        // Cannot import again
        expect(viewModel.canImport, isFalse);
      });
    });

    group('Import and Save', () {
      test('should save imported recipe', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }
        expect(viewModel.hasParsedRecipe, isTrue);

        // Act
        final saved = await viewModel.saveImportedRecipe();

        // Assert
        expect(saved, isTrue);
        verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
      });

      test('should not save without parsed recipe', () async {
        // Arrange - no recipe parsed

        // Act
        final saved = await viewModel.saveImportedRecipe();

        // Assert
        expect(saved, isFalse);
        expect(viewModel.error, equals('Inget recept att spara'));
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });

      test('should handle save failure', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }
        when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer((
          _,
        ) async {
          return ImportManagerResult.failure(
            'Failed to save',
            strategy: 'photo',
          );
        });

        // Act
        final saved = await viewModel.saveImportedRecipe();

        // Assert
        expect(saved, isFalse);
        expect(viewModel.error, equals('Ett oväntat fel uppstod'));
      });
    });

    group('Complete Import Workflow', () {
      test('should complete full import from camera', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Act
        final saved = await viewModel.saveImportedRecipe();

        // Assert
        expect(saved, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.hasOcrResult, isTrue);
      });

      test('should complete full import from gallery', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Act
        final saved = await viewModel.saveImportedRecipe();

        // Assert
        expect(saved, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.hasOcrResult, isTrue);
      });

      test('should handle manual import after failed auto-parse', () async {
        // Arrange - Make auto-parse fail initially
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);

        // First auto-parse fails
        when(
          () => mockImportManager.autoImport(any()),
        ).thenThrow(Exception('Auto-parse failed'));

        try {
          await mockImportManager.autoImport(viewModel.ocrText);
        } catch (e) {
          // Expected failure
        }

        expect(viewModel.hasParsedRecipe, isFalse); // Auto-parse failed
        expect(viewModel.hasOcrResult, isTrue); // But OCR succeeded

        // Reset mock for manual import
        when(() => mockImportManager.autoImport(any())).thenAnswer((_) async {
          return ImportManagerResult.success(
            RecipeFactory.build(),
            strategy: 'text',
          );
        });

        // Perform manual import
        await viewModel.performImport();

        // Assert
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe, isNotNull);
      });
    });

    group('Debug State', () {
      test('should provide comprehensive debug information', () async {
        // Arrange
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }

        // Act
        final debug = viewModel.debugState;

        // Assert
        expect(debug['hasImage'], isTrue);
        expect(debug['hasOcrResult'], isTrue);
        expect(debug['ocrTextLength'], greaterThan(0));
        expect(debug['isProcessing'], isFalse);
        expect(debug['imageBytesSize'], equals(testImageBytes.length));
        expect(debug['hasParsedRecipe'], isTrue);
        expect(debug['canImport'], isTrue);
        expect(debug['importType'], equals('photo'));
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = TestablePhotoImportViewModel(
          importManager: mockImportManager,
        );

        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should clean up resources on dispose', () async {
        // Arrange
        final testViewModel = TestablePhotoImportViewModel(
          importManager: mockImportManager,
        );
        testViewModel.setTestImageBytes(testImageBytes);
        testViewModel.setTestOcrText(testOcrText);
        expect(testViewModel.hasImage, isTrue);
        expect(testViewModel.hasOcrResult, isTrue);

        // Act
        testViewModel.dispose();

        // Assert
        // Create a new instance to verify initial state
        final newViewModel = TestablePhotoImportViewModel(
          importManager: mockImportManager,
        );
        expect(newViewModel.hasImage, isFalse);
        expect(newViewModel.hasOcrResult, isFalse);

        // Cleanup
        newViewModel.dispose();
      });

      test('should handle multiple image selections', () async {
        // Act - Select multiple images
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        expect(viewModel.hasImage, isTrue);

        // Simulate another selection
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText('Different OCR text');
        expect(viewModel.hasImage, isTrue);

        viewModel.clearPhoto();
        expect(viewModel.hasImage, isFalse);

        // Final selection
        viewModel.setTestImageBytes(testImageBytes);
        viewModel.setTestOcrText(testOcrText);
        final importResult = await mockImportManager.autoImport(
          viewModel.ocrText,
        );
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(importResult.importedRecipes.first);
        }
        expect(viewModel.hasImage, isTrue);

        // Assert
        expect(viewModel.hasOcrResult, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
      });
    });

    // BUT-1175: exercise the heirloom-pending upload branch of the inherited
    // saveImportedRecipe at the REAL PhotoImportViewModel level. The outer
    // setUp already registered an (empty) HeirloomBridge and bridged the
    // production ServiceLocator; here we add a MockStorageRepository, stage a
    // pending draft, and authenticate the FakePermissionService so
    // `_attachHeirloomIfPending` actually runs (it early-returns in every other
    // test because no draft is pending). Complements the base-class coverage in
    // import_base_viewmodel_heirloom_test.dart with a concrete-VM proof.
    group('BUT-1175: VM-level heirloom-pending upload via saveImportedRecipe', () {
      late MockStorageRepository mockStorage;
      late HeirloomBridge bridge;

      setUp(() {
        final getIt = GetIt.instance;
        bridge = getIt<HeirloomBridge>();
        if (getIt.isRegistered<StorageRepository>()) {
          getIt.unregister<StorageRepository>();
        }
        mockStorage = MockStorageRepository();
        getIt.registerSingleton<StorageRepository>(mockStorage);

        // TestServiceLocator registers a FakePermissionService — authenticate it.
        (getIt<PermissionService>() as FakePermissionService)
            .setPermissionState(currentUserId: 'user-abc');
      });

      test(
        'pending draft + upload OK → uploads scan, attaches metadata, saves',
        () async {
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(
            RecipeFactory.build(id: 'recipe-xyz', title: 'Arvegods'),
          );
          bridge.setDraft(
            HeirloomDraft(
              imageBytes: Uint8List.fromList(List<int>.generate(64, (i) => i)),
              writerName: 'Farmor Elsa',
              year: 1972,
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

          final ok = await viewModel.saveImportedRecipe();

          expect(ok, isTrue);
          expect(viewModel.hasError, isFalse);
          expect(
            viewModel.parsedRecipe?.heirloom,
            isNotNull,
            reason: 'metadata must be stitched onto the recipe before save',
          );
          expect(viewModel.parsedRecipe!.heirloom!.writerName, 'Farmor Elsa');
          expect(viewModel.parsedRecipe!.heirloom!.addedByUserId, 'user-abc');
          expect(
            bridge.hasPending,
            isFalse,
            reason: 'draft drained after upload',
          );
          verify(
            () => mockStorage.uploadImageData(
              imageData: any(named: 'imageData'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              metadata: any(named: 'metadata'),
              cacheControl: any(named: 'cacheControl'),
            ),
          ).called(1);
        },
      );

      test(
        'pending draft + signed out (null uid) → save blocked, no upload, draft restored',
        () async {
          (GetIt.instance<PermissionService>() as FakePermissionService)
              .setPermissionState(currentUserId: null);
          // ignore: invalid_use_of_protected_member
          viewModel.setParsedRecipe(RecipeFactory.build(id: 'recipe-xyz'));
          bridge.setDraft(
            HeirloomDraft(
              imageBytes: Uint8List.fromList([1, 2, 3, 4]),
            ),
          );

          final ok = await viewModel.saveImportedRecipe();

          expect(
            ok,
            isFalse,
            reason: 'save must fail when the heirloom auth re-check fails',
          );
          expect(viewModel.hasError, isTrue);
          expect(
            viewModel.parsedRecipe?.heirloom,
            isNull,
            reason: 'no metadata when upload never ran',
          );
          verifyNever(
            () => mockStorage.uploadImageData(
              imageData: any(named: 'imageData'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              metadata: any(named: 'metadata'),
              cacheControl: any(named: 'cacheControl'),
            ),
          );
          expect(
            bridge.hasPending,
            isTrue,
            reason: 'failed auth restores the draft so sign-in + retry works',
          );
        },
      );
    });

    group('BUT-684: handwritten mode', () {
      test('setHandwritten flips state and notifies listeners', () {
        expect(viewModel.isHandwritten, isFalse);
        var notified = 0;
        viewModel.addListener(() => notified++);

        viewModel.setHandwritten(true);

        expect(viewModel.isHandwritten, isTrue);
        expect(notified, greaterThan(0));
      });

      test(
        'handwritten import routes through importSinglePhoto with '
        'isHandwritten:true and surfaces the recipe as reviewable OCR text',
        () async {
          Map<String, dynamic>? capturedOptions;
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            capturedOptions =
                invocation.namedArguments[#options] as Map<String, dynamic>;
            return ImportManagerResult.success(
              RecipeFactory.build(
                title: 'Mormors pannkakor',
                ingredients: ['3 ägg', '3 dl mjölk'],
                instructions: ['Vispa ihop', 'Stek tunt'],
              ),
              strategy: 'photo',
            );
          });

          viewModel.setHandwritten(true);
          await viewModel.extractHandwrittenForTesting(testImageBytes);

          expect(capturedOptions, isNotNull);
          expect(capturedOptions!['isHandwritten'], isTrue);
          expect(viewModel.parsedRecipe?.title, 'Mormors pannkakor');
          expect(viewModel.hasOcrResult, isTrue);
          expect(viewModel.ocrText, contains('Mormors pannkakor'));
        },
      );

      test(
        'vision path reflects the OFF flag: options isHandwritten:false when '
        'not opted in (guards against a hardcoded true)',
        () async {
          Map<String, dynamic>? capturedOptions;
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            capturedOptions =
                invocation.namedArguments[#options] as Map<String, dynamic>;
            return ImportManagerResult.success(
              RecipeFactory.build(title: 'Tryckt recept'),
              strategy: 'photo',
            );
          });

          // Flag left at its default (false); the option must mirror that.
          expect(viewModel.isHandwritten, isFalse);
          await viewModel.extractHandwrittenForTesting(testImageBytes);

          expect(capturedOptions, isNotNull);
          expect(capturedOptions!['isHandwritten'], isFalse);
        },
      );

      test(
        'BUT-1460: toggle stays switchable after a capture (no capture-lock) — '
        'setHandwritten can flip it back off',
        () async {
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'Handskrivet', ingredients: ['1 ägg']),
              strategy: 'photo',
            ),
          );

          expect(viewModel.canToggleHandwritten, isTrue);
          viewModel.setHandwritten(true);
          await viewModel.extractHandwrittenForTesting(testImageBytes);

          // A capture now exists, but the toggle is NOT locked (single-image
          // replace flow — nothing to strand). It stays switchable and can be
          // flipped back off.
          expect(
            viewModel.canToggleHandwritten,
            isTrue,
            reason: 'no capture-lock — switchable while not processing',
          );
          viewModel.setHandwritten(false);
          expect(
            viewModel.isHandwritten,
            isFalse,
            reason: 'the user can turn handwritten back off after a capture',
          );
        },
      );

      test(
        'clearPhoto resets the handwritten flag (not sticky across imports)',
        () {
          viewModel.setHandwritten(true);
          expect(viewModel.isHandwritten, isTrue);

          viewModel.clearPhoto();

          expect(
            viewModel.isHandwritten,
            isFalse,
            reason: 'a fresh import must default back to the printed-text path',
          );
          expect(viewModel.canToggleHandwritten, isTrue);
        },
      );

      // BUT-1460: the char-OCR quality gate (BUT-660) hard-rejects tiny/low-res
      // images. testImageBytes is 5 bytes → below the min-size gate → isRejected.
      // These prove the handwritten branch runs BEFORE that gate (so a readable
      // handwritten photo the LLM could parse is never rejected first), while
      // the printed path still enforces it.
      test(
        'handwritten pick SKIPS the char-OCR quality gate and reaches the '
        'vision path even on gate-rejecting bytes',
        () async {
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'Handskrivet', ingredients: ['1 ägg']),
              strategy: 'photo',
            ),
          );

          viewModel.setHandwritten(true);
          await viewModel.processPickedImageForTesting(
            testImageBytes, // 5 bytes → the gate WOULD reject this
            ImageSource.gallery,
          );

          expect(
            viewModel.hasError,
            isFalse,
            reason: 'the quality gate must be skipped for handwritten',
          );
          verify(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).called(1);
        },
      );

      test(
        'printed (handwritten OFF) pick still ENFORCES the quality gate — '
        'gate-rejecting bytes error out before any vision call',
        () async {
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'skall aldrig nas'),
              strategy: 'photo',
            ),
          );

          // Handwritten left OFF.
          await viewModel.processPickedImageForTesting(
            testImageBytes,
            ImageSource.gallery,
          );

          expect(
            viewModel.hasError,
            isTrue,
            reason: 'the printed path must reject tiny images at the gate',
          );
          verifyNever(
            () => mockImportManager.importSinglePhoto(
              any(),
              options: any(named: 'options'),
            ),
          );
        },
      );

      test(
        'BUT-1460 review FIX 1: a handwritten pick clears the previous printed '
        'pick quality-gate fields (no stale "Bildkvaliteten är låg" banner)',
        () async {
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'Handskrivet', ingredients: ['1 ägg']),
              strategy: 'photo',
            ),
          );

          // 1) Printed pick populates the quality fields (the tiny bytes score
          //    low and get gate-rejected — the fields are set either way).
          await viewModel.processPickedImageForTesting(
            testImageBytes,
            ImageSource.gallery,
          );
          expect(
            viewModel.qualityScore,
            isNotNull,
            reason: 'precondition: the printed pick set a quality score',
          );

          // 2) Handwritten pick WITHOUT pressing X (no clearPhoto) — the
          //    previous image's quality warning state must not survive, or the
          //    view renders a stale low-quality banner for the new photo.
          viewModel.setHandwritten(true);
          await viewModel.processPickedImageForTesting(
            testImageBytes,
            ImageSource.gallery,
          );

          expect(
            viewModel.qualityScore,
            isNull,
            reason: 'stale quality score from the previous image must be gone',
          );
          expect(
            viewModel.recommendations,
            isNull,
            reason: 'stale quality tips from the previous image must be gone',
          );
        },
      );

      test(
        'a printed pick AFTER a handwritten one routes to the char-OCR path, '
        'not the vision path (no second importSinglePhoto)',
        () async {
          when(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'Handskrivet', ingredients: ['1 ägg']),
              strategy: 'photo',
            ),
          );

          // 1) Handwritten pick → vision path (one importSinglePhoto call).
          viewModel.setHandwritten(true);
          await viewModel.processPickedImageForTesting(
            testImageBytes,
            ImageSource.gallery,
          );

          // 2) Turn it off (freely switchable) and pick again → char-OCR path,
          //    which rejects the tiny bytes at the gate. Crucially it does NOT
          //    fire a second vision call.
          viewModel.setHandwritten(false);
          await viewModel.processPickedImageForTesting(
            testImageBytes,
            ImageSource.gallery,
          );

          verify(
            () => mockImportManager.importSinglePhoto(
              'photo',
              options: any(named: 'options'),
            ),
          ).called(1);
          expect(
            viewModel.hasError,
            isTrue,
            reason: 'the second, printed pick hits the char-OCR quality gate',
          );
        },
      );
    });
  });
}

// Using centralized MockTextImportStrategy from production_mocks.dart
