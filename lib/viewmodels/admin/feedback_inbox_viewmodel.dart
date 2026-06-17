import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel powering the admin-only feedback inbox.
///
/// Mirrors the moderator-review lifecycle: subscribes to a Firestore stream in
/// [start], re-subscribes when the [statusFilter] or page size changes,
/// and cancels in [dispose]. Access is enforced by Firestore rules
/// (`feedback` read = isAdmin); non-admins never reach this screen.
class FeedbackInboxViewModel extends BaseViewModel {
  final FeedbackRepository _repository;

  static const int _pageSize = 50;

  StreamSubscription<List<FeedbackEntry>>? _sub;
  List<FeedbackEntry> _entries = const [];
  FeedbackStatus? _statusFilter;
  int _limit = _pageSize;

  FeedbackInboxViewModel({FeedbackRepository? repository})
      : _repository = repository ?? ServiceLocator.get<FeedbackRepository>();

  List<FeedbackEntry> get entries => _entries;
  FeedbackStatus? get statusFilter => _statusFilter;

  /// True while the current page might be incomplete — i.e. the stream filled
  /// the limit, so raising it could surface more entries.
  bool get canLoadMore => _entries.length >= _limit;

  void start() {
    if (_sub != null) return;
    _subscribe();
  }

  /// Switch the status filter (null = all) and re-subscribe from the first page.
  void setStatusFilter(FeedbackStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _limit = _pageSize;
    _subscribe();
  }

  /// Grow the page size by one increment and re-subscribe.
  void loadMore() {
    if (!canLoadMore) return;
    _limit += _pageSize;
    _subscribe();
  }

  Future<void> updateStatus(String id, FeedbackStatus status) async {
    await executeAsyncVoid(
      () => _repository.updateStatus(id, status),
      errorPrefix: 'updateFeedbackStatus',
    );
  }

  void _subscribe() {
    _sub?.cancel();
    setLoading(true);
    _sub =
        _repository.watchFeedback(status: _statusFilter, limit: _limit).listen(
      (list) {
        if (isDisposed) return;
        _entries = list;
        setLoading(false);
        notifyListeners();
      },
      onError: (Object err) {
        if (isDisposed) return;
        // Null the subscription so start()'s `_sub != null` guard doesn't
        // swallow a retry from the error-state action button.
        _sub?.cancel();
        _sub = null;
        setError(err.toString());
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
