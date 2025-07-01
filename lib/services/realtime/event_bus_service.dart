// lib/services/realtime/event_bus_service.dart

import 'dart:async';

/// Content types supported by [EventBusService].
enum RealtimeContentType { recipe, menu, shopping }

/// Event object carrying a [RealtimeContentType] and optional payload.
class RealtimeEvent {
  final RealtimeContentType type;
  final dynamic payload;

  RealtimeEvent({required this.type, this.payload});
}

/// Simple event bus to broadcast [RealtimeEvent]s across the app.
class EventBusService {
  static final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  /// Stream of all realtime events.
  static Stream<RealtimeEvent> get stream => _controller.stream;

  /// Emit a new [event] to all listeners.
  static void emit(RealtimeEvent event) => _controller.add(event);

  /// Close the underlying stream controller.
  static void dispose() => _controller.close();
}
