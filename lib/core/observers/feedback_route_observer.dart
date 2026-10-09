import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:butlery/core/constants/routes.dart';

/// Tells the feedback "!" whether the screen on top is one it must stay off
/// (produktregler.md § 18.1): it never competes with the screen's primary
/// action, so it hides under a dialog or sheet and in cooking mode.
///
/// The button is built in `MaterialApp.builder`, outside the Navigator, so it
/// cannot ask a route for its type and has to be told by an observer.
class FeedbackRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  final ValueNotifier<bool> _suppressed = ValueNotifier<bool>(false);

  ValueListenable<bool> get suppressed => _suppressed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute == null) {
      if (index >= 0) _stack.removeAt(index);
    } else if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
    _publish();
  }

  // Dialogs, bottom sheets and popup menus are all PopupRoutes.
  bool _computeSuppressed() {
    if (_stack.isEmpty) return false;
    final top = _stack.last;
    return top is PopupRoute || top.settings.name == Routes.cookingMode;
  }

  // The navigator calls observers while it is itself building, and the
  // button listens from outside it, so notifying then would rebuild the
  // button mid-frame.
  void _publish() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      _suppressed.value = _computeSuppressed();
      return;
    }
    binding.addPostFrameCallback((_) {
      _suppressed.value = _computeSuppressed();
    });
  }
}

/// Process-wide instance registered on `MaterialApp.navigatorObservers`; the
/// button reads it by default.
final FeedbackRouteObserver appFeedbackRouteObserver = FeedbackRouteObserver();
