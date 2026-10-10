// BUT-1700: a failed refresh must not leave the previous numbers on screen
// passing for current ones.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';
import 'package:butlery/viewmodels/admin/metrics_tab_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FlakyRecipesFetcher implements CategoryFetcher {
  bool fail = false;

  @override
  MetricCategory get category => MetricCategory.recipes;

  @override
  Future<Object> fetch() async {
    if (fail) throw Exception('boom');
    return const RecipeStats(
      total: 5,
      byMethod: {RecipeImportMethod.manual: 5},
    );
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const keys = [MetricKey.recipeTotal];

  setUpAll(() async => BaseUnitTest.setupUnit());

  test(
    'a successful load then a failing refresh clears values and sets error',
    () async {
      final fetcher = _FlakyRecipesFetcher();
      final vm = MetricsTabViewModel(assembler: MetricsAssembler([fetcher]));
      addTearDown(vm.dispose);

      await vm.load(keys, l10n);
      expect(vm.values, isNotEmpty);
      expect(vm.hasError, isFalse);

      fetcher.fail = true;
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.refresh();

      expect(vm.values, isEmpty);
      expect(vm.valueOf(MetricKey.recipeTotal), isNull);
      expect(vm.hasError, isTrue);
      expect(notified, greaterThanOrEqualTo(1));
    },
  );
}
