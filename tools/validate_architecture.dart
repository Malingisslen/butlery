// tools/validate_architecture.dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';

/// Comprehensive architecture validation tool for Butlery Flutter app
///
/// Validates:
/// - Firebase usage only in repositories (repository pattern compliance)
/// - No hardcoded styling values (theme system compliance)
/// - File size limit of 500 lines (SRP compliance)
/// - SRP violations and code quality metrics
class ArchitectureValidator {
  static const int _fileSizeLimit = 500;
  static const int _methodSizeLimit = 50;
  static const int _classMethodLimit = 20;

  final Map<String, List<String>> _violations = {
    'firebase_violations': [],
    'hardcoded_styling': [],
    'design_in_views': [],
    'oversized_files': [],
    'srp_violations': [],
    'performance_issues': [],
  };

  final Map<String, int> _stats = {
    'total_files': 0,
    'total_lines': 0,
    'firebase_compliant': 0,
    'theme_compliant': 0,
    'size_compliant': 0,
  };

  /// Main validation entry point
  Future<void> validateArchitecture() async {
    print('🔍 Starting Butlery Architecture Validation...\n');

    final dartFiles = await _getDartFiles();
    _stats['total_files'] = dartFiles.length;

    print('📊 Found ${dartFiles.length} Dart files to analyze\n');

    // Run all validation checks
    await _validateFirebaseUsage(dartFiles);
    await _validateStylingCompliance(dartFiles);
    await _validateDesignSeparation(dartFiles);
    await _validateFileSizes(dartFiles);
    await _validateSRPCompliance(dartFiles);

    // Generate comprehensive report
    _generateReport();
  }

