// lib/services/unified/operations/realtime_recipe/realtime_watching_module.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';

/// Realtime recipe watching module
/// 
/// This module handles ONLY real-time watching and stream management:
/// - Watch single recipes for real-time updates
/// - Watch multiple recipes simultaneously
/// - Connection status monitoring
/// - Fallback polling when realtime unavailable
/// 
/// ❌ DOES NOT CONTAIN: Editing, presence, notifications, collaboration management
class RealtimeWatchingModule {
  final dynamic _parent; // UnifiedRecipeService
  final dynamic _realtimeSyncService; // RealtimeSyncService?

  RealtimeWatchingModule(this._parent, [this._realtimeSyncService]);

  // ===== SINGLE RECIPE WATCHING =====

  /// Watch a recipe for real-time updates
  Stream<Recipe> watchRecipe(String recipeId) {
    if (_realtimeSyncService == null) {
      AppLogger.warning('RealtimeSyncService not available, falling back to periodic updates');
      return _watchRecipeWithPolling(recipeId);
    }

    try {
      return _realtimeSyncService!
          .watchResource<dynamic>(recipeId)
          .map((realtimeRecipe) => RealtimeRecipeUtils.convertToRecipe(realtimeRecipe))
          .handleError((error) {
            AppLogger.error('Error watching recipe $recipeId', error);
          });
    } catch (e) {
      AppLogger.error('Failed to start watching recipe $recipeId', e);
      return _watchRecipeWithPolling(recipeId);
    }
  }

  /// Watch recipe with automatic retry on connection failure
  Stream<Recipe> watchRecipeWithRetry(String recipeId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return _watchRecipeWithRetryLogic(recipeId, maxRetries, retryDelay, 0);
  }

  /// Internal retry logic for watching recipes
  Stream<Recipe> _watchRecipeWithRetryLogic(
    String recipeId, 
    int maxRetries, 
    Duration retryDelay, 
    int currentAttempt
  ) {
    return watchRecipe(recipeId).handleError((error) {
      if (currentAttempt < maxRetries) {
        AppLogger.warning('Watch attempt ${currentAttempt + 1} failed for recipe $recipeId, retrying...');
        return Future.delayed(retryDelay).then((_) =>
          _watchRecipeWithRetryLogic(recipeId, maxRetries, retryDelay, currentAttempt + 1)
        );
      } else {
        AppLogger.error('Max retries exceeded for watching recipe $recipeId');
        throw error;
      }
    });
  }

  // ===== MULTIPLE RECIPE WATCHING =====

  /// Watch multiple recipes for real-time updates
  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    if (_realtimeSyncService == null) {
      return _watchMultipleRecipesWithPolling(recipeIds);
    }

