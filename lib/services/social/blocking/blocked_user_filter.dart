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
///
/// ## Two directions, and what each one is allowed to hide
///
/// BUT-1917. The filter holds TWO sets: everyone the viewer has blocked
/// (OUTGOING) and everyone who has blocked the viewer (INCOMING).
///
/// They are deliberately not interchangeable, and the asymmetry is the
/// decision rather than an unfinished half:
///
/// - **Message display uses OUTGOING only.** Hiding what someone says the
///   moment they block you would tell you that they did, turning a silent
///   safety control into a notification.
/// - **Poll tallies use BOTH.** A vote is not speech: it decides which recipe
///   lands in the household's week. A ballot cast by someone who blocked you
///   counting toward what you are served is the harm the ticket names, and the
///   rule that now refuses such a vote is not retroactive — rows written before
///   it landed are still there, so the client filter is what covers them.
///
/// Anything reaching for `blockedByIds` for a DISPLAY surface should stop and
/// re-read the two bullets above.
class BlockedUserFilter {
  BlockedUserFilter({FirebaseBlockRepository? blockRepository})
    : _blockRepository = blockRepository;

  final FirebaseBlockRepository? _blockRepository;

  /// Bumped by [dispose]. Both caches read it through a callback rather than
  /// keeping their own, so one dispose invalidates every in-flight read on both
  /// directions at once — the alternative, a counter per cache, is two things
  /// that must be kept in step and eventually are not.
  int _generation = 0;

  static const String _disposedDuringFetch =
      'BlockedUserFilter was disposed while its block list was being read';

  _BlockSetCache? _outgoing;
  _BlockSetCache? _incoming;

  FirebaseBlockRepository get _repo =>
      _blockRepository ?? ServiceLocator.get<FirebaseBlockRepository>();

  _BlockSetCache get _outgoingCache => _outgoing ??= _BlockSetCache(
    label: 'blocked',
    fetch: () => _repo.getBlockedUserIds(),
    watch: () => _repo.watchBlockedUserIds(),
    generation: () => _generation,
  );

  _BlockSetCache get _incomingCache => _incoming ??= _BlockSetCache(
    label: 'blockedBy',
    fetch: () => _repo.getBlockedByUserIds(),
    watch: () => _repo.watchBlockedByUserIds(),
    generation: () => _generation,
  );

  /// Best-effort current blocked-IDs set. First call seeds the cache and
  /// starts a stream subscription; subsequent calls return the cached set
  /// synchronously (no `await`). Returning a `Future` keeps the call site
  /// future-friendly even when the value is hot.
  Future<Set<String>> currentBlockedIds() => _outgoingCache.current();

  /// The INCOMING twin of [currentBlockedIds]: everyone who has blocked the
  /// viewer. Display-safe in the same fail-open sense, and restricted by
  /// convention to poll tallies — see the class doc.
  Future<Set<String>> currentBlockedByIds() => _incomingCache.current();

  /// The decision path's lookup: SERVER-only, and it THROWS instead of
  /// degrading to an empty set.
  ///
  /// BUT-1909. `currentBlockedIds` swallows, which is right for display and
  /// wrong for any decision that cannot be taken back — an empty set there is
  /// indistinguishable from "nobody is blocked", so a blocked ballot would
  /// resolve a poll winner into the household's week. A refusal branch written
  /// against `currentBlockedIds` is DEAD CODE for exactly that reason, and a
  /// test that stubs it to throw measures the mock rather than the collaborator.
  Future<Set<String>> requireBlockedIds() =>
      _require(_repo.getBlockedUserIdsFromServer);

  /// The INCOMING twin of [requireBlockedIds], with the same contract: server
  /// only, throws rather than degrading.
  ///
  /// `closePoll` needs both directions for the same reason it needs either. If
  /// the screen strips a ballot the winner resolution keeps, the number the
  /// user read and the recipe they got disagree — which is the BUT-1908 harm,
  /// arriving through the other direction.
  Future<Set<String>> requireBlockedByIds() =>
      _require(_repo.getBlockedByUserIdsFromServer);

