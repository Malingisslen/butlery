// lib/core/events/realtime/shopping_realtime_event.dart

import 'dart:async';

import 'base_realtime_event.dart';

/// Event types for shopping list real-time updates
enum ShoppingRealtimeEventType {
  itemAdded,
  itemUpdated,
  itemRemoved,
}

/// Event bus for shopping list changes
class ShoppingRealtimeEventBus
    implements BaseRealtimeEvent<ShoppingRealtimeEventType> {
  static final StreamController<ShoppingRealtimeEventType> _controller =
      StreamController<ShoppingRealtimeEventType>.broadcast();

  @override
  Stream<ShoppingRealtimeEventType> get stream => _controller.stream;

  // ===== EVENT TRIGGERS =====
  static void itemAdded() => _controller.add(ShoppingRealtimeEventType.itemAdded);
  static void itemUpdated() =>
      _controller.add(ShoppingRealtimeEventType.itemUpdated);
  static void itemRemoved() =>
      _controller.add(ShoppingRealtimeEventType.itemRemoved);

  @override
  void add(ShoppingRealtimeEventType event) => _controller.add(event);

  @override
  void dispose() => _controller.close();
}
