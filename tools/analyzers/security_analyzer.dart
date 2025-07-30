// tools/analyzers/security_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Security vulnerability analyzer - 30% of overall health score
/// 
/// Detects:
/// - Hardcoded secrets (API keys, tokens, passwords)
/// - Authentication vulnerabilities
/// - Data exposure risks  
/// - Network security issues
/// - Permission escalation patterns
class SecurityAnalyzer {
  static const List<String> _secretPatterns = [
    // API Keys and tokens - simplified patterns
    'api_key',
    'apikey',
    'secret_key',
    'secretkey',
    'access_token',
    'bearer_token',
    'firebase_api_key',
    'google_api_key',
    
    // Database connections
    'mongodb://',
    'mysql://',
    'postgres://',
    
    // AWS credentials
    'AKIA',
    'aws_secret_access_key',
    
    // Private keys
    'BEGIN PRIVATE KEY',
    'ssh-rsa',
    
    // Common passwords
    'password=',
    'pwd=',
  ];

  static const List<String> _insecurePatterns = [
    // HTTP instead of HTTPS
    'http://',
    
    // Insecure random
    'Random()',
    'math.Random()',
    
    // Debug info in production
    'print(',
    'debugPrint(',
    
    // Insecure storage
    'SharedPreferences',
    'localStorage',
    
    // Certificate validation bypass
    'badCertificateCallback',
    'onBadCertificate',
    
    // SQL injection risks
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
  ];

  static const List<String> _permissionRisks = [
    // Excessive Android permissions
    'WRITE_EXTERNAL_STORAGE',
    'READ_EXTERNAL_STORAGE', 
    'ACCESS_FINE_LOCATION',
    'CAMERA',
    'RECORD_AUDIO',
    'READ_CONTACTS',
    'WRITE_CONTACTS',
    'READ_SMS',
    'SEND_SMS',
    
    // iOS sensitive permissions
    'NSLocationAlwaysUsageDescription',
    'NSCameraUsageDescription',
    'NSMicrophoneUsageDescription',
    'NSContactsUsageDescription',
  ];

  /// Analyze files for security vulnerabilities
  static Future<List<SecurityAnalysisResult>> analyzeFiles(List<File> files) async {
    final results = <SecurityAnalysisResult>[];
    
    for (final file in files) {
      final result = await _analyzeFile(file);
      if (result.violations.isNotEmpty || result.metrics.isNotEmpty) {
        results.add(result);
      }
    }
    
    return results;
  }

  /// Analyze single file for security issues
  static Future<SecurityAnalysisResult> _analyzeFile(File file) async {
    final content = await file.readAsString();
    final filePath = file.path.replaceAll('\\', '/');
    final violations = <Violation>[];
    final metrics = <String, dynamic>{};

    // Check for hardcoded secrets
    violations.addAll(await _detectSecrets(content, filePath));
    
    // Check for insecure patterns
    violations.addAll(await _detectInsecurePatterns(content, filePath));
    
    // Check for permission risks
    violations.addAll(await _detectPermissionRisks(content, filePath));

    // Calculate security metrics
    metrics['secret_patterns_found'] = violations.where((v) => v.category == 'secrets').length;
    metrics['insecure_patterns_found'] = violations.where((v) => v.category == 'insecure_patterns').length;
    metrics['permission_risks'] = violations.where((v) => v.category == 'permissions').length;
    metrics['security_score'] = _calculateFileSecurityScore(violations);

    return SecurityAnalysisResult(
      filePath: filePath,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Detect hardcoded secrets and credentials
  static Future<List<Violation>> _detectSecrets(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');
    final lowerContent = content.toLowerCase();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      
      // Skip comments and imports
      if (line.trim().startsWith('//') || line.trim().startsWith('import')) {
        continue;
      }

      for (final pattern in _secretPatterns) {
        if (line.contains(pattern.toLowerCase()) && !_isTestValue(line)) {
          violations.add(Violation(
            severity: ViolationSeverity.critical,
            message: 'Potential hardcoded secret detected: $pattern',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'secrets',
            suggestion: 'Move secrets to environment variables or secure configuration',
          ));
        }
      }
    }

    return violations;
  }

  /// Detect insecure coding patterns
  static Future<List<Violation>> _detectInsecurePatterns(String content, String filePath) async {
    final violations = <Violation>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final pattern in _insecurePatterns) {
        if (line.contains(pattern)) {
          violations.add(Violation(
            severity: _getInsecurePatternSeverity(pattern),
            message: 'Insecure pattern detected: $pattern',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'insecure_patterns',
            suggestion: _getInsecurePatternSuggestion(pattern),
          ));
        }
      }
    }

    return violations;
  }

  /// Detect excessive permission usage
  static Future<List<Violation>> _detectPermissionRisks(String content, String filePath) async {
    final violations = <Violation>[];
    
    // Only check manifest files and permission-related code
    if (!filePath.contains('android') && !filePath.contains('ios') && 
        !filePath.contains('permission')) {
      return violations;
    }

    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final permission in _permissionRisks) {
        if (line.contains(permission)) {
          violations.add(Violation(
            severity: ViolationSeverity.high,
            message: 'Sensitive permission detected: $permission',
            filePath: filePath,
            lineNumber: i + 1,
            category: 'permissions',
            suggestion: 'Ensure this permission is necessary and properly justified to users',
          ));
        }
      }
    }

    return violations;
  }

  /// Check if value appears to be test/example data
  static bool _isTestValue(String value) {
    final testPatterns = [
      'test', 'example', 'demo', 'sample', 'fake', 'mock',
      'xxxxxxxx', '12345', 'abcd', 'your-key-here'
    ];
    
    final lowerValue = value.toLowerCase();
    return testPatterns.any((pattern) => lowerValue.contains(pattern));
  }

  /// Get severity for insecure pattern
  static ViolationSeverity _getInsecurePatternSeverity(String pattern) {
    if (pattern.contains('PRIVATE KEY') || pattern.contains('password')) {
      return ViolationSeverity.critical;
    }
    if (pattern.contains('http://') || pattern.contains('badCertificate')) {
      return ViolationSeverity.high;
    }
    return ViolationSeverity.medium;
  }

  /// Get suggestion for insecure pattern
  static String _getInsecurePatternSuggestion(String pattern) {
    if (pattern.contains('http://')) return 'Use HTTPS for all network connections';
    if (pattern.contains('Random()')) return 'Use cryptographically secure random: Random.secure()';
    if (pattern.contains('print')) return 'Remove debug prints containing sensitive data';
    if (pattern.contains('SharedPreferences')) return 'Use secure storage like flutter_secure_storage';
    if (pattern.contains('badCertificate')) return 'Implement proper certificate validation';
    if (pattern.contains('SELECT')) return 'Use parameterized queries to prevent SQL injection';
    return 'Follow secure coding practices';
  }

  /// Calculate security score for file
  static double _calculateFileSecurityScore(List<Violation> violations) {
    if (violations.isEmpty) return 1.0;
    
    double score = 1.0;
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
    
    return score < 0.0 ? 0.0 : score;
  }
}

class SecurityAnalysisResult extends AnalysisResult {
  SecurityAnalysisResult({
    required String filePath,
    required List<Violation> violations,
    required Map<String, dynamic> metrics,
  }) : super(filePath: filePath, violations: violations, metrics: metrics);
}