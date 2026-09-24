// lib/core/observers/page_route_stack_observer.dart
//
// Flow 06 (P6-U06, TR::FLOW::06::session::utgang): after a timeout, signing
// in again as the same account returns to where the user was. The session
// timeout needs the top SCREEN at that moment, with its arguments. The
// warning dialog is itself a route on top, so the top route is not enough,
// and `RouteTracker` keeps names only.

import 'package:flutter/widgets.dart';

/// Tracks the navigator's routes and answers which named page is on top,
/// skipping dialogs, sheets and popups.
class PageRouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  /// The topmost named [PageRoute], or null when there is none.
  Route<dynamic>? get topPageRoute {
    for (final route in _stack.reversed) {
      if (route is PageRoute && route.settings.name != null) return route;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute == null) {
      if (index >= 0) _stack.removeAt(index);
      return;
    }
    if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
  }
}
