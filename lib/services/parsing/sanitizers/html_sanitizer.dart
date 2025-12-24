import 'package:butlery/core/utils/logger.dart';

/// Security-focused HTML and content sanitizer.
///
/// Provides protection against:
/// - Script injection attempts
/// - Homoglyph attacks (Cyrillic/Latin confusion)
/// - Malformed HTML that could break parsing
/// - Suspicious URL patterns
class HtmlSanitizer {
  /// Singleton instance.
  static final HtmlSanitizer instance = HtmlSanitizer._();

  HtmlSanitizer._();

  /// Pattern for detecting script injection attempts.
  static final _scriptPatterns = [
    RegExp(r'<script\b', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'on\w+\s*=', caseSensitive: false), // onclick=, onerror=, etc.
    RegExp(r'data:\s*text/html', caseSensitive: false),
    RegExp(r'expression\s*\(', caseSensitive: false), // CSS expression()
    RegExp(r'vbscript:', caseSensitive: false),
  ];

  /// Pattern for detecting potentially malicious URLs.
  static final _suspiciousUrlPatterns = [
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'data:', caseSensitive: false),
    RegExp(r'vbscript:', caseSensitive: false),
  ];

  /// Common Cyrillic homoglyphs that look like Latin characters.
  /// Maps Cyrillic character to Latin equivalent for detection.
  static const _cyrillicHomoglyphs = {
    '\u0430': 'a', // Cyrillic a
    '\u0435': 'e', // Cyrillic e
    '\u043E': 'o', // Cyrillic o
    '\u0440': 'p', // Cyrillic r (looks like p)
    '\u0441': 'c', // Cyrillic s (looks like c)
    '\u0443': 'y', // Cyrillic u (looks like y)
    '\u0445': 'x', // Cyrillic h (looks like x)
    '\u0410': 'A', // Cyrillic A
    '\u0412': 'B', // Cyrillic V (looks like B)
    '\u0415': 'E', // Cyrillic E
    '\u041A': 'K', // Cyrillic K
    '\u041C': 'M', // Cyrillic M
    '\u041D': 'H', // Cyrillic N (looks like H)
    '\u041E': 'O', // Cyrillic O
    '\u0420': 'P', // Cyrillic R (looks like P)
    '\u0421': 'C', // Cyrillic S (looks like C)
    '\u0422': 'T', // Cyrillic T
    '\u0425': 'X', // Cyrillic H (looks like X)
  };

  /// Result of sanitization check.
  SanitizationResult check(String content) {
    final issues = <SanitizationIssue>[];

    // Check for script injection
    for (final pattern in _scriptPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        issues.add(SanitizationIssue(
          type: IssueType.scriptInjection,
          description: 'Script injection pattern detected: ${match.group(0)}',
          position: match.start,
          severity: IssueSeverity.critical,
        ));
      }
    }

    // Check for homoglyphs
    final homoglyphResult = _detectHomoglyphs(content);
    if (homoglyphResult.hasHomoglyphs) {
      issues.add(SanitizationIssue(
        type: IssueType.homoglyph,
        description:
            'Homoglyph characters detected (${homoglyphResult.count} instances)',
        position: homoglyphResult.firstPosition ?? 0,
        severity: IssueSeverity.warning,
      ));
    }

    // Check for null bytes
    if (content.contains('\x00')) {
      issues.add(SanitizationIssue(
        type: IssueType.nullByte,
        description: 'Null byte detected in content',
        position: content.indexOf('\x00'),
        severity: IssueSeverity.critical,
      ));
    }

    // Check for excessively long strings (potential DoS)
    if (content.length > 5000000) {
      // 5MB
      issues.add(const SanitizationIssue(
        type: IssueType.excessiveLength,
        description: 'Content exceeds maximum safe length (5MB)',
        position: 0,
        severity: IssueSeverity.critical,
      ));
    }

    return SanitizationResult(
      isClean: issues.isEmpty ||
          issues.every((i) => i.severity != IssueSeverity.critical),
      issues: issues,
      hasCriticalIssues:
          issues.any((i) => i.severity == IssueSeverity.critical),
    );
  }

  /// Sanitize HTML content for safe parsing.
  ///
  /// Removes potentially dangerous elements while preserving recipe content.
  String sanitize(String html) {
    var result = html;

    // Remove script tags and their content
    result = result.replaceAll(
      RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
          caseSensitive: false),
      '',
    );

    // Remove style tags and their content
    result = result.replaceAll(
      RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
          caseSensitive: false),
      '',
    );

    // Remove event handlers (onclick, onerror, etc.)
    result = result.replaceAll(
      RegExp('\\s+on\\w+\\s*=\\s*["\'][^"\']*["\']', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\s+on\w+\s*=\s*[^\s>]+', caseSensitive: false),
      '',
    );

    // Remove javascript: URLs
    result = result.replaceAll(
      RegExp('href\\s*=\\s*["\']?\\s*javascript:[^"\'\\s>]*',
          caseSensitive: false),
      'href="#"',
    );

    // Remove null bytes
    result = result.replaceAll('\x00', '');

    // Normalize homoglyphs to Latin equivalents
    result = normalizeHomoglyphs(result);

    return result;
  }

  /// Sanitize a URL for safe use.
  String sanitizeUrl(String url) {
    // Check for dangerous protocols
    for (final pattern in _suspiciousUrlPatterns) {
      if (pattern.hasMatch(url)) {
        AppLogger.warning('HtmlSanitizer: Blocked suspicious URL: $url');
        return '';
      }
    }

    // Normalize and clean
    var result = url.trim();

    // Remove null bytes
    result = result.replaceAll('\x00', '');

    // Normalize homoglyphs
    result = normalizeHomoglyphs(result);

    return result;
  }

  /// Sanitize text content (not HTML).
  ///
  /// Use this for recipe text fields like title, ingredients, instructions.
  String sanitizeText(String text) {
    var result = text;

    // Remove null bytes
    result = result.replaceAll('\x00', '');

    // Normalize homoglyphs
    result = normalizeHomoglyphs(result);

    // Remove control characters except newlines and tabs
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    return result;
  }

  /// Normalize homoglyph characters to their Latin equivalents.
  String normalizeHomoglyphs(String text) {
    var result = text;
    for (final entry in _cyrillicHomoglyphs.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Detect homoglyph characters in text.
  _HomoglyphResult _detectHomoglyphs(String text) {
    var count = 0;
    int? firstPosition;

    for (var i = 0; i < text.length; i++) {
      if (_cyrillicHomoglyphs.containsKey(text[i])) {
        count++;
        firstPosition ??= i;
      }
    }

    return _HomoglyphResult(
      hasHomoglyphs: count > 0,
      count: count,
      firstPosition: firstPosition,
    );
  }

  /// Check if content looks like it might be a recipe.
  ///
  /// Returns false for obvious non-recipe content like error pages.
  bool looksLikeRecipeContent(String content) {
    final lowerContent = content.toLowerCase();

    // Check for common recipe indicators
    final recipeIndicators = [
      'ingredient',
      'ingrediens',
      'portion',
      'servings',
      'instructions',
      'gör så här',
      'tillagning',
      'recept',
      'recipe',
      'minuter',
      'minutes',
      'timmar',
      'hours',
    ];

    var indicatorCount = 0;
    for (final indicator in recipeIndicators) {
      if (lowerContent.contains(indicator)) {
        indicatorCount++;
      }
    }

    // At least 2 indicators suggest recipe content
    return indicatorCount >= 2;
  }

  /// Check if content is likely an error page.
  bool looksLikeErrorPage(String content) {
    final lowerContent = content.toLowerCase();

    final errorIndicators = [
      '404',
      'not found',
      'page not found',
      'error',
      'sidan kunde inte hittas',
      'access denied',
      'forbidden',
      '403',
      '500',
      'internal server error',
    ];

    for (final indicator in errorIndicators) {
      if (lowerContent.contains(indicator)) {
        return true;
      }
    }

    return false;
  }
}

/// Result of homoglyph detection.
class _HomoglyphResult {
  final bool hasHomoglyphs;
  final int count;
  final int? firstPosition;

  const _HomoglyphResult({
    required this.hasHomoglyphs,
    required this.count,
    this.firstPosition,
  });
}

/// Result of content sanitization check.
class SanitizationResult {
  /// Whether the content is clean enough to process.
  final bool isClean;

  /// List of issues found.
  final List<SanitizationIssue> issues;

  /// Whether critical security issues were found.
  final bool hasCriticalIssues;

  const SanitizationResult({
    required this.isClean,
    required this.issues,
    required this.hasCriticalIssues,
  });

  @override
  String toString() => 'SanitizationResult(clean: $isClean, '
      'issues: ${issues.length}, critical: $hasCriticalIssues)';
}

/// A specific sanitization issue found in content.
class SanitizationIssue {
  /// Type of issue.
  final IssueType type;

  /// Human-readable description.
  final String description;

  /// Position in content where issue was found.
  final int position;

  /// Severity level.
  final IssueSeverity severity;

  const SanitizationIssue({
    required this.type,
    required this.description,
    required this.position,
    required this.severity,
  });

  @override
  String toString() => 'SanitizationIssue($type at $position: $description)';
}

/// Types of sanitization issues.
enum IssueType {
  /// Script injection attempt.
  scriptInjection,

  /// Homoglyph character (Cyrillic/Latin confusion).
  homoglyph,

  /// Null byte in content.
  nullByte,

  /// Content exceeds safe length.
  excessiveLength,

  /// Suspicious URL pattern.
  suspiciousUrl,
}

/// Severity levels for sanitization issues.
enum IssueSeverity {
  /// Informational, no action needed.
  info,

  /// Warning, content may be suspicious.
  warning,

  /// Critical, content should be rejected.
  critical,
}
