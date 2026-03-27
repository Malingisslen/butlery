// lib/services/unified/operations/realtime_recipe/realtime_watching_module.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';

/// Realtime recipe watching module
/// This module handles ONLY real-time watching and stream management:
/// - Watch single recipes for real-time updates
/// - Watch multiple recipes simultaneously
/// - Connection status monitoring
/// - Fallback polling when realtime unavailable
/// ❌ DOES NOT CONTAIN: Editing, presence, notifications, collaboration management
class RealtimeWatchingModule {
  final List<Recipe> Function() _getRecipes;
  final RealtimeSyncService? _realtimeSyncService;

  RealtimeWatchingModule({
    required List<Recipe> Function() getRecipes,
    RealtimeSyncService? realtimeSyncService,
  })  : _getRecipes = getRecipes,
        _realtimeSyncService = realtimeSyncService;

  /// Watch a recipe for real-time updates
  Stream<Recipe> watchRecipe(String recipeId) {
    if (_realtimeSyncService == null) {
      AppLogger.warning(
          'RealtimeSyncService not available, falling back to periodic updates');
      return _watchRecipeWithPolling(recipeId);
    }

    try {
      return _realtimeSyncService
          .watchResource<RealtimeRecipe>(recipeId)
          .map((realtimeRecipe) =>
              RealtimeRecipeUtils.convertToRecipe(realtimeRecipe))
          .handleError((error) {
        AppLogger.error('Error watching recipe $recipeId', error);
        // Rethrow the error so it can be handled by the caller
        throw error;
      });
    } catch (e) {
      AppLogger.error('Failed to start watching recipe $recipeId', e);
      return _watchRecipeWithPolling(recipeId);
    }
  }

  /// Watch recipe with automatic retry on connection failure
  Stream<Recipe> watchRecipeWithRetry(
    String recipeId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    // Create a controller to manage the retry logic
    StreamController<Recipe>? controller;
    StreamSubscription<Recipe>? subscription;
    bool hasEmittedValue = false;
    bool isClosed = false;
    int attemptCount = 0; // Track attempts locally

    void attemptWatch() {
      subscription?.cancel();

      if (isClosed) return; // Don't attempt if controller is closed

      attemptCount++; // Increment attempt count before each try

      subscription = watchRecipe(recipeId).listen(
        (recipe) {
          hasEmittedValue = true;
          if (!isClosed && controller != null && !controller.isClosed) {
            controller.add(recipe);
          }
        },
        onError: (error) {
          if (!isClosed && !hasEmittedValue && attemptCount < maxRetries) {
            AppLogger.warning(
                'Watch attempt $attemptCount failed for recipe $recipeId, retrying...');
            Future.delayed(retryDelay, attemptWatch);
          } else if (!isClosed && attemptCount >= maxRetries) {
            AppLogger.error(
                'Max retries exceeded for watching recipe $recipeId after $attemptCount attempts');
            if (controller != null && !controller.isClosed) {
              controller.addError(error);
            }
          } else if (!isClosed) {
            // If we've already emitted values, just pass the error through
            if (controller != null && !controller.isClosed) {
              controller.addError(error);
            }
          }
        },
        onDone: () {
          if (!isClosed && controller != null && !controller.isClosed) {
            isClosed = true;
            controller.close();
          }
        },
      );
    }

    controller = StreamController<Recipe>.broadcast(
      onListen: attemptWatch,
      onCancel: () {
        isClosed = true;
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Watch multiple recipes for real-time updates
  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    if (_realtimeSyncService == null) {
      return _watchMultipleRecipesWithPolling(recipeIds);
    }

    try {
      // Create a StreamController to emit combined results
      // ignore: close_sinks - Controller is closed via onCancel callback
      final controller = StreamController<List<Recipe>>.broadcast();
      final currentRecipes = <String, Recipe>{};
      final subscriptions = <StreamSubscription>[];

      // Subscribe to each recipe stream
      for (final recipeId in recipeIds) {
        final subscription = watchRecipe(recipeId).listen(
          (recipe) {
            currentRecipes[recipeId] = recipe;
            // Emit the current list of all recipes whenever any updates
            if (!controller.isClosed) {
              controller.add(currentRecipes.values.toList());
            }
          },
          onError: (error) {
            AppLogger.error('Error watching recipe $recipeId', error);
          },
        );
        subscriptions.add(subscription);
      }

      // Clean up subscriptions and close controller when the stream is closed
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await controller.close();
      };

      return controller.stream;
    } catch (e) {
      AppLogger.error('Failed to watch multiple recipes', e);
      return _watchMultipleRecipesWithPolling(recipeIds);
    }
  }

  /// Watch multiple recipes with individual error handling
  Stream<Map<String, Recipe?>> watchMultipleRecipesIndividually(
      List<String> recipeIds) {
    // ignore: close_sinks - Controller is closed via onCancel callback
    final resultController = StreamController<Map<String, Recipe?>>.broadcast();
    final currentRecipes = <String, Recipe?>{};
    final subscriptions = <StreamSubscription>[];

    try {
      // Initialize all recipes as null
      for (final recipeId in recipeIds) {
        currentRecipes[recipeId] = null;
      }

      // Start watching each recipe individually
      for (final recipeId in recipeIds) {
        final subscription = watchRecipe(recipeId).listen(
          (recipe) {
            currentRecipes[recipeId] = recipe;
            if (!resultController.isClosed) {
              resultController.add(Map.from(currentRecipes));
            }
          },
          onError: (error) {
            AppLogger.error('Error watching recipe $recipeId in batch', error);
            currentRecipes[recipeId] = null;
            if (!resultController.isClosed) {
              resultController.add(Map.from(currentRecipes));
            }
          },
        );
        subscriptions.add(subscription);
      }

      // Emit initial state with all nulls
      if (!resultController.isClosed) {
        resultController.add(Map.from(currentRecipes));
      }

      // Clean up subscriptions when stream is closed
      resultController.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await resultController.close();
      };

      return resultController.stream;
    } catch (e) {
      AppLogger.error('Failed to setup individual recipe watching', e);
      resultController.close();
      return Stream.value({});
    }
  }

