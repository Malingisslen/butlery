// lib/core/observers/route_tracker.dart
//
// BUT-521 follow-up: tracks the topmost route's settings.name so the
// keyboard layer can dedupe shortcut-driven navigation. Without this,
// spamming Cmd+K stacks N copies of the search route and the user has to
// press Back N times to escape.
//
// We use a `NavigatorObserver` (not `RouteObserver<ModalRoute>`) because we
// only need the most-recent route name — we don't need to multicast change
// events to per-route subscribers. The observer is wired into
// `MaterialApp.navigatorObservers` from `main.dart`.

import 'package:flutter/widgets.dart';

/// Tracks the topmost route in the navigator stack so other layers (e.g.
/// the keyboard shortcut handler) can read `currentRouteName` without
/// holding a `BuildContext`.
///
/// Lifecycle: install one instance globally and pass it to
/// `MaterialApp.navigatorObservers`. The instance is also exposed as
/// `appRouteObserver` for the rare case a `RouteObserver` consumer needs
/// the same observer chain — but most call sites should read
/// `currentRouteName` directly.
class RouteTracker extends NavigatorObserver {
  RouteTracker();

  /// History of route names, parallel to the navigator stack. The last
  /// element is the topmost route. Routes with `settings.name == null`
  /// (anonymous pushes) are still tracked so pop ordering stays correct.
  final List<String?> _stack = <String?>[];

  /// Name of the topmost route, or `null` if the stack is empty / the
  /// topmost route was pushed anonymously (no `settings.name`).
  String? get currentRouteName => _stack.isEmpty ? null : _stack.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Removed routes can be anywhere in the stack — match by name + pop the
    // last occurrence. Best-effort only: anonymous routes get popped LIFO.
    final name = route.settings.name;
    final idx = _stack.lastIndexOf(name);
    if (idx >= 0) _stack.removeAt(idx);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_stack.isEmpty) {
      _stack.add(newRoute?.settings.name);
      return;
    }
    _stack[_stack.length - 1] = newRoute?.settings.name;
  }
}

/// Process-wide tracker used by the keyboard layer. Initialized once in
/// `main.dart` and registered on `MaterialApp.navigatorObservers`. Tests
/// can replace it with a fresh instance via `appRouteTracker = …` to
/// isolate state.
RouteTracker appRouteTracker = RouteTracker();
