// test/unit/viewmodels/import_base_viewmodel_test.dart
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// Test implementation of ImportBaseViewModel
class TestImportViewModel extends ImportBaseViewModel {
  TestImportViewModel({required super.importManager});

  @override
  Future<void> performImport() async {
    if (!canImport) {
      setError('Cannot import');
      return;
    }

    final recipe = await parseTextToRecipe('Test recipe content');
    setParsedRecipe(recipe);
  }

  @override
  String get importType => 'test';
}

// Test implementation with TextImportMixin
class TestTextImportViewModel extends ImportBaseViewModel with TextImportMixin {
  TestTextImportViewModel({required super.importManager});

  @override
  String get importType => 'text';
}

// Test implementation with UrlImportMixin
class TestUrlImportViewModel extends ImportBaseViewModel with UrlImportMixin {
  TestUrlImportViewModel({required super.importManager});

  @override
  String get importType => 'url';

  @override
  Future<String> fetchContentFromUrl(String url) async {
    if (url.contains('error')) {
      throw Exception('Failed to fetch URL');
    }
    return 'Fetched content from $url';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImportManager mockImportManager;
  late MockTextImportStrategy mockTextStrategy;
  late TestImportViewModel viewModel;
  late TestTextImportViewModel textViewModel;
  late TestUrlImportViewModel urlViewModel;

  // Default recipe returned by the text strategy stub
  final defaultImportedRecipe = RecipeFactory.build(
    title: 'Imported Recipe',
    description: 'From text: test content',
  );

  setUpAll(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() async {
    mockImportManager = MockFactory.createImportManager();
    mockTextStrategy = MockTextImportStrategy();

    mockImportManager.setImportManagerState(
      textImportStrategy: mockTextStrategy,
      availableStrategies: [mockTextStrategy],
    );

    // Stub import() WITHOUT named options — matches production call site
    when(() => mockTextStrategy.import(any()))
        .thenAnswer((_) async => ImportResult.success(defaultImportedRecipe));

    when(() => mockImportManager.saveImportedRecipe(any()))
        .thenAnswer((_) async => ImportManagerResult.success(
              RecipeFactory.build(),
              strategy: 'test',
            ));

    viewModel = TestImportViewModel(importManager: mockImportManager);
    textViewModel = TestTextImportViewModel(importManager: mockImportManager);
    urlViewModel = TestUrlImportViewModel(importManager: mockImportManager);
  });

  tearDown(() async {
    viewModel.dispose();
    textViewModel.dispose();
    urlViewModel.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  group('ImportBaseViewModel - State Management', () {
    test('should initialize with default state', () {
      expect(viewModel.parsedRecipe, isNull);
      expect(viewModel.hasParsedRecipe, isFalse);
      expect(viewModel.sourceUrl, isNull);
      expect(viewModel.canImport, isTrue);
      expect(viewModel.isParsing, isFalse);
      expect(viewModel.canParse, isTrue);
      expect(viewModel.importType, equals('test'));
      expect(viewModel.error, isNull);
      expect(viewModel.hasError, isFalse);
      expect(viewModel.isLoading, isFalse);
    });

    test('should set parsed recipe correctly', () {
      final recipe = RecipeFactory.build(title: 'Test Recipe');

      viewModel.setParsedRecipe(recipe);

      expect(viewModel.parsedRecipe, equals(recipe));
      expect(viewModel.hasParsedRecipe, isTrue);
    });

    test('should clear parsed recipe when set to null', () {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);
      expect(viewModel.hasParsedRecipe, isTrue);

      viewModel.setParsedRecipe(null);

      expect(viewModel.parsedRecipe, isNull);
      expect(viewModel.hasParsedRecipe, isFalse);
    });

    test('should set source URL correctly', () {
      const url = 'https://example.com/recipe';

      viewModel.setSourceUrl(url);

      expect(viewModel.sourceUrl, equals(url));
    });

    test('should clear source URL when set to null', () {
      viewModel.setSourceUrl('https://example.com');
      expect(viewModel.sourceUrl, isNotNull);

      viewModel.setSourceUrl(null);

      expect(viewModel.sourceUrl, isNull);
    });

    test('should clear all import data', () {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);
      viewModel.setSourceUrl('https://example.com');
      viewModel.setError('Test error');

      viewModel.clearAll();

      expect(viewModel.parsedRecipe, isNull);
      expect(viewModel.sourceUrl, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.hasError, isFalse);
    });

    test('should handle error state correctly', () {
      viewModel.setError('Import failed');

      expect(viewModel.error, equals('Import failed'));
      expect(viewModel.hasError, isTrue);

      viewModel.clearError();

      expect(viewModel.error, isNull);
      expect(viewModel.hasError, isFalse);
    });

    test('should track loading state during operations', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isParsing, isFalse);

      viewModel.setLoading(true);

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isParsing, isTrue);
    });

