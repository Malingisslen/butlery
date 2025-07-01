// lib/core/events/realtime/menu_realtime_event.dart

import 'dart:async';

import 'base_realtime_event.dart';

/// Event types for menu real-time updates
enum MenuRealtimeEventType {
  created,
  updated,
  deleted,
}

/// Event bus for menu changes
class MenuRealtimeEventBus implements BaseRealtimeEvent<MenuRealtimeEventType> {
  static final StreamController<MenuRealtimeEventType> _controller =
      StreamController<MenuRealtimeEventType>.broadcast();

  @override
  Stream<MenuRealtimeEventType> get stream => _controller.stream;

  // ===== EVENT TRIGGERS =====
  static void menuCreated() => _controller.add(MenuRealtimeEventType.created);
  static void menuUpdated() => _controller.add(MenuRealtimeEventType.updated);
  static void menuDeleted() => _controller.add(MenuRealtimeEventType.deleted);

  @override
  void add(MenuRealtimeEventType event) => _controller.add(event);

  @override
  void dispose() => _controller.close();
}
