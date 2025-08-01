// tools/analyzers/predictive_analyzer.dart

import 'dart:io';
import '../code_intelligence_platform.dart';

/// Predictive analyzer for bug hotspots and maintenance burden
///
/// Uses heuristics to predict:
/// - Files most likely to have bugs
/// - Code areas that will require most maintenance
/// - Performance degradation risks
/// - Security vulnerability likelihood
/// - Technical debt accumulation patterns
class PredictiveAnalyzer {
  /// Identify high-risk code areas (hotspots)
  static Future<List<CodeHotspot>> identifyHotspots(
      List<File> files, List<AnalysisResult>? allResults) async {
    final hotspots = <CodeHotspot>[];

    for (final file in files) {
      final hotspot = await _analyzeFileRisk(file, allResults);
      if (hotspot.riskScore > 0.6) {
        // High risk threshold
        hotspots.add(hotspot);
      }
    }

    // Sort by risk score (highest first)
    hotspots.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return hotspots;
  }

  /// Analyze individual file risk factors
  static Future<CodeHotspot> _analyzeFileRisk(
      File file, List<AnalysisResult>? allResults) async {
    final content = await file.readAsString();
    final filePath = file.path.replaceAll('\\', '/');

    // Calculate various risk factors
    final complexityRisk = _calculateComplexityRisk(content);
    final sizeRisk = _calculateSizeRisk(content);
    final couplingRisk = _calculateCouplingRisk(content, filePath);
    final codeSmellRisk = _calculateCodeSmellRisk(content);
    final securityRisk = _calculateSecurityRisk(content);
    final changeFrequencyRisk = _estimateChangeFrequency(filePath);
    final testCoverageRisk = _estimateTestCoverageRisk(filePath);

    // Calculate overall risk score using weighted factors
    final riskScore = (complexityRisk * 0.25 +
        sizeRisk * 0.15 +
        couplingRisk * 0.15 +
        codeSmellRisk * 0.10 +
        securityRisk * 0.05 +
        changeFrequencyRisk * 0.20 +
        testCoverageRisk * 0.10);

    // Calculate maintenance burden
    final maintenanceBurden = _calculateMaintenanceBurden(
        content, filePath, complexityRisk, couplingRisk);

    // Identify specific risk factors
    final riskFactors = _identifyRiskFactors(content, filePath, complexityRisk,
        sizeRisk, couplingRisk, codeSmellRisk, securityRisk);

    // Generate predictions
    final predictions =
        _generatePredictions(riskScore, maintenanceBurden, riskFactors);

    return CodeHotspot(
      filePath: filePath,
      riskScore: riskScore,
      maintenanceBurden: maintenanceBurden,
      bugLikelihood: _calculateBugLikelihood(riskScore),
      performanceRisk: _calculatePerformanceRisk(content),
      securityVulnerabilityRisk: securityRisk,
      riskFactors: riskFactors,
      predictions: predictions,
      recommendedActions: _generateRecommendedActions(riskFactors, riskScore),
    );
  }

  /// Calculate complexity-based risk
  static double _calculateComplexityRisk(String content) {
    int complexity = 1; // Base complexity
    complexity += content.split('if (').length - 1;
    complexity += content.split('for (').length - 1;
    complexity += content.split('while (').length - 1;
    complexity += content.split('switch (').length - 1;
    complexity += content.split('catch (').length - 1;
    complexity += content.split('?').length - 1; // Ternary operators

    // Method count complexity
    final lines = content.split('\n');
    int methodCount = 0;
    for (final line in lines) {
      if (line.contains('(') &&
          line.contains('){') &&
          !line.trim().startsWith('//')) {
        methodCount++;
      }
    }
    complexity += methodCount > 20 ? methodCount - 20 : 0;

    // Normalize to 0-1 scale
    return _min(1.0, complexity / 50.0);
  }

  /// Calculate file size risk
  static double _calculateSizeRisk(String content) {
    final lineCount = content.split('\n').length;

    // Risk increases with size
    if (lineCount < 100) return 0.1;
    if (lineCount < 300) return 0.3;
    if (lineCount < 500) return 0.6;
    if (lineCount < 1000) return 0.8;
    return 1.0;
  }

