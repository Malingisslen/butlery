// lib/services/realtime/realtime_event_handler.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'event_bus_service.dart';
import 'content_sharing_service.dart';

/// Service that listens to real-time events from [EventBusService]
/// and performs side effects based on the event type.
class RealtimeEventHandler {
  final EventBusService _eventBus;
  final ContentSharingService _sharingService;
  StreamSubscription<dynamic>? _subscription;

  RealtimeEventHandler({
    required EventBusService eventBus,
    required ContentSharingService sharingService,
  })  : _eventBus = eventBus,
        _sharingService = sharingService;

  /// Start listening to events.
  void initialize() {
    _subscription = _eventBus.stream.listen(_handleEvent);
  }

  void _handleEvent(dynamic event) {
    if (event is ContentSharedEvent) {
      // Additional processing for shared content could be placed here.
      debugPrint('📤 Content shared: ${event.content.substring(0, event.content.length.clamp(0, 50))}');
    }
  }

  /// Dispose the event subscription.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
