// tools/analyzers/architecture_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Enhanced architecture analyzer - 20% of overall health score
///
/// Improved version of existing validator with:
/// - Stricter MVVM enforcement
/// - Better repository pattern detection  
/// - Realistic violation scoring
/// - Service layer validation
/// - Dependency injection analysis
class ArchitectureAnalyzer {
  static const Map<String, List<String>> _layerPatterns = {
    'views': [r'lib/views/', r'lib/pages/', r'lib/screens/'],
    'viewmodels': [r'lib/viewmodels/', r'lib/view_models/'],
    'services': [r'lib/services/'],
    'repositories': [r'lib/repositories/'],
    'models': [r'lib/models/', r'lib/data/models/'],
    'core': [r'lib/core/'],
    'widgets': [r'lib/widgets/'],
  };

  static const List<String> _firebaseImportPatterns = [
    "import 'package:cloud_firestore/cloud_firestore.dart'",
    'import "package:cloud_firestore/cloud_firestore.dart"',
    "import 'package:firebase_auth/firebase_auth.dart'",
    'import "package:firebase_auth/firebase_auth.dart"',
    "import 'package:firebase_storage/firebase_storage.dart'",
    'import "package:firebase_storage/firebase_storage.dart"',
  ];

  static const List<String> _repositoryPatterns = [
    r'FirebaseFirestore\.instance',
    r'FirebaseAuth\.instance',
    r'FirebaseStorage\.instance',
    r'\.collection\(',
    r'\.doc\(',
    r'\.get\(\)',
    r'\.add\(',
    r'\.update\(',
    r'\.delete\(',
  ];

  static const List<String> _serviceLayerViolations = [
    r'context\.read<.*Repository>',
    r'context\.watch<.*Repository>',
    r'Provider\.of<.*Repository>',
    r'GetIt.*get<.*Repository>',
  ];

  /// Analyze files for architectural violations
  static Future<List<ArchitectureAnalysisResult>> analyzeFiles(List<File> files) async {
    final results = <ArchitectureAnalysisResult>[];
    
    for (final file in files) {
      final result = await _analyzeFile(file);
      if (result.violations.isNotEmpty || result.metrics.isNotEmpty) {
        results.add(result);
      }
    }
    
    return results;
  }

  /// Analyze single file for architectural violations
  static Future<ArchitectureAnalysisResult> _analyzeFile(File file) async {
    final content = await file.readAsString();
    final filePath = file.path.replaceAll('\\', '/');
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};

    final layer = _determineArchitecturalLayer(filePath);
    
    // Check Firebase usage patterns
    violations.addAll(await _analyzeFirebaseUsage(content, filePath, layer));
    
    // Check MVVM pattern compliance
    violations.addAll(await _analyzeMVVMCompliance(content, filePath, layer));
    
    // Check repository pattern usage
    violations.addAll(await _analyzeRepositoryPattern(content, filePath, layer));
    
    // Check service layer architecture
    violations.addAll(await _analyzeServiceLayer(content, filePath, layer));
    
    // Check dependency injection patterns
    violations.addAll(await _analyzeDependencyInjection(content, filePath));
    
    // Check file size compliance (500 line limit)
    violations.addAll(await _analyzeFileSize(content, filePath));

    // Calculate architecture metrics
    metrics['architectural_layer'] = layer;
    metrics['file_size'] = content.split('\n').length;
    metrics['firebase_imports'] = _countFirebaseImports(content);
    metrics['repository_operations'] = _countRepositoryOperations(content);
    metrics['architecture_score'] = _calculateArchitectureScore(violations, layer);

    return ArchitectureAnalysisResult(
      filePath: filePath,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Analyze Firebase usage patterns
  static Future<List<Violation>> _analyzeFirebaseUsage(String content, String filePath, String layer) async {
    final violations = <Violation>[];
    
    // Check for direct Firebase imports in wrong layers
    for (final pattern in _firebaseImportPatterns) {
      if (content.contains(pattern)) {
        final severity = _getFirebaseImportSeverity(layer);
        if (severity != null) {
          violations.add(Violation(
            severity: severity,
            message: 'Direct Firebase import in $layer layer',
            filePath: filePath,
            category: 'firebase_architecture',
            suggestion: _getFirebaseImportSuggestion(layer),
          ));
        }
      }
    }

    // Check for direct Firebase operations
    for (final pattern in _repositoryPatterns) {
      final regex = RegExp(pattern);
      if (regex.hasMatch(content)) {
        final severity = _getFirebaseOperationSeverity(layer);
        if (severity != null) {
          violations.add(Violation(
            severity: severity,
            message: 'Direct Firebase operation in $layer layer: $pattern',
            filePath: filePath,
            category: 'firebase_architecture',
            suggestion: 'Use repository pattern to abstract Firebase operations',
          ));
        }
      }
    }

    return violations;
  }

  /// Analyze MVVM pattern compliance
  static Future<List<Violation>> _analyzeMVVMCompliance(String content, String filePath, String layer) async {
    final violations = <Violation>[];

    switch (layer) {
      case 'views':
        // Views should not contain business logic
        if (_hasBusinessLogic(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'Business logic found in view layer',
            filePath: filePath,
            category: 'mvvm_violation',
            suggestion: 'Move business logic to ViewModel',
          ));
        }

        // Views should not directly access repositories
        if (_hasDirectRepositoryAccess(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.critical,
            message: 'View directly accessing repository',
            filePath: filePath,
            category: 'mvvm_violation',
            suggestion: 'Access repositories through ViewModel',
          ));
        }
        break;

      case 'viewmodels':
        // ViewModels should not import Flutter UI packages
        if (_hasUIImports(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.medium,
            message: 'ViewModel importing UI packages',
            filePath: filePath,
            category: 'mvvm_violation',
            suggestion: 'Keep ViewModels UI-independent',
          ));
        }

