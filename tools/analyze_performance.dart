import 'dart:io';
import 'dart:convert';

/// Performance Analysis Tool for Butlery App
/// 
/// This tool analyzes performance test results and generates detailed reports
/// Usage: dart tools/analyze_performance.dart [options]
/// 
/// Options:
///   --input [file]    Path to performance report JSON file (default: performance_report.json)
///   --output [file]   Path to output analysis file (default: performance_analysis.md)
///   --baseline [file] Path to baseline performance data for comparison
///   --format [type]   Output format: markdown, json, html (default: markdown)
///   --threshold       Exit with error if thresholds are exceeded
///   
/// Example:
///   dart tools/analyze_performance.dart --input perf.json --baseline baseline.json --threshold

void main(List<String> args) async {
  final config = _parseArguments(args);
  
  try {
    // Load performance data
    final performanceData = await _loadPerformanceData(config['input']);
    
    // Load baseline data if provided
    Map<String, dynamic>? baselineData;
    if (config['baseline'] != null) {
      baselineData = await _loadPerformanceData(config['baseline']);
    }
    
    // Analyze performance
    final analysis = _analyzePerformance(performanceData, baselineData);
    
    // Generate report
    final report = _generateReport(analysis, config['format']);
    
    // Save report
    await _saveReport(report, config['output'], config['format']);
    
    // Check thresholds if requested
    if (config['threshold'] == true) {
      _checkThresholds(analysis);
    }
    
    // ignore: avoid_print
    print('✅ Performance analysis completed successfully!');
    // ignore: avoid_print
    print('📊 Report saved to: ${config['output']}');
    
  } catch (e) {
    // ignore: avoid_print
    print('❌ Error analyzing performance: $e');
    exit(1);
  }
}

/// Parse command line arguments
Map<String, dynamic> _parseArguments(List<String> args) {
  final config = <String, dynamic>{
    'input': 'performance_report.json',
    'output': 'performance_analysis.md',
    'format': 'markdown',
    'threshold': false,
  };
  
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--input':
        if (i + 1 < args.length) {
          config['input'] = args[++i];
        }
        break;
      case '--output':
        if (i + 1 < args.length) {
          config['output'] = args[++i];
        }
        break;
      case '--baseline':
        if (i + 1 < args.length) {
          config['baseline'] = args[++i];
        }
        break;
      case '--format':
        if (i + 1 < args.length) {
          final format = args[++i];
          if (['markdown', 'json', 'html'].contains(format)) {
            config['format'] = format;
          }
        }
        break;
      case '--threshold':
        config['threshold'] = true;
        break;
      case '--help':
      case '-h':
        _printHelp();
        exit(0);
    }
  }
  
  return config;
}

/// Print help message
void _printHelp() {
  // ignore: avoid_print
  print('''
Performance Analysis Tool for Butlery App

Usage: dart tools/analyze_performance.dart [options]

Options:
  --input <file>    Path to performance report JSON file (default: performance_report.json)
  --output <file>   Path to output analysis file (default: performance_analysis.md)
  --baseline <file> Path to baseline performance data for comparison
  --format <type>   Output format: markdown, json, html (default: markdown)
  --threshold       Exit with error if thresholds are exceeded
  --help, -h        Show this help message

Example:
  dart tools/analyze_performance.dart --input perf.json --baseline baseline.json --threshold
''');
}

/// Load performance data from JSON file
Future<Map<String, dynamic>> _loadPerformanceData(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Performance data file not found: $filePath');
  }
  
  final content = await file.readAsString();
  return json.decode(content) as Map<String, dynamic>;
}

