import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// BUT-1360: counts how many times the text-import strategy's `import` is
/// invoked. The offline pre-check in [ImportBaseViewModel.parseTextToRecipe]
/// must short-circuit BEFORE the Cloud-Function round-trip, so an offline parse
/// must leave [importCalls] at zero — proving the ~60s client timeout is never
/// entered. Online, exactly one call must land.
class _CountingTextImportStrategy extends Mock implements TextImportStrategy {
  int importCalls = 0;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    importCalls++;
    return ImportResult.success(
      Recipe.personal(
        title: 'Pannkakor',
        description: '',
        ingredients: const ['3 ägg', '5 dl mjölk'],
        instructions: const ['Vispa ihop allt'],
        mealType: 'Frukost',
      ),
    );
  }
}

/// Concrete [ImportBaseViewModel] using [TextImportMixin] — exercises the
/// shared [parseTextToRecipe] path that both text and URL import funnel through.
class _TestTextImportViewModel extends ImportBaseViewModel
    with TextImportMixin {
  _TestTextImportViewModel({
    required super.importManager,
    required super.connectivity,
  });
}

void main() {
  group(
    'ImportBaseViewModel.parseTextToRecipe offline pre-check (BUT-1360)',
    () {
      late MockImportManager mockImportManager;
      late MockConnectivityMonitoringService mockConnectivity;
      late _CountingTextImportStrategy strategy;
      late _TestTextImportViewModel viewModel;

      setUpAll(() async {
        await BaseUnitTest.setupUnit();
      });

      setUp(() async {
        await TestServiceLocator.initialize();
        strategy = _CountingTextImportStrategy();
        mockImportManager = MockImportManager();
        mockImportManager.setImportManagerState(textImportStrategy: strategy);
        mockConnectivity = MockConnectivityMonitoringService();
        // Offline by default; the online test flips this.
        when(() => mockConnectivity.isConnectedToInternet).thenReturn(false);

        viewModel = _TestTextImportViewModel(
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
        'offline: performImport sets the offline message, parses no recipe, and '
        'never calls the import strategy',
        () async {
          viewModel.updateInputText('Pannkakor\n3 ägg\nVispa ihop allt');

          await viewModel.performImport();

          expect(viewModel.error, AppLocale.current.importOfflineMessage);
          expect(viewModel.hasParsedRecipe, isFalse);
          expect(
            strategy.importCalls,
            0,
            reason: 'strategy must not run while offline',
          );
          expect(viewModel.isLoading, isFalse);
        },
      );

      test(
        'online: performImport reaches the strategy and parses a recipe',
        () async {
          when(() => mockConnectivity.isConnectedToInternet).thenReturn(true);
          viewModel.updateInputText('Pannkakor\n3 ägg\nVispa ihop allt');

          await viewModel.performImport();

          expect(strategy.importCalls, 1);
          expect(viewModel.hasParsedRecipe, isTrue);
          expect(viewModel.error, isNull);
        },
      );
    },
  );
}
