import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/repositories/recipe_stats_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin recipe-overview tab: total recipes + a breakdown by
/// import method. Read-only.
class RecipeOverviewViewModel extends BaseViewModel {
  final RecipeStatsRepository _repository;

  /// Fixed display order for the breakdown rows (stable regardless of counts).
  static const List<RecipeImportMethod> methodOrder = [
    RecipeImportMethod.url,
    RecipeImportMethod.photo,
    RecipeImportMethod.textPaste,
    RecipeImportMethod.social,
    RecipeImportMethod.manual,
  ];

  RecipeStats _stats = const RecipeStats(total: 0, byMethod: {});

  RecipeOverviewViewModel({RecipeStatsRepository? repository})
      : _repository = repository ?? ServiceLocator.get<RecipeStatsRepository>();

  int get total => _stats.total;
  int get imported => _stats.imported;
  int get manual => _stats.count(RecipeImportMethod.manual);
  int countOf(RecipeImportMethod method) => _stats.count(method);

  Future<void> load() async {
    await executeAsyncVoid(
      () async {
        _stats = await _repository.getRecipeStats();
      },
      errorPrefix: 'Kunde inte ladda receptstatistik',
    );
  }

  Future<void> refresh() => load();
}
