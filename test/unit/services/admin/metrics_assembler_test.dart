// BUT-1700: a failed delta read fails the tab, on purpose — a number shown
// without its delta would pass for "no change".
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/repositories/daily_snapshot_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';

import '../../../test_support/failing_firestore.dart';

class _RecipesFetcher implements CategoryFetcher {
  @override
  MetricCategory get category => MetricCategory.recipes;

  @override
  Future<Object> fetch() async =>
      const RecipeStats(total: 5, byMethod: {RecipeImportMethod.manual: 5});
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('a throwing snapshot repository makes resolve() throw', () async {
    final assembler = MetricsAssembler(
      [_RecipesFetcher()],
      snapshots: DailySnapshotRepository(firestore: FailingFirestore()),
    );

    await expectLater(
      assembler.resolve({MetricKey.recipeTotal}, l10n),
      throwsFirestoreFailure,
    );
  });

  test(
    'without a snapshot repository the fetched slice still resolves',
    () async {
      final assembler = MetricsAssembler([_RecipesFetcher()]);

      final values = await assembler.resolve({MetricKey.recipeTotal}, l10n);

      expect(values.keys, [MetricKey.recipeTotal]);
    },
  );
}