  /// Get connection status for real-time operations
  bool get isConnected => _realtimeSyncService?.isConnected ?? false;

  /// Get connection status stream
  Stream<bool> get connectionStream =>
      _realtimeSyncService?.connectionStream ?? Stream.value(false);

  /// Wait for connection to be established
  Future<bool> waitForConnection(
      {Duration timeout = const Duration(seconds: 10)}) async {
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
    // Create initial status
    final initialStatus = ConnectionStatus(
      isConnected: isConnected,
      timestamp: DateTime.now(),
      hasRealtimeService: _realtimeSyncService != null,
    );

    // If no realtime service, just return the initial status
    if (_realtimeSyncService == null) {
      return Stream.value(initialStatus);
    }

    // Create a stream that emits initial value then follows connection changes
    // ignore: close_sinks - Controller is closed via onCancel callback
    late final StreamController<ConnectionStatus> controller;
    StreamSubscription<bool>? subscription;

    controller = StreamController<ConnectionStatus>.broadcast(
      onListen: () {
        // Emit initial status when someone starts listening
        controller.add(initialStatus);

        // Then start listening to connection changes
        subscription = connectionStream.listen(
          (connected) {
            if (!controller.isClosed) {
              controller.add(ConnectionStatus(
                isConnected: connected,
                timestamp: DateTime.now(),
                hasRealtimeService: true, // We know it's not null here
              ));
            }
          },
          onError: (error) {
            if (!controller.isClosed) {
              controller.addError(error);
            }
          },
        );
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );

    return controller.stream;
  }

  /// Fallback watching with polling when RealtimeSyncService unavailable
  Stream<Recipe> _watchRecipeWithPolling(String recipeId) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return _getRecipes().where((r) => r.id == recipeId).firstOrNull;
    }).where((recipe) => recipe != null).cast<Recipe>();
  }

  /// Fallback watching multiple recipes with polling
  Stream<List<Recipe>> _watchMultipleRecipesWithPolling(
      List<String> recipeIds) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return recipeIds
          .map((id) => _getRecipes().where((r) => r.id == id).firstOrNull)
          .where((r) => r != null)
          .cast<Recipe>()
          .toList();
    });
  }

  /// Start watching recipe with callback
  StreamSubscription<Recipe> startWatchingRecipe(
    String recipeId,
    void Function(Recipe) onRecipeUpdated, {
    void Function(dynamic)? onError,
  }) {
    return watchRecipe(recipeId).listen(
      onRecipeUpdated,
      onError: onError ??
          (error) {
            AppLogger.error(
                'Error in recipe watch callback for $recipeId', error);
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
      onError: onError ??
          (error) {
            AppLogger.error('Error in multiple recipes watch callback', error);
          },
    );
  }

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