    test('should provide debug state information', () {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);
      viewModel.setSourceUrl('https://example.com');

      final debugState = viewModel.debugState;

      expect(debugState['hasParsedRecipe'], isTrue);
      expect(debugState['sourceUrl'], equals('https://example.com'));
      expect(debugState['canImport'], isTrue);
      expect(debugState['importType'], equals('test'));
    });

    test('should handle disposal correctly', () {
      final recipe = RecipeFactory.build();
      final testVm = TestImportViewModel(importManager: mockImportManager);
      testVm.setParsedRecipe(recipe);
      testVm.setSourceUrl('https://example.com');

      testVm.dispose();

      // After disposal, state changes should not crash
      expect(() => testVm.setParsedRecipe(null), returnsNormally);
      expect(() => testVm.setSourceUrl(null), returnsNormally);
    });

    test('should not update state after disposal', () {
      final testVm = TestImportViewModel(importManager: mockImportManager);
      testVm.dispose();

      testVm.setParsedRecipe(RecipeFactory.build());
      testVm.setSourceUrl('https://example.com');

      expect(testVm.parsedRecipe, isNull);
      expect(testVm.sourceUrl, isNull);
    });

    test('should notify listeners on state changes', () {
      int notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      viewModel.setParsedRecipe(RecipeFactory.build());
      expect(notificationCount, equals(1));

      viewModel.setSourceUrl('https://example.com');
      expect(notificationCount, equals(2));

      viewModel.clearAll();
      expect(notificationCount,
          equals(4)); // clearAll calls notifyListeners after clearing state
    });
  });

  group('ImportBaseViewModel - Import Operations', () {
    test('should parse text to recipe successfully', () async {
      final result = await viewModel.parseTextToRecipe('Test recipe content');

      expect(result, isNotNull);
      expect(result?.title, equals('Imported Recipe'));
    });

    test('should parse text with source URL', () async {
      const url = 'https://example.com/recipe';

      final result = await viewModel.parseTextToRecipe(
        'Test recipe content',
        url: url,
      );

      expect(result, isNotNull);
      expect(result?.sourceUrl, equals(url));
    });

    test('should handle parse error', () async {
      when(() => mockTextStrategy.import(any())).thenAnswer(
          (_) async => ImportResult.failure('Failed to parse recipe'));

      // executeAsync rethrows — catch the exception
      Object? caughtError;
      try {
        await viewModel.parseTextToRecipe('Invalid content');
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isNotNull);
      expect(viewModel.hasError, isTrue);
    });

    test('should save imported recipe successfully', () async {
      final recipe = RecipeFactory.build(title: 'Test Recipe');
      viewModel.setParsedRecipe(recipe);

      final success = await viewModel.saveImportedRecipe();

      expect(success, isTrue);
      expect(viewModel.hasError, isFalse);

      verify(() => mockImportManager.saveImportedRecipe(recipe)).called(1);
    });

    test('should handle save without parsed recipe', () async {
      final success = await viewModel.saveImportedRecipe();

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      // Production uses Swedish locale
      expect(viewModel.error, equals('Inget recept att spara'));

      verifyNever(() => mockImportManager.saveImportedRecipe(any()));
    });

    test('should handle save error', () async {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);

      when(() => mockImportManager.saveImportedRecipe(any()))
          .thenAnswer((_) async => ImportManagerResult.failure('Save failed'));

      final success = await viewModel.saveImportedRecipe();

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      // executeAsyncVoid sets errorPrefix or errorUnexpected
      expect(viewModel.error, isNotNull);
    });

    test('should complete full import workflow', () async {
      final success = await viewModel.completeImport();

      expect(success, isTrue);
      expect(viewModel.hasParsedRecipe, isTrue);

      verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
    });

    test('should handle complete import with validation failure', () async {
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.success(
                RecipeFactory.build(
                  title: '',
                  ingredients: [],
                  instructions: [],
                ),
              ));

      final success = await viewModel.completeImport();

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, equals('Recepttitel kr\u00e4vs'));
    });

    test('should handle complete import when cannot import', () async {
      textViewModel.updateInputText('');

      final success = await textViewModel.completeImport();

      expect(success, isFalse);
      expect(textViewModel.hasError, isTrue);
      expect(textViewModel.error, equals('Importvillkor inte uppfyllda'));
    });

    test('should perform import successfully', () async {
      await viewModel.performImport();

      expect(viewModel.hasParsedRecipe, isTrue);
      expect(viewModel.parsedRecipe?.title, equals('Imported Recipe'));
    });

    test('should validate import data correctly', () {
      // No recipe
      expect(viewModel.validateImportData(), isFalse);
      expect(viewModel.error, equals('Inget recept att validera'));

      // Recipe with empty title
      final invalidRecipe = RecipeFactory.build(title: '  ');
      viewModel.setParsedRecipe(invalidRecipe);
      expect(viewModel.validateImportData(), isFalse);
      expect(viewModel.error, equals('Recepttitel kr\u00e4vs'));

      // Recipe without ingredients
      final noIngredientsRecipe = RecipeFactory.build(
        title: 'Valid Title',
        ingredients: [],
      );
      viewModel.setParsedRecipe(noIngredientsRecipe);
      expect(viewModel.validateImportData(), isFalse);
      expect(viewModel.error, contains('minst en ingrediens'));

      // Recipe without instructions
      final noInstructionsRecipe = RecipeFactory.build(
        title: 'Valid Title',
        ingredients: ['Ingredient 1'],
        instructions: [],
      );
      viewModel.setParsedRecipe(noInstructionsRecipe);
      expect(viewModel.validateImportData(), isFalse);
      expect(viewModel.error, contains('minst en instruktion'));

      // Valid recipe
      viewModel.clearError();
      final validRecipe = RecipeFactory.build(
        title: 'Valid Title',
        ingredients: ['Ingredient 1'],
        instructions: ['Step 1'],
      );
      viewModel.setParsedRecipe(validRecipe);
      expect(viewModel.validateImportData(), isTrue);
      expect(viewModel.error, isNull);
    });

    test('should complete import workflow successfully', () async {
      final recipe = RecipeFactory.build(
        title: 'Complete Recipe',
        ingredients: ['Ingredient 1'],
        instructions: ['Step 1'],
      );

      viewModel = TestImportViewModel(importManager: mockImportManager);

      when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
          (_) async => ImportManagerResult.success(recipe, strategy: 'test'));

      final success = await viewModel.completeImport();

      expect(success, isTrue);
      expect(viewModel.hasParsedRecipe, isTrue);
    });

    test('should handle complete import workflow errors', () async {
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.failure('Parse failed'));
      textViewModel.updateInputText('Invalid recipe content');

      // executeAsync rethrows — catch at test level
      bool success;
      try {
        success = await textViewModel.completeImport();
      } catch (_) {
        success = false;
      }

      expect(success, isFalse);
      expect(textViewModel.hasError, isTrue);
    });

    test('should update parsed recipe with new data', () {
      final recipe = RecipeFactory.build(
        title: 'Original',
        description: 'Original description',
      );
      viewModel.setParsedRecipe(recipe);

      viewModel.updateParsedRecipe(
        title: 'Updated',
        description: 'Updated description',
        portions: 4,
        timeMinutes: 30,
      );

      expect(viewModel.parsedRecipe?.title, equals('Updated'));
      expect(
          viewModel.parsedRecipe?.description, equals('Updated description'));
      expect(viewModel.parsedRecipe?.portions, equals(4));
      expect(viewModel.parsedRecipe?.timeMinutes, equals(30));
    });

    test('should clear all data', () {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);
      viewModel.setSourceUrl('https://example.com');
      viewModel.setError('Error message');

      viewModel.clearAll();

      expect(viewModel.parsedRecipe, isNull);
      expect(viewModel.sourceUrl, isNull);
      expect(viewModel.error, isNull);
    });

    test('should provide debug state', () {
      viewModel.setParsedRecipe(RecipeFactory.build());
      viewModel.setSourceUrl('https://example.com');

      final debugState = viewModel.debugState;

      expect(debugState['hasParsedRecipe'], isTrue);
      expect(debugState['sourceUrl'], equals('https://example.com'));
      expect(debugState['canImport'], isTrue);
      expect(debugState['importType'], equals('test'));
    });
  });

  group('TextImportMixin', () {
    test('should initialize with empty text', () {
      expect(textViewModel.inputText, isEmpty);
      expect(textViewModel.hasValidInput, isFalse);
      expect(textViewModel.canImport, isFalse);
    });

    test('should update input text', () {
      textViewModel.updateInputText('Recipe content');

      expect(textViewModel.inputText, equals('Recipe content'));
      expect(textViewModel.hasValidInput, isTrue);
      expect(textViewModel.canImport, isTrue);
    });

    test('should clear input text and data when text is empty', () {
      textViewModel.updateInputText('Recipe content');
      textViewModel.setParsedRecipe(RecipeFactory.build());

      textViewModel.updateInputText('');

      expect(textViewModel.inputText, isEmpty);
      expect(textViewModel.hasValidInput, isFalse);
      expect(textViewModel.parsedRecipe, isNull);
    });

    test('should clear input', () {
      textViewModel.updateInputText('Recipe content');
      textViewModel.setParsedRecipe(RecipeFactory.build());

      textViewModel.clearInput();

      expect(textViewModel.inputText, isEmpty);
      expect(textViewModel.parsedRecipe, isNull);
    });

    test('should perform text import successfully', () async {
      textViewModel.updateInputText('Recipe content to import');

      final recipe = RecipeFactory.build(title: 'Imported Recipe');
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.success(recipe));

      await textViewModel.performImport();

      expect(textViewModel.hasParsedRecipe, isTrue);
      expect(textViewModel.parsedRecipe?.title, equals('Imported Recipe'));
    });

    test('should handle empty text on import', () async {
      textViewModel.updateInputText('');

      await textViewModel.performImport();

      // Swedish locale: 'Ange text att importera'
      expect(textViewModel.error, equals('Ange text att importera'));
      expect(textViewModel.hasParsedRecipe, isFalse);
    });

    test('should return correct import type', () {
      expect(textViewModel.importType, equals('text'));
    });

    test('should provide text-specific debug state', () {
      textViewModel.updateInputText('Short text');

      final debugState = textViewModel.debugState;

      expect(debugState['inputText'], equals('Short text'));
      expect(debugState['hasValidInput'], isTrue);
    });

    test('should truncate long text in debug state', () {
      final longText = 'a' * 100;
      textViewModel.updateInputText(longText);

      final debugState = textViewModel.debugState;

      expect(debugState['inputText'], endsWith('...'));
      expect((debugState['inputText'] as String).length, equals(53));
    });
  });

  group('UrlImportMixin', () {
    test('should initialize with empty URL', () {
      expect(urlViewModel.url, isEmpty);
      expect(urlViewModel.extractedText, isEmpty);
      expect(urlViewModel.hasExtractedText, isFalse);
      expect(urlViewModel.canFetch, isFalse);
      expect(urlViewModel.canImport, isFalse);
    });

    test('should update URL', () {
      urlViewModel.updateUrl('https://example.com/recipe');

      expect(urlViewModel.url, equals('https://example.com/recipe'));
      expect(urlViewModel.canFetch, isTrue);
    });

    test('should validate URL format', () {
      urlViewModel.updateUrl('invalid-url');
      expect(urlViewModel.canFetch, isFalse);

      urlViewModel.updateUrl('https://valid.com');
      expect(urlViewModel.canFetch, isTrue);

      urlViewModel.updateUrl('http://valid.com');
      expect(urlViewModel.canFetch, isTrue);

      urlViewModel.updateUrl('ftp://invalid.com');
      expect(urlViewModel.canFetch, isFalse);
    });

    test('should fetch content from URL successfully', () async {
      urlViewModel.updateUrl('https://example.com/recipe');

      await urlViewModel.fetchFromUrl();

      expect(urlViewModel.hasExtractedText, isTrue);
      expect(urlViewModel.extractedText, contains('Fetched content'));
      expect(urlViewModel.sourceUrl, equals('https://example.com/recipe'));
    });

    test('should handle fetch error', () async {
      urlViewModel.updateUrl('https://error.com');

      await urlViewModel.fetchFromUrl();

      expect(urlViewModel.hasExtractedText, isFalse);
      expect(urlViewModel.hasError, isTrue);
    });

    test(
        'BUG-32: fetch failure surfaces an error state without leaking an '
        'unhandled async error', () async {
      urlViewModel.updateUrl('https://error.com');

      // The fetch throws inside executeAsync (which rethrows). fetchFromUrl
      // must NOT propagate that rethrow — a leaked async error would crash the
      // zone. It should instead settle with an error state and no spinner.
      await expectLater(urlViewModel.fetchFromUrl(), completes);

      expect(urlViewModel.hasError, isTrue);
      expect(urlViewModel.isLoading, isFalse);
      expect(urlViewModel.hasExtractedText, isFalse);
    });

    test('should not fetch with invalid URL', () async {
      urlViewModel.updateUrl('invalid-url');

      await urlViewModel.fetchFromUrl();

      // Swedish locale: 'Ange en giltig URL'
      expect(urlViewModel.error, equals('Ange en giltig URL'));
      expect(urlViewModel.hasExtractedText, isFalse);
    });

    test('should perform URL import successfully', () async {
      urlViewModel.updateUrl('https://example.com');
      await urlViewModel.fetchFromUrl();

      final recipe = RecipeFactory.build(title: 'URL Recipe');
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.success(recipe));

      await urlViewModel.performImport();

      expect(urlViewModel.hasParsedRecipe, isTrue);
      expect(urlViewModel.parsedRecipe?.title, equals('URL Recipe'));
    });

    test('should handle import without extracted text', () async {
      await urlViewModel.performImport();

      // Swedish locale
      expect(urlViewModel.error,
          equals('Inget inneh\u00e5ll kunde h\u00e4mtas fr\u00e5n URL:en'));
      expect(urlViewModel.hasParsedRecipe, isFalse);
    });

    test('should clear URL and data', () {
      urlViewModel.updateUrl('https://example.com');
      urlViewModel.setParsedRecipe(RecipeFactory.build());

      urlViewModel.clearUrl();

      expect(urlViewModel.url, isEmpty);
      expect(urlViewModel.extractedText, isEmpty);
      expect(urlViewModel.parsedRecipe, isNull);
    });

    test('should return correct import type', () {
      expect(urlViewModel.importType, equals('url'));
    });

    test('should provide URL-specific debug state', () {
      urlViewModel.updateUrl('https://example.com');

      final debugState = urlViewModel.debugState;

      expect(debugState['url'], equals('https://example.com'));
      expect(debugState['hasExtractedText'], isFalse);
      expect(debugState['canFetch'], isTrue);
    });
  });

  group('ImportBaseViewModel - Integration Tests', () {
    test('should complete full text import workflow', () async {
      textViewModel.updateInputText('Recipe: Pasta');

      final success = await textViewModel.completeImport();

      expect(success, isTrue);
      expect(textViewModel.hasParsedRecipe, isTrue);

      verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
    });

    test('should complete full URL import workflow', () async {
      urlViewModel.updateUrl('https://example.com/recipe');
      await urlViewModel.fetchFromUrl();

      final success = await urlViewModel.completeImport();

      expect(success, isTrue);
      expect(urlViewModel.hasParsedRecipe, isTrue);

      verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
    });

    test('should handle error recovery in workflow', () async {
      // First attempt: strategy returns failure
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.failure('Parse error'));
      textViewModel.updateInputText('Recipe content');

      // completeImport -> performImport -> parseTextToRecipe -> executeAsync
      // executeAsync rethrows the exception, so we catch it here
      bool success;
      try {
        success = await textViewModel.completeImport();
      } catch (_) {
        success = false;
      }
      expect(success, isFalse);
      expect(textViewModel.hasError, isTrue);

      // Retry with valid data
      textViewModel.clearError();
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.success(RecipeFactory.build()));

      success = await textViewModel.completeImport();
      expect(success, isTrue);
      expect(textViewModel.hasError, isFalse);
    });

    test('should maintain state consistency through operations', () async {
      textViewModel.updateInputText('Recipe 1');
      await textViewModel.performImport();
      final recipe1 = textViewModel.parsedRecipe;

      textViewModel.clearInput();
      textViewModel.updateInputText('Recipe 2');
      await textViewModel.performImport();
      final recipe2 = textViewModel.parsedRecipe;

      expect(recipe1, isNotNull);
      expect(recipe2, isNotNull);
    });

    test('should handle concurrent operations safely', () async {
      final viewModels = <TestTextImportViewModel>[];

      for (int i = 0; i < 5; i++) {
        final vm = TestTextImportViewModel(importManager: mockImportManager);
        viewModels.add(vm);
        vm.updateInputText('Recipe $i');
      }

      final futures = viewModels.map((vm) => vm.performImport()).toList();
      await Future.wait(futures);

      expect(futures.length, equals(5));

      for (final vm in viewModels) {
        vm.dispose();
      }
    });
  });

  group('ImportBaseViewModel - Error Scenarios', () {
    test('should handle ImportManager not configured', () async {
      final emptyManager = MockImportManager();
      emptyManager.setImportManagerState(
        textImportStrategy: null,
        availableStrategies: [],
      );

      final vm = TestTextImportViewModel(importManager: emptyManager);
      vm.updateInputText('Recipe content');

      // performImport -> parseTextToRecipe -> executeAsync rethrows StateError
      try {
        await vm.performImport();
      } catch (_) {
        // Expected: rethrown from executeAsync
      }

      expect(vm.hasError, isTrue);
      // executeAsync sets error to errorUnexpected (no errorPrefix)
      expect(vm.error, isNotNull);

      vm.dispose();
    });

    test('should handle save exception', () async {
      final recipe = RecipeFactory.build();
      viewModel.setParsedRecipe(recipe);

      when(() => mockImportManager.saveImportedRecipe(any()))
          .thenThrow(Exception('Database error'));

      // saveImportedRecipe uses executeAsyncVoid which does NOT rethrow
      final success = await viewModel.saveImportedRecipe();

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      // executeAsyncVoid: error is errorPrefix or errorUnexpected (Swedish)
      expect(viewModel.error, isNotNull);
    });

    test('should handle parse exception via failure result', () async {
      when(() => mockTextStrategy.import(any()))
          .thenAnswer((_) async => ImportResult.failure('Parse exception'));

      // executeAsync rethrows
      Object? caught;
      try {
        await viewModel.parseTextToRecipe('Content');
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(viewModel.hasError, isTrue);
    });

    // BUT-924: re-parse failure must not wipe the previously-parsed recipe
    // (user may have manually edited it since the last successful parse).
    // executeAsync rethrows on failure, so the bug surface is "what state is
    // left when the throw escapes performImport." Contract: recipe preserved,
    // error visible.
    test('re-parse failure preserves previous recipe + sets error (BUT-924)',
        () async {
      final firstRecipe = RecipeFactory.build(title: 'First parse');

      // Successful first parse.
      when(() => mockTextStrategy.import(any())).thenAnswer(
        (_) async => ImportResult.success(firstRecipe),
      );
      textViewModel.updateInputText('initial');
      await textViewModel.performImport();
      expect(textViewModel.parsedRecipe?.title, 'First parse');

      // User edits — simulated by updating the parsed recipe in place.
      textViewModel.setParsedRecipe(
        firstRecipe.copyWith(title: 'User-edited title'),
      );

      // Re-parse fails (Cloud Function error, timeout, etc). performImport
      // rethrows via executeAsync — caller must catch.
      when(() => mockTextStrategy.import(any())).thenAnswer(
        (_) async => ImportResult.failure('Parse exception'),
      );
      textViewModel.updateInputText('updated input');
      try {
        await textViewModel.performImport();
      } catch (_) {
        // Expected: executeAsync rethrows.
      }

      // BUT-924 contract: previous parse + user edit survives.
      expect(textViewModel.hasParsedRecipe, isTrue);
      expect(textViewModel.parsedRecipe?.title, 'User-edited title');
      expect(textViewModel.hasError, isTrue);
    });

    // BUT-924: defensive guard — preserveOrSetParsedRecipe(null) is a no-op
    // covers the future case where parseTextToRecipe returns null instead of
    // throwing (e.g. if executeAsync swallowed via a future API change).
    test('preserveOrSetParsedRecipe(null) is a no-op (BUT-924)', () {
      final recipe = RecipeFactory.build(title: 'Keep me');
      viewModel.setParsedRecipe(recipe);

      viewModel.preserveOrSetParsedRecipe(null);

      expect(viewModel.parsedRecipe?.title, 'Keep me');
    });

    test('should handle URL fetch error', () async {
      final timeoutViewModel =
          TestUrlImportViewModel(importManager: mockImportManager);

      timeoutViewModel.updateUrl('https://error.com');

      // executeAsync rethrows the exception from fetchContentFromUrl
      try {
        await timeoutViewModel.fetchFromUrl();
      } catch (_) {
        // Expected
      }

      expect(timeoutViewModel.hasError, isTrue);
      expect(timeoutViewModel.error, isNotNull);

      timeoutViewModel.dispose();
    });

    test('should use Swedish error messages for validation', () async {
      // Validation: no recipe
      viewModel.validateImportData();
      expect(viewModel.error, contains('Inget recept'));

      // Save without recipe: Swedish locale
      await viewModel.saveImportedRecipe();
      expect(viewModel.error, equals('Inget recept att spara'));

      // Validation: empty title
      viewModel.setParsedRecipe(RecipeFactory.build(title: ''));
      viewModel.validateImportData();
      expect(viewModel.error, contains('Recepttitel'));

      // Validation: no ingredients
      viewModel.setParsedRecipe(RecipeFactory.build(ingredients: []));
      viewModel.validateImportData();
      expect(viewModel.error, contains('minst en ingrediens'));

      // Validation: no instructions
      viewModel.setParsedRecipe(RecipeFactory.build(instructions: []));
      viewModel.validateImportData();
      expect(viewModel.error, contains('minst en instruktion'));
    });
  });
}