  /// Get all Dart files in the lib directory
  Future<List<File>> _getDartFiles() async {
    final libDir = Directory('lib');
    if (!await libDir.exists()) {
      throw Exception('lib directory not found. Run from project root.');
    }

    return libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  /// Validate Firebase usage only in repositories
  Future<void> _validateFirebaseUsage(List<File> files) async {
    print('🔥 Validating Firebase abstraction compliance...');

    final firebaseImportPattern =
        RegExp(r'import.*firebase_|import.*cloud_firestore');
    final repositoryPathPattern = RegExp(
        r'repositories[/\\]firebase[/\\]|repositories[/\\]interfaces[/\\]');
    final allowedNonRepoFiles = {
      'lib/main.dart',
      'lib/firebase_options.dart',
      'lib/core/injection.dart',
      'lib/core/startup/app_initializer.dart',
    };

    int compliantFiles = 0;

    for (final file in files) {
      final content = await file.readAsString();
      final relativePath = file.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll('\\', '/');

      if (firebaseImportPattern.hasMatch(content)) {
        final isRepositoryFile = repositoryPathPattern.hasMatch(relativePath);
        final isAllowedFile = allowedNonRepoFiles
            .any((allowed) => relativePath.endsWith(allowed));

        if (!isRepositoryFile && !isAllowedFile) {
          _violations['firebase_violations']!.add(
              '❌ $relativePath - Direct Firebase import outside repository layer');
        } else {
          compliantFiles++;
        }
      } else {
        compliantFiles++;
      }
    }

    _stats['firebase_compliant'] = compliantFiles;
    print('   ✅ $compliantFiles/${files.length} files compliant\n');
  }

  /// Validate styling compliance (no hardcoded values)
  Future<void> _validateStylingCompliance(List<File> files) async {
    print('🎨 Validating theme system compliance...');

    final hardcodedPatterns = [
      RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'), // Hardcoded colors
      RegExp(r'FontSize\s*:\s*\d+'), // Hardcoded font sizes
      RegExp(
          r'EdgeInsets\.all\(\d+\.?\d*\)'), // Hardcoded padding (except theme files)
      RegExp(r'BorderRadius\.circular\(\d+\.?\d*\)'), // Hardcoded border radius
      RegExp(r'SizedBox\(width:\s*\d+\.?\d*\)'), // Hardcoded widths
      RegExp(r'SizedBox\(height:\s*\d+\.?\d*\)'), // Hardcoded heights
    ];

    final themeFiles = {
      'lib/theme/app_colors.dart',
      'lib/theme/app_dimensions.dart',
      'lib/theme/app_text_styles.dart',
      'lib/theme/app_theme.dart',
    };

    int compliantFiles = 0;

    for (final file in files) {
      final content = await file.readAsString();
      final relativePath = file.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll('\\', '/');

      // Skip theme files - they're allowed to have hardcoded values
      if (themeFiles.any((theme) => relativePath.endsWith(theme))) {
        compliantFiles++;
        continue;
      }

      bool hasViolations = false;

      for (final pattern in hardcodedPatterns) {
        final matches = pattern.allMatches(content);
        for (final match in matches) {
          hasViolations = true;
          final lineNumber =
              content.substring(0, match.start).split('\n').length;
          _violations['hardcoded_styling']!.add(
              '❌ $relativePath:$lineNumber - Hardcoded value: ${match.group(0)}');
        }
      }

      if (!hasViolations) {
        compliantFiles++;
      }
    }

    _stats['theme_compliant'] = compliantFiles;
    print('   ✅ $compliantFiles/${files.length} files compliant\n');
  }

  /// Validate design separation (no styling in views, should be in widgets)
  Future<void> _validateDesignSeparation(List<File> files) async {
    print(
        '🎨 Validating design separation (views should delegate to widgets)...');

    // Design patterns that should be in widgets, not views
    final designPatterns = [
      RegExp(r'Container\s*\(\s*[^)]*(?:decoration|color|margin|padding)',
          multiLine: true),
      RegExp(r'Padding\s*\(\s*padding:', multiLine: true),
      RegExp(r'Card\s*\(\s*[^)]*(?:elevation|shape|margin)', multiLine: true),
      RegExp(r'AppBar\s*\(\s*[^)]*(?:backgroundColor|elevation|shape)',
          multiLine: true),
      RegExp(
          r'FloatingActionButton\s*\(\s*[^)]*(?:backgroundColor|foregroundColor)',
          multiLine: true),
      RegExp(r'ElevatedButton\.styleFrom\s*\(', multiLine: true),
      RegExp(r'TextButton\.styleFrom\s*\(', multiLine: true),
      RegExp(r'OutlinedButton\.styleFrom\s*\(', multiLine: true),
      RegExp(r'TextStyle\s*\(\s*[^)]*(?:fontSize|fontWeight|color)',
          multiLine: true),
      RegExp(r'BoxDecoration\s*\(\s*[^)]*(?:color|borderRadius|border)',
          multiLine: true),
    ];

    // Acceptable design patterns in views (layout structure)
    final acceptablePatterns = [
      RegExp(r'Scaffold\s*\('),
      RegExp(r'Column\s*\('),
      RegExp(r'Row\s*\('),
      RegExp(r'Stack\s*\('),
      RegExp(r'ListView\s*\('),
      RegExp(r'GridView\s*\('),
      RegExp(r'SingleChildScrollView\s*\('),
      RegExp(r'Expanded\s*\('),
      RegExp(r'Flexible\s*\('),
      RegExp(
          r'SizedBox\s*\(\s*(?:width:|height:)?\s*[^,)]*\)'), // Simple sizing
    ];

    int compliantFiles = 0;
    int designViolationsCount = 0;

    for (final file in files) {
      final content = await file.readAsString();
      final relativePath = file.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll('\\', '/');

      // Only check view files
      if (!relativePath.contains('/views/') ||
          !relativePath.endsWith('_view.dart')) {
        compliantFiles++;
        continue;
      }

      // Skip widget files in views directory (these can have design)
      if (relativePath.contains('/widgets/') ||
          relativePath.contains('_widget.dart')) {
        compliantFiles++;
        continue;
      }

      bool hasDesignViolations = false;

      for (final pattern in designPatterns) {
        final matches = pattern.allMatches(content);
        for (final match in matches) {
          final lineNumber =
              content.substring(0, match.start).split('\n').length;
          final matchedText = match.group(0)?.split('\n').first ?? '';

          // Check if this is acceptable structure vs styling
          bool isAcceptableStructure = false;
          for (final acceptable in acceptablePatterns) {
            if (acceptable.hasMatch(matchedText)) {
              isAcceptableStructure = true;
              break;
            }
          }

          if (!isAcceptableStructure) {
            hasDesignViolations = true;
            designViolationsCount++;
            _violations['design_in_views']!.add(
                '❌ $relativePath:$lineNumber - Design in view: ${matchedText.trim()}');
          }
        }
      }

      if (!hasDesignViolations) {
        compliantFiles++;
      }
    }

    _stats['design_separation_compliant'] = compliantFiles;
    print('   ✅ $compliantFiles/${files.length} files compliant');
    print('   ⚠️  Found $designViolationsCount design-in-view violations\n');
  }

  /// Validate file size limits (500 lines max)
  Future<void> _validateFileSizes(List<File> files) async {
    print('📏 Validating file size compliance (500 lines max)...');

    int compliantFiles = 0;
    int totalLines = 0;

    for (final file in files) {
      final lines = await file.readAsLines();
      final lineCount = lines.length;
      totalLines += lineCount;

      final relativePath = file.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll('\\', '/');

      if (lineCount > _fileSizeLimit) {
        _violations['oversized_files']!
            .add('❌ $relativePath - $lineCount lines (limit: $_fileSizeLimit)');
      } else {
        compliantFiles++;
      }
    }

    _stats['size_compliant'] = compliantFiles;
    _stats['total_lines'] = totalLines;
    print('   ✅ $compliantFiles/${files.length} files compliant\n');
  }

  /// Validate Single Responsibility Principle compliance
  Future<void> _validateSRPCompliance(List<File> files) async {
    print('🎯 Validating SRP compliance...');

    for (final file in files) {
      final content = await file.readAsString();
      final relativePath = file.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll('\\', '/');

      await _analyzeClassComplexity(content, relativePath);
      await _analyzeMethodComplexity(content, relativePath);
    }

    print('   ✅ SRP analysis complete\n');
  }

  /// Analyze class complexity and method count
  Future<void> _analyzeClassComplexity(String content, String filePath) async {
    final classPattern = RegExp(r'class\s+(\w+).*?\{', multiLine: true);
    final methodPattern = RegExp(
        r'\s+([\w<>]+\s+)?(\w+)\s*\([^)]*\)\s*(async\s*)?\{',
        multiLine: true);

    final classMatches = classPattern.allMatches(content);

    for (final classMatch in classMatches) {
      final className = classMatch.group(1)!;

      // Find the class body (simplified - doesn't handle nested classes perfectly)
      final classStart = classMatch.end;
      int braceCount = 1;
      int classEnd = classStart;

      for (int i = classStart; i < content.length && braceCount > 0; i++) {
        if (content[i] == '{') braceCount++;
        if (content[i] == '}') braceCount--;
        classEnd = i;
      }

      final classBody = content.substring(classStart, classEnd);
      final methodMatches = methodPattern.allMatches(classBody);
      final methodCount = methodMatches.length;

      if (methodCount > _classMethodLimit) {
        _violations['srp_violations']!.add(
            '❌ $filePath - Class $className has $methodCount methods (limit: $_classMethodLimit)');
      }
    }
  }

  /// Analyze method complexity
  Future<void> _analyzeMethodComplexity(String content, String filePath) async {
    final methodPattern =
        RegExp(r'(\w+)\s*\([^)]*\)\s*(async\s*)?\{', multiLine: true);
    final lines = content.split('\n');

    final methodMatches = methodPattern.allMatches(content);

    for (final methodMatch in methodMatches) {
      final methodName = methodMatch.group(1)!;
      final startLine =
          content.substring(0, methodMatch.start).split('\n').length;

      // Find method end (simplified - counts braces)
      int braceCount = 1;
      int currentLine = startLine;

      for (int i = startLine; i < lines.length && braceCount > 0; i++) {
        final line = lines[i];
        braceCount += '{'.allMatches(line).length;
        braceCount -= '}'.allMatches(line).length;
        currentLine = i;
      }

      final methodLength = currentLine - startLine + 1;

      if (methodLength > _methodSizeLimit) {
        _violations['srp_violations']!.add(
            '❌ $filePath:$startLine - Method $methodName is $methodLength lines (limit: $_methodSizeLimit)');
      }
    }
  }

  /// Generate comprehensive validation report
  void _generateReport() {
    print('📋 BUTLERY ARCHITECTURE VALIDATION REPORT');
    print('=' * 50);

    // Summary statistics
    print('\n📊 SUMMARY STATISTICS:');
    print('Total files analyzed: ${_stats['total_files']}');
    print('Total lines of code: ${_stats['total_lines']}');
    print(
        'Average file size: ${(_stats['total_lines']! / _stats['total_files']!).round()} lines');

    // Compliance rates
    print('\n✅ COMPLIANCE RATES:');
    print(
        'Firebase abstraction: ${_getCompliancePercentage('firebase_compliant')}%');
    print(
        'Theme system usage: ${_getCompliancePercentage('theme_compliant')}%');
    print(
        'Design separation: ${_getCompliancePercentage('design_separation_compliant')}%');
    print('File size limits: ${_getCompliancePercentage('size_compliant')}%');

    // Detailed violations
    _printViolations(
        '🔥 FIREBASE ABSTRACTION VIOLATIONS', 'firebase_violations');
    _printViolations('🎨 HARDCODED STYLING VIOLATIONS', 'hardcoded_styling');
    _printViolations('🎨 DESIGN-IN-VIEWS VIOLATIONS', 'design_in_views');
    _printViolations('📏 OVERSIZED FILE VIOLATIONS', 'oversized_files');
    _printViolations('🎯 SRP VIOLATIONS', 'srp_violations');

    // Overall assessment
    _printOverallAssessment();

    // Recommendations
    _printRecommendations();
  }

  /// Calculate compliance percentage
  double _getCompliancePercentage(String statKey) {
    final compliant = _stats[statKey]!;
    final total = _stats['total_files']!;
    return ((compliant / total) * 100).roundToDouble();
  }

  /// Print violations for a specific category
  void _printViolations(String title, String category) {
    final violations = _violations[category]!;

    if (violations.isEmpty) {
      print('\n$title: ✅ No violations found');
      return;
    }

    print('\n$title (${violations.length} violations):');
    for (final violation in violations.take(10)) {
      // Limit to first 10
      print('  $violation');
    }

    if (violations.length > 10) {
      print('  ... and ${violations.length - 10} more violations');
    }
  }

  /// Print overall assessment
  void _printOverallAssessment() {
    final totalViolations =
        _violations.values.fold(0, (sum, list) => sum + list.length);
    final totalFiles = _stats['total_files']!;
    final overallCompliance =
        ((totalFiles - totalViolations) / totalFiles * 100).round();

    print('\n🎯 OVERALL ASSESSMENT:');

    if (overallCompliance >= 95) {
      print('🌟 EXCELLENT - $overallCompliance% compliance rate');
      print(
          'Your architecture follows best practices with minimal violations.');
    } else if (overallCompliance >= 85) {
      print('✅ GOOD - $overallCompliance% compliance rate');
      print('Your architecture is solid with some areas for improvement.');
    } else if (overallCompliance >= 70) {
      print('⚠️  NEEDS IMPROVEMENT - $overallCompliance% compliance rate');
      print('Several architectural violations need attention.');
    } else {
      print('❌ POOR - $overallCompliance% compliance rate');
      print('Significant architectural refactoring is recommended.');
    }

    print('Total violations: $totalViolations across $totalFiles files');
  }

  /// Print recommendations for improvement
  void _printRecommendations() {
    print('\n💡 RECOMMENDATIONS:');

    if (_violations['firebase_violations']!.isNotEmpty) {
      print('🔥 Firebase: Move direct Firebase imports to repository layer');
    }

    if (_violations['hardcoded_styling']!.isNotEmpty) {
      print(
          '🎨 Styling: Replace hardcoded values with AppColors/AppDimensions constants');
    }

    if (_violations['oversized_files']!.isNotEmpty) {
      print('📏 File Size: Apply facade pattern to files over 500 lines');
    }

    if (_violations['srp_violations']!.isNotEmpty) {
      print('🎯 SRP: Break down large classes/methods into focused components');
    }

    print('\n📚 For detailed guidance, see: docs/PROJECT_PLAN.md');
    print('🔧 Phase 7 & 9 patterns can be applied to resolve violations');
  }

  /// Save detailed report to file
  void _saveDetailedReport() {
    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'stats': _stats,
      'violations': _violations,
      'summary': {
        'total_violations':
            _violations.values.fold(0, (sum, list) => sum + list.length),
        'compliance_rates': {
          'firebase': _getCompliancePercentage('firebase_compliant'),
          'theme': _getCompliancePercentage('theme_compliant'),
          'file_size': _getCompliancePercentage('size_compliant'),
        }
      }
    };

    final reportFile = File('architecture_validation_report.json');
    reportFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(reportData));

    print('\n💾 Detailed report saved to: architecture_validation_report.json');
  }
}

/// Main entry point
void main(List<String> arguments) async {
  try {
    final validator = ArchitectureValidator();
    await validator.validateArchitecture();
    validator._saveDetailedReport();

    print('\n🎉 Architecture validation complete!');
    print('Run with --help for additional options');
  } catch (e) {
    print('❌ Validation failed: $e');
    exit(1);
  }
}
