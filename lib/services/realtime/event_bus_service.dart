// lib/services/realtime/event_bus_service.dart

import 'dart:async';

/// Central event bus for distributing real-time events across the app.
///
/// Other services can publish events here and subscribe to specific event
/// types. The bus uses a broadcast [StreamController] so multiple listeners
/// can react to the same event without interfering with each other.
class EventBusService {
  // Singleton pattern for easy global access
  static final EventBusService _instance = EventBusService._internal();
  factory EventBusService() => _instance;
  EventBusService._internal();

  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  /// Stream of all events published to the bus.
  Stream<dynamic> get stream => _controller.stream;

  /// Publish a new event to all listeners.
  void publish(dynamic event) => _controller.add(event);

  /// Listen for events of type [T].
  Stream<T> on<T>() => stream.where((e) => e is T).cast<T>();

  /// Close the bus. Primarily used in tests.
  void dispose() => _controller.close();
}