/// Analyze performance data
Map<String, dynamic> _analyzePerformance(
  Map<String, dynamic> current,
  Map<String, dynamic>? baseline,
) {
  final analysis = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'current': current,
    'summary': <String, dynamic>{},
    'recommendations': <String>[],
    'comparisons': <String, dynamic>{},
  };
  
  final metrics = current['metrics'] as Map<String, dynamic>? ?? {};
  
  // Analyze startup time
  if (metrics['startup_time_ms'] != null) {
    final startupTime = metrics['startup_time_ms'] as int;
    analysis['summary']['startup'] = {
      'value': startupTime,
      'status': startupTime < 2000 ? '✅ Excellent' : 
                startupTime < 3000 ? '⚠️ Good' : '❌ Poor',
    };
    
    if (startupTime > 3000) {
      analysis['recommendations'].add(
        'Startup time is ${startupTime}ms. Consider lazy loading and code splitting.'
      );
    }
  }
  
  // Analyze frame performance
  if (metrics['frame_statistics'] != null) {
    final frameStats = metrics['frame_statistics'] as Map<String, dynamic>;
    final jankPercentage = double.parse(frameStats['jank_percentage'].toString());
    
    analysis['summary']['frame_performance'] = {
      'jank_percentage': jankPercentage,
      'average_frame_time': frameStats['average_frame_time_ms'],
      'status': jankPercentage < 2 ? '✅ Excellent' : 
                jankPercentage < 5 ? '⚠️ Good' : '❌ Poor',
    };
    
    if (jankPercentage > 5) {
      analysis['recommendations'].add(
        'High jank rate ($jankPercentage%). Profile with Flutter DevTools to identify performance bottlenecks.'
      );
    }
  }
  
  // Analyze memory usage
  if (metrics['memory'] != null) {
    final memory = metrics['memory'] as Map<String, dynamic>;
    final heapUsageMB = (memory['heap_usage'] ?? 0) / (1024 * 1024);
    
    analysis['summary']['memory'] = {
      'heap_usage_mb': heapUsageMB.toStringAsFixed(2),
      'status': heapUsageMB < 128 ? '✅ Excellent' : 
                heapUsageMB < 256 ? '⚠️ Good' : '❌ Poor',
    };
    
    if (heapUsageMB > 256) {
      analysis['recommendations'].add(
        'High memory usage (${heapUsageMB.toStringAsFixed(2)}MB). Check for memory leaks and optimize image caching.'
      );
    }
  }
  
  // Compare with baseline
  if (baseline != null) {
    analysis['comparisons'] = _compareWithBaseline(metrics, baseline['metrics'] as Map<String, dynamic>);
  }
  
  return analysis;
}

/// Compare current metrics with baseline
Map<String, dynamic> _compareWithBaseline(
  Map<String, dynamic> current,
  Map<String, dynamic> baseline,
) {
  final comparisons = <String, dynamic>{};
  
  // Compare startup time
  if (current['startup_time_ms'] != null && baseline['startup_time_ms'] != null) {
    final currentStartup = current['startup_time_ms'] as int;
    final baselineStartup = baseline['startup_time_ms'] as int;
    final diff = currentStartup - baselineStartup;
    final percentChange = ((diff / baselineStartup) * 100).toStringAsFixed(1);
    
    comparisons['startup_time'] = {
      'current': currentStartup,
      'baseline': baselineStartup,
      'difference': diff,
      'percent_change': percentChange,
      'improved': diff < 0,
    };
  }
  
  // Compare frame performance
  if (current['frame_statistics'] != null && baseline['frame_statistics'] != null) {
    final currentStats = current['frame_statistics'] as Map<String, dynamic>;
    final baselineStats = baseline['frame_statistics'] as Map<String, dynamic>;
    
    final currentJank = double.parse(currentStats['jank_percentage'].toString());
    final baselineJank = double.parse(baselineStats['jank_percentage'].toString());
    final jankDiff = currentJank - baselineJank;
    
    comparisons['frame_performance'] = {
      'current_jank': currentJank,
      'baseline_jank': baselineJank,
      'difference': jankDiff.toStringAsFixed(2),
      'improved': jankDiff < 0,
    };
  }
  
  return comparisons;
}

/// Generate report in specified format
String _generateReport(Map<String, dynamic> analysis, String format) {
  switch (format) {
    case 'json':
      return const JsonEncoder.withIndent('  ').convert(analysis);
    case 'html':
      return _generateHtmlReport(analysis);
    case 'markdown':
    default:
      return _generateMarkdownReport(analysis);
  }
}

