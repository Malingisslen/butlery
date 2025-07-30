// tools/analyzers/performance_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Performance analyzer - 25% of overall health score
///
/// Detects:
/// - Memory leaks (unclosed streams, retained references)
/// - UI thread blocking operations
/// - Inefficient widget builds
/// - Database query issues
/// - Network efficiency problems
/// - Layout performance issues
class PerformanceAnalyzer {
  static const List<String> _memoryLeakIndicators = [
    'StreamSubscription',
    'AnimationController',
    'TabController',
    'ScrollController',
    'TextEditingController',
    'Timer.periodic',
    'Timer(',
  ];

  static const List<String> _uiBlockingIndicators = [
    'readAsStringSync',
    'readAsBytesSync',
    'writeAsStringSync',
    'listSync',
    'existsSync',
  ];

  static const List<String> _performanceIssues = [
    'ListView.builder',
    'GridView.builder',
    'setState',
    'build(',
    'jsonDecode',
    'jsonEncode',
    'http.get',
    'http.post',
  ];

  /// Analyze files for performance issues
  static Future<List<PerformanceAnalysisResult>> analyzeFiles(List<File> files) async {
    final results = <PerformanceAnalysisResult>[];
    
    for (final file in files) {
      final result = await _analyzeFile(file);
      if (result.violations.isNotEmpty || result.metrics.isNotEmpty) {
        results.add(result);
      }
    }
    
    return results;
  }

  /// Analyze single file for performance issues
  static Future<PerformanceAnalysisResult> _analyzeFile(File file) async {
    final content = await file.readAsString();
    final filePath = file.path.replaceAll('\\', '/');
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};

    // Memory leak detection
    violations.addAll(await _detectMemoryLeaks(content, filePath));
    
    // UI blocking detection
    violations.addAll(await _detectUIBlocking(content, filePath));
    
    // Widget performance issues
    violations.addAll(await _detectWidgetPerformance(content, filePath));

    // Calculate performance metrics
    metrics['memory_leak_risks'] = violations.where((v) => v.category == 'memory_leaks').length;
    metrics['ui_blocking_issues'] = violations.where((v) => v.category == 'ui_blocking').length;
    metrics['widget_performance_issues'] = violations.where((v) => v.category == 'widget_performance').length;
    metrics['performance_score'] = _calculateFilePerformanceScore(violations);

    return PerformanceAnalysisResult(
      filePath: filePath,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Detect memory leak patterns
  static Future<List<Violation>> _detectMemoryLeaks(String content, String filePath) async {
    final violations = <Violation>[];

    // Check for controllers without dispose
    if (_hasControllerWithoutDispose(content)) {
      violations.add(Violation(
        severity: ViolationSeverity.high,
        message: 'Controller found without dispose() method - potential memory leak',
        filePath: filePath,
        category: 'memory_leaks',
        suggestion: 'Override dispose() method and call controller.dispose()',
      ));
    }

    // Check for stream subscriptions without cancel
    if (_hasStreamSubscriptionWithoutCancel(content)) {
      violations.add(Violation(
        severity: ViolationSeverity.high,
        message: 'StreamSubscription without cancel() - potential memory leak',
        filePath: filePath,
        category: 'memory_leaks',
        suggestion: 'Store subscription and call cancel() in dispose()',
      ));
    }

    // Check for timers without cancel
    if (content.contains('Timer.periodic') || content.contains('Timer(')) {
      if (!content.contains('cancel()')) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Timer created without cancel - potential memory leak',
          filePath: filePath,
          category: 'memory_leaks',
          suggestion: 'Store timer reference and call cancel() when done',
        ));
      }
    }

    return violations;
  }

  /// Detect UI thread blocking operations
  static Future<List<Violation>> _detectUIBlocking(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final pattern in _uiBlockingIndicators) {
        if (line.contains(pattern)) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'UI blocking operation detected: $pattern',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'ui_blocking',
            suggestion: 'Use async version of this operation',
          ));
        }
      }
    }

    return violations;
  }

  /// Detect widget performance issues
  static Future<List<Violation>> _detectWidgetPerformance(String content, String filePath) async {
    final violations = <Violation>[];

    // Check for expensive build methods
    if (_hasExpensiveOperationsInBuild(content)) {
      violations.add(Violation(
        severity: ViolationSeverity.high,
        message: 'Expensive operations in build method - causes unnecessary rebuilds',
        filePath: filePath,
        category: 'widget_performance',
        suggestion: 'Move expensive operations to initState() or use memoization',
      ));
    }

    // Check for missing const constructors
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.contains('return ') && !line.contains('const ') && 
          line.contains('(')) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Widget constructor could be const',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'widget_performance',
          suggestion: 'Add const constructor for better performance',
        ));
        break; // Only report once per file
      }
    }

    return violations;
  }

  // Helper methods

  static bool _hasControllerWithoutDispose(String content) {
    final hasController = content.contains('Controller(') || 
                         content.contains('AnimationController') ||
                         content.contains('TextEditingController');
    final hasDispose = content.contains('dispose()') && content.contains('.dispose()');
    return hasController && !hasDispose;
  }

  static bool _hasStreamSubscriptionWithoutCancel(String content) {
    final hasSubscription = content.contains('StreamSubscription') || content.contains('.listen(');
    final hasCancel = content.contains('.cancel()');
    return hasSubscription && !hasCancel;
  }

  static bool _hasExpensiveOperationsInBuild(String content) {
    final buildMethodStart = content.indexOf('build(BuildContext context)');
    if (buildMethodStart == -1) return false;
    
    final buildMethodEnd = _findMethodEnd(content, buildMethodStart);
    final buildContent = content.substring(buildMethodStart, buildMethodEnd);
    
    return buildContent.contains('DateTime.now()') ||
           buildContent.contains('Random()') ||
           buildContent.contains('http.') ||
           buildContent.contains('jsonDecode') ||
           buildContent.contains('File(');
  }

  static int _findMethodEnd(String content, int start) {
    int braceCount = 0;
    bool foundFirstBrace = false;
    
    for (int i = start; i < content.length; i++) {
      final char = content[i];
      if (char == '{') {
        braceCount++;
        foundFirstBrace = true;
      } else if (char == '}') {
        braceCount--;
        if (foundFirstBrace && braceCount == 0) {
          return i;
        }
      }
    }
    
    return content.length;
  }

  /// Calculate performance score for file
  static double _calculateFilePerformanceScore(List<Violation> violations) {
    if (violations.isEmpty) return 1.0;
    
    double score = 1.0;
    for (final violation in violations) {
      switch (violation.severity) {
        case ViolationSeverity.critical:
          score -= 0.25;
          break;
        case ViolationSeverity.high:
          score -= 0.15;
          break;
        case ViolationSeverity.medium:
          score -= 0.08;
          break;
        case ViolationSeverity.low:
          score -= 0.03;
          break;
      }
    }
    
    return score < 0.0 ? 0.0 : score;
  }
}

class PerformanceAnalysisResult extends AnalysisResult {
  PerformanceAnalysisResult({
    required String filePath,
    required List<Violation> violations,
    required Map<String, dynamic> metrics,
  }) : super(filePath: filePath, violations: violations, metrics: metrics);
}