import 'package:uuid/uuid.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// "Sätt status på valda": one proposal per row, saved in one write batch with
/// a shared batch id. Old values come from the loaded list.
class BulkStatusProposalViewModel extends BaseViewModel {
  BulkStatusProposalViewModel({
    required List<IngredientData> selected,
    IngredientChangeRequestRepository? repository,
    String Function()? batchIdFactory,
  }) : selected = List.unmodifiable(selected),
       _repository =
           repository ??
           ServiceLocator.get<IngredientChangeRequestRepository>(),
       _batchId = batchIdFactory ?? (() => const Uuid().v4());

  static const int maxRows = IngredientChangeRequestRepository.maxBatchSize;

  final List<IngredientData> selected;
  final IngredientChangeRequestRepository _repository;
  final String Function() _batchId;

  bool get exceedsLimit => selected.length > maxRows;

  /// Current status of the chosen rows, for the confirmation text.
  Map<String, int> get statusDistribution {
    final counts = <String, int>{};
    for (final i in selected) {
      counts[i.status] = (counts[i.status] ?? 0) + 1;
    }
    return counts;
  }

  /// Rows already in [status] get no proposal.
  int rowsChangedBy(String status) =>
      selected.where((i) => i.status != status).length;

  Future<bool> submit(String status) {
    if (exceedsLimit || !kProposableStatuses.contains(status)) {
      return Future.value(false);
    }
    final rows = selected.where((i) => i.status != status).toList();
    if (rows.isEmpty) return Future.value(false);
    final batchId = _batchId();
    return executeAsyncVoid(() async {
      await _repository.createBatch([
        for (final i in rows)
          IngredientChangeRequest(
            ingredientId: i.id,
            ingredientUpdatedAt: i.updatedAt,
            batchId: batchId,
            changes: [
              IngredientFieldChange.from(i, IngredientColumn.status, status),
            ],
          ),
      ]);
    }, errorPrefix: AppLocale.current.adminProposalSaveFailed);
  }
}
