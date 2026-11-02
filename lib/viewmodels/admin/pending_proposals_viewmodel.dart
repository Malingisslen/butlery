import 'dart:async';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The pending ingredient proposals, shared by the "Förslag" tab and the
/// markers in the ingredient list. A failed stream is an error state, never an
/// empty list.
class PendingProposalsViewModel extends BaseViewModel {
  PendingProposalsViewModel({IngredientChangeRequestRepository? repository})
    : _repository =
          repository ?? ServiceLocator.get<IngredientChangeRequestRepository>();

  final IngredientChangeRequestRepository _repository;

  StreamSubscription<List<IngredientChangeRequest>>? _sub;
  List<IngredientChangeRequest> _proposals = const [];
  bool _loaded = false;

  List<IngredientChangeRequest> get proposals => _proposals;

  /// False until the first snapshot (or error) has arrived.
  bool get hasLoaded => _loaded;

  /// The stream is capped at [IngredientChangeRequestRepository.maxPending],
  /// so a full list means more proposals are waiting than are shown.
  bool get mayHaveMore =>
      _proposals.length >= IngredientChangeRequestRepository.maxPending;

  Set<String> get pendingIngredientIds => {
    for (final p in _proposals) p.ingredientId,
  };

  void start() {
    if (_sub != null) return;
    _subscribe();
  }

  void retry() {
    _sub?.cancel();
    _sub = null;
    _loaded = false;
    clearError();
    notifyListeners();
    _subscribe();
  }

  void _subscribe() {
    _sub = _repository.watchPending().listen(
      (items) {
        // A just-created proposal has no server time yet and sorts first.
        _proposals = [...items]
          ..sort((a, b) {
            final x = a.createdAt, y = b.createdAt;
            if (x == null && y == null) return 0;
            if (x == null) return -1;
            if (y == null) return 1;
            return y.compareTo(x);
          });
        _loaded = true;
        clearError();
        notifyListeners();
      },
      onError: (Object e) {
        _proposals = const [];
        _loaded = true;
        setError(AppLocale.current.adminProposalsLoadFailed);
      },
    );
  }

  Future<bool> withdraw(String id) => executeAsyncVoid(
    () => _repository.withdraw(id),
    errorPrefix: AppLocale.current.adminProposalWithdrawFailed,
  );

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
