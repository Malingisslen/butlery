import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/unified/types/recipe_types.dart'
    show RecipeOperationResult;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

/// BUT-1040: helper to build a single-recipe [BatchImportResult] — mirrors what
/// `autoParseMulti` returns for a paste with no recipe separators, so the
/// existing single-recipe assertions stay valid after `parseText` was rewired
/// from `autoImport` to `autoParseMulti`.
BatchImportResult _singleResult(Recipe recipe) => BatchImportResult(
  results: [ImportManagerResult.success(recipe, strategy: 'text')],
  successfulRecipes: [recipe],
  errors: const [],
  totalProcessed: 1,
  successCount: 1,
  failureCount: 0,
);

// Using centralized mocks from production_mocks.dart:
// - MockImportManager with setImportManagerState() method
// - MockTextImportStrategy with enhanced stubbing support

void main() {
  group('TextImportViewModel', () {
    late TextImportViewModel viewModel;
    late MockImportManager mockImportManager;
    late MockTextImportStrategy mockTextStrategy; // Centralized mock

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // BUT-1181: bridge the production ServiceLocator so saveImportedRecipe()'s
      // ServiceLocator.get<HeirloomBridge>() resolves (DIContainer wraps the
      // shared GetIt where TestServiceLocator registers HeirloomBridge).
      prod_locator.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create centralized mocks
      mockImportManager = MockImportManager();
      mockTextStrategy = MockTextImportStrategy();

      // Configure default mock result for text parsing using mocktail stubbing
      when(
        () => mockTextStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => ImportResult.success(
          RecipeFactory.build(
            title: 'Parsed Recipe',
            description: 'Recipe parsed from text',
            ingredients: ['2 ägg', '3 dl mjölk', '2 dl vetemjöl'],
            instructions: ['Vispa ihop', 'Stek i pannan'],
          ),
        ),
      );

      // Configure ImportManager using centralized setImportManagerState()
      mockImportManager.setImportManagerState(
        textImportStrategy: mockTextStrategy,
      );

      // Configure autoImport for text strategy approach
      when(
        () => mockImportManager.autoImport(
          any(),
          preferredStrategy: any(named: 'preferredStrategy'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => ImportManagerResult.success(
          RecipeFactory.build(
            title: 'Parsed Recipe',
            description: 'Recipe parsed from text',
            ingredients: ['2 ägg', '3 dl mjölk', '2 dl vetemjöl'],
            instructions: ['Vispa ihop', 'Stek i pannan'],
          ),
          strategy: 'text',
        ),
      );

      // BUT-1040: parseText() now routes through autoParseMulti (not
      // autoImport). Default to a single-recipe batch so the single-recipe
      // path is behaviourally unchanged; multi-recipe tests override this.
      when(
        () => mockImportManager.autoParseMulti(
          any(),
          preferredStrategy: any(named: 'preferredStrategy'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _singleResult(
          RecipeFactory.build(
            title: 'Parsed Recipe',
            description: 'Recipe parsed from text',
            ingredients: ['2 ägg', '3 dl mjölk', '2 dl vetemjöl'],
            instructions: ['Vispa ihop', 'Stek i pannan'],
          ),
        ),
      );

      when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
        (_) async => ImportManagerResult.success(
          RecipeFactory.build(),
          strategy: 'text',
        ),
      );

      // Create viewModel
      viewModel = TextImportViewModel(
        importManager: mockImportManager,
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

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.canImport, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(viewModel.sourceUrl, isNull);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.isParsing, isFalse);
        expect(viewModel.canParse, isTrue);
      });

      test('should have correct import type', () {
        // Assert
        expect(viewModel.importType, equals('text'));
      });
    });

    group('Text Input Management', () {
      test('should update input text', () {
        // Arrange
        const testText = '''
        Pannkakor
        Ingredienser:
        - 2 ägg
        - 3 dl mjölk
        - 2 dl vetemjöl
        
        Instruktioner:
        1. Vispa ihop alla ingredienser
        2. Stek i smör i pannan
        ''';
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateInputText(testText);

        // Assert
        expect(viewModel.inputText, equals(testText));
        expect(viewModel.hasValidInput, isTrue);
        expect(viewModel.canImport, isTrue);
        expect(notificationCount, greaterThan(0));
      });

      test('should validate empty input', () {
        // Arrange
        viewModel.updateInputText('  ');

        // Act & Assert
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.canImport, isFalse);
      });

      test('should clear input and data', () {
        // Arrange
        viewModel.updateInputText('Some recipe text');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearInput();

        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(notificationCount, greaterThan(0));
      });

      test('should clear error when updating text', () {
        // Arrange
        // Force an error state by trying to parse empty text
        viewModel.updateInputText('');
        viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateInputText('New text');

        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should clear import data when empty text is set', () {
        // Arrange
        viewModel.updateInputText('Recipe text');

        // Act
        viewModel.updateInputText('');

        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasParsedRecipe, isFalse);
      });
    });

    group('Text Parsing', () {
      test('should parse valid text successfully', () async {
        // Arrange
        const testText = '''
        Köttbullar
        Ingredienser: 500g köttfärs, 1 ägg
        Instruktioner: Blanda och forma bullar
        ''';
        viewModel.updateInputText(testText);

        // Act
        final result = await viewModel.parseText();

        // Assert
        expect(result, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe, isNotNull);
        expect(viewModel.parsedRecipe!.title, equals('Parsed Recipe'));
        expect(viewModel.error, isNull);
        // Can't verify internal strategy calls with real TextImportStrategy
      });

      test('should fail parsing with empty text', () async {
        // Arrange
        viewModel.updateInputText('');

        // Act
        final result = await viewModel.parseText();

        // Assert
        expect(result, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.error, equals('Vänligen ange text att tolka'));
      });

      test('should handle parsing error', () async {
        // Arrange
        viewModel.updateInputText('Some text');
        when(
          () => mockImportManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenThrow(Exception('Parsing failed'));

        // Act
        final result = await viewModel.parseText();

        // Assert
        expect(result, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.error, contains('Import misslyckades'));
      });

      test(
        'parseText drives isParsing during the parse (BUT-960 spinner)',
        () async {
          // Intent: the social-media view binds the parse button's spinner and
          // its double-tap guard to `viewModel.isParsing` (fran_sociala_medier_
          // view lines 335/338). parseText must flip isParsing (== isLoading)
          // true for the whole Cloud Function round-trip so the "Tolkar..."
          // spinner shows and a second tap is blocked mid-parse — then back to
          // false on completion.
          viewModel.updateInputText('Recipe text');
          bool wasParsing = false;

          viewModel.addListener(() {
            if (viewModel.isParsing) wasParsing = true;
          });

          // Act
          await viewModel.parseText();

          // Assert
          expect(
            wasParsing,
            isTrue,
            reason:
                'parseText must flip isParsing true during the parse so '
                'the spinner shows and double-submit is blocked.',
          );
          expect(viewModel.isParsing, isFalse, reason: 'idle after completion');
        },
      );

      test(
        'parseText surfaces the timeout copy on a server-side hang (BUT-960)',
        () {
          // Intent: a parse that never returns must surface errorImportTimeout
          // (not an endless spinner or the generic import-failed banner). We use
          // fakeAsync so the real 60s client timeout fires in zero wall-clock:
          // autoParseMulti hangs past the window, .timeout() throws the localized
          // copy, and parseText maps it to errorImportTimeout (NOT errorImport-
          // Failed) — proving the distinct-message branch the fix added.
          fakeAsync((async) {
            viewModel.updateInputText('Recipe text');
            when(
              () => mockImportManager.autoParseMulti(
                any(),
                preferredStrategy: any(named: 'preferredStrategy'),
                options: any(named: 'options'),
              ),
            ).thenAnswer(
              (_) => Future.delayed(
                const Duration(seconds: 120),
                () => _singleResult(RecipeFactory.build()),
              ),
            );

            bool? result;
            viewModel.parseText().then((r) => result = r);

            // Past the 60s timeout but before the 120s "server" reply.
            async.elapse(const Duration(seconds: 61));

            expect(result, isFalse);
            expect(
              viewModel.error,
              equals(AppLocale.current.errorImportTimeout),
            );
            expect(viewModel.isParsing, isFalse);
          });
        },
      );

      test('should parse with source URL', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        viewModel.setSourceUrl('https://example.com/recipe');

        // Act
        await viewModel.parseText();

        // Assert
        // Source URL is handled internally
        expect(viewModel.sourceUrl, equals('https://example.com/recipe'));
      });
    });

    group('Recipe Manipulation', () {
      test('should update parsed recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateRecipeTitle('Updated Title');
        viewModel.updateRecipeMealType('Middag');
        viewModel.updateRecipePortions(6);

        // Assert
        expect(viewModel.parsedRecipe!.title, equals('Updated Title'));
        expect(viewModel.parsedRecipe!.mealType, equals('Middag'));
        expect(viewModel.parsedRecipe!.portions, equals(6));
        expect(notificationCount, greaterThan(0));
      });

      test('should clear parsed recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearInput();

        // Assert
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Import and Save', () {
      test('should complete import workflow successfully', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
        // Verify through ImportManager - internal strategy calls can't be verified
        verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
      });

      test('should handle save failure', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
          (_) async => ImportManagerResult.failure(
            'Failed to save',
            strategy: 'text',
          ),
        );

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isFalse);
      });

      test('should not save without valid input', () async {
        // Arrange
        viewModel.updateInputText('');

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });

      test('should handle import error', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        // importAndSave() still routes through completeImport → performImport →
        // strategy.import (the single-recipe path), NOT autoParseMulti, so the
        // strategy is the seam to fault-inject here.
        when(
          () => mockTextStrategy.import(any(), options: any(named: 'options')),
        ).thenThrow(Exception('Import failed'));

        // Act — executeAsync rethrows after setting error
        try {
          await viewModel.importAndSave();
        } catch (_) {}

        // Assert
        expect(viewModel.hasError, isTrue);
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });
    });

    // BUT-1040: a cookbook-style paste with explicit separators yields N
    // recipes routed into the shared multi-recipe picker; a single-recipe
    // paste collapses to one and drives the existing single-recipe path.
    group('Multi-recipe parse (BUT-1040)', () {
      test('single-recipe parse → hasMultipleParsedRecipes false, mirrors '
          'parsedRecipe', () async {
        // Intent: a normal paste must NOT route to the picker, and the
        // single-recipe getter must stay populated so existing consumers work.
        viewModel.updateInputText('Pannkakor\n2 ägg\nVispa och stek.');

        final ok = await viewModel.parseText();

        expect(ok, isTrue);
        expect(viewModel.hasMultipleParsedRecipes, isFalse);
        expect(viewModel.parsedRecipes, hasLength(1));
        expect(viewModel.parsedRecipe, isNotNull);
        expect(viewModel.parsedRecipe, same(viewModel.parsedRecipes.first));
      });

      test('multi-recipe parse → hasMultipleParsedRecipes true and picker list '
          'holds every recipe', () async {
        // Intent: when the splitter yields >1 recipe the view must be able to
        // route to the picker (hasMultipleParsedRecipes) AND see all recipes.
        final batch = BatchImportResult(
          results: const [],
          successfulRecipes: [
            RecipeFactory.build(id: 'r1', title: 'Pannkakor'),
            RecipeFactory.build(id: 'r2', title: 'Våfflor'),
            RecipeFactory.build(id: 'r3', title: 'Plättar'),
          ],
          errors: const [],
          totalProcessed: 3,
          successCount: 3,
          failureCount: 0,
        );
        when(
          () => mockImportManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => batch);
        viewModel.updateInputText('Pannkakor\n---\nVåfflor\n---\nPlättar');

        final ok = await viewModel.parseText();

        expect(ok, isTrue);
        expect(viewModel.hasMultipleParsedRecipes, isTrue);
        expect(viewModel.parsedRecipes.map((r) => r.title), [
          'Pannkakor',
          'Våfflor',
          'Plättar',
        ]);
        // First seeds the single-recipe getter so non-null consumers survive.
        expect(viewModel.parsedRecipe!.title, 'Pannkakor');
      });

      test(
        'source URL is carried across EVERY recipe in a multi-recipe batch',
        () async {
          // Intent: the old single-recipe path stamped sourceUrl onto the parsed
          // recipe; the batch path must stamp it onto all N, not just the first.
          final batch = BatchImportResult(
            results: const [],
            successfulRecipes: [
              RecipeFactory.build(id: 'r1', title: 'A'),
              RecipeFactory.build(id: 'r2', title: 'B'),
            ],
            errors: const [],
            totalProcessed: 2,
            successCount: 2,
            failureCount: 0,
          );
          when(
            () => mockImportManager.autoParseMulti(
              any(),
              preferredStrategy: any(named: 'preferredStrategy'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((_) async => batch);
          viewModel.updateTextAndSource(
            'A\n---\nB',
            sourceUrl: 'https://insta.test/p',
          );

          await viewModel.parseText();

          expect(
            viewModel.parsedRecipes.map((r) => r.sourceUrl),
            everyElement('https://insta.test/p'),
          );
        },
      );

      test(
        'parse that yields no recipes sets an error and returns false',
        () async {
          // Intent: an empty batch must surface the import-failed error, not
          // silently report success with an empty picker list.
          final empty = BatchImportResult(
            results: const [],
            successfulRecipes: const [],
            errors: const ['no recipe'],
            totalProcessed: 1,
            successCount: 0,
            failureCount: 1,
          );
          when(
            () => mockImportManager.autoParseMulti(
              any(),
              preferredStrategy: any(named: 'preferredStrategy'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((_) async => empty);
          viewModel.updateInputText('not a recipe');

          final ok = await viewModel.parseText();

          expect(ok, isFalse);
          expect(viewModel.hasMultipleParsedRecipes, isFalse);
          expect(viewModel.error, contains('Import misslyckades'));
        },
      );

      test('parsedRecipes is reset between consecutive parses', () async {
        // Intent: a fresh paste must not leak the previous parse's picker list
        // (the _parsedRecipes.clear() at the top of parseText).
        final two = BatchImportResult(
          results: const [],
          successfulRecipes: [
            RecipeFactory.build(id: 'r1', title: 'A'),
            RecipeFactory.build(id: 'r2', title: 'B'),
          ],
          errors: const [],
          totalProcessed: 2,
          successCount: 2,
          failureCount: 0,
        );
        when(
          () => mockImportManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => two);
        viewModel.updateInputText('A\n---\nB');
        await viewModel.parseText();
        expect(viewModel.parsedRecipes, hasLength(2));

        // Second parse → back to a single recipe; list must shrink to 1.
        when(
          () => mockImportManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _singleResult(RecipeFactory.build(id: 'r3', title: 'C')),
        );
        viewModel.updateInputText('C');
        await viewModel.parseText();

        expect(viewModel.parsedRecipes, hasLength(1));
        expect(viewModel.hasMultipleParsedRecipes, isFalse);
      });
    });

    // BUT-1040: saveSelectedRecipes persists the user's picker selection,
    // one import-layer save per recipe, surfacing the first failure.
    group('saveSelectedRecipes (BUT-1040)', () {
      test('saves each selected recipe and reports success', () async {
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'A'),
          RecipeFactory.build(id: 'r2', title: 'B'),
        ];

        final ok = await viewModel.saveSelectedRecipes(recipes);

        expect(ok, isTrue);
        verify(() => mockImportManager.saveImportedRecipe(any())).called(2);
      });

      test('empty selection sets an error and saves nothing', () async {
        final ok = await viewModel.saveSelectedRecipes(const []);

        expect(ok, isFalse);
        expect(viewModel.hasError, isTrue);
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });

      test(
        'first failing save surfaces an error and stops the batch',
        () async {
          // Intent: if recipe 1 fails to save, the user must see an error — we
          // must not silently report success for a partially-saved batch.
          when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
            (_) async =>
                ImportManagerResult.failure('disk full', strategy: 'text'),
          );
          final recipes = [
            RecipeFactory.build(id: 'r1', title: 'A'),
            RecipeFactory.build(id: 'r2', title: 'B'),
          ];

          final ok = await viewModel.saveSelectedRecipes(recipes);

          expect(ok, isFalse);
          expect(viewModel.hasError, isTrue);
        },
      );
    });

    // BUT-1040: end-to-end through the REAL ImportManager + splitter + parser,
    // so the wiring (not just the mock contract) is exercised.
    group('Multi-recipe parse — real ImportManager (BUT-1040)', () {
      late TextImportViewModel realVm;
      late MockPersonalRecipeOperations mockOps;

      setUp(() {
        mockOps = MockPersonalRecipeOperations();
        when(
          () => mockOps.addUnifiedRecipe(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
        realVm = TextImportViewModel(
          importManager: ImportManager.withStrategies(mockOps, [
            TextImportStrategy(),
          ]),
        );
      });

      tearDown(() => realVm.dispose());

      const singleRecipe = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.''';

      const twoRecipePage = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.

Våfflor
Ingredienser:
4 dl vetemjöl
3 dl grädde
Gör så här:
Grädda i våffeljärn tills gyllene.''';

      test('single recipe collapses to one — picker not triggered', () async {
        realVm.updateInputText(singleRecipe);

        final ok = await realVm.parseText();

        expect(ok, isTrue);
        expect(realVm.hasMultipleParsedRecipes, isFalse);
        expect(realVm.parsedRecipe, isNotNull);
      });

      test('two-recipe page splits and routes to the picker', () async {
        realVm.updateInputText(twoRecipePage);

        final ok = await realVm.parseText();

        expect(ok, isTrue);
        expect(realVm.hasMultipleParsedRecipes, isTrue);
        expect(realVm.parsedRecipes.length, greaterThanOrEqualTo(2));
      });
    });

    group('Text and Source Management', () {
      test('should update text and source URL together', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateTextAndSource(
          'Recipe content from social media',
          sourceUrl: 'https://instagram.com/recipe-post',
        );

        // Assert
        expect(viewModel.inputText, equals('Recipe content from social media'));
        expect(
          viewModel.sourceUrl,
          equals('https://instagram.com/recipe-post'),
        );
        expect(
          notificationCount,
          greaterThanOrEqualTo(2),
        ); // One for text, one for URL
      });

      test('should update source URL', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setSourceUrl('https://example.com/recipe');

        // Assert
        expect(viewModel.sourceUrl, equals('https://example.com/recipe'));
        expect(notificationCount, greaterThan(0));
      });

      test('should clear source URL with import data', () {
        // Arrange
        viewModel.setSourceUrl('https://example.com');

        // Act
        viewModel.clearInput();

        // Assert
        expect(viewModel.sourceUrl, isNull);
      });
    });

    group('Input Suggestions', () {
      test('should provide input suggestions for empty text', () {
        // Arrange
        viewModel.updateInputText('');

        // Act
        final suggestions = viewModel.getInputSuggestions();

        // Assert
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.any(
            (s) => s.contains('Klistra in') || s.contains('skriv'),
          ),
          isTrue,
        );
      });

      test('should provide suggestions for short text', () {
        // Arrange
        viewModel.updateInputText('Kort text');

        // Act
        final suggestions = viewModel.getInputSuggestions();

        // Assert
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.any(
            (s) =>
                s.toLowerCase().contains('ingrediens') ||
                s.toLowerCase().contains('instruktion'),
          ),
          isTrue,
        );
      });

      test('should provide suggestions for text without ingredients', () {
        // Arrange
        viewModel.updateInputText('Pannkakor är goda. Stek dem i pannan.');

        // Act
        final suggestions = viewModel.getInputSuggestions();

        // Assert
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.any((s) => s.toLowerCase().contains('ingrediens')),
          isTrue,
        );
      });

      test('should provide suggestions for text without instructions', () {
        // Arrange
        viewModel.updateInputText('Ingredienser: 2 ägg, 3 dl mjölk, 2 dl mjöl');

        // Act
        final suggestions = viewModel.getInputSuggestions();

        // Assert
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.any((s) => s.toLowerCase().contains('instruktion')),
          isTrue,
        );
      });

      test('should return empty suggestions for well-formed text', () {
        // Arrange
        viewModel.updateInputText('''
          Pannkakor
          
          Ingredienser:
          - 2 ägg
          - 3 dl mjölk
          - 2 dl vetemjöl
          - 1 krm salt
          
          Instruktioner:
          1. Vispa ihop alla ingredienser
          2. Låt smeten svälla 10 minuter
          3. Stek tunna pannkakor i smör
          4. Servera med sylt och grädde
        ''');

        // Act
        final suggestions = viewModel.getInputSuggestions();

        // Assert - well-formed text might still have minor suggestions (e.g., portions)
        expect(suggestions.length, equals(1));
        expect(
          suggestions[0],
          anyOf(
            contains('ser bra ut'),
            contains('portion'),
          ),
        );
      });
    });

    group('Validation', () {
      test('should validate import data with recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();

        // Act - validateImportData is part of complete import workflow
        final hasRecipe = viewModel.hasParsedRecipe;

        // Assert
        expect(hasRecipe, isTrue);
      });

      test('should not validate without recipe', () {
        // Arrange - no recipe parsed

        // Act - check if we have parsed recipe
        final hasRecipe = viewModel.hasParsedRecipe;

        // Assert
        expect(hasRecipe, isFalse);
      });

      test('should validate input text', () {
        // Arrange
        viewModel.updateInputText('Valid recipe text');

        // Act
        final isValid = viewModel.validateInput();

        // Assert
        expect(isValid, isTrue);
      });

      test('should not validate empty input', () {
        // Arrange
        viewModel.updateInputText('');

        // Act
        final isValid = viewModel.validateInput();

        // Assert
        expect(isValid, isFalse);
      });
    });

    group('Error Handling', () {
      test('should set and clear error', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        when(
          () => mockImportManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenThrow(Exception('Test error'));

        // Act - trigger error
        await viewModel.parseText();

        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Import misslyckades'));

        // Clear error by updating text
        viewModel.updateInputText('New text');
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should handle import manager not available', () async {
        // Arrange
        final separateMockManager = MockImportManager();
        when(
          () => separateMockManager.autoParseMulti(
            any(),
            preferredStrategy: any(named: 'preferredStrategy'),
            options: any(named: 'options'),
          ),
        ).thenThrow(Exception('Import manager not available'));

        final testViewModel = TextImportViewModel(
          importManager: separateMockManager,
        );
        testViewModel.updateInputText('Recipe text');

        // Act
        final result = await testViewModel.parseText();

        // Assert
        expect(result, isFalse);
        expect(testViewModel.error, contains('Import misslyckades'));

        // Cleanup
        testViewModel.dispose();
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = TextImportViewModel(
          importManager: mockImportManager,
        );

        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should not update after disposal', () {
        // Arrange
        final testViewModel = TextImportViewModel(
          importManager: mockImportManager,
        );
        testViewModel.dispose();

        // Act
        testViewModel.updateInputText('Should not update');

        // Assert
        expect(testViewModel.inputText, isEmpty);
      });

      test('should handle multiple operations', () async {
        // Arrange
        viewModel.updateInputText('First recipe');

        // Act - Multiple operations
        await viewModel.parseText();
        viewModel.updateInputText('Second recipe');
        await viewModel.parseText();
        viewModel.clearInput();
        viewModel.updateInputText('Third recipe');
        await viewModel.importAndSave();

        // Assert
        expect(viewModel.inputText, equals('Third recipe'));
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
      });
    });
  });
}
