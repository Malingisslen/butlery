import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';

/// Shared block-aware predicate used by comment + chat read paths to
/// retroactively hide content authored by users the viewer has blocked.
///
/// `friends_state_manager` already maintains a streaming set of blocked
/// IDs for the friends-feed surface; this filter centralizes the lookup
/// so both other surfaces share one predicate and one cache invalidation.
///
/// Why a small helper instead of `whereNotIn`: Firestore caps `whereNotIn`
/// at 10 IDs and forks an index per query. Result-set filtering is cheaper
/// when block lists grow past 10 and avoids index churn — the read still
/// happens, but the blocked author's content never reaches the UI.
class BlockedUserFilter {
  BlockedUserFilter({FirebaseBlockRepository? blockRepository})
    : _blockRepository = blockRepository;

  final FirebaseBlockRepository? _blockRepository;

  /// Cached snapshot to avoid hammering Firestore on every list read. The
  /// stream from `watchBlockedUserIds` keeps it fresh; `currentBlockedIds`
  /// falls back to a one-shot fetch on cold start.
  Set<String> _cached = const <String>{};
  StreamSubscription<Set<String>>? _subscription;
  bool _initialized = false;

  FirebaseBlockRepository get _repo =>
      _blockRepository ?? ServiceLocator.get<FirebaseBlockRepository>();

  /// Best-effort current blocked-IDs set. First call seeds the cache and
  /// starts a stream subscription; subsequent calls return the cached set
  /// synchronously (no `await`). Returning a `Future` keeps the call site
  /// future-friendly even when the value is hot.
  Future<Set<String>> currentBlockedIds() async {
    if (!_initialized) {
      _initialized = true;
      try {
        _cached = await _repo.getBlockedUserIds();
        // Keep cache fresh — block adds/removes propagate without restart.
        _subscription = _repo.watchBlockedUserIds().listen(
          (ids) {
            _cached = ids;
          },
          onError: (Object e) {
            AppLogger.warning('[BlockedUserFilter] watch failed: $e');
          },
        );
      } catch (e) {
        AppLogger.warning('[BlockedUserFilter] initial fetch failed: $e');
        _cached = const <String>{};
      }
    }
    return _cached;
  }

  /// Cheap predicate for in-memory filtering. Empty set → no-op (return
  /// list unchanged), preserving the pre-block-aware behavior for users
  /// who haven't blocked anyone.
  static bool shouldHide(String authorId, Set<String> blockedIds) {
    return blockedIds.contains(authorId);
  }

  /// Convenience: filter a list by author-extracting key. Always returns
  /// a new `List<T>` to avoid mutating shared streams.
  static List<T> filter<T>(
    Iterable<T> items, {
    required String Function(T item) authorOf,
    required Set<String> blockedIds,
  }) {
    if (blockedIds.isEmpty) {
      return items is List<T> ? items : items.toList();
    }
    return items.where((it) => !shouldHide(authorOf(it), blockedIds)).toList();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _cached = const <String>{};
  }
}
