// lib/services/realtime/handlers/menu_realtime_handler.dart

import 'dart:async';
import '../../menu_service.dart';
import '../event_bus_service.dart';
import '../../../core/utils/logger.dart';

/// Handles realtime events for menus.
class MenuRealtimeHandler {
  final MenuService _menuService;
  late final StreamSubscription<RealtimeEvent> _subscription;

  MenuRealtimeHandler({required MenuService menuService})
      : _menuService = menuService {
    _subscription = EventBusService.stream.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent event) {
    if (event.type != RealtimeContentType.menu) return;
    AppLogger.debug('MenuRealtimeHandler received event');
    // TODO: process menu related updates with _menuService
  }

  void dispose() {
    _subscription.cancel();
  }
}