  /// Calculate coupling risk
  static double _calculateCouplingRisk(String content, String filePath) {
    // Count imports and dependencies
    final importCount = content.split('import ').length - 1;
    final externalDeps = content.split('package:').length - 1;

    // Count method calls to other classes
    final externalCalls = content.split('.').length - 1;

    final totalCoupling = importCount + externalDeps + (externalCalls ~/ 10);

    // Normalize to 0-1 scale
    return _min(1.0, totalCoupling / 30.0);
  }

  /// Calculate code smell risk
  static double _calculateCodeSmellRisk(String content) {
    double riskScore = 0.0;

    // Long parameter lists (simplified detection)
    final lines = content.split('\n');
    for (final line in lines) {
      final commas = line.split(',').length - 1;
      if (line.contains('(') && commas > 5) {
        riskScore += 0.1;
      }
    }

    final todoComments = content.split('TODO').length - 1;
    riskScore += todoComments * 0.05;

    // Magic numbers
    final magicNumbers = content.split(RegExp(r'\b\d{2,}\b')).length - 1;
    riskScore += magicNumbers * 0.02;

    // Empty catch blocks
    final emptyCatches = content.split('catch').length - 1;
    if (emptyCatches > 0 &&
        content.contains('catch (') &&
        content.contains('{}')) {
      riskScore += emptyCatches * 0.15;
    }

    return _min(1.0, riskScore);
  }

  /// Calculate security risk
  static double _calculateSecurityRisk(String content) {
    double riskScore = 0.0;

    // Potential secrets
    if (content.toLowerCase().contains('api_key') ||
        content.toLowerCase().contains('secret') ||
        content.toLowerCase().contains('password')) {
      riskScore += 0.3;
    }

    // Insecure network patterns
    if (content.contains('http://')) riskScore += 0.2;
    if (content.contains('badCertificate')) riskScore += 0.4;

    // Insecure storage
    if (content.contains('SharedPreferences') &&
        (content.contains('password') || content.contains('token'))) {
      riskScore += 0.3;
    }

    return _min(1.0, riskScore);
  }

  /// Estimate change frequency risk (heuristic-based)
  static double _estimateChangeFrequency(String filePath) {
    // Files that are likely to change frequently
    if (filePath.contains('view') ||
        filePath.contains('widget') ||
        filePath.contains('ui')) {
      return 0.7; // UI components change frequently
    }

    if (filePath.contains('service') || filePath.contains('api')) {
      return 0.6; // Services change with business requirements
    }

    if (filePath.contains('model') || filePath.contains('dto')) {
      return 0.5; // Data models change with API changes
    }

    if (filePath.contains('core') || filePath.contains('util')) {
      return 0.2; // Core utilities change less frequently
    }

    return 0.4; // Default frequency
  }

  /// Estimate test coverage risk (heuristic-based)
  static double _estimateTestCoverageRisk(String filePath) {
    // Look for corresponding test file
    final testFilePath =
        filePath.replaceAll('lib/', 'test/').replaceAll('.dart', '_test.dart');
    final testFile = File(testFilePath);

    if (!testFile.existsSync()) {
      return 1.0; // No test file = high risk
    }

    // If test file exists, assume moderate coverage
    return 0.3;
  }

  /// Calculate maintenance burden
  static double _calculateMaintenanceBurden(
      String content, String filePath, double complexity, double coupling) {
    // Technical debt indicators
    final todoCount = content.split('TODO').length - 1;
    final technicalDebt = _min(1.0, todoCount / 10.0);

    // Documentation quality (inverse of burden)
    final commentLines = content
        .split('\n')
        .where((line) => line.trim().startsWith('//'))
        .length;
    final totalLines = content.split('\n').length;
    final documentationScore = totalLines > 0 ? commentLines / totalLines : 0.0;
    final documentationBurden = 1.0 - _min(1.0, documentationScore * 5);

    // Test quality burden
    final testQualityBurden = _estimateTestCoverageRisk(filePath);

    // Calculate weighted maintenance burden
    final burden = (technicalDebt * 0.30 +
        complexity * 0.25 +
        coupling * 0.20 +
        documentationBurden * 0.15 +
        testQualityBurden * 0.10);

    return _min(1.0, burden);
  }

  /// Calculate bug likelihood
  static double _calculateBugLikelihood(double riskScore) {
    // Non-linear relationship: risk increases exponentially
    return _min(1.0, riskScore * riskScore * 1.2);
  }

