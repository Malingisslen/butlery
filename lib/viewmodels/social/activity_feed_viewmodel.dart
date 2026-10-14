/// ViewModel for the social activity feed tab.
library;

import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class ActivityFeedViewModel extends BaseViewModel {
  static const int _pageSize = 20;

  List<ActivityEvent> _events = [];
  bool _hasMore = true;
  ActivityEventType? _filter;

  List<ActivityEvent> get events => _events;
  bool get hasMore => _hasMore;
  ActivityEventType? get filter => _filter;

  /// Returns events filtered by the active type filter.
  List<ActivityEvent> get filteredEvents => _filter == null
      ? _events
      : _events.where((e) => e.type == _filter).toList();

  ActivityFeedService get _service => ServiceLocator.get<ActivityFeedService>();

  /// Load the initial page of feed events.
  Future<void> loadFeed() async {
    await executeAsyncVoid(
      () async {
        final result = await _service.fetchFeed(limit: _pageSize);
        _events = result;
        _hasMore = result.length >= _pageSize;
      },
      errorPrefix: AppLocale.current.activityFeedLoadFailed,
    );
  }

  bool _isLoadingMore = false;
  int _listVersion = 0;
  String? _loadMoreError;

  /// True while the next page is fetched. Separate from `isLoading` so the
  /// list stays on screen (and keeps its scroll position) meanwhile.
  bool get isLoadingMore => _isLoadingMore;

  /// Set when the next page could not be fetched; the list keeps what it has.
  String? get loadMoreError => _loadMoreError;

  /// Load the next page of events.
  Future<void> loadMore() async {
    if (!_hasMore || _events.isEmpty || _isLoadingMore) return;

    _isLoadingMore = true;
    _loadMoreError = null;
    final version = _listVersion;
    notifyListeners();
    try {
      final result = await _service.fetchFeed(
        limit: _pageSize,
        before: _events.last.createdAt,
      );
      // A refresh that landed meanwhile replaced the list this page continues.
      if (version == _listVersion) {
        _events.addAll(result);
        _hasMore = result.length >= _pageSize;
      }
    } catch (_) {
      _loadMoreError = AppLocale.current.activityFeedLoadMoreFailed;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Reload the feed. The current list stays on screen until the new one
  /// arrives; a failed refresh keeps it and reports the error.
  Future<void> refresh() async {
    _hasMore = true;
    _loadMoreError = null;
    try {
      final result = await _service.fetchFeed(limit: _pageSize);
      _events = result;
      _listVersion++;
      _hasMore = result.length >= _pageSize;
      clearError();
    } catch (_) {
      setError(AppLocale.current.activityFeedLoadFailed);
    }
    notifyListeners();
  }

  /// Set or clear the event type filter (client-side).
  void setFilter(ActivityEventType? type) {
    _filter = type;
    notifyListeners();
  }
}