        // ViewModels should not directly access Firebase
        if (_hasDirectFirebaseAccess(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'ViewModel directly accessing Firebase',
            filePath: filePath,
            category: 'mvvm_violation',
            suggestion: 'Use repository pattern for data access',
          ));
        }
        break;

      case 'services':
        // Services should not access UI context
        if (_hasUIContextAccess(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'Service accessing UI context',
            filePath: filePath,
            category: 'mvvm_violation',
            suggestion: 'Services should be UI-independent',
          ));
        }
        break;
    }

    return violations;
  }

  /// Analyze repository pattern usage
  static Future<List<Violation>> _analyzeRepositoryPattern(String content, String filePath, String layer) async {
    final violations = <Violation>[];

    if (layer == 'repositories') {
      // Repositories should implement interfaces
      if (!_implementsInterface(content)) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Repository does not implement interface',
          filePath: filePath,
          category: 'repository_pattern',
          suggestion: 'Create and implement repository interface for testability',
        ));
      }

      // Repositories should handle errors properly
      if (!_hasProperErrorHandling(content)) {
        violations.add(Violation(
          severity: ViolationSeverity.medium,
          message: 'Repository lacks proper error handling',
          filePath: filePath,
          category: 'repository_pattern',
          suggestion: 'Add try-catch blocks and proper error handling',
        ));
      }
    }

    return violations;
  }

  /// Analyze service layer architecture
  static Future<List<Violation>> _analyzeServiceLayer(String content, String filePath, String layer) async {
    final violations = <Violation>[];

    if (layer == 'services') {
      // Services should not directly access repositories from other services
      for (final pattern in _serviceLayerViolations) {
        if (RegExp(pattern).hasMatch(content)) {
          violations.add(Violation(
            severity: ViolationSeverity.medium,
            message: 'Service directly accessing repository',
            filePath: filePath,
            category: 'service_layer',
            suggestion: 'Inject repository through constructor or use service locator',
          ));
        }
      }

      // Services should be stateless
      if (_hasInstanceState(content)) {
        violations.add(Violation(
          severity: ViolationSeverity.low,
          message: 'Service contains mutable state',
          filePath: filePath,
          category: 'service_layer',
          suggestion: 'Keep services stateless for better testability',
        ));
      }
    }

    return violations;
  }

  /// Analyze dependency injection patterns
  static Future<List<Violation>> _analyzeDependencyInjection(String content, String filePath) async {
    final violations = <Violation>[];

    // Check for hardcoded dependencies
    if (_hasHardcodedDependencies(content)) {
      violations.add(Violation(
        severity: ViolationSeverity.medium,
        message: 'Hardcoded dependencies detected',
        filePath: filePath,
        category: 'dependency_injection',
        suggestion: 'Use dependency injection for better testability',
      ));
    }

    // Check for singleton abuse
    if (_hasSingletonAbuse(content)) {
      violations.add(Violation(
        severity: ViolationSeverity.low,
        message: 'Potential singleton abuse',
        filePath: filePath,
        category: 'dependency_injection',
        suggestion: 'Consider using dependency injection instead of singletons',
      ));
    }

    return violations;
  }

  /// Analyze file size compliance
  static Future<List<Violation>> _analyzeFileSize(String content, String filePath) async {
    final violations = <Violation>[];
    final lineCount = content.split('\n').length;
    
    if (lineCount > 500) {
      violations.add(Violation(
        severity: ViolationSeverity.medium,
        message: 'File exceeds 500 line limit ($lineCount lines)',
        filePath: filePath,
        category: 'file_size',
        suggestion: 'Apply facade pattern to break down large files',
      ));
    }

    return violations;
  }

  // Helper methods

  static String _determineArchitecturalLayer(String filePath) {
    for (final entry in _layerPatterns.entries) {
      for (final pattern in entry.value) {
        if (filePath.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return 'unknown';
  }

  static ViolationSeverity? _getFirebaseImportSeverity(String layer) {
    switch (layer) {
      case 'views':
      case 'viewmodels':
      case 'widgets':
        return ViolationSeverity.critical;
      case 'services':
        return ViolationSeverity.high;
      case 'repositories':
        return null; // Allowed in repositories
      default:
        return ViolationSeverity.medium;
    }
  }

  static ViolationSeverity? _getFirebaseOperationSeverity(String layer) {
    switch (layer) {
      case 'views':
      case 'viewmodels':
      case 'widgets':
        return ViolationSeverity.critical;
      case 'services':
        return ViolationSeverity.high;
      case 'repositories':
        return null; // Allowed in repositories
      default:
        return ViolationSeverity.medium;
    }
  }

  static String _getFirebaseImportSuggestion(String layer) {
    switch (layer) {
      case 'views':
      case 'viewmodels':
        return 'Use repository pattern through dependency injection';
      case 'services':
        return 'Access Firebase through repository layer';
      default:
        return 'Consider proper architectural layering';
    }
  }

  static bool _hasBusinessLogic(String content) {
    final businessLogicPatterns = [
      r'for\s*\([^}]*\).*\{[^}]*(?:calculate|compute|process)',
      r'if\s*\([^}]*\).*\{[^}]*(?:validate|transform|convert)',
      r'switch\s*\([^}]*\).*\{[^}]*case',
    ];

    return businessLogicPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _hasDirectRepositoryAccess(String content) {
    final repositoryAccessPatterns = [
      r'Repository\(\)',
      r'\.getInstance\(\).*Repository',
      r'GetIt.*Repository',
    ];

    return repositoryAccessPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _hasUIImports(String content) {
    final uiImportPatterns = [
      "import 'package:flutter/material.dart'",
      "import 'package:flutter/cupertino.dart'",
      "import 'package:flutter/widgets.dart'",
    ];

    return uiImportPatterns.any((pattern) => content.contains(pattern));
  }

  static bool _hasDirectFirebaseAccess(String content) {
    return _firebaseImportPatterns.any((pattern) => content.contains(pattern)) ||
           _repositoryPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _hasUIContextAccess(String content) {
    final contextPatterns = [
      r'BuildContext\s+context',
      r'context\.',
      r'Navigator\.',
      r'showDialog\(',
    ];

    return contextPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _implementsInterface(String content) {
    return content.contains('implements ') || content.contains('extends ');
  }

  static bool _hasProperErrorHandling(String content) {
    return content.contains('try {') && content.contains('catch (') ||
           content.contains('onError:') ||
           content.contains('catchError');
  }

  static bool _hasInstanceState(String content) {
    final statePatterns = [
      r'(?:final|var)\s+\w+\s*=.*(?!const)',
      r'List<\w+>\s+\w+\s*=',
      r'Map<\w+,\s*\w+>\s+\w+\s*=',
    ];

    return statePatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _hasHardcodedDependencies(String content) {
    final hardcodedPatterns = [
      r'new\s+\w+Repository\(',
      r'\w+Service\(\)',
      r'DatabaseHelper\(\)',
    ];

    return hardcodedPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static bool _hasSingletonAbuse(String content) {
    final singletonPatterns = [
      r'\.getInstance\(\)',
      r'static\s+final\s+\w+\s+instance',
      r'static\s+\w+\?\s+_instance',
    ];

    return singletonPatterns.any((pattern) => RegExp(pattern).hasMatch(content));
  }

  static int _countFirebaseImports(String content) {
    return _firebaseImportPatterns.where((pattern) => content.contains(pattern)).length;
  }

  static int _countRepositoryOperations(String content) {
    return _repositoryPatterns.where((pattern) => RegExp(pattern).hasMatch(content)).length;
  }

  /// Calculate architecture score with stricter standards
  static double _calculateArchitectureScore(List<Violation> violations, String layer) {
    if (violations.isEmpty) return 1.0;
    
    double score = 1.0;
    
    // Apply stricter penalties than current system
    for (final violation in violations) {
      switch (violation.severity) {
        case ViolationSeverity.critical:
          score -= 0.4;  // Much harsher than before
          break;
        case ViolationSeverity.high:
          score -= 0.25;
          break;
        case ViolationSeverity.medium:
          score -= 0.15;
          break;
        case ViolationSeverity.low:
          score -= 0.05;
          break;
      }
    }
    
    // Additional penalty for critical layers with violations
    if (['views', 'viewmodels'].contains(layer) && violations.isNotEmpty) {
      score -= 0.1;  // Extra penalty for UI layer violations
    }
    
    return score < 0.0 ? 0.0 : score;
  }
}

class ArchitectureAnalysisResult extends AnalysisResult {
  ArchitectureAnalysisResult({
    required String filePath,
    required List<Violation> violations,
    required Map<String, dynamic> metrics,
  }) : super(filePath: filePath, violations: violations, metrics: metrics);
}