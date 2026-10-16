import 'package:flutter/material.dart';

import 'package:butlery/services/feedback/interaction_logger.dart';

/// Navigator observer that logs route changes to [InteractionLogger]
/// for inclusion in beta feedback submissions.
class InteractionRouteObserver extends NavigatorObserver {
  final InteractionLogger _logger;

  InteractionRouteObserver(this._logger);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isTransientMenu(route)) return;
    _logger.logInteraction(_label(route), 'navigate');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isTransientMenu(route)) return;
    _logger.logInteraction(_label(previousRoute), 'back');
  }

  // Dropdowns and popup menus open and close in place; logged, they fill the
  // 20-entry buffer and push the screens the user visited out of it.
  static bool _isTransientMenu(Route<dynamic> route) =>
      route is PopupRoute &&
      route.settings.name == null &&
      route is! RawDialogRoute &&
      route is! ModalBottomSheetRoute;

  // Release builds are obfuscated, so a widget type is no use as a label.
  static String _label(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) return name;
    if (route is RawDialogRoute) return 'dialog';
    if (route is ModalBottomSheetRoute) return 'sheet';
    if (route is PageRoute) return 'page:unnamed';
    return 'unknown';
  }
}
