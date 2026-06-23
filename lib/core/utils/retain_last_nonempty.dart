import 'dart:async';

/// Stream transform that keeps an RTDB-backed widget from blanking when the
/// device drops offline.
///
/// RTDB has no read cache: when connectivity is lost, an `.onValue` listener
/// emits an empty/last value rather than retaining what it last showed, so a
/// presence bar or cooking-session card abruptly vanishes (BUT-1360 item 6).
///
/// This transform suppresses *empty* upstream emissions **only while the
/// device is offline**, replaying the last non-empty value instead. The
/// moment connectivity returns, the live stream is trusted completely — so a
/// session that legitimately ended (or a friend who genuinely went offline)
/// disappears as soon as we're back online. We never fabricate data: if the
/// first emission while offline is already empty (no last-known-good), the
/// empty passes through and the widget renders nothing, exactly as today.
///
/// Why gate on device-offline rather than always retaining: an empty emission
/// while *online* is authoritative (the RTDB `onDisconnect().remove()` cleared
/// the row server-side because the cook stopped). Retaining across that would
/// show a stale "X lagar just nu" after X stopped — the misleading-staleness
/// the ticket explicitly warns against. Only an offline-induced empty is
/// untrustworthy, and that is the sole case we suppress.
///
/// [isEmpty] decides what counts as an empty emission for [T] (e.g.
/// `(set) => set.isEmpty`). [isOffline] is consulted lazily per emission so it
/// always reflects current connectivity — pass a closure over your
/// connectivity source (e.g. `() => !offlineService.isOnline`).
StreamTransformer<T, T> retainLastNonEmptyWhileOffline<T>({
  required bool Function(T value) isEmpty,
  required bool Function() isOffline,
}) {
  T? lastNonEmpty;
  bool hasLastNonEmpty = false;

  return StreamTransformer<T, T>.fromHandlers(
    handleData: (value, sink) {
      if (!isEmpty(value)) {
        lastNonEmpty = value;
        hasLastNonEmpty = true;
        sink.add(value);
        return;
      }

      // Empty emission. Trust it while online; while offline, replay the last
      // non-empty value if we have one (otherwise let the empty through —
      // never invent data).
      if (isOffline() && hasLastNonEmpty) {
        sink.add(lastNonEmpty as T);
      } else {
        sink.add(value);
      }
    },
  );
}