    try {
      // Combine streams from multiple recipes
      return Stream.fromIterable(recipeIds)
          .asyncMap((recipeId) => watchRecipe(recipeId).first)
          .fold<List<Recipe>>([], (previous, recipe) {
            return [...previous, recipe];
          })
          .asStream();
    } catch (e) {
      AppLogger.error('Failed to watch multiple recipes', e);
      return _watchMultipleRecipesWithPolling(recipeIds);
    }
  }

  /// Watch multiple recipes with individual error handling
  Stream<Map<String, Recipe?>> watchMultipleRecipesIndividually(List<String> recipeIds) {
    final controllers = <String, StreamController<Recipe>>{};
    final resultController = StreamController<Map<String, Recipe?>>();
    final currentRecipes = <String, Recipe?>{};

    try {
      // Initialize controllers for each recipe
      for (final recipeId in recipeIds) {
        controllers[recipeId] = StreamController<Recipe>();
        currentRecipes[recipeId] = null;

        // Start watching each recipe individually
        watchRecipe(recipeId).listen(
          (recipe) {
            currentRecipes[recipeId] = recipe;
            resultController.add(Map.from(currentRecipes));
          },
          onError: (error) {
            AppLogger.error('Error watching recipe $recipeId in batch', error);
            currentRecipes[recipeId] = null;
            resultController.add(Map.from(currentRecipes));
          },
        );
      }

      return resultController.stream;
    } catch (e) {
      AppLogger.error('Failed to setup individual recipe watching', e);
      resultController.close();
      return Stream.value({});
    }
  }

  // ===== CONNECTION MONITORING =====

  /// Get connection status for real-time operations
  bool get isConnected => _realtimeSyncService?.isConnected ?? false;

  /// Get connection status stream
  Stream<bool> get connectionStream => 
      _realtimeSyncService?.connectionStream ?? Stream.value(false);

  /// Wait for connection to be established
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (isConnected) return true;

    try {
      await connectionStream
          .where((connected) => connected)
          .timeout(timeout)
          .first;
      return true;
    } catch (e) {
      AppLogger.warning('Connection timeout after ${timeout.inSeconds}s');
      return false;
    }
  }

  /// Monitor connection status changes
  Stream<ConnectionStatus> monitorConnectionStatus() {
    return connectionStream.map((connected) {
      return ConnectionStatus(
        isConnected: connected,
        timestamp: DateTime.now(),
        hasRealtimeService: _realtimeSyncService != null,
      );
    });
  }

  // ===== FALLBACK POLLING =====

  /// Fallback watching with polling when RealtimeSyncService unavailable
  Stream<Recipe> _watchRecipeWithPolling(String recipeId) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    }).where((recipe) => recipe != null).cast<Recipe>();
  }

  /// Fallback watching multiple recipes with polling
  Stream<List<Recipe>> _watchMultipleRecipesWithPolling(List<String> recipeIds) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return recipeIds
          .map((id) => _parent.recipes.where((r) => r.id == id).firstOrNull)
          .where((r) => r != null)
          .cast<Recipe>()
          .toList();
    });
  }

  // ===== WATCH MANAGEMENT =====

  /// Start watching recipe with callback
  StreamSubscription<Recipe> startWatchingRecipe(
    String recipeId, 
    void Function(Recipe) onRecipeUpdated, {
    void Function(dynamic)? onError,
  }) {
    return watchRecipe(recipeId).listen(
      onRecipeUpdated,
      onError: onError ?? (error) {
        AppLogger.error('Error in recipe watch callback for $recipeId', error);
      },
    );
  }

  /// Start watching multiple recipes with callback
  StreamSubscription<List<Recipe>> startWatchingMultipleRecipes(
    List<String> recipeIds,
    void Function(List<Recipe>) onRecipesUpdated, {
    void Function(dynamic)? onError,
  }) {
    return watchMultipleRecipes(recipeIds).listen(
      onRecipesUpdated,
      onError: onError ?? (error) {
        AppLogger.error('Error in multiple recipes watch callback', error);
      },
    );
  }

  // ===== UTILITY METHODS =====

  /// Check if recipe watching is available
  bool isWatchingAvailable() {
    return _realtimeSyncService != null;
  }

  /// Get watching capabilities
  Map<String, bool> getWatchingCapabilities() {
    return {
      'hasRealtimeService': _realtimeSyncService != null,
      'isConnected': isConnected,
      'canWatchSingle': true, // Always available with polling fallback
      'canWatchMultiple': true, // Always available with polling fallback
      'hasRetry': _realtimeSyncService != null,
      'hasConnectionMonitoring': _realtimeSyncService != null,
    };
  }
}

/// Connection status information
class ConnectionStatus {
  final bool isConnected;
  final DateTime timestamp;
  final bool hasRealtimeService;

  const ConnectionStatus({
    required this.isConnected,
    required this.timestamp,
    required this.hasRealtimeService,
  });

  @override
  String toString() {
    return 'ConnectionStatus{isConnected: $isConnected, hasRealtimeService: $hasRealtimeService, timestamp: $timestamp}';
  }
}