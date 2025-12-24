// lib/viewmodels/recipe_form/image_management/image_state_synchronizer.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Thread-safe state synchronization for image upload operations.
/// Extracted from RecipeImageManager for better separation of concerns.
///
/// **Responsibilities:**
/// - Thread-safe state update coordination
/// - Debounced notification management
/// - Disposal-safe listener notification
/// - Queue management for pending updates
///
/// **Thread Safety:**
/// - Prevents race conditions during state updates
/// - Queues updates during active state modification
/// - Debounces rapid notifications to prevent UI thrashing
/// - Safe disposal handling for pending operations
class ImageStateSynchronizer {
  final VoidCallback _notifyListeners;

  bool _disposed = false;
  bool _isStateUpdating = false;
  bool _isNotifying = false;
  final List<VoidCallback> _pendingStateUpdates = [];
  Timer? _notificationDebounceTimer;

  /// Debounce duration for notifications (milliseconds)
  static const int _debounceMs = 50;

  ImageStateSynchronizer({
    required VoidCallback notifyListeners,
  }) : _notifyListeners = notifyListeners;

  /// Check if synchronizer is disposed
  bool get isDisposed => _disposed;

  /// Thread-safe state update coordination.
  /// Queues updates if another update is in progress, then processes queue.
  void safeUpdateState(VoidCallback updateFunction) {
    if (_disposed) return;

    if (_isStateUpdating) {
      // Queue the update for when current update completes
      _pendingStateUpdates.add(updateFunction);
      return;
    }

    _isStateUpdating = true;
    try {
      updateFunction();

      // Process any pending updates
      while (_pendingStateUpdates.isNotEmpty && !_disposed) {
        final nextUpdate = _pendingStateUpdates.removeAt(0);
        nextUpdate();
      }
    } finally {
      _isStateUpdating = false;
    }
  }

  /// Thread-safe notification with disposal protection and optional debouncing.
  /// Use immediate=true for instant UI feedback (e.g., adding images).
  void safeNotifyListeners({bool immediate = false}) {
    if (_disposed || _isNotifying) return;

    if (immediate) {
      _doSafeNotification();
    } else {
      // Cancel previous debounce timer
      _notificationDebounceTimer?.cancel();

      // Debounce notifications to prevent excessive updates
      _notificationDebounceTimer =
          Timer(const Duration(milliseconds: _debounceMs), () {
        _doSafeNotification();
      });
    }
  }

  /// Immediate notification for instant UI feedback.
  void notifyImmediately() {
    safeNotifyListeners(immediate: true);
  }

  /// Perform the actual notification with protection.
  void _doSafeNotification() {
    if (_disposed || _isNotifying) return;

    _isNotifying = true;
    try {
      _notifyListeners();
      AppLogger.debug('🔔 UI notification sent');
    } catch (e) {
      AppLogger.debug('Notification skipped due to disposal: $e');
    } finally {
      _isNotifying = false;
    }
  }

  /// Update state and notify listeners in one call.
  void updateAndNotify(VoidCallback updateFunction, {bool immediate = false}) {
    safeUpdateState(updateFunction);
    safeNotifyListeners(immediate: immediate);
  }

  /// Dispose synchronizer and cancel pending operations.
  void dispose() {
    _disposed = true;

    // Cancel notification timer
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = null;

    // Clear pending state updates
    _pendingStateUpdates.clear();

    AppLogger.debug('🔄 ImageStateSynchronizer disposed');
  }
}
