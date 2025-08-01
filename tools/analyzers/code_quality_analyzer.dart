// tools/analyzers/code_quality_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Code quality analyzer - 15% of overall health score
///
/// Analyzes:
/// - Cyclomatic complexity
/// - Code duplication (semantic and textual)
/// - Maintainability metrics
/// - Technical debt indicators
/// - Cognitive load assessment
/// - Method and class complexity
class CodeQualityAnalyzer {
  static const int _maxCyclomaticComplexity = 10;
  static const int _maxMethodLength = 30;
  static const int _maxClassLength = 200;
  static const double _duplicateThreshold = 0.8;

  static const List<String> _complexityIndicators = [
    r'if\s*\(',
    r'else\s*if\s*\(',
    r'for\s*\(',
    r'while\s*\(',
    r'switch\s*\(',
    r'case\s+',
    r'catch\s*\(',
    r'\?\s*:', // Ternary operator
    r'&&',
    r'\|\|',
  ];

  /// Analyze files for code quality issues
  static Future<List<CodeQualityAnalysisResult>> analyzeFiles(
      List<File> files) async {
    final results = <CodeQualityAnalysisResult>[];
    final allFileContents = <String, String>{};

    // Read all files first for duplication analysis
    for (final file in files) {
      allFileContents[file.path] = await file.readAsString();
    }

    for (final file in files) {
      final result = await _analyzeFile(file, allFileContents);
      if (result.violations.isNotEmpty || result.metrics.isNotEmpty) {
        results.add(result);
      }
    }

    return results;
  }

  /// Analyze single file for code quality
  static Future<CodeQualityAnalysisResult> _analyzeFile(
      File file, Map<String, String> allFiles) async {
    final content = allFiles[file.path]!;
    final filePath = file.path.replaceAll('\\', '/');
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};

    // Analyze cyclomatic complexity
    violations.addAll(await _analyzeCyclomaticComplexity(content, filePath));

    // Analyze method complexity
    violations.addAll(await _analyzeMethodComplexity(content, filePath));

    // Analyze class complexity
    violations.addAll(await _analyzeClassComplexity(content, filePath));

    // Analyze code duplication
    violations
        .addAll(await _analyzeCodeDuplication(content, filePath, allFiles));

    // Analyze maintainability issues
    violations.addAll(await _analyzeMaintainability(content, filePath));

    // Analyze technical debt
    violations.addAll(await _analyzeTechnicalDebt(content, filePath));

    // Calculate quality metrics
    metrics['cyclomatic_complexity'] = _calculateCyclomaticComplexity(content);
    metrics['method_count'] = _countMethods(content);
    metrics['class_count'] = _countClasses(content);
    metrics['line_count'] = content.split('\n').length;
    metrics['comment_ratio'] = _calculateCommentRatio(content);
    metrics['maintainability_index'] =
        _calculateMaintainabilityIndex(content, violations);
    metrics['technical_debt_ratio'] = _calculateTechnicalDebtRatio(violations);
    metrics['cognitive_complexity'] = _calculateCognitiveComplexity(content);
    metrics['quality_score'] = _calculateQualityScore(violations, content);

    return CodeQualityAnalysisResult(
      filePath: filePath,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Analyze cyclomatic complexity
  static Future<List<Violation>> _analyzeCyclomaticComplexity(
      String content, String filePath) async {
    final violations = <Violation>[];
    final methods = _extractMethods(content);

    for (final method in methods) {
      final complexity = _calculateMethodCyclomaticComplexity(method.content);
      if (complexity > _maxCyclomaticComplexity) {
        violations.add(Violation(
          severity: _getComplexitySeverity(complexity),
          message:
              'Method "${method.name}" has high cyclomatic complexity: $complexity',
          filePath: filePath,
          lineNumber: method.startLine,
          category: 'cyclomatic_complexity',
          suggestion: 'Break down method into smaller, focused methods',
        ));
      }
    }

    return violations;
  }

  /// Analyze method complexity
  static Future<List<Violation>> _analyzeMethodComplexity(
      String content, String filePath) async {
    final violations = <Violation>[];
    final methods = _extractMethods(content);

    for (final method in methods) {
      final lineCount = method.content.split('\n').length;

      if (lineCount > _maxMethodLength) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Method "${method.name}" is too long: $lineCount lines',
          filePath: filePath,
          lineNumber: method.startLine,
          category: 'method_complexity',
          suggestion: 'Split method into smaller, more focused methods',
        ));
      }

