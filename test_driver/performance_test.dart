import 'package:integration_test/integration_test_driver.dart';
import 'dart:io';
import 'dart:convert';

/// Performance test driver for measuring app performance metrics
/// This driver runs performance tests and collects timing data
Future<void> main() async {
  // Enable performance profiling
  
  // Run the integration tests with performance profiling
  await integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data != null) {
        // Process performance data
        final performanceData = _processPerformanceData(data);
        
        // Save performance report
        final reportFile = File('performance_report.json');
        await reportFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(performanceData),
        );
        
        // ignore: avoid_print
        print('Performance report saved to: ${reportFile.absolute.path}');
        
        // Check performance thresholds
        _checkPerformanceThresholds(performanceData);
      }
    },
  );
}

/// Process raw performance data into structured format
Map<String, dynamic> _processPerformanceData(Map<String, dynamic> data) {
  final processedData = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'metrics': <String, dynamic>{},
    'timeline': data['timeline'] ?? [],
  };
  
  // Extract frame timing data
  if (data.containsKey('frame_timings')) {
    final frameTimings = data['frame_timings'] as List<dynamic>;
    processedData['metrics']['frame_statistics'] = _calculateFrameStatistics(frameTimings);
  }
  
  // Extract memory usage
  if (data.containsKey('memory_usage')) {
    processedData['metrics']['memory'] = data['memory_usage'];
  }
  
  // Extract startup time
  if (data.containsKey('startup_time')) {
    processedData['metrics']['startup_time_ms'] = data['startup_time'];
  }
  
  // Extract custom metrics
  if (data.containsKey('custom_metrics')) {
    processedData['metrics']['custom'] = data['custom_metrics'];
  }
  
  return processedData;
}

/// Calculate frame statistics from timing data
Map<String, dynamic> _calculateFrameStatistics(List<dynamic> frameTimings) {
  if (frameTimings.isEmpty) {
    return {
      'average_frame_time_ms': 0,
      'percentile_90_ms': 0,
      'percentile_95_ms': 0,
      'percentile_99_ms': 0,
      'jank_frames': 0,
      'total_frames': 0,
    };
  }
  
  final timings = frameTimings.cast<double>()..sort();
  final totalFrames = timings.length;
  
  // Calculate average
  final average = timings.reduce((a, b) => a + b) / totalFrames;
  
  // Calculate percentiles
  final p90Index = (totalFrames * 0.9).floor();
  final p95Index = (totalFrames * 0.95).floor();
  final p99Index = (totalFrames * 0.99).floor();
  
  // Count jank frames (>16.67ms for 60fps)
  final jankFrames = timings.where((t) => t > 16.67).length;
  
  return {
    'average_frame_time_ms': average.toStringAsFixed(2),
    'percentile_90_ms': timings[p90Index].toStringAsFixed(2),
    'percentile_95_ms': timings[p95Index].toStringAsFixed(2),
    'percentile_99_ms': timings[p99Index].toStringAsFixed(2),
    'jank_frames': jankFrames,
    'jank_percentage': ((jankFrames / totalFrames) * 100).toStringAsFixed(2),
    'total_frames': totalFrames,
  };
}

/// Check if performance metrics meet required thresholds
void _checkPerformanceThresholds(Map<String, dynamic> performanceData) {
  final metrics = performanceData['metrics'] as Map<String, dynamic>;
  final failures = <String>[];
  
  // Check startup time (should be under 3 seconds)
  if (metrics['startup_time_ms'] != null) {
    final startupTime = metrics['startup_time_ms'] as int;
    if (startupTime > 3000) {
      failures.add('Startup time ${startupTime}ms exceeds 3000ms threshold');
    }
  }
  
  // Check frame statistics
  if (metrics['frame_statistics'] != null) {
    final frameStats = metrics['frame_statistics'] as Map<String, dynamic>;
    final jankPercentage = double.parse(frameStats['jank_percentage'].toString());
    
    if (jankPercentage > 5.0) {
      failures.add('Jank percentage $jankPercentage% exceeds 5% threshold');
    }
  }
  
  // Check memory usage (if available)
  if (metrics['memory'] != null) {
    final memory = metrics['memory'] as Map<String, dynamic>;
    final heapUsageMB = (memory['heap_usage'] ?? 0) / (1024 * 1024);
    
    if (heapUsageMB > 256) {
      failures.add('Heap usage ${heapUsageMB.toStringAsFixed(2)}MB exceeds 256MB threshold');
    }
  }
  
  // Report results
  if (failures.isEmpty) {
    // ignore: avoid_print
    print('✅ All performance thresholds passed!');
  } else {
    // ignore: avoid_print
    print('❌ Performance threshold failures:');
    for (final failure in failures) {
      // ignore: avoid_print
      print('   - $failure');
    }
    // Exit with error code for CI
    exit(1);
  }
}