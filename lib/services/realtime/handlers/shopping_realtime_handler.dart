// lib/services/realtime/handlers/shopping_realtime_handler.dart

import 'dart:async';
import '../../unified/unified_shopping_service.dart';
import '../event_bus_service.dart';
import '../../../core/utils/logger.dart';

/// Handles realtime events for shopping lists.
class ShoppingRealtimeHandler {
  final UnifiedShoppingService _shoppingService;
  late final StreamSubscription<RealtimeEvent> _subscription;

  ShoppingRealtimeHandler({required UnifiedShoppingService shoppingService})
      : _shoppingService = shoppingService {
    _subscription = EventBusService.stream.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent event) {
    if (event.type != RealtimeContentType.shopping) return;
    AppLogger.debug('ShoppingRealtimeHandler received event');
    // TODO: update shopping service using event.payload
  }

  void dispose() {
    _subscription.cancel();
  }
}