/// Generate markdown report
String _generateMarkdownReport(Map<String, dynamic> analysis) {
  final buffer = StringBuffer();
  final summary = analysis['summary'] as Map<String, dynamic>;
  final recommendations = (analysis['recommendations'] as List).cast<String>();
  final comparisons = analysis['comparisons'] as Map<String, dynamic>;
  
  buffer.writeln('# Butlery App Performance Analysis Report');
  buffer.writeln();
  buffer.writeln('Generated: ${analysis['timestamp']}');
  buffer.writeln();
  
  // Summary section
  buffer.writeln('## Performance Summary');
  buffer.writeln();
  
  if (summary['startup'] != null) {
    final startup = summary['startup'] as Map<String, dynamic>;
    buffer.writeln('### 🚀 Startup Performance');
    buffer.writeln('- Time: **${startup['value']}ms**');
    buffer.writeln('- Status: ${startup['status']}');
    buffer.writeln();
  }
  
  if (summary['frame_performance'] != null) {
    final frames = summary['frame_performance'] as Map<String, dynamic>;
    buffer.writeln('### 🎯 Frame Performance');
    buffer.writeln('- Jank Rate: **${frames['jank_percentage']}%**');
    buffer.writeln('- Average Frame Time: **${frames['average_frame_time']}ms**');
    buffer.writeln('- Status: ${frames['status']}');
    buffer.writeln();
  }
  
  if (summary['memory'] != null) {
    final memory = summary['memory'] as Map<String, dynamic>;
    buffer.writeln('### 💾 Memory Usage');
    buffer.writeln('- Heap Usage: **${memory['heap_usage_mb']}MB**');
    buffer.writeln('- Status: ${memory['status']}');
    buffer.writeln();
  }
  
  // Baseline comparison
  if (comparisons.isNotEmpty) {
    buffer.writeln('## 📊 Baseline Comparison');
    buffer.writeln();
    
    if (comparisons['startup_time'] != null) {
      final startup = comparisons['startup_time'] as Map<String, dynamic>;
      final icon = startup['improved'] ? '✅' : '❌';
      buffer.writeln('### Startup Time');
      buffer.writeln('- Current: ${startup['current']}ms');
      buffer.writeln('- Baseline: ${startup['baseline']}ms');
      buffer.writeln('- Change: ${startup['difference']}ms (${startup['percent_change']}%) $icon');
      buffer.writeln();
    }
    
    if (comparisons['frame_performance'] != null) {
      final frames = comparisons['frame_performance'] as Map<String, dynamic>;
      final icon = frames['improved'] ? '✅' : '❌';
      buffer.writeln('### Frame Performance');
      buffer.writeln('- Current Jank: ${frames['current_jank']}%');
      buffer.writeln('- Baseline Jank: ${frames['baseline_jank']}%');
      buffer.writeln('- Change: ${frames['difference']}% $icon');
      buffer.writeln();
    }
  }
  
  // Recommendations
  if (recommendations.isNotEmpty) {
    buffer.writeln('## 🔧 Recommendations');
    buffer.writeln();
    for (final recommendation in recommendations) {
      buffer.writeln('- $recommendation');
    }
    buffer.writeln();
  }
  
  // Performance thresholds
  buffer.writeln('## 📏 Performance Thresholds');
  buffer.writeln();
  buffer.writeln('| Metric | Excellent | Good | Poor |');
  buffer.writeln('|--------|-----------|------|------|');
  buffer.writeln('| Startup Time | < 2s | < 3s | ≥ 3s |');
  buffer.writeln('| Jank Rate | < 2% | < 5% | ≥ 5% |');
  buffer.writeln('| Memory Usage | < 128MB | < 256MB | ≥ 256MB |');
  
  return buffer.toString();
}

/// Generate HTML report
String _generateHtmlReport(Map<String, dynamic> analysis) {
  // Simplified HTML report - in production, use a proper template engine
  return '''
<!DOCTYPE html>
<html>
<head>
  <title>Butlery Performance Analysis</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1, h2, h3 { color: #333; }
    .metric { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 8px; }
    .excellent { border-left: 4px solid #4CAF50; }
    .good { border-left: 4px solid #FF9800; }
    .poor { border-left: 4px solid #F44336; }
    table { border-collapse: collapse; width: 100%; margin: 20px 0; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Butlery App Performance Analysis Report</h1>
  <p>Generated: ${analysis['timestamp']}</p>
  ${_generateHtmlContent(analysis)}
</body>
</html>
''';
}

/// Generate HTML content
String _generateHtmlContent(Map<String, dynamic> analysis) {
  // Convert the markdown content to HTML
  final markdownContent = _generateMarkdownReport(analysis);
  // In production, use a proper markdown to HTML converter
  return markdownContent
      .replaceAll('# ', '<h1>')
      .replaceAll('## ', '<h2>')
      .replaceAll('### ', '<h3>')
      .replaceAll('**', '<strong>')
      .replaceAll('- ', '<li>')
      .replaceAll('\n\n', '</p><p>')
      .replaceAll('\n', '<br>');
}

/// Save report to file
Future<void> _saveReport(String report, String outputPath, String format) async {
  final file = File(outputPath);
  await file.writeAsString(report);
}

/// Check performance thresholds
void _checkThresholds(Map<String, dynamic> analysis) {
  final summary = analysis['summary'] as Map<String, dynamic>;
  final failures = <String>[];
  
  // Check startup time
  if (summary['startup'] != null) {
    final startup = summary['startup'] as Map<String, dynamic>;
    if (startup['value'] > 3000) {
      failures.add('Startup time exceeds 3s threshold');
    }
  }
  
  // Check frame performance
  if (summary['frame_performance'] != null) {
    final frames = summary['frame_performance'] as Map<String, dynamic>;
    if (frames['jank_percentage'] > 5.0) {
      failures.add('Jank rate exceeds 5% threshold');
    }
  }
  
  // Check memory usage
  if (summary['memory'] != null) {
    final memory = summary['memory'] as Map<String, dynamic>;
    final heapUsage = double.parse(memory['heap_usage_mb'].toString());
    if (heapUsage > 256) {
      failures.add('Memory usage exceeds 256MB threshold');
    }
  }
  
  if (failures.isNotEmpty) {
    // ignore: avoid_print
    print('\n❌ Performance threshold violations:');
    for (final failure in failures) {
      // ignore: avoid_print
      print('   - $failure');
    }
    exit(1);
  }
}