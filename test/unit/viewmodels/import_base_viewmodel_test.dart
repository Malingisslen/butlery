// test/unit/viewmodels/import_base_viewmodel_test.dart
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';

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
  String get importType => 'test';
}

// Test implementation with TextImportMixin
class TestTextImportViewModel extends ImportBaseViewModel with TextImportMixin {
  TestTextImportViewModel({required super.importManager});

  @override
  String get importType => 'text';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImportManager mockImportManager;
  late TestImportViewModel viewModel;
  late TestTextImportViewModel textViewModel;

  setUpAll(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() async {
    mockImportManager = MockFactory.createImportManager();
    when(() => mockImportManager.saveImportedRecipe(any())).thenAnswer(
      (_) async =>
          ImportManagerResult.success(RecipeFactory.build(), strategy: 'test'),
    );

    viewModel = TestImportViewModel(importManager: mockImportManager);
    textViewModel = TestTextImportViewModel(importManager: mockImportManager);
  });

  tearDown(() async {
    viewModel.dispose();
    textViewModel.dispose();
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
      expect(
        notificationCount,
        equals(4),
      ); // clearAll calls notifyListeners after clearing state
    });
  });

  group('ImportBaseViewModel - Import Operations', () {
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
        viewModel.parsedRecipe?.description,
        equals('Updated description'),
      );
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
}