  /// Calculate performance risk
  static double _calculatePerformanceRisk(String content) {
    double risk = 0.0;

    // Synchronous operations
    if (content.contains('Sync(')) risk += 0.3;

    // Build method issues
    if (content.contains('build(') && content.contains('for (')) {
      risk += 0.4;
    }

    // Memory leaks
    if (content.contains('StreamSubscription') &&
        !content.contains('cancel()')) {
      risk += 0.3;
    }

    return _min(1.0, risk);
  }

  /// Identify specific risk factors
  static List<String> _identifyRiskFactors(
      String content,
      String filePath,
      double complexity,
      double size,
      double coupling,
      double codeSmells,
      double security) {
    final factors = <String>[];

    if (complexity > 0.7) factors.add('High cyclomatic complexity');
    if (size > 0.6) factors.add('Large file size');
    if (coupling > 0.7) factors.add('High coupling to other modules');
    if (codeSmells > 0.5) factors.add('Multiple code smells detected');
    if (security > 0.3) factors.add('Security vulnerability patterns');

    // Specific patterns
    if (content.contains('TODO') || content.contains('FIXME')) {
      factors.add('Technical debt comments');
    }

    if (content.contains('catch (') && content.contains('{}')) {
      factors.add('Empty error handling');
    }

    if (!File(filePath
            .replaceAll('lib/', 'test/')
            .replaceAll('.dart', '_test.dart'))
        .existsSync()) {
      factors.add('Missing test coverage');
    }

    return factors;
  }

  /// Generate predictions based on analysis
  static List<String> _generatePredictions(
      double riskScore, double maintenanceBurden, List<String> riskFactors) {
    final predictions = <String>[];

    if (riskScore > 0.8) {
      predictions.add('High probability of bugs in next 6 months');
    } else if (riskScore > 0.6) {
      predictions.add('Moderate bug risk - worth monitoring');
    }

    if (maintenanceBurden > 0.7) {
      predictions.add('Will require significant developer time to maintain');
    }

    if (riskFactors.contains('High coupling to other modules')) {
      predictions.add('Changes may have ripple effects across codebase');
    }

    if (riskFactors.contains('Missing test coverage')) {
      predictions.add('Difficult to refactor safely without tests');
    }

    if (riskFactors.contains('Security vulnerability patterns')) {
      predictions.add('May be target for security exploits');
    }

    return predictions;
  }

  /// Generate recommended actions
  static List<String> _generateRecommendedActions(
      List<String> riskFactors, double riskScore) {
    final actions = <String>[];

    if (riskScore > 0.8) {
      actions.add('URGENT: Schedule refactoring in next sprint');
    }

    if (riskFactors.contains('High cyclomatic complexity')) {
      actions.add('Break down complex methods into smaller functions');
    }

    if (riskFactors.contains('Large file size')) {
      actions.add('Apply facade pattern to split large files');
    }

    if (riskFactors.contains('Missing test coverage')) {
      actions.add('Add unit tests before making changes');
    }

    if (riskFactors.contains('Security vulnerability patterns')) {
      actions.add('Security review required');
    }

    if (riskFactors.contains('Technical debt comments')) {
      actions.add('Address TODO/FIXME comments');
    }

    if (riskFactors.contains('Empty error handling')) {
      actions.add('Implement proper error handling');
    }

    return actions;
  }

  // Helper methods
  static double _min(double a, double b) => a < b ? a : b;
}

class CodeHotspot {
  final String filePath;
  final double riskScore;
  final double maintenanceBurden;
  final double bugLikelihood;
  final double performanceRisk;
  final double securityVulnerabilityRisk;
  final List<String> riskFactors;
  final List<String> predictions;
  final List<String> recommendedActions;

  CodeHotspot({
    required this.filePath,
    required this.riskScore,
    required this.maintenanceBurden,
    required this.bugLikelihood,
    required this.performanceRisk,
    required this.securityVulnerabilityRisk,
    required this.riskFactors,
    required this.predictions,
    required this.recommendedActions,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'risk_score': riskScore,
        'maintenance_burden': maintenanceBurden,
        'bug_likelihood': bugLikelihood,
        'performance_risk': performanceRisk,
        'security_vulnerability_risk': securityVulnerabilityRisk,
        'risk_factors': riskFactors,
        'predictions': predictions,
        'recommended_actions': recommendedActions,
      };
}
