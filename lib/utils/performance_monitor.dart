/// Performance monitoring utilities for tracking optimization improvements.
/// 
/// This utility provides development-time performance tracking to measure
/// the impact of our ULTRATHINK performance optimizations on widget rebuilds,
/// scroll performance, and memory usage.

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Performance monitoring utility for tracking optimization impact.
class PerformanceMonitor {
  static final Map<String, DateTime> _timers = {};
  static final Map<String, int> _counters = {};
  static final Map<String, List<double>> _measurements = {};

  /// Start a performance timer for measuring operation duration.
  static void startTimer(String name) {
    if (kDebugMode) {
      _timers[name] = DateTime.now();
    }
  }

  /// End a performance timer and log the result.
  static void endTimer(String name) {
    if (kDebugMode && _timers.containsKey(name)) {
      final duration = DateTime.now().difference(_timers[name]!);
      developer.log('⚡ Performance: $name took ${duration.inMilliseconds}ms');
      _timers.remove(name);
    }
  }

  /// Track rebuild frequency for ViewModels.
  static void trackRebuild(String viewModelName) {
    if (kDebugMode) {
      _counters[viewModelName] = (_counters[viewModelName] ?? 0) + 1;
      if (_counters[viewModelName]! % 10 == 0) {
        developer.log('🔄 Rebuild count for $viewModelName: ${_counters[viewModelName]}');
      }
    }
  }

  /// Track scroll performance metrics.
  static void trackScrollFrame(double frameTime) {
    if (kDebugMode) {
      _measurements.putIfAbsent('scroll_frames', () => []).add(frameTime);
      final frames = _measurements['scroll_frames']!;
      
      if (frames.length >= 60) { // Track every 60 frames
        final avgFrameTime = frames.reduce((a, b) => a + b) / frames.length;
        final fps = 1000 / avgFrameTime;
        developer.log('📱 Scroll performance: ${fps.toStringAsFixed(1)} FPS (avg: ${avgFrameTime.toStringAsFixed(2)}ms)');
        frames.clear();
      }
    }
  }

  /// Get rebuild statistics for analysis.
  static Map<String, int> getRebuildStats() {
    return Map.from(_counters);
  }

  /// Reset all performance counters.
  static void reset() {
    if (kDebugMode) {
      _timers.clear();
      _counters.clear();
      _measurements.clear();
      developer.log('🧹 Performance monitoring reset');
    }
  }

  /// Log overall performance summary.
  static void logSummary() {
    if (kDebugMode) {
      developer.log('📊 PERFORMANCE SUMMARY:');
      developer.log('   Widget rebuilds tracked: ${_counters.length} ViewModels');
      developer.log('   Active timers: ${_timers.length}');
      developer.log('   Measurements collected: ${_measurements.length} types');
      
      for (final entry in _counters.entries) {
        developer.log('   ${entry.key}: ${entry.value} rebuilds');
      }
    }
  }
}

/// Mixin for ViewModels to track performance automatically.
mixin PerformanceTrackingMixin on ChangeNotifier {
  String get performanceId;

  @override
  void notifyListeners() {
    PerformanceMonitor.trackRebuild(performanceId);
    super.notifyListeners();
  }
}