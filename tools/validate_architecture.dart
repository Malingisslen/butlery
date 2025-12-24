// tools/validate_architecture.dart
// Architecture validation tool for CI/CD
// Usage: dart run tools/validate_architecture.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Configuration constants
const int maxFileLines = 500;
const String libDir = 'lib';

/// Violation types
enum ViolationType {
  fileSize,
  directFirestore,
  directFirebaseInstance,
  themeHardcoded,
}

/// Represents a single violation
class Violation {
  final String file;
  final ViolationType type;
  final String message;
  final int? lineNumber;

  Violation({
    required this.file,
    required this.type,
    required this.message,
    this.lineNumber,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'type': type.name,
        'message': message,
        if (lineNumber != null) 'line': lineNumber,
      };
}

/// Main validation runner
Future<void> main() async {
  print('Architecture Validation Tool');
  print('=' * 50);
  print('');

  final violations = <Violation>[];
  var totalFiles = 0;
  var fileSizeViolations = 0;
  var firestoreViolations = 0;
  var themeViolations = 0;

  // Get all Dart files in lib/
  final libDirectory = Directory(libDir);
  if (!libDirectory.existsSync()) {
    print('Error: $libDir directory not found.');
    exit(1);
  }

  final dartFiles = libDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('.g.dart'))
      .where((f) => !f.path.contains('.freezed.dart'))
      .toList();

  totalFiles = dartFiles.length;
  print('Scanning $totalFiles Dart files...');
  print('');

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll('\\', '/');
    final lines = file.readAsLinesSync();
    final lineCount = lines.length;

    // Check 1: File size (500 line limit)
    if (lineCount > maxFileLines) {
      fileSizeViolations++;
      violations.add(Violation(
        file: relativePath,
        type: ViolationType.fileSize,
        message: 'File has $lineCount lines (max: $maxFileLines)',
      ));
    }

    // Check 2: Direct Firestore access (should use repositories)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip comments
      if (line.trim().startsWith('//') || line.trim().startsWith('*')) {
        continue;
      }

      // Check for direct FirebaseFirestore.instance usage
      if (line.contains('FirebaseFirestore.instance') &&
          !relativePath.contains('repository') &&
          !relativePath.contains('_repository.dart')) {
        firestoreViolations++;
        violations.add(Violation(
          file: relativePath,
          type: ViolationType.directFirebaseInstance,
          message: 'Direct FirebaseFirestore.instance usage outside repository',
          lineNumber: i + 1,
        ));
      }

      // Check for hardcoded hex colors only (Colors.* is often legitimate)
      // Only flag Color(0x...) which is clearly hardcoded
      if (line.contains('Color(0x') &&
          !relativePath.contains('theme') &&
          !relativePath.contains('constants') &&
          !line.contains('// ignore-theme-check')) {
        themeViolations++;
        violations.add(Violation(
          file: relativePath,
          type: ViolationType.themeHardcoded,
          message: 'Hardcoded hex color - consider using theme',
          lineNumber: i + 1,
        ));
      }
    }
  }

  // Calculate compliance rates (files without violations / total files)
  final filesWithSizeViolations = violations
      .where((v) => v.type == ViolationType.fileSize)
      .map((v) => v.file)
      .toSet()
      .length;
  final filesWithFirestoreViolations = violations
      .where((v) => v.type == ViolationType.directFirebaseInstance)
      .map((v) => v.file)
      .toSet()
      .length;
  final filesWithThemeViolations = violations
      .where((v) => v.type == ViolationType.themeHardcoded)
      .map((v) => v.file)
      .toSet()
      .length;

  final fileSizeCompliance =
      ((totalFiles - filesWithSizeViolations) / totalFiles * 100).round();
  final firestoreCompliance =
      ((totalFiles - filesWithFirestoreViolations) / totalFiles * 100).round();
  final themeCompliance =
      ((totalFiles - filesWithThemeViolations) / totalFiles * 100).round();

  // Build report
  final report = {
    'timestamp': DateTime.now().toIso8601String(),
    'stats': {
      'total_files': totalFiles,
      'max_file_lines': maxFileLines,
    },
    'summary': {
      'compliance_rates': {
        'file_size': fileSizeCompliance,
        'firebase': firestoreCompliance,
        'theme': themeCompliance,
      },
      'total_violations': violations.length,
      'violations_by_type': {
        'file_size': fileSizeViolations,
        'firebase': firestoreViolations,
        'theme': themeViolations,
      },
    },
    'violations': violations.map((v) => v.toJson()).toList(),
  };

  // Output report to console
  print('Results:');
  print('-' * 50);
  print('Total Files: $totalFiles');
  print('');
  print('Compliance Rates:');
  print('  File Size ($maxFileLines lines): $fileSizeCompliance%');
  print('  Firebase (repository pattern): $firestoreCompliance%');
  print('  Theme (no hardcoded colors): $themeCompliance%');
  print('');
  print('Violations: ${violations.length}');
  print('  - File size: $fileSizeViolations');
  print('  - Firebase: $firestoreViolations');
  print('  - Theme: $themeViolations');
  print('');

  if (violations.isNotEmpty) {
    print('Violation Details:');
    print('-' * 50);
    for (final v in violations.take(20)) {
      // Show first 20
      final lineInfo = v.lineNumber != null ? ':${v.lineNumber}' : '';
      print('  ${v.type.name}: ${v.file}$lineInfo');
      print('    ${v.message}');
    }
    if (violations.length > 20) {
      print('  ... and ${violations.length - 20} more violations');
    }
  }

  // Write JSON report for CI artifact
  final reportFile = File('architecture_validation_report.json');
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  print('');
  print('Report written to: ${reportFile.path}');

  // Exit with error if critical violations
  if (fileSizeViolations > 0 || firestoreViolations > 0) {
    print('');
    print('WARNING: Architecture violations detected.');
    // Don't fail the build, just warn
    // exit(1);
  }

  print('');
  print('Architecture validation complete.');
}
