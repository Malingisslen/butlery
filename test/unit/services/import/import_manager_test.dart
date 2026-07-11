import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart'
    as import_strategy;
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/core/di/di_container.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// BUT-1460: returns a fixed [RateLimitResult] so importSinglePhoto's local
/// rate-limit branch can be driven to denied without Firestore.
class _StubRateLimiter extends Fake implements ImportRateLimiter {
  _StubRateLimiter(this._result);
  final RateLimitResult _result;

  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async =>
      _result;
}

/// BUT-1460: a handwritten LLM-vision service that always fails with a
/// distinctive message, so a test can prove importSinglePhoto surfaces the
/// strategy's OWN message rather than the generic multi-strategy miss.
class _FakeLlmFailure extends Fake implements LlmEnhancementService {
  _FakeLlmFailure(this.message);
  final String message;
  int calls = 0;

  @override
  Future<ImportResultV2> extractFromImage(
    Uint8List imageBytes, {
    String? context,
    bool isHandwritten = false,
  }) async {
    calls++;
    return ImportFailure(
      message: message,
      errorCode: ImportErrorCode.ocrFailed,
      pipeline: 'photo',
      tier: 4,
    );
  }
}

void main() {
  // Constructing a real PhotoImportStrategy (importSinglePhoto tests) builds
  // OCRExtractionService.instance, which reads SharedPreferences on init —
  // needs the test binding + a stubbed prefs channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportManager', () {
    late ImportManager importManager;
    late MockPersonalRecipeOperations mockPersonalOps;
    late MockImportStrategy mockStrategy;
    late TextImportStrategy textStrategy;
    late Recipe testRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      SharedPreferences.setMockInitialValues({});
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      mockStrategy = MockImportStrategy();
      textStrategy = TextImportStrategy();
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Test Recipe',
      );

      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) async => RecipeOperationResult.success('Added'));

      // Use withStrategies to avoid Firebase init in UrlImportStrategy
      importManager = ImportManager.withStrategies(
        mockPersonalOps,
        [textStrategy],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Strategy Management', () {
      test('should expose available strategies', () {
        expect(importManager.availableStrategies, isNotEmpty);
        expect(
          importManager.availableStrategies.first,
          isA<TextImportStrategy>(),
        );
      });

      test('should get text import strategy', () {
        expect(
          importManager.getTextImportStrategy(),
          isA<TextImportStrategy>(),
        );
      });

      test('should get compatible strategies for text input', () {
        const input = '''
        Kottbullar
        Ingredienser: 500 g kottfars
        Gor sa har: 1. Forma 2. Stek
        ''';
        final strategies = importManager.getCompatibleStrategies(input);
        expect(strategies, isNotEmpty);
      });

      test('should return empty for input no strategy handles', () {
        final strategies = importManager.getCompatibleStrategies('');
        expect(strategies, isEmpty);
      });

      // BUT-1572: every other test builds the manager via withStrategies, so
      // nothing pins what the DEFAULT constructor actually registers. This
      // guards the real _initializeStrategies() registry — in particular that
      // PhotoImportStrategy survived the BUT-1487 cleanup that removed
      // FileImportStrategy (whose canHandle() is always false, so it was
      // unreachable in the auto loops). A regression that drops the photo/OCR
      // strategy or re-adds the dead file strategy would break silently
      // otherwise.
      test('default constructor registers the expected strategy set', () {
        final defaultManager = ImportManager(mockPersonalOps);
        final strategies = defaultManager.availableStrategies;

        // The four strategies wired in _initializeStrategies, in priority order.
        expect(strategies, hasLength(4));
        expect(strategies[0], isA<ArchiveImportStrategy>());
        expect(strategies[1], isA<UrlImportStrategy>());
        expect(strategies[2], isA<TextImportStrategy>());
        expect(strategies[3], isA<PhotoImportStrategy>());

        // PhotoImportStrategy specifically must remain registered — it backs
        // the OCR / handwritten photo import path.
        expect(
          strategies.whereType<PhotoImportStrategy>(),
          isNotEmpty,
          reason: 'PhotoImportStrategy must stay in the default registry',
        );

        // FileImportStrategy was deliberately unregistered in BUT-1487
        // (unreachable in the auto loops) and must not creep back.
        expect(
          strategies.whereType<FileImportStrategy>(),
          isEmpty,
          reason: 'FileImportStrategy is intentionally not registered',
        );
      });
    });

    group('Auto Import', () {
      test('should auto-detect text strategy and parse', () async {
        const input = '''
        Kottbullar med graddsas

        Ingredienser:
        500 g kottfars
        1 dl mjolk
        2 msk strobrod

        Gor sa har:
        1. Blanda kottfars med mjolk
        2. Forma till bollar
        3. Stek i smor
        ''';

        final result = await importManager.autoImport(input);
        expect(result.isSuccess, isTrue);
        expect(result.strategy, isNotNull);
      });

      test('should try preferred strategy first', () async {
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'mock_strategy');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => import_strategy.ImportResult.success(testRecipe),
        );

        final mgr = ImportManager.withStrategies(
          mockPersonalOps,
          [textStrategy],
        );

        final result = await mgr.autoImport(
          'some recipe text',
          preferredStrategy: mockStrategy,
        );

        expect(result.isSuccess, isTrue);
        expect(result.strategy, equals('mock_strategy'));
        verify(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).called(1);
      });

      test('should fallback when preferred strategy fails', () async {
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'failing');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => import_strategy.ImportResult.failure('Failed'),
        );

        // Input that TextImportStrategy can handle
        const input = '''
        Kottbullar
        Ingredienser: 500 g kottfars
        Gor sa har: 1. Forma 2. Stek
        ''';

        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );

        // Should fall back to built-in TextImportStrategy
        expect(result.strategy, isNot('failing'));
      });

      test('should return failure when no strategy handles input', () async {
        final result = await importManager.autoImport('');
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No import strategy'));
      });

      test('should handle strategy throwing exception', () async {
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'error_strategy');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenThrow(Exception('Boom'));

        final mgr = ImportManager.withStrategies(mockPersonalOps, []);
        final result = await mgr.autoImport(
          'error input',
          preferredStrategy: mockStrategy,
        );

        expect(result.isSuccess, isFalse);
      });

      test('propagates needsAssistance result instead of dropping it', () async {
        // Tier-7 recovery: a strategy that can extract text but not structure
        // it returns ImportResult.assistance (isSuccess=false,
        // needsAssistance=true). The manager must surface this as an assistance
        // result — previously it collapsed into a plain failure, losing the
        // extracted text the user could finish manually.
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'assist');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => import_strategy.ImportResult.assistance(
            extractedText: 'Some unstructured recipe text',
            suggestedTitle: 'Mormors kaka',
            likelyIngredientLines: [2, 3],
          ),
        );

        final mgr = ImportManager.withStrategies(mockPersonalOps, []);
        final result = await mgr.autoImport(
          'recipe',
          preferredStrategy: mockStrategy,
        );

        expect(result.needsAssistance, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.extractedText, 'Some unstructured recipe text');
        expect(result.suggestedTitle, 'Mormors kaka');
        expect(result.likelyIngredientLines, [2, 3]);
        expect(result.strategy, 'assist');
      });

      test('needsAssistance short-circuits the strategy fallback loop', () async {
        // An assistance result is terminal: the manager must NOT keep trying
        // other strategies after one returns needsAssistance.
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'assist');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => import_strategy.ImportResult.assistance(
            extractedText: 'partial',
          ),
        );

        // mockStrategy is in the strategy list (not preferred) so it is reached
        // via the fallback loop.
        final mgr = ImportManager.withStrategies(
          mockPersonalOps,
          [mockStrategy, textStrategy],
        );
        final result = await mgr.autoImport('recipe');

        expect(result.needsAssistance, isTrue);
        expect(result.extractedText, 'partial');
        verify(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).called(1);
      });

      test('should pass options to strategy', () async {
        final options = {'lang': 'sv'};
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'opts');
        when(() => mockStrategy.import(any(), options: options)).thenAnswer(
          (_) async => import_strategy.ImportResult.success(testRecipe),
        );

        final mgr = ImportManager.withStrategies(mockPersonalOps, []);
        final result = await mgr.autoImport(
          'recipe',
          preferredStrategy: mockStrategy,
          options: options,
        );

        expect(result.isSuccess, isTrue);
        verify(() => mockStrategy.import(any(), options: options)).called(1);
      });
    });

    group('Import with Specific Strategy', () {
      test('should import with named strategy', () async {
        const input = '''
        Kottbullar recept

        Ingredienser:
        500 g kottfars
        1 kg potatis

        Gor sa har:
        1. Koka potatis
        2. Forma kottbullar
        ''';

        final result = await importManager.importWithStrategy(
          'Text Import',
          input,
        );
        expect(result.strategy, equals('Text Import'));
      });

      test('should return failure for unknown strategy', () async {
        final result = await importManager.importWithStrategy(
          'NonExistent',
          'input',
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Strategy not found'));
      });
    });

    group('Batch Import', () {
      test('should process multiple imports', () async {
        final inputs = [
          '''Pannkakor
          Ingredienser: 3 agg, 5 dl mjolk, 3 dl vetemjol
          Gor sa har: 1. Vispa ihop 2. Stek i panna''',
          '''Kottbullar
          Ingredienser: 500 g kottfars, 1 dl mjolk
          Gor sa har: 1. Blanda 2. Forma 3. Stek''',
        ];

        final result = await importManager.batchImport(inputs);
        expect(result.totalProcessed, equals(2));
        expect(result.results.length, equals(2));
      });

      test('should handle mixed success and failure', () async {
        final inputs = [
          '''Kottbullar
          Ingredienser: 500 g kottfars
          Gor sa har: 1. Forma 2. Stek''',
          '', // Will fail
        ];

        final result = await importManager.batchImport(inputs);
        expect(result.totalProcessed, equals(2));
        expect(result.failureCount, greaterThan(0));
        expect(result.hasErrors, isTrue);
      });

      test('should handle empty batch', () async {
        final result = await importManager.batchImport([]);
        expect(result.totalProcessed, equals(0));
        expect(result.successCount, equals(0));
        expect(result.successRate, equals(0.0));
      });

      test('should use preferred strategy for all batch items', () async {
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        mockStrategy.setStrategyState(strategyName: 'batch');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => import_strategy.ImportResult.success(testRecipe),
        );

        final result = await importManager.batchImport(
          ['a', 'b'],
          preferredStrategy: mockStrategy,
        );

        expect(result.successCount, equals(2));
        verify(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).called(2);
      });
    });

    group('Direct Recipe Save', () {
      test('should save recipe successfully', () async {
        when(
          () => mockPersonalOps.addUnifiedRecipe(testRecipe),
        ).thenAnswer((_) async => RecipeOperationResult.success('Saved'));

        final result = await importManager.saveImportedRecipe(testRecipe);

        expect(result.isSuccess, isTrue);
        expect(result.strategy, equals('direct_save'));
        verify(() => mockPersonalOps.addUnifiedRecipe(testRecipe)).called(1);
      });

      test('should handle save failure', () async {
        when(() => mockPersonalOps.addUnifiedRecipe(testRecipe)).thenAnswer(
          (_) async => RecipeOperationResult.failure('DB error'),
        );

        final result = await importManager.saveImportedRecipe(testRecipe);

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Failed to save'));
      });

      test('should handle save exception', () async {
        when(
          () => mockPersonalOps.addUnifiedRecipe(testRecipe),
        ).thenThrow(Exception('Connection lost'));

        final result = await importManager.saveImportedRecipe(testRecipe);

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Error saving'));
      });
    });

    group('Validation', () {
      test('should validate input with specific strategy', () {
        final ts = importManager.getTextImportStrategy();
        const valid = '''
        Pannkakor
        Ingredienser: 3 agg, 5 dl mjolk
        Gor sa har: 1. Vispa 2. Stek
        ''';

        expect(importManager.validateInput(valid, strategy: ts), isTrue);
        expect(importManager.validateInput('', strategy: ts), isFalse);
      });

      test('should validate input with any compatible strategy', () {
        const input = '''
        Kottbullar
        Ingredienser: 500 g kottfars
        Gor sa har: 1. Forma 2. Stek
        ''';
        expect(importManager.validateInput(input), isTrue);
      });
    });

    group('Import Suggestions', () {
      test('should provide suggestions sorted by confidence', () {
        const input = '''
        Kottbullar
        Ingredienser: 500 g kottfars
        Gor sa har: 1. Forma 2. Stek
        ''';

        final suggestions = importManager.getImportSuggestions(input);
        expect(suggestions, isNotEmpty);

        for (int i = 0; i < suggestions.length - 1; i++) {
          expect(
            suggestions[i].confidence,
            greaterThanOrEqualTo(suggestions[i + 1].confidence),
          );
        }
      });

      test('should return empty suggestions for empty input', () {
        expect(importManager.getImportSuggestions(''), isEmpty);
      });
    });

    group('Result Objects', () {
      test('ImportManagerResult success properties', () {
        final result = ImportManagerResult.success(
          testRecipe,
          strategy: 'test',
          warnings: ['w1'],
          metadata: {'k': 'v'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.recipe, equals(testRecipe));
        expect(result.hasWarnings, isTrue);
        expect(result.hasMetadata, isTrue);
        expect(result.importedRecipes, hasLength(1));
        expect(result.error, isNull);
      });

      test('ImportManagerResult failure properties', () {
        final result = ImportManagerResult.failure(
          'Error',
          strategy: 'test',
          availableStrategies: ['s1', 's2'],
        );

        expect(result.isSuccess, isFalse);
        expect(result.recipe, isNull);
        expect(result.errorMessage, equals('Error'));
        expect(result.error, equals('Error'));
        expect(result.availableStrategies, hasLength(2));
        expect(result.importedRecipes, isEmpty);
      });

      test('BatchImportResult calculations', () {
        final batch = BatchImportResult(
          results: [
            ImportManagerResult.success(testRecipe),
            ImportManagerResult.failure('err'),
            ImportManagerResult.success(testRecipe),
          ],
          successfulRecipes: [testRecipe, testRecipe],
          errors: ['err'],
          totalProcessed: 3,
          successCount: 2,
          failureCount: 1,
        );

        expect(batch.successRate, closeTo(0.667, 0.001));
        expect(batch.hasErrors, isTrue);
        expect(batch.allSuccessful, isFalse);
      });

      test('BatchImportResult all successful', () {
        final batch = BatchImportResult(
          results: [ImportManagerResult.success(testRecipe)],
          successfulRecipes: [testRecipe],
          errors: [],
          totalProcessed: 1,
          successCount: 1,
          failureCount: 0,
        );

        expect(batch.allSuccessful, isTrue);
        expect(batch.hasErrors, isFalse);
        expect(batch.successRate, equals(1.0));
      });

      test('ImportSuggestion stores properties', () {
        // strategyName is a concrete override on MockImportStrategy,
        // so use setStrategyState instead of when().
        mockStrategy.setStrategyState(strategyName: 'test');
        final suggestion = ImportSuggestion(
          strategy: mockStrategy,
          confidence: 0.85,
          description: 'desc',
        );

        expect(suggestion.confidence, equals(0.85));
        expect(suggestion.description, equals('desc'));
      });
    });

    // BUT-1460: importSinglePhoto is the single-image (handwritten LLM-vision)
    // path. Unlike autoImport it must NOT run the fallback loop that swallows a
    // terminal failure/rate-limit into the generic "No import strategy could
    // handle" message — its whole point is to return the strategy's own result.
    group('importSinglePhoto (BUT-1460)', () {
      final imageBytes = Uint8List.fromList(List<int>.filled(16, 7));

      tearDown(() {
        final getIt = GetIt.instance;
        if (getIt.isRegistered<ImportRateLimiter>()) {
          getIt.unregister<ImportRateLimiter>();
        }
        if (getIt.isRegistered<LlmEnhancementService>()) {
          getIt.unregister<LlmEnhancementService>();
        }
        app_provider.ServiceLocator.reset();
      });

      test(
        'a denied rate limit returns a structured rateLimit result '
        '(not a swallowed generic failure)',
        () async {
          const denied = RateLimitDenied(
            message: 'Too many imports per minute',
            retryAfter: Duration(seconds: 30),
            limitType: LimitType.perMinute,
            suggestedAction: FallbackAction.retryLater,
          );
          final getIt = GetIt.instance;
          if (getIt.isRegistered<ImportRateLimiter>()) {
            getIt.unregister<ImportRateLimiter>();
          }
          getIt.registerSingleton<ImportRateLimiter>(_StubRateLimiter(denied));
          app_provider.ServiceLocator.reset();
          app_provider.ServiceLocator.initialize(DIContainer());

          final mgr = ImportManager.withStrategies(mockPersonalOps, [
            PhotoImportStrategy(),
          ]);

          final result = await mgr.importSinglePhoto(
            'photo',
            options: {'imageBytes': imageBytes, 'isHandwritten': true},
          );

          expect(result.isSuccess, isFalse);
          expect(result.strategy, 'rate_limited');
          expect(result.rateLimitDenied, isNotNull);
          expect(result.rateLimitDenied!.limitType, LimitType.perMinute);
          expect(
            result.errorMessage,
            isNot(contains('No import strategy')),
            reason: 'the rate-limit denial must not be swallowed',
          );
        },
      );

      test(
        'a strategy failure surfaces the strategy own message, preserved '
        '(NOT the generic multi-strategy miss)',
        () async {
          final fakeLlm = _FakeLlmFailure('kunde inte tolka handstilen');
          final getIt = GetIt.instance;
          if (getIt.isRegistered<LlmEnhancementService>()) {
            getIt.unregister<LlmEnhancementService>();
          }
          getIt.registerSingleton<LlmEnhancementService>(fakeLlm);
          // No ImportRateLimiter registered → _rateLimiter resolves null → the
          // rate-limit check is skipped and we reach the strategy.
          app_provider.ServiceLocator.reset();
          app_provider.ServiceLocator.initialize(DIContainer());

          final mgr = ImportManager.withStrategies(mockPersonalOps, [
            PhotoImportStrategy(),
          ]);

          final result = await mgr.importSinglePhoto(
            'photo',
            options: {'imageBytes': imageBytes, 'isHandwritten': true},
          );

          expect(result.isSuccess, isFalse);
          expect(
            result.errorMessage,
            'kunde inte tolka handstilen',
            reason:
                'the strategy failure message must pass through unswallowed',
          );
          expect(result.errorMessage, isNot(contains('No import strategy')));
          expect(fakeLlm.calls, 1, reason: 'exactly one vision call');
        },
      );

      test(
        'returns a clear failure when no photo strategy is registered',
        () async {
          final mgr = ImportManager.withStrategies(mockPersonalOps, [
            textStrategy,
          ]);

          final result = await mgr.importSinglePhoto(
            'photo',
            options: {'imageBytes': imageBytes},
          );

          expect(result.isSuccess, isFalse);
          expect(result.errorMessage, contains('No photo import strategy'));
        },
      );
    });
  });
}
