// lib/services/realtime/handlers/recipe_realtime_handler.dart

import 'dart:async';
import '../../recipe_service.dart';
import '../event_bus_service.dart';
import '../../../core/utils/logger.dart';

/// Handles realtime events for recipes.
class RecipeRealtimeHandler {
  final RecipeService _recipeService;
  late final StreamSubscription<RealtimeEvent> _subscription;

  RecipeRealtimeHandler({required RecipeService recipeService})
      : _recipeService = recipeService {
    _subscription = EventBusService.stream.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent event) {
    if (event.type != RealtimeContentType.recipe) return;
    AppLogger.debug('RecipeRealtimeHandler received event');
    // TODO: add actual handling logic using _recipeService and event.payload
  }

  void dispose() {
    _subscription.cancel();
  }
}
