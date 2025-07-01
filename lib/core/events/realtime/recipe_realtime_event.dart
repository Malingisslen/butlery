// lib/core/events/realtime/recipe_realtime_event.dart

import 'dart:async';

import 'base_realtime_event.dart';

/// Event types for recipe real-time updates
enum RecipeRealtimeEventType {
  created,
  updated,
  deleted,
}

/// Event bus for recipe changes
class RecipeRealtimeEventBus implements BaseRealtimeEvent<RecipeRealtimeEventType> {
  static final StreamController<RecipeRealtimeEventType> _controller =
      StreamController<RecipeRealtimeEventType>.broadcast();

  @override
  Stream<RecipeRealtimeEventType> get stream => _controller.stream;

  // ===== EVENT TRIGGERS =====
  static void recipeCreated() =>
      _controller.add(RecipeRealtimeEventType.created);
  static void recipeUpdated() =>
      _controller.add(RecipeRealtimeEventType.updated);
  static void recipeDeleted() =>
      _controller.add(RecipeRealtimeEventType.deleted);

  @override
  void add(RecipeRealtimeEventType event) => _controller.add(event);

  @override
  void dispose() => _controller.close();
}
