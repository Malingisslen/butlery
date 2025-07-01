import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../realtime/event_bus_service.dart';
import '../../../core/events/realtime/shopping_realtime_event.dart';

/// Handles shopping list specific real-time events.
class ShoppingRealtimeHandler {
  final EventBusService _eventBus;
  StreamSubscription<ShoppingRealtimeEventType>? _subscription;

  ShoppingRealtimeHandler({required EventBusService eventBus})
      : _eventBus = eventBus;

  /// Start listening for shopping events.
  void initialize() {
    _subscription =
        _eventBus.on<ShoppingRealtimeEventType>().listen(_onEvent);
  }

  void _onEvent(ShoppingRealtimeEventType event) {
    debugPrint('🛒 Shopping realtime event: $event');
    // Additional shopping-specific logic could be added here.
  }

  /// Stop listening to events.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
