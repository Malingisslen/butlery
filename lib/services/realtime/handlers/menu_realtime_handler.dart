import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../realtime/event_bus_service.dart';
import '../../../core/events/realtime/menu_realtime_event.dart';

/// Handles menu-specific real-time events.
class MenuRealtimeHandler {
  final EventBusService _eventBus;
  StreamSubscription<MenuRealtimeEventType>? _subscription;

  MenuRealtimeHandler({required EventBusService eventBus})
      : _eventBus = eventBus;

  /// Start listening for menu events.
  void initialize() {
    _subscription = _eventBus.on<MenuRealtimeEventType>().listen(_onEvent);
  }

  void _onEvent(MenuRealtimeEventType event) {
    debugPrint('📋 Menu realtime event: $event');
    // Additional menu-specific logic could be added here.
  }

  /// Stop listening to events.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
