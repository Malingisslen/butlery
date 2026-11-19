/// Every recipe an AI reading finds on a photo reaches the recipe list, so the
/// picker shows as it does when the phone splits a page.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/models/photo_ai_recipes.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../../fixtures/ocr_test_data.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MissingRecognizer implements DeviceTextRecognizer {
  @override
  bool get isAvailable => true;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async => null;

  @override
  Future<void> dispose() async {}
}

class _OnlineConnectivity extends Fake
    implements ConnectivityMonitoringService {
  @override
  bool get isConnectedToInternet => true;
}

class _ScriptedVision extends Fake implements LlmEnhancementService {
  _ScriptedVision(this.script);

  final List<ImportResultV2> script;
  int calls = 0;

  @override
  Future<ImportResultV2> extractFromImage(
    Uint8List imageBytes, {
    String? context,
    bool isHandwritten = false,
  }) async => script[calls++];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImportManager manager;
  late PhotoImportViewModel vm;

  Recipe recipe(
    String title, {
    List<String> ingredients = const ['1 dl mjöl'],
    List<String> steps = const ['Blanda.'],
  }) => RecipeFactory.build(
    title: title,
    ingredients: ingredients,
    instructions: steps,
  );

  ImportManagerResult answer(List<Recipe> recipes, {bool continues = false}) =>
      ImportManagerResult.success(
        recipes.first,
        aiRecipes: PhotoAiRecipes(
          recipes,
          firstContinuesFromPreviousPage: continues,
        ),
      );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(ConsentPurposes.defaults());
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    OCRExtractionService.createForTesting(
      testDeviceRecognizer: _MissingRecognizer(),
      testOnDeviceEnabled: () => true,
      registerAsInstance: true,
    );
    manager = MockImportManager();
    vm =
        PhotoImportViewModel(
            importManager: manager,
            connectivity: _OnlineConnectivity(),
          )
          ..hasAiConsentOverride = (() async => true)
          ..grantAiConsentOverride = (() async => true);
  });

  tearDown(() async {
    vm.dispose();
    OCRExtractionService.resetForTesting();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  void visionAnswers(List<ImportManagerResult> results) {
    var i = 0;
    when(
      () => manager.importSinglePhoto(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => results[i++]);
  }

  Future<void> readThroughOffer(int pages) async {
    for (var i = 0; i < pages; i++) {
      vm.stagePageForTesting(OCRTestImages.uniqueImage(i + 1));
    }
    await vm.readPages();
    await vm.acceptAiOffer();
  }

  test(
    'one page with two recipes fills the list and opens the picker',
    () async {
      visionAnswers([
        answer([recipe('Ett'), recipe('Två')]),
      ]);

      await readThroughOffer(1);

      expect(vm.parsedRecipes.map((r) => r.title), ['Ett', 'Två']);
      expect(vm.hasMultipleRecipes, isTrue);
      expect(vm.parsedRecipe, isNull);
      expect(vm.parsedRecipes.every(vm.isAiFoundRecipe), isTrue);
      expect(vm.recipesReadByAi, isTrue);
    },
  );

  test('one page with one recipe behaves as a single import', () async {
    visionAnswers([
      answer([recipe('Ensam')]),
    ]);

    await readThroughOffer(1);

    expect(vm.parsedRecipes, hasLength(1));
    expect(vm.parsedRecipe?.title, 'Ensam');
  });

  test('a lone continuation gets the placeholder title', () async {
    visionAnswers([
      answer([recipe('')], continues: true),
    ]);

    await readThroughOffer(1);

    expect(vm.parsedRecipe?.title, AppLocale.current.llmUnknownRecipe);
  });

  test(
    'two pages: the continuation is joined, with no text round trip',
    () async {
      visionAnswers([
        answer([
          recipe('Bröd', ingredients: ['5 dl mjöl'], steps: ['Knåda.']),
        ]),
        answer([
          recipe('', ingredients: ['1 tsk salt'], steps: ['Grädda.']),
          recipe('Kaka'),
        ], continues: true),
      ]);

      await readThroughOffer(2);

      expect(vm.parsedRecipes.map((r) => r.title), ['Bröd', 'Kaka']);
      expect(vm.parsedRecipes.first.ingredients, ['5 dl mjöl', '1 tsk salt']);
      expect(vm.parsedRecipes.first.instructions, ['Knåda.', 'Grädda.']);
      verifyNever(
        () => manager.autoParseMulti(
          any(),
          layout: any(named: 'layout'),
          channel: any(named: 'channel'),
          reflow: any(named: 'reflow'),
        ),
      );
    },
  );

  test(
    'a page answered with text keeps the text route for the pages',
    () async {
      visionAnswers([
        answer([recipe('Bröd')]),
        ImportManagerResult.assistance(extractedText: 'Rå text från sidan två'),
      ]);
      when(
        () => manager.autoParseMulti(
          any(),
          layout: any(named: 'layout'),
          channel: any(named: 'channel'),
          reflow: any(named: 'reflow'),
        ),
      ).thenAnswer(
        (_) async => BatchImportResult(
          results: const [],
          successfulRecipes: [recipe('Från text')],
          errors: const [],
          totalProcessed: 1,
          successCount: 1,
          failureCount: 0,
        ),
      );

      await readThroughOffer(2);

      expect(vm.parsedRecipe?.title, 'Från text');
      expect(vm.isAiFoundRecipe(vm.parsedRecipes.single), isFalse);
      expect(vm.recipesReadByAi, isFalse);
    },
  );

  test(
    'a recipe the AI could not read is still reported on the text route',
    () async {
      final bread = recipe('Bröd');
      visionAnswers([
        ImportManagerResult.success(
          bread,
          aiRecipes: PhotoAiRecipes([bread], droppedRecipeCount: 1),
        ),
        ImportManagerResult.assistance(extractedText: 'Rå text från sidan två'),
      ]);
      when(
        () => manager.autoParseMulti(
          any(),
          layout: any(named: 'layout'),
          channel: any(named: 'channel'),
          reflow: any(named: 'reflow'),
        ),
      ).thenAnswer(
        (_) async => BatchImportResult(
          results: const [],
          successfulRecipes: [recipe('Från text')],
          errors: const [],
          totalProcessed: 1,
          successCount: 1,
          failureCount: 0,
        ),
      );

      await readThroughOffer(2);

      expect(vm.parsedRecipe?.title, 'Från text');
      expect(vm.droppedRecipeCount, 1);
    },
  );

  test(
    'recipes the AI could not read are summed over pages and cleared by a new photo',
    () async {
      final a = recipe('Ett');
      final b = recipe('Två');
      visionAnswers([
        ImportManagerResult.success(
          a,
          aiRecipes: PhotoAiRecipes([a], droppedRecipeCount: 1),
        ),
        ImportManagerResult.success(
          b,
          aiRecipes: PhotoAiRecipes([b], droppedRecipeCount: 2),
        ),
      ]);

      await readThroughOffer(2);

      expect(vm.droppedRecipeCount, 3);

      vm.clearPhoto();

      expect(vm.droppedRecipeCount, 0);
    },
  );

  test(
    'through the real manager and strategy the list and recipe agree',
    () async {
      final first = recipe('Ett');
      final vision = _ScriptedVision([
        ImportSuccess(
          recipe: first,
          aiRecipes: PhotoAiRecipes(
            [first, recipe('Två')],
            firstContinuesFromPreviousPage: true,
            droppedRecipeCount: 1,
          ),
          confidence: 0.8,
          pipeline: 'photo',
          tier: 4,
          method: 'llm-vision',
          usedLlm: true,
        ),
      ]);
      final real = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [PhotoImportStrategy(llmEnhancement: () => vision)],
      );

      final result = await real.importSinglePhoto(
        'photo',
        options: {
          'imageBytes': OCRTestImages.uniqueImage(7),
          'visionOnly': true,
        },
      );

      expect(result.isSuccess, isTrue);
      expect(result.aiRecipes!.recipes, hasLength(2));
      expect(identical(result.aiRecipes!.recipes.first, result.recipe), isTrue);
      expect(result.aiRecipes!.firstContinuesFromPreviousPage, isTrue);
      expect(result.aiRecipes!.droppedRecipeCount, 1);
    },
  );
}
