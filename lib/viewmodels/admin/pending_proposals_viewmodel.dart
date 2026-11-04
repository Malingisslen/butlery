import 'dart:async';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/services/tagging/ingredient_change_pr_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The open and recently decided ingredient proposals, shared by the
/// "Förslag" tab and the markers in the ingredient list, plus the button that
/// turns the waiting ones into a pull request. A failed stream is an error
/// state, never an empty list.
class PendingProposalsViewModel extends BaseViewModel {
  PendingProposalsViewModel({
    IngredientChangeRequestRepository? repository,
    IngredientChangePrService? prService,
  }) : _repository =
           repository ??
           ServiceLocator.get<IngredientChangeRequestRepository>(),
       _prServiceOverride = prService;

  final IngredientChangeRequestRepository _repository;
  final IngredientChangePrService? _prServiceOverride;

  // Resolved on first use so a tab that never creates a review needs no
  // callable client.
  IngredientChangePrService get _prService =>
      _prServiceOverride ?? ServiceLocator.get<IngredientChangePrService>();

  StreamSubscription<List<IngredientChangeRequest>>? _sub;
  StreamSubscription<List<IngredientChangeRequest>>? _appliedSub;
  StreamSubscription<List<IngredientChangeRequest>>? _rejectedSub;
  List<IngredientChangeRequest> _proposals = const [];
  List<IngredientChangeRequest> _applied = const [];
  List<IngredientChangeRequest> _rejected = const [];
  bool _loaded = false;
  bool _appliedFailed = false;
  bool _rejectedFailed = false;
  bool _creating = false;
  IngredientChangePrResult? _lastReview;
  String? _reviewError;

  /// Pending, in review and conflicting proposals, newest first.
  List<IngredientChangeRequest> get proposals => _proposals;

  List<IngredientChangeRequest> get pending => _with(
    _proposals,
    IngredientChangeStatus.pending,
  );
  List<IngredientChangeRequest> get inReview => _with(
    _proposals,
    IngredientChangeStatus.inReview,
  );
  List<IngredientChangeRequest> get conflicts => _with(
    _proposals,
    IngredientChangeStatus.conflict,
  );
  List<IngredientChangeRequest> get rejected => _rejected;
  List<IngredientChangeRequest> get applied => _applied;

  /// Proposals the next review would carry: the server re-reads both
  /// `pending` and `inReview`.
  int get waitingCount => pending.length + inReview.length;

  bool get canCreateReview => waitingCount > 0 && !_creating;
  bool get isCreatingReview => _creating;
  IngredientChangePrResult? get lastReview => _lastReview;
  String? get reviewError => _reviewError;

  /// True when the recently decided list could not be read.
  bool get decidedFailed => _appliedFailed || _rejectedFailed;

  /// False until the first snapshot (or error) has arrived.
  bool get hasLoaded => _loaded;

  /// Both streams are capped, so a full open list means more proposals are
  /// waiting than are shown.
  bool get mayHaveMore =>
      _proposals.length >= IngredientChangeRequestRepository.maxPending;

  bool get isEmpty =>
      _proposals.isEmpty && _applied.isEmpty && _rejected.isEmpty;

  Set<String> get pendingIngredientIds => {
    for (final p in _proposals) p.ingredientId,
  };

  static List<IngredientChangeRequest> _with(
    List<IngredientChangeRequest> all,
    IngredientChangeStatus status,
  ) => [
    for (final p in all)
      if (p.status == status) p,
  ];

  void start() {
    if (_sub != null) return;
    _subscribe();
  }

  void retry() {
    _sub?.cancel();
    _appliedSub?.cancel();
    _rejectedSub?.cancel();
    _sub = null;
    _loaded = false;
    _appliedFailed = false;
    _rejectedFailed = false;
    clearError();
    notifyListeners();
    _subscribe();
  }

  // A just-created proposal has no server time yet and sorts first.
  static List<IngredientChangeRequest> _newestFirst(
    List<IngredientChangeRequest> items,
  ) => [...items]
    ..sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) return 0;
      if (x == null) return -1;
      if (y == null) return 1;
      return y.compareTo(x);
    });

  void _subscribe() {
    _sub = _repository.watchOpen().listen(
      (items) {
        _proposals = _newestFirst(items);
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
    _appliedSub = _repository.watchApplied().listen(
      (items) {
        _applied = _byAppliedAtDesc(items);
        _appliedFailed = false;
        notifyListeners();
      },
      onError: (Object e) => _decidedError(applied: true),
    );
    _rejectedSub = _repository.watchRejected().listen(
      (items) {
        _rejected = _newestFirst(items);
        _rejectedFailed = false;
        notifyListeners();
      },
      onError: (Object e) => _decidedError(applied: false),
    );
  }

  void _decidedError({required bool applied}) {
    if (applied) {
      _applied = const [];
      _appliedFailed = true;
    } else {
      _rejected = const [];
      _rejectedFailed = true;
    }
    notifyListeners();
  }

  // The query already orders by appliedAt; this only places a snapshot whose
  // server time has not arrived yet.
  static List<IngredientChangeRequest> _byAppliedAtDesc(
    List<IngredientChangeRequest> items,
  ) => [...items]
    ..sort((a, b) {
      final x = a.appliedAt, y = b.appliedAt;
      if (x == null && y == null) return 0;
      if (x == null) return -1;
      if (y == null) return 1;
      return y.compareTo(x);
    });

  Future<bool> withdraw(String id) => executeAsyncVoid(
    () => _repository.withdraw(id),
    errorPrefix: AppLocale.current.adminProposalWithdrawFailed,
  );

  /// Builds the pull request from the waiting proposals. The outcome is in
  /// [lastReview] or [reviewError]; the open list updates through the stream.
  Future<bool> createReview() async {
    if (!canCreateReview) return false;
    _creating = true;
    _lastReview = null;
    _reviewError = null;
    notifyListeners();
    try {
      _lastReview = await _prService.createPr();
      return true;
    } on IngredientChangePrException catch (e) {
      _reviewError = _messageFor(e.failure);
      return false;
    } catch (_) {
      _reviewError = _messageFor(IngredientChangePrFailure.other);
      return false;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  void dismissReviewResult() {
    _lastReview = null;
    _reviewError = null;
    notifyListeners();
  }

  static String _messageFor(IngredientChangePrFailure failure) {
    final l10n = AppLocale.current;
    return switch (failure) {
      IngredientChangePrFailure.notAdmin => l10n.adminReviewErrorNotAdmin,
      IngredientChangePrFailure.locked => l10n.adminReviewErrorLocked,
      IngredientChangePrFailure.tooManyProposals =>
        l10n.adminReviewErrorTooMany,
      IngredientChangePrFailure.notConfigured =>
        l10n.adminReviewErrorNotConfigured,
      IngredientChangePrFailure.unavailable => l10n.adminReviewErrorUnavailable,
      IngredientChangePrFailure.mainMoved => l10n.adminReviewErrorMainMoved,
      IngredientChangePrFailure.foreignCommits =>
        l10n.adminReviewErrorForeignCommits,
      IngredientChangePrFailure.rateLimited => l10n.adminReviewErrorRateLimited,
      IngredientChangePrFailure.other => l10n.adminReviewErrorOther,
    };
  }

  @override
  void dispose() {
    _sub?.cancel();
    _appliedSub?.cancel();
    _rejectedSub?.cancel();
    super.dispose();
  }
}
