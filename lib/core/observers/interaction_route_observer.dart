import 'package:flutter/widgets.dart';

import 'package:butlery/services/feedback/interaction_logger.dart';

/// Navigator observer that logs route changes to [InteractionLogger]
/// for inclusion in beta feedback submissions.
class InteractionRouteObserver extends NavigatorObserver {
  final InteractionLogger _logger;

  InteractionRouteObserver(this._logger);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.logInteraction(
      route.settings.name ?? 'unknown',
      'navigate',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.logInteraction(
      previousRoute?.settings.name ?? 'unknown',
      'back',
    );
  }
}
