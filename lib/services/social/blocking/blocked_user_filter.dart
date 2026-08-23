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
  Future<Set<String>>? _inFlight;
  int _generation = 0;

  static const String _disposedDuringFetch =
      'BlockedUserFilter was disposed while its block list was being read';
  bool _initialized = false;

  FirebaseBlockRepository get _repo =>
      _blockRepository ?? ServiceLocator.get<FirebaseBlockRepository>();

  /// Best-effort current blocked-IDs set. First call seeds the cache and
  /// starts a stream subscription; subsequent calls return the cached set
  /// synchronously (no `await`). Returning a `Future` keeps the call site
  /// future-friendly even when the value is hot.
  Future<Set<String>> currentBlockedIds() async {
    if (_initialized) return _cached;
    try {
      return await requireBlockedIds();
    } catch (e) {
      // Fail-open, and only for surfaces where an over-inclusive list is
      // recoverable — a blank conversation is worse than a briefly unfiltered
      // one. Callers that must REFUSE on an unknown list call
      // `requireBlockedIds` instead; see `MessagingService.closePoll`.
      AppLogger.warning('[BlockedUserFilter] initial fetch failed: $e');
      return const <String>{};
    }
  }

  /// The same lookup, but it THROWS instead of degrading to an empty set.
  ///
  /// BUT-1909. `currentBlockedIds` swallows, which is right for display and
  /// wrong for any decision that cannot be taken back — an empty set there is
  /// indistinguishable from "nobody is blocked", so a blocked ballot would
  /// resolve a poll winner into the household's week. A refusal branch written
  /// against `currentBlockedIds` is DEAD CODE for exactly that reason, and a
  /// test that stubs it to throw measures the mock rather than the collaborator.
  Future<Set<String>> requireBlockedIds() {
    if (_initialized) return Future.value(_cached);
    // Shared across concurrent first callers. Without it each of them runs the
    // fetch AND opens its own watch, and every subscription but the last is
    // overwritten in `_subscription` and never cancelled — it outlives
    // `dispose()` and keeps listening on the signed-out user's query. One cold
    // chat open reaches this from three places at once.
    return _inFlight ??= _fetchAndWatch().whenComplete(() => _inFlight = null);
  }

  Future<Set<String>> _fetchAndWatch() async {
    // Captured before the await. `dispose()` bumps it, so a fetch still in
    // flight at scope pop can tell that the answer it is holding belongs to a
    // user who has since signed out — clearing `_inFlight` alone does not stop
    // a future that is ALREADY running, which is what the test for this found.
    final generation = _generation;
    final ids = await _repo.getBlockedUserIds();
    // THROWS rather than returning an empty set. An empty set here is
    // indistinguishable from "nobody is blocked", which would fail OPEN on the
    // one decision this variant exists to refuse — the neutral-value trap this
    // file keeps being caught by. `currentBlockedIds` converts the throw back
    // into the display path's empty set, so the fail-open half is preserved
    // for free.
    if (generation != _generation) throw StateError(_disposedDuringFetch);
    await _subscription?.cancel();
    // Keep cache fresh — block adds/removes propagate without restart, which
    // matters because blocking someone does not push into the filter.
    final subscription = _repo.watchBlockedUserIds().listen(
      (ids) {
        _cached = ids;
      },
      onError: (Object e) {
        // Invalidate, do not just log. Leaving the latch set here was the
        // second layer of the same fail-open: the initial fetch could no longer
        // freeze the session, but ONE `unavailable` on this long-lived stream
        // still could — and `requireBlockedIds` would then hand `closePoll` a
        // stale set with no error at all, so the refusal it exists for could
        // never fire while a since-blocked person decided the winner.
        AppLogger.warning('[BlockedUserFilter] watch failed: $e');
        _invalidate();
      },
      onDone: _invalidate,
    );
    // Re-checked AFTER opening the watch: a dispose that lands in between would
    // otherwise leave this subscription listening on the signed-out user.
    if (generation != _generation) {
      await subscription.cancel();
      throw StateError(_disposedDuringFetch);
    }
    // Latched only HERE, past every await, so check-and-write is atomic: every
    // `dispose()` has to land on a yield one of the two generation checks
    // covers.
    _initialized = true;
    _cached = ids;
    _subscription = subscription;
    return _cached;
  }

  /// Forget everything and re-read on the next call.
  ///
  /// `_cached` is left in place but is unreachable afterwards: every read goes
  /// through the `_initialized` check, so the display path re-fetches and falls
  /// back to an EMPTY set on failure rather than to the last known list.
  void _invalidate() {
    _initialized = false;
    _subscription?.cancel();
    _subscription = null;
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
    // `_inFlight` too. Without it a fetch still in flight at scope pop
    // completes afterwards, re-latches, repopulates the cache with the PREVIOUS
    // user's block list and opens a subscription nobody cancels. Reachable —
    // `social_module.dart` registers this with `dispose: (f) => f.dispose()`.
    _inFlight = null;
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _cached = const <String>{};
  }
}