  /// BUT-1922. Deliberately NOT served from the cache, and deliberately not
  /// seeded by the display path's read. A plain `get()` answers from the
  /// local cache without an error while the device is offline, so the latch
  /// can hold a list that was never confirmed against the server: open a chat
  /// offline and the display path latches a cache-served set, after which this
  /// method would return it with no I/O at all. A block made on the user's
  /// OTHER device would then be invisible here, and the ballot it should have
  /// removed would decide the household's week.
  Future<Set<String>> _require(
    Future<Set<String>> Function() fromServer,
  ) async {
    final generation = _generation;
    final ids = await fromServer();
    // `dispose()` bumps the generation, so an answer whose read outlived the
    // dispose belongs to a user this filter is no longer speaking for, and must
    // not reach a decision. Defence in depth today: this singleton is
    // registered in `SocialModule.configure`, i.e. the app scope, so
    // `popUserScope()` on logout does not dispose it.
    if (generation != _generation) throw StateError(_disposedDuringFetch);
    // The shared cache is left alone on purpose. It is kept fresh by the watch
    // the display path opens; writing into it from here would seed a set with
    // nothing behind it to update it.
    return ids;
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
    // Bumped BEFORE the caches are torn down, so a fetch still in flight in
    // either direction sees the new value at its own generation check.
    _generation++;
    await _outgoing?.dispose();
    await _incoming?.dispose();
  }
}

/// One direction's cached set, its watch, and the lifecycle around both.
///
/// Extracted rather than written twice. Every subtlety below — the shared
/// in-flight future, the generation checks either side of opening the watch,
/// the invalidate-on-watch-error — was found by a separate review round on the
/// outgoing direction, and a second hand-written copy for the incoming one is
/// how the two stop agreeing.
class _BlockSetCache {
  _BlockSetCache({
    required this.label,
    required this.fetch,
    required this.watch,
    required this.generation,
  });

  /// Names the direction in log lines, so a failure says which read broke.
  final String label;
  final Future<Set<String>> Function() fetch;
  final Stream<Set<String>> Function() watch;
  final int Function() generation;

  Set<String> _cached = const <String>{};
  StreamSubscription<Set<String>>? _subscription;
  Future<Set<String>>? _inFlight;
  bool _initialized = false;

  Future<Set<String>> current() async {
    if (_initialized) return _cached;
    try {
      return await _seed();
    } catch (e) {
      // Fail-open, and only for surfaces where an over-inclusive list is
      // recoverable — a blank conversation is worse than a briefly unfiltered
      // one. Callers that must REFUSE on an unknown list go through
      // `requireBlockedIds`/`requireBlockedByIds` instead; see
      // `MessagingService.closePoll`.
      AppLogger.warning('[BlockedUserFilter] initial $label fetch failed: $e');
      return const <String>{};
    }
  }

  Future<Set<String>> _seed() {
    // No `_initialized` check here: the only caller tests it and calls this
    // synchronously, so it cannot flip in between.
    //
    // Shared across concurrent first callers. Without it each of them runs the
    // fetch AND opens its own watch, and every subscription but the last is
    // overwritten in `_subscription` and never cancelled — it outlives
    // `dispose()` and keeps listening on that query. One cold chat open reaches
    // this from three places at once.
    return _inFlight ??= _fetchAndWatch().whenComplete(() => _inFlight = null);
  }

  Future<Set<String>> _fetchAndWatch() async {
    // Captured before the await. `dispose()` bumps it, so a fetch still in
    // flight when `dispose()` runs can tell that the answer it is holding
    // belongs to a user this filter no longer speaks for — clearing `_inFlight`
    // alone does not stop a future that is ALREADY running, which is what the
    // test for this found.
    final gen = generation();
    final ids = await fetch();
    // THROWS rather than returning an empty set, which would be
    // indistinguishable from "nobody is blocked" — the neutral-value trap this
    // file keeps being caught by. `current()` converts the throw into the
    // display path's empty set.
    if (gen != generation()) {
      throw StateError(BlockedUserFilter._disposedDuringFetch);
    }
    await _subscription?.cancel();
    // Keep cache fresh — block adds/removes propagate without restart, which
    // matters because blocking someone does not push into the filter.
    final subscription = watch().listen(
      (ids) {
        _cached = ids;
      },
      onError: (Object e) {
        // Invalidate, do not just log. Leaving the latch set here froze the
        // display path's set for the session on ONE `unavailable`, which is
        // routine on a long-lived listener.
        AppLogger.warning('[BlockedUserFilter] $label watch failed: $e');
        _invalidate();
      },
      onDone: _invalidate,
    );
    // Re-checked AFTER opening the watch: a dispose that lands in between would
    // otherwise leave this subscription running past it.
    if (gen != generation()) {
      await subscription.cancel();
      throw StateError(BlockedUserFilter._disposedDuringFetch);
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

  Future<void> dispose() async {
    // `_inFlight` too. Without it a fetch still in flight when this runs
    // completes afterwards, re-latches, repopulates the cache with the PREVIOUS
    // user's block list and opens a subscription nobody cancels.
    // `social_module.dart` registers the filter with `dispose: (f) => f.dispose()`.
    _inFlight = null;
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _cached = const <String>{};
  }
}
