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
      return await _seedBlockedIds();
    } catch (e) {
      // Fail-open, and only for surfaces where an over-inclusive list is
      // recoverable — a blank conversation is worse than a briefly unfiltered
      // one. Callers that must REFUSE on an unknown list call
      // `requireBlockedIds` instead; see `MessagingService.closePoll`.
      AppLogger.warning('[BlockedUserFilter] initial fetch failed: $e');
      return const <String>{};
    }
  }

  /// The decision path's lookup: SERVER-only, and it THROWS instead of
  /// degrading to an empty set.
  ///
  /// BUT-1909. `currentBlockedIds` swallows, which is right for display and
  /// wrong for any decision that cannot be taken back — an empty set there is
  /// indistinguishable from "nobody is blocked", so a blocked ballot would
  /// resolve a poll winner into the household's week. A refusal branch written
  /// against `currentBlockedIds` is DEAD CODE for exactly that reason, and a
  /// test that stubs it to throw measures the mock rather than the collaborator.
  Future<Set<String>> requireBlockedIds() async {
    // BUT-1922. Deliberately NOT served from `_cached`, and deliberately not
    // seeded by the display path's read. A plain `get()` answers from the
    // local cache without an error while the device is offline, so the latch
    // can hold a list that was
    // never confirmed against the server: open a chat offline and the display
    // path latches a cache-served set, after which this method would return it
    // with no I/O at all. A block made on the user's OTHER device would then
    // be invisible here, and the ballot it should have removed would decide
    // the household's week.
    final generation = _generation;
    final ids = await _repo.getBlockedUserIdsFromServer();
    // `dispose()` bumps the generation, so an answer whose read outlived the
    // dispose belongs to a user this filter is no longer speaking for, and must
    // not reach a decision. Defence in depth today: this singleton is
    // registered in `SocialModule.configure`, i.e. the app scope, so
    // `popUserScope()` on logout does not dispose it.
    if (generation != _generation) throw StateError(_disposedDuringFetch);
    // The shared cache is left alone on purpose. It is kept fresh by the watch
    // that `_fetchAndWatch` opens; writing into it from here would seed a set
    // with nothing behind it to update it.
    return ids;
  }

  /// The display path's cold start: cache-friendly, watch-opening, and allowed
  /// to answer from the local cache. `currentBlockedIds` converts its failure
  /// into an empty set; nothing here may be used for a decision.
  Future<Set<String>> _seedBlockedIds() {
    // No `_initialized` check here: the only caller tests it and calls this
    // synchronously, so it cannot flip in between.
    //
    // Shared across concurrent first callers. Without it each of them runs the
    // fetch AND opens its own watch, and every subscription but the last is
    // overwritten in `_subscription` and never cancelled — it outlives
    // `dispose()` and keeps listening on that query. One cold
    // chat open reaches this from three places at once.
    return _inFlight ??= _fetchAndWatch().whenComplete(() => _inFlight = null);
  }

  Future<Set<String>> _fetchAndWatch() async {
    // Captured before the await. `dispose()` bumps it, so a fetch still in
    // flight when `dispose()` runs can tell that the answer it is holding
    // belongs to a user this filter no longer speaks for — clearing `_inFlight`
    // alone does not stop a future that is ALREADY running, which is what the
    // test for this found.
    final generation = _generation;
    final ids = await _repo.getBlockedUserIds();
    // THROWS rather than returning an empty set, which would be
    // indistinguishable from "nobody is blocked" — the neutral-value trap this
    // file keeps being caught by. `currentBlockedIds` converts the throw into
    // the display path's empty set.
    if (generation != _generation) throw StateError(_disposedDuringFetch);
    await _subscription?.cancel();
    // Keep cache fresh — block adds/removes propagate without restart, which
    // matters because blocking someone does not push into the filter.
    final subscription = _repo.watchBlockedUserIds().listen(
      (ids) {
        _cached = ids;
      },
      onError: (Object e) {
        // Invalidate, do not just log. Leaving the latch set here froze the
        // display path's set for the session on ONE `unavailable`, which is
        // routine on a long-lived listener.
        AppLogger.warning('[BlockedUserFilter] watch failed: $e');
        _invalidate();
      },
      onDone: _invalidate,
    );
    // Re-checked AFTER opening the watch: a dispose that lands in between would
    // otherwise leave this subscription running past it.
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
  /// `_cached` is left in place but is unreachable afterwards: the display path
  /// reads it only past the `_initialized` check, so it re-fetches and falls
  /// back to an EMPTY set on failure rather than to the last known list. The
  /// decision path never reads `_cached` at all.
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
    // `_inFlight` too. Without it a fetch still in flight when this runs
    // completes afterwards, re-latches, repopulates the cache with the PREVIOUS
    // user's block list and opens a subscription nobody cancels.
    // `social_module.dart` registers this with `dispose: (f) => f.dispose()`.
    _inFlight = null;
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _cached = const <String>{};
  }
}
