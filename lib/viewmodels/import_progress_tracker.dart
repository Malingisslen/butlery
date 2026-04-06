/// Tracks import progress phases and elapsed time, notifying a parent ViewModel.
///
/// Extracted from SmartImportViewModel to keep it under 500 lines.
/// Manages the Stopwatch and a periodic Timer that drives UI elapsed updates.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/viewmodels/smart_import_viewmodel.dart';

/// Tracks elapsed time and phase transitions during recipe import.
class ImportProgressTracker {
  final VoidCallback _notifyListeners;
  final void Function(ImportPhase) _setPhase;
  final bool Function() _isDisposed;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _elapsedTimer;

  ImportProgressTracker({
    required VoidCallback notifyListeners,
    required void Function(ImportPhase) setPhase,
    required bool Function() isDisposed,
  })  : _notifyListeners = notifyListeners,
        _setPhase = setPhase,
        _isDisposed = isDisposed;

  /// Elapsed time since import started. Returns Duration.zero when not running.
  Duration get elapsed => _stopwatch.elapsed;

  /// Whether the tracker is currently running.
  bool get isRunning => _stopwatch.isRunning;

  /// Start tracking — resets stopwatch and begins 1-second periodic timer.
  void start() {
    _stopwatch
      ..reset()
      ..start();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed()) {
        stop();
        return;
      }
      _notifyListeners();
    });
  }

  /// Stop tracking — stops stopwatch and cancels periodic timer.
  void stop() {
    _stopwatch.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  /// Reset tracker to initial state.
  void reset() {
    stop();
    _stopwatch.reset();
  }

  /// Callback for ImportManager.autoImport's onProgress parameter.
  /// Maps plain string phases to ImportPhase enum values.
  void onProgress(String phase) {
    if (_isDisposed()) return;
    _setPhase(_mapStringToPhase(phase));
  }

  /// Cancel timer to prevent leaks. Call from ViewModel.dispose().
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _stopwatch.stop();
  }

  static ImportPhase _mapStringToPhase(String phase) {
    return switch (phase) {
      'fetching' => ImportPhase.fetching,
      'analyzing' => ImportPhase.analyzing,
      'creating' => ImportPhase.creating,
      _ => ImportPhase.analyzing,
    };
  }
}