      // Check for too many parameters
      final paramCount = _countParameters(method.signature);
      if (paramCount > 5) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message:
              'Method "${method.name}" has too many parameters: $paramCount',
          filePath: filePath,
          lineNumber: method.startLine,
          category: 'method_complexity',
          suggestion: 'Consider using parameter objects or builder pattern',
        ));
      }

      // Check for deep nesting
      final maxNestingLevel = _calculateMaxNestingLevel(method.content);
      if (maxNestingLevel > 4) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message:
              'Method "${method.name}" has deep nesting: $maxNestingLevel levels',
          filePath: filePath,
          lineNumber: method.startLine,
          category: 'method_complexity',
          suggestion: 'Extract nested logic into separate methods',
        ));
      }
    }

    return violations;
  }

  /// Analyze class complexity
  static Future<List<Violation>> _analyzeClassComplexity(
      String content, String filePath) async {
    final violations = <Violation>[];
    final classes = _extractClasses(content);

    for (final classInfo in classes) {
      final lineCount = classInfo.content.split('\n').length;

      if (lineCount > _maxClassLength) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Class "${classInfo.name}" is too large: $lineCount lines',
          filePath: filePath,
          lineNumber: classInfo.startLine,
          category: 'class_complexity',
          suggestion: 'Apply Single Responsibility Principle and split class',
        ));
      }

      // Check for too many methods
      final methodCount = _countMethods(classInfo.content);
      if (methodCount > 20) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message:
              'Class "${classInfo.name}" has too many methods: $methodCount',
          filePath: filePath,
          lineNumber: classInfo.startLine,
          category: 'class_complexity',
          suggestion: 'Split class into smaller, more focused classes',
        ));
      }

      // Check for too many fields
      final fieldCount = _countFields(classInfo.content);
      if (fieldCount > 15) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Class "${classInfo.name}" has too many fields: $fieldCount',
          filePath: filePath,
          lineNumber: classInfo.startLine,
          category: 'class_complexity',
          suggestion:
              'Consider extracting related fields into separate classes',
        ));
      }
    }

    return violations;
  }

  /// Analyze code duplication
  static Future<List<Violation>> _analyzeCodeDuplication(
      String content, String filePath, Map<String, String> allFiles) async {
    final violations = <Violation>[];
    final methods = _extractMethods(content);

    // Check for duplication within file
    for (int i = 0; i < methods.length; i++) {
      for (int j = i + 1; j < methods.length; j++) {
        final similarity =
            _calculateSimilarity(methods[i].content, methods[j].content);
        if (similarity > _duplicateThreshold) {
          violations.add(Violation(
            severity: ViolationSeverity.medium,
            message:
                'Duplicate code detected between methods "${methods[i].name}" and "${methods[j].name}"',
            filePath: filePath,
            lineNumber: methods[i].startLine,
            category: 'code_duplication',
            suggestion: 'Extract common logic into a shared method',
          ));
        }
      }
    }

    // Check for duplication across files (simplified)
    final currentMethods = methods;
    for (final otherFilePath in allFiles.keys) {
      if (otherFilePath != filePath) {
        final otherMethods = _extractMethods(allFiles[otherFilePath]!);
        for (final currentMethod in currentMethods) {
          for (final otherMethod in otherMethods) {
            final similarity = _calculateSimilarity(
                currentMethod.content, otherMethod.content);
            if (similarity > _duplicateThreshold &&
                currentMethod.content.length > 100) {
              violations.add(Violation(
                severity: ViolationSeverity.high,
                message:
                    'Duplicate code detected with method in ${otherFilePath.split('/').last}',
                filePath: filePath,
                lineNumber: currentMethod.startLine,
                category: 'code_duplication',
                suggestion: 'Extract common logic into a shared utility class',
              ));
            }
          }
        }
      }
    }

    return violations;
  }

  /// Analyze maintainability issues
  static Future<List<Violation>> _analyzeMaintainability(
      String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for magic numbers
      if (_hasMagicNumbers(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Magic number detected',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'maintainability',
          suggestion: 'Extract magic numbers into named constants',
        ));
      }

      // Check for long lines
      if (line.length > 120) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Line too long: ${line.length} characters',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'maintainability',
          suggestion: 'Break long lines for better readability',
        ));
      }

      // Check for complex expressions
      if (_hasComplexExpression(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Complex expression detected',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'maintainability',
          suggestion: 'Break complex expressions into intermediate variables',
        ));
      }
    }

    return violations;
  }

  /// Analyze technical debt indicators
  static Future<List<Violation>> _analyzeTechnicalDebt(
      String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.contains('TODO') ||
          line.contains('FIXME') ||
          line.contains('HACK')) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Technical debt comment: ${line.trim()}',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'technical_debt',
          suggestion: 'Address technical debt comment',
        ));
      }

      // Check for commented out code
      if (_isCommentedOutCode(line)) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Commented out code detected',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'technical_debt',
          suggestion:
              'Remove commented out code or convert to proper documentation',
        ));
      }

      // Check for empty catch blocks
      if (line.contains('catch') &&
          i + 1 < lines.length &&
          lines[i + 1].trim() == '}') {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Empty catch block',
          filePath: filePath,
          lineNumber: i + 1,
          category: 'technical_debt',
          suggestion: 'Add proper error handling or at least log the error',
        ));
      }
    }

    return violations;
  }

  // Helper methods

  static List<MethodInfo> _extractMethods(String content) {
    final methods = <MethodInfo>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final methodMatch = RegExp(
              r'^\s*(?:@\w+\s+)*(?:static\s+)?(?:\w+\s+)*(\w+)\s*\([^)]*\)\s*(?:async\s*)?{')
          .firstMatch(line);

      if (methodMatch != null) {
        final methodName = methodMatch.group(1)!;
        final methodEnd = _findMethodEnd(lines, i);
        final methodContent = lines.sublist(i, methodEnd + 1).join('\n');

        methods.add(MethodInfo(
          name: methodName,
          signature: line,
          content: methodContent,
          startLine: i + 1,
        ));
      }
    }

    return methods;
  }

  static List<ClassInfo> _extractClasses(String content) {
    final classes = <ClassInfo>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final classMatch =
          RegExp(r'^\s*(?:abstract\s+)?class\s+(\w+)').firstMatch(line);

      if (classMatch != null) {
        final className = classMatch.group(1)!;
        final classEnd = _findClassEnd(lines, i);
        final classContent = lines.sublist(i, classEnd + 1).join('\n');

        classes.add(ClassInfo(
          name: className,
          content: classContent,
          startLine: i + 1,
        ));
      }
    }

    return classes;
  }

  static int _findMethodEnd(List<String> lines, int start) {
    int braceCount = 0;
    bool foundFirstBrace = false;

    for (int i = start; i < lines.length; i++) {
      for (final char in lines[i].split('')) {
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
    }

    return lines.length - 1;
  }

  static int _findClassEnd(List<String> lines, int start) {
    return _findMethodEnd(lines, start); // Same logic
  }

  static int _calculateCyclomaticComplexity(String content) {
    int complexity = 1; // Base complexity

    for (final pattern in _complexityIndicators) {
      complexity += RegExp(pattern).allMatches(content).length;
    }

    return complexity;
  }

  static int _calculateMethodCyclomaticComplexity(String methodContent) {
    return _calculateCyclomaticComplexity(methodContent);
  }

  static int _countMethods(String content) {
    return RegExp(
            r'^\s*(?:@\w+\s+)*(?:static\s+)?(?:\w+\s+)*\w+\s*\([^)]*\)\s*(?:async\s*)?{',
            multiLine: true)
        .allMatches(content)
        .length;
  }

  static int _countClasses(String content) {
    return RegExp(r'^\s*(?:abstract\s+)?class\s+\w+', multiLine: true)
        .allMatches(content)
        .length;
  }

  static int _countFields(String content) {
    return RegExp(r'^\s*(?:final|var|static)\s+\w+', multiLine: true)
        .allMatches(content)
        .length;
  }

  static int _countParameters(String signature) {
    final paramMatch = RegExp(r'\(([^)]*)\)').firstMatch(signature);
    if (paramMatch == null) return 0;

    final params = paramMatch.group(1)!.trim();
    if (params.isEmpty) return 0;

    return params.split(',').length;
  }

  static int _calculateMaxNestingLevel(String content) {
    final lines = content.split('\n');
    int maxLevel = 0;
    int currentLevel = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('{')) currentLevel++;
      if (trimmed.contains('}')) currentLevel--;
      if (currentLevel > maxLevel) maxLevel = currentLevel;
    }

    return maxLevel;
  }

  static double _calculateSimilarity(String content1, String content2) {
    // Simple similarity calculation based on common lines
    final lines1 = content1
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    final lines2 = content2
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();

    if (lines1.isEmpty && lines2.isEmpty) return 1.0;
    if (lines1.isEmpty || lines2.isEmpty) return 0.0;

    final commonLines = lines1.intersection(lines2).length;
    final totalLines = lines1.union(lines2).length;

    return commonLines / totalLines;
  }

  static double _calculateCommentRatio(String content) {
    final lines = content.split('\n');
    final commentLines =
        lines.where((line) => line.trim().startsWith('//')).length;
    return lines.isEmpty ? 0.0 : commentLines / lines.length;
  }

  static double _calculateMaintainabilityIndex(
      String content, List<Violation> violations) {
    final complexity = _calculateCyclomaticComplexity(content);
    final linesOfCode = content.split('\n').length;
    final commentRatio = _calculateCommentRatio(content);

    // Simplified maintainability index calculation
    double index =
        171.0 - 5.2 * complexity - 0.23 * linesOfCode + 16.2 * commentRatio;

    // Adjust for violations
    for (final violation in violations) {
      switch (violation.severity) {
        case ViolationSeverity.critical:
          index -= 20;
          break;
        case ViolationSeverity.high:
          index -= 15;
          break;
        case ViolationSeverity.medium:
          index -= 10;
          break;
        case ViolationSeverity.low:
          index -= 5;
          break;
      }
    }

    return Math.max(0.0, Math.min(100.0, index));
  }

  static double _calculateTechnicalDebtRatio(List<Violation> violations) {
    final debtViolations =
        violations.where((v) => v.category == 'technical_debt').length;
    return debtViolations / Math.max(1.0, violations.length.toDouble());
  }

  static int _calculateCognitiveComplexity(String content) {
    // Simplified cognitive complexity calculation
    int complexity = 0;

    complexity += RegExp(r'if\s*\(').allMatches(content).length;
    complexity += RegExp(r'for\s*\(').allMatches(content).length * 2;
    complexity += RegExp(r'while\s*\(').allMatches(content).length * 2;
    complexity += RegExp(r'switch\s*\(').allMatches(content).length * 2;
    complexity += RegExp(r'catch\s*\(').allMatches(content).length;

    return complexity;
  }

  static bool _hasMagicNumbers(String line) {
    // Skip common acceptable numbers
    final acceptableNumbers = ['0', '1', '2', '10', '100', '1000'];
    final numberMatches = RegExp(r'\b\d+\b').allMatches(line);

    for (final match in numberMatches) {
      final number = match.group(0)!;
      if (!acceptableNumbers.contains(number) && int.tryParse(number) != null) {
        return true;
      }
    }

    return false;
  }

  static bool _hasComplexExpression(String line) {
    // Check for nested ternary operators or complex boolean expressions
    return line.contains('?') && line.contains(':') && line.contains('?') ||
        RegExp(r'&&.*\|\||\|\|.*&&').hasMatch(line) ||
        line.split('(').length > 3;
  }

  static bool _isCommentedOutCode(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('//') &&
        (RegExp(r'//\s*[a-zA-Z_]\w*\s*\(').hasMatch(trimmed) ||
            RegExp(r'//\s*(?:if|for|while|switch)\s*\(').hasMatch(trimmed));
  }

  static ViolationSeverity _getComplexitySeverity(int complexity) {
    if (complexity > 20) return ViolationSeverity.critical;
    if (complexity > 15) return ViolationSeverity.high;
    if (complexity > 10) return ViolationSeverity.medium;
    return ViolationSeverity.low;
  }

  static double _calculateQualityScore(
      List<Violation> violations, String content) {
    if (violations.isEmpty) return 1.0;

    double score = 1.0;
    final lines = content.split('\n').length;

    for (final violation in violations) {
      switch (violation.severity) {
        case ViolationSeverity.critical:
          score -= 0.3;
          break;
        case ViolationSeverity.high:
          score -= 0.2;
          break;
        case ViolationSeverity.medium:
          score -= 0.1;
          break;
        case ViolationSeverity.low:
          score -= 0.05;
          break;
      }
    }

    // Bonus for good practices
    final commentRatio = _calculateCommentRatio(content);
    if (commentRatio > 0.1) score += 0.05; // Good commenting
    if (lines < 100) score += 0.05; // Concise files

    return Math.max(0.0, Math.min(1.0, score));
  }
}

class CodeQualityAnalysisResult extends AnalysisResult {
  CodeQualityAnalysisResult({
    required super.filePath,
    required super.violations,
    required super.metrics,
  });
}

class MethodInfo {
  final String name;
  final String signature;
  final String content;
  final int startLine;

  MethodInfo({
    required this.name,
    required this.signature,
    required this.content,
    required this.startLine,
  });
}

class ClassInfo {
  final String name;
  final String content;
  final int startLine;

  ClassInfo({
    required this.name,
    required this.content,
    required this.startLine,
  });
}

class Math {
  static double max(double a, double b) => a > b ? a : b;
  static double min(double a, double b) => a < b ? a : b;
}
