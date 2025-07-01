// lib/core/events/realtime/base_realtime_event.dart

import 'dart:async';

/// Base interface for real-time event buses
abstract class BaseRealtimeEvent<T> {
  /// Stream of real-time events
  Stream<T> get stream;

  /// Add a new event to the bus
  void add(T event);

  /// Dispose underlying resources
  void dispose();
}
