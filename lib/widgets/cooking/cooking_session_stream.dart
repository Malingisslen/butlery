// BUT-408 follow-up (/simplify): hoist the per-view merged cooking-session
// stream into a State-owned holder so it isn't re-allocated — with fresh
// RTDB subscriptions — on every parent rebuild.
//
// Usage: create one holder in `initState()` of a view hosting the
// CookingSessionCard, call `refresh(module, groupIds, selfUserId)` once
// (idempotent if the inputs are unchanged), read `stream` in `build`, and
// `dispose()` in the state's dispose.

import 'dart:async';

import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';

/// Stream holder that merges per-group cooking-session streams into one
/// list, filtering out the current user, without reallocating on rebuild.
class CookingSessionStreamHolder {
  StreamController<List<CookingSession>>? _controller;

  /// Cached `controller.stream` wrapper. [StreamController.broadcast.stream]
  /// returns a new `_BroadcastStream` on every call — we cache the first one
  /// so `StreamBuilder` sees a stable stream identity across rebuilds and
  /// doesn't re-subscribe (which on a broadcast stream would briefly blank
  /// its snapshot until the next emit).
  Stream<List<CookingSession>>? _stream;

  final List<StreamSubscription<List<CookingSession>>> _subs = [];
  List<String> _groupIds = const [];
  String? _selfUserId;

  /// Live merged stream, or `null` until [refresh] has been called with a
  /// non-empty group list.
  Stream<List<CookingSession>>? get stream => _stream;

  /// Re-subscribe only when the inputs have actually changed. Cheap to
  /// call on every build — identical inputs are a no-op.
  void refresh(
    CookingSessionModule module,
    List<String> groupIds,
    String selfUserId,
  ) {
    if (_selfUserId == selfUserId && _sameGroups(_groupIds, groupIds)) {
      return;
    }

    _closeSubs();
    _selfUserId = selfUserId;
    _groupIds = List<String>.unmodifiable(groupIds);

    if (groupIds.isEmpty) {
      _controller = null;
      _stream = null;
      return;
    }

    final perGroupLatest = <String, List<CookingSession>>{
      for (final id in groupIds) id: const [],
    };

    final controller = StreamController<List<CookingSession>>.broadcast();
    _controller = controller;
    _stream = controller.stream;

    void emit() {
      if (controller.isClosed) return;
      final seen = <String>{};
      final merged = <CookingSession>[];
      for (final list in perGroupLatest.values) {
        for (final s in list) {
          if (s.userId == selfUserId) continue;
          if (seen.add(s.userId)) merged.add(s);
        }
      }
      merged.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      controller.add(merged);
    }

    for (final id in groupIds) {
      _subs.add(module.watchGroupSessions(id).listen((sessions) {
        perGroupLatest[id] = sessions;
        emit();
      }));
    }
    emit();
  }

  void dispose() {
    _closeSubs();
    _controller?.close();
    _controller = null;
    _stream = null;
  }

  void _closeSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  static bool _sameGroups(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
