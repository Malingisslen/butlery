/// ViewModel for the social activity feed tab.
library;

import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/services/social/activity_feed_service.dart';

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
      errorPrefix: 'Kunde inte ladda flödet',
    );
  }

  /// Load the next page of events.
  Future<void> loadMore() async {
    if (!_hasMore || _events.isEmpty) return;

    await executeAsyncVoid(
      () async {
        final result = await _service.fetchFeed(
          limit: _pageSize,
          before: _events.last.createdAt,
        );
        _events.addAll(result);
        _hasMore = result.length >= _pageSize;
      },
      errorPrefix: 'Kunde inte ladda fler händelser',
    );
  }

  /// Clear and reload the feed.
  Future<void> refresh() async {
    _events = [];
    _hasMore = true;
    notifyListeners();
    await loadFeed();
  }

  /// Set or clear the event type filter (client-side).
  void setFilter(ActivityEventType? type) {
    _filter = type;
    notifyListeners();
  }
}
