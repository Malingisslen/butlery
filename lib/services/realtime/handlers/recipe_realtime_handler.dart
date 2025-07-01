import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../realtime/event_bus_service.dart';
import '../../../core/events/realtime/recipe_realtime_event.dart';

/// Handles recipe-specific real-time events.
class RecipeRealtimeHandler {
  final EventBusService _eventBus;
  StreamSubscription<RecipeRealtimeEventType>? _subscription;

  RecipeRealtimeHandler({required EventBusService eventBus})
      : _eventBus = eventBus;

  /// Start listening for recipe events.
  void initialize() {
    _subscription =
        _eventBus.on<RecipeRealtimeEventType>().listen(_onEvent);
  }

  void _onEvent(RecipeRealtimeEventType event) {
    debugPrint('📒 Recipe realtime event: $event');
    // Additional recipe-specific logic could be added here.
  }

  /// Stop listening to events.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
