import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:clock/clock.dart';

/// ViewModel for the in-app notification inbox.
class NotificationsViewModel extends BaseViewModel {
  final NotificationService _notificationService;

  List<NotificationHistoryEntry> _entries = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<NotificationHistoryEntry> get entries => List.unmodifiable(_entries);
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isEmpty => _entries.isEmpty && !isLoading;

  NotificationsViewModel({NotificationService? notificationService})
      : _notificationService =
            notificationService ?? ServiceLocator.get<NotificationService>();

  /// Loads the first page of notification history.
  Future<void> loadHistory() async {
    await executeAsyncVoid(() async {
      final results =
          await _notificationService.getNotificationHistory(limit: 20);
      _entries = results;
      _hasMore = results.length == 20;
    });
  }

  /// Loads the next page of notifications.
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _entries.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final results = await _notificationService.getNotificationHistory(
        limit: 20,
        before: _entries.last.sentAt,
      );
      _entries = [..._entries, ...results];
      _hasMore = results.length == 20;
    } catch (e) {
      AppLogger.warning('Failed to load more notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: reloads from the beginning.
  Future<void> refresh() async {
    _entries = [];
    _hasMore = true;
    notifyListeners();
    await loadHistory();
  }

  /// BUT-952: mark every unread entry as opened. Optimistic local update
  /// followed by a fire-and-forget batched-write service call. Returns
  /// the number of entries marked (0 if everything was already read).
  Future<int> markAllAsOpened() async {
    final unread = _entries.where((e) => !e.opened).toList();
    if (unread.isEmpty) return 0;

    final now = clock.now();
    _entries = _entries
        .map((e) => e.opened ? e : e.copyWith(opened: true, openedAt: now))
        .toList();
    notifyListeners();

    try {
      return await _notificationService.markAllHistoryNotificationsOpened();
    } catch (e) {
      AppLogger.warning('Failed to mark all notifications opened: $e');
      return unread.length;
    }
  }

  /// Marks a notification as opened with optimistic local update.
  void markAsOpened(String notificationId) {
    final index =
        _entries.indexWhere((e) => e.notificationId == notificationId);
    if (index == -1) return;

    _entries[index] = _entries[index].copyWith(
      opened: true,
      openedAt: clock.now(),
    );
    notifyListeners();

    unawaited(
      _notificationService
          .markHistoryNotificationOpened(notificationId)
          .catchError((e) =>
              AppLogger.warning('Failed to mark notification opened: $e')),
    );
  }
}
