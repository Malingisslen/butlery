// tools/analyzers/flutter_intelligence_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Flutter-specific intelligence analyzer
///
/// Analyzes Flutter-specific patterns:
/// - State management patterns (Provider, Riverpod, Bloc)
/// - Widget lifecycle optimization
/// - Build method efficiency
/// - Hot reload compatibility
/// - Platform-specific code organization
/// - Flutter best practices
class FlutterIntelligenceAnalyzer {
  static const Map<String, List<String>> _stateManagementPatterns = {
    'provider': [
      r'Provider\.of<',
      r'context\.read<',
      r'context\.watch<',
      r'Consumer<',
      r'ChangeNotifierProvider',
    ],
    'riverpod': [
      r'ConsumerWidget',
      r'ref\.read\(',
      r'ref\.watch\(',
      r'StateProvider',
      r'FutureProvider',
    ],
    'bloc': [
      r'BlocBuilder',
      r'BlocListener',
      r'BlocConsumer',
      r'context\.read<.*Bloc>',
      r'BlocProvider',
    ],
    'setState': [
      r'setState\(',
      r'StatefulWidget',
    ],
  };


  /// Analyze files for Flutter-specific patterns
  static Future<List<FlutterIntelligenceResult>> analyzeFiles(List<File> files) async {
    final results = <FlutterIntelligenceResult>[];
    
    for (final file in files) {
      // Only analyze Flutter-relevant files
      if (_isFlutterRelevantFile(file.path)) {
        final result = await _analyzeFile(file);
        if (result.violations.isNotEmpty || result.metrics.isNotEmpty) {
          results.add(result);
        }
      }
    }
    
    return results;
  }

  /// Analyze single file for Flutter patterns
  static Future<FlutterIntelligenceResult> _analyzeFile(File file) async {
    final content = await file.readAsString();
    final filePath = file.path.replaceAll('\\', '/');
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};

    // Analyze state management patterns
    final stateManagementInfo = _analyzeStateManagement(content, filePath);
    violations.addAll(stateManagementInfo['violations'] as List<Violation>);
    metrics.addAll(stateManagementInfo['metrics'] as Map<String, dynamic>);

    // Analyze widget lifecycle
    violations.addAll(await _analyzeWidgetLifecycle(content, filePath));
    
    // Analyze build method optimization
    violations.addAll(await _analyzeBuildOptimization(content, filePath));
    
    // Analyze hot reload compatibility
    violations.addAll(await _analyzeHotReloadCompatibility(content, filePath));
    
    // Analyze platform-specific code
    violations.addAll(await _analyzePlatformSpecificCode(content, filePath));
    
    // Analyze Flutter best practices
    violations.addAll(await _analyzeFlutterBestPractices(content, filePath));

    // Calculate Flutter intelligence metrics
    metrics['widget_count'] = _countWidgets(content);
    metrics['state_management_pattern'] = _detectPrimaryStateManagementPattern(content);
    metrics['build_complexity'] = _calculateBuildComplexity(content);
    metrics['hot_reload_score'] = _calculateHotReloadScore(violations);
    metrics['flutter_score'] = _calculateFlutterScore(violations);

