/// Tests for the FileImportViewModel extracted from FileImportView (WS10 MVVM).
/// Covers the parse path, which is the cleanly-injectable core of the flow.
/// The importSelected loop+count mirrors the (separately tested)
/// PhotoImportViewModel.saveSelectedRecipes partial-failure logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/viewmodels/file_import_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _FakeStrategy extends FileImportStrategy {
  _FakeStrategy({this.result = const [], this.throws = false});
  final List<Recipe> result;
  final bool throws;

  @override
  Future<List<Recipe>> importMultiple({Map<String, dynamic>? options}) async {
    if (throws) throw Exception('boom');
    return result;
  }
}

Recipe _recipe(String id) => RecipeFactory.build(id: id, title: 'R$id');

void main() {
  group('FileImportViewModel.parseFile', () {
    test('returns parsed recipes and clears loading on success', () async {
      final vm = FileImportViewModel(
        strategy: _FakeStrategy(result: [_recipe('1'), _recipe('2')]),
      );
      addTearDown(vm.dispose);

      final parsed = await vm.parseFile();

      expect(parsed, hasLength(2));
      expect(vm.isLoading, isFalse);
    });

    test('returns empty and sets the no-recipes status when none found',
        () async {
      final vm = FileImportViewModel(strategy: _FakeStrategy(result: const []));
      addTearDown(vm.dispose);

      final parsed = await vm.parseFile();

      expect(parsed, isEmpty);
      expect(vm.isLoading, isFalse);
      expect(
          vm.statusMessage, equals(AppLocale.current.importNoFileOrNoRecipes));
    });

    test('returns empty and surfaces a generic error when the strategy throws',
        () async {
      final vm = FileImportViewModel(strategy: _FakeStrategy(throws: true));
      addTearDown(vm.dispose);

      final parsed = await vm.parseFile();

      expect(parsed, isEmpty);
      expect(vm.isLoading, isFalse);
      expect(vm.statusMessage, equals(AppLocale.current.errorGeneric));
    });
  });

  group('FileImportViewModel.importSelected', () {
    test('resets when nothing was selected', () async {
      final vm = FileImportViewModel(strategy: _FakeStrategy());
      addTearDown(vm.dispose);

      await vm.importSelected(const []);

      expect(vm.isLoading, isFalse);
      expect(vm.importedCount, 0);
      expect(vm.failedCount, 0);
      expect(vm.allSucceeded, isTrue);
    });
  });
}
