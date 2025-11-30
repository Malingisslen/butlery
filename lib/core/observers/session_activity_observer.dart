// lib/core/observers/session_activity_observer.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Navigator observer that records session activity on route changes
/// Integrates with SessionTimeoutService to reset inactivity timer whenever user navigates
class SessionActivityObserver extends NavigatorObserver {
  final SessionTimeoutService _sessionService;

  SessionActivityObserver(this._sessionService);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _recordActivity('didPush', route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _recordActivity('didPop', route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _recordActivity('didReplace', newRoute);
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    _recordActivity('didRemove', route);
  }

  void _recordActivity(String action, Route route) {
    _sessionService.recordActivity();
    AppLogger.debug(
      'SessionActivityObserver: $action - ${route.settings.name ?? "unknown"}',
    );
  }
}