    return FlutterIntelligenceResult(
      filePath: filePath,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Analyze state management patterns
  static Map<String, dynamic> _analyzeStateManagement(String content, String filePath) {
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};
    final patternsFound = <String>[];

    _stateManagementPatterns.forEach((pattern, regexes) {
      for (final regex in regexes) {
        if (RegExp(regex).hasMatch(content)) {
          patternsFound.add(pattern);
          break;
        }
      }
    });

    metrics['state_management_patterns'] = patternsFound;

    // Check for mixed state management patterns
    if (patternsFound.length > 2) {
      violations.add(Violation(
        severity: ViolationSeverity.medium,
        message: 'Multiple state management patterns detected: ${patternsFound.join(', ')}',
        filePath: filePath,
        category: 'state_management',
        suggestion: 'Consider standardizing on a single state management approach',
      ));
    }

    // Check for setState with complex operations
    if (patternsFound.contains('setState')) {
      final setStateComplexity = _analyzeSetStateComplexity(content);
      if (setStateComplexity > 3) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Complex operations in setState - consider state management library',
          filePath: filePath,
          category: 'state_management',
          suggestion: 'Move complex state logic to Provider, Bloc, or Riverpod',
        ));
      }
    }

    return {
      'violations': violations,
      'metrics': metrics,
    };
  }

  /// Analyze widget lifecycle management
  static Future<List<Violation>> _analyzeWidgetLifecycle(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    bool hasDispose = false;
    bool hasControllers = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('dispose()')) hasDispose = true;
      if (RegExp(r'(?:Animation|Text|Scroll|Tab)Controller').hasMatch(line)) {
        hasControllers = true;
      }

      // Check for missing super calls in lifecycle methods
      if (line.contains('initState()')) {
        if (!_hasSuperCall(lines, i, 'super.initState()')) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'Missing super.initState() call',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'widget_lifecycle',
            suggestion: 'Add super.initState() as first line in initState()',
          ));
        }
      }

      if (line.contains('dispose()')) {
        if (!_hasSuperCall(lines, i, 'super.dispose()')) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'Missing super.dispose() call',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'widget_lifecycle',
            suggestion: 'Add super.dispose() as last line in dispose()',
          ));
        }
      }
    }

    // Check for controllers without dispose
    if (hasControllers && !hasDispose) {
      violations.add(Violation(
        severity: ViolationSeverity.high,
        message: 'Controllers found without dispose() method',
        filePath: filePath,
        category: 'widget_lifecycle',
        suggestion: 'Override dispose() method to clean up controllers',
      ));
    }

    return violations;
  }

  /// Analyze build method optimization
  static Future<List<Violation>> _analyzeBuildOptimization(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for expensive operations in build
      if (_isInBuildMethod(lines, i) && _hasExpensiveOperation(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.high,
          message: 'Expensive operation in build method: ${_getExpensiveOperation(line)}',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'build_optimization',
          suggestion: 'Move expensive operations to initState, didChangeDependencies, or use memoization',
        ));
      }

      // Check for anonymous functions in build
      if (line.contains('onPressed:') && line.contains('() {')) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Anonymous function in build method - causes unnecessary rebuilds',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'build_optimization',
          suggestion: 'Extract callback to a method or use a variable',
        ));
      }

      // Check for missing const constructors
      if (line.contains('return ') && !line.contains('const ') && 
          RegExp(r'return\s+[A-Z]\w*\(').hasMatch(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Widget could be const',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'build_optimization',
          suggestion: 'Add const constructor for better performance',
        ));
      }
    }

    return violations;
  }

  /// Analyze hot reload compatibility
  static Future<List<Violation>> _analyzeHotReloadCompatibility(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for static variables that break hot reload
      if (RegExp(r'static\s+(?!const\s).*=').hasMatch(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Non-const static variable breaks hot reload',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'hot_reload',
          suggestion: 'Make static variable const or move to instance variable',
        ));
      }

      // Check for global variables
      if (i < 50 && RegExp(r'^(?:final|var)\s+\w+\s*=').hasMatch(line.trim())) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Global variable may affect hot reload',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'hot_reload',
          suggestion: 'Consider encapsulating in a class or using const',
        ));
      }
    }

    return violations;
  }

  /// Analyze platform-specific code organization
  static Future<List<Violation>> _analyzePlatformSpecificCode(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    bool hasPlatformChecks = false;
    bool hasWebImports = false;
    bool hasIOImports = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.contains('Platform.is') || line.contains('kIsWeb')) {
        hasPlatformChecks = true;
      }

      if (line.contains("import 'dart:html'")) {
        hasWebImports = true;
      }

      if (line.contains("import 'dart:io'")) {
        hasIOImports = true;
      }

      // Check for inappropriate platform-specific code
      if (hasWebImports && hasIOImports) {
        violations.add(Violation(
          severity: ViolationSeverity.high,
          message: 'File imports both dart:html and dart:io - platform conflict',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'platform_specific',
          suggestion: 'Separate platform-specific code into different files',
        ));
        break;
      }
    }

    // Check for platform-specific code without proper organization
    if (hasPlatformChecks && !filePath.contains('platform') && !filePath.contains('web') && !filePath.contains('mobile')) {
      violations.add(Violation(
        severity: ViolationSeverity.medium,
        message: 'Platform-specific code not in dedicated platform files',
        filePath: filePath,
        category: 'platform_specific',
        suggestion: 'Move platform-specific code to dedicated platform directories',
      ));
    }

    return violations;
  }

  /// Analyze Flutter best practices
  static Future<List<Violation>> _analyzeFlutterBestPractices(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for empty Container
      if (line.contains('Container()') && !line.contains('child')) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Empty Container - use SizedBox instead',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'flutter_best_practices',
          suggestion: 'Replace Container() with SizedBox for spacing',
        ));
      }

      // Check for unnecessary Padding + Container
      if (line.contains('Padding(') && i + 1 < lines.length && 
          lines[i + 1].contains('child: Container(')) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Unnecessary Padding + Container nesting',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'flutter_best_practices',
          suggestion: 'Use Container with padding property instead',
        ));
      }

      // Check for FutureBuilder without error handling
      if (line.contains('FutureBuilder') && !content.contains('error')) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'FutureBuilder without error handling',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'flutter_best_practices',
          suggestion: 'Add error state handling to FutureBuilder',
        ));
      }
    }

    return violations;
  }

  // Helper methods

  static bool _isFlutterRelevantFile(String filePath) {
    return filePath.contains('lib/') && 
           (filePath.contains('views/') || 
            filePath.contains('widgets/') || 
            filePath.contains('pages/') ||
            filePath.contains('screens/') ||
            filePath.endsWith('_view.dart') ||
            filePath.endsWith('_widget.dart') ||
            filePath.endsWith('_page.dart'));
  }

  static int _analyzeSetStateComplexity(String content) {
    final setStateRegex = RegExp(r'setState\([^}]*\{([^}]*)\}', dotAll: true);
    final matches = setStateRegex.allMatches(content);
    
    int maxComplexity = 0;
    for (final match in matches) {
      final setStateBody = match.group(1) ?? '';
      int complexity = 0;
      
      if (setStateBody.contains('for (')) complexity += 2;
      if (setStateBody.contains('while (')) complexity += 2;
      if (setStateBody.contains('map(')) complexity += 1;
      if (setStateBody.contains('where(')) complexity += 1;
      if (setStateBody.contains('sort(')) complexity += 1;
      
      if (complexity > maxComplexity) maxComplexity = complexity;
    }
    
    return maxComplexity;
  }

  static bool _hasSuperCall(List<String> lines, int startIndex, String superCall) {
    for (int i = startIndex; i < lines.length && i < startIndex + 10; i++) {
      if (lines[i].contains(superCall)) return true;
      if (lines[i].contains('}')) break;
    }
    return false;
  }

  static bool _isInBuildMethod(List<String> lines, int currentIndex) {
    for (int i = currentIndex; i >= 0 && i > currentIndex - 20; i--) {
      if (lines[i].contains('build(BuildContext context)')) return true;
      if (lines[i].contains('class ') || lines[i].contains('Widget ')) break;
    }
    return false;
  }

  static bool _hasExpensiveOperation(String line) {
    return line.contains('DateTime.now()') ||
           line.contains('Random()') ||
           line.contains('http.') ||
           line.contains('jsonDecode') ||
           line.contains('jsonEncode') ||
           line.contains('.sort(') ||
           line.contains('File(') ||
           line.contains('Directory(');
  }

  static String _getExpensiveOperation(String line) {
    if (line.contains('DateTime.now()')) return 'DateTime.now()';
    if (line.contains('Random()')) return 'Random()';
    if (line.contains('http.')) return 'HTTP request';
    if (line.contains('jsonDecode')) return 'JSON decoding';
    if (line.contains('.sort(')) return 'List sorting';
    return 'Expensive operation';
  }

  static int _countWidgets(String content) {
    final widgetPatterns = [
      'Container', 'Column', 'Row', 'Stack', 'ListView', 'GridView',
      'Scaffold', 'AppBar', 'Text', 'Image', 'Icon', 'Button',
      'Card', 'Chip', 'Dialog', 'BottomSheet'
    ];
    
    int count = 0;
    for (final pattern in widgetPatterns) {
      count += RegExp(pattern + r'\(').allMatches(content).length;
    }
    return count;
  }

  static String _detectPrimaryStateManagementPattern(String content) {
    for (final entry in _stateManagementPatterns.entries) {
      for (final regex in entry.value) {
        if (RegExp(regex).hasMatch(content)) {
          return entry.key;
        }
      }
    }
    return 'none';
  }

  static int _calculateBuildComplexity(String content) {
    final buildRegex = RegExp(r'build\([^}]*\{([^}]*)\}', dotAll: true);
    final matches = buildRegex.allMatches(content);
    
    int maxComplexity = 0;
    for (final match in matches) {
      final buildBody = match.group(1) ?? '';
      final complexity = buildBody.split('\n').length;
      if (complexity > maxComplexity) maxComplexity = complexity;
    }
    
    return maxComplexity;
  }

  static double _calculateHotReloadScore(List<Violation> violations) {
    final hotReloadViolations = violations.where((v) => v.category == 'hot_reload').length;
    return hotReloadViolations == 0 ? 1.0 : Math.max(0.0, 1.0 - (hotReloadViolations * 0.2));
  }

  static double _calculateFlutterScore(List<Violation> violations) {
    if (violations.isEmpty) return 1.0;
    
    double score = 1.0;
    for (final violation in violations) {
      switch (violation.severity) {
        case ViolationSeverity.critical:
          score -= 0.2;
          break;
        case ViolationSeverity.high:
          score -= 0.15;
          break;
        case ViolationSeverity.medium:
          score -= 0.1;
          break;
        case ViolationSeverity.low:
          score -= 0.05;
          break;
      }
    }
    
    return score < 0.0 ? 0.0 : score;
  }
}

class FlutterIntelligenceResult extends AnalysisResult {
  FlutterIntelligenceResult({
    required super.filePath,
    required super.violations,
    required super.metrics,
  });
}

// Helper class
class Math {
  static double max(double a, double b) => a > b ? a : b;
}