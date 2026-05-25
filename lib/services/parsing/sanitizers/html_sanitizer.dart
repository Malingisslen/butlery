import 'package:butlery/core/utils/logger.dart';
import 'package:html_unescape/html_unescape.dart';

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

  /// Patterns that warrant rejecting content at the security gate instead
  /// of relying on `sanitize()` to silently strip them. `data:text/html`
  /// embeds executable URIs with no legitimate use in recipe content —
  /// always critical.
  static final _scriptPatterns = [
    RegExp(r'data:\s*text/html', caseSensitive: false),
  ];

  /// `<script>` tags warrant surfacing as a WARNING (not critical) so the
  /// security gate logs them without aborting the import. Critical would
  /// regress URL imports — real recipe sites carry analytics/ad scripts
  /// inline. JSON-LD structured data (`application/ld+json`) is exempted
  /// entirely since `sanitize()`'s `preserveWhen` keeps it for schema.org
  /// extraction. The `type=` prefix in the lookahead prevents the
  /// `<script data-note="application/ld+json">alert(1)</script>` bypass:
  /// only a real `type=` attribute carrying `application/ld+json` exempts
  /// the tag.
  static final _scriptTagPattern = RegExp(
    r'''<script\b(?![^>]*\btype\s*=\s*["']?application/ld\+json)''',
    caseSensitive: false,
  );

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

    // Check for critical script-injection patterns (data:text/html etc.)
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

    // Surface non-JSON-LD <script> tags as warnings. sanitize() still
    // strips them, but the warning lets callers audit/log instead of the
    // tags vanishing silently.
    for (final match in _scriptTagPattern.allMatches(content)) {
      issues.add(SanitizationIssue(
        type: IssueType.scriptInjection,
        description:
            'Non-JSON-LD script tag present (will be stripped by sanitize)',
        position: match.start,
        severity: IssueSeverity.warning,
      ));
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
  /// Tags to strip completely (tag + content).
  static const _dangerousBlockTags = [
    'script',
    'style',
    'iframe',
    'embed',
    'object',
    'form',
    'svg',
  ];

  /// Tags to strip (self-closing or tag only, no block content).
  static const _dangerousSelfTags = ['meta', 'base', 'link'];

  String sanitize(String html) {
    // Size guard matching check()'s 5MB threshold
    if (html.length > 5000000) {
      return '';
    }

    var result = html;

    // State-machine approach for dangerous block tags (avoids ReDoS)
    for (final tag in _dangerousBlockTags) {
      result = _removeTagWithContent(
        result,
        tag,
        // Preserve <script type="application/ld+json"> (structured data)
        preserveWhen: tag == 'script'
            ? (openingTag) => openingTag.contains('application/ld+json')
            : null,
      );
    }

    // Remove dangerous self-closing/void tags
    for (final tag in _dangerousSelfTags) {
      result = result.replaceAll(
        RegExp('<$tag\\b[^>]*/?>', caseSensitive: false),
        '',
      );
    }

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

  /// State-machine tag removal: finds opening tag, then scans for
  /// matching close tag. Avoids backtracking-prone regex on nested content.
  ///
  /// If [preserveWhen] is provided, tags whose opening tag matches the
  /// predicate are kept instead of removed (e.g. JSON-LD script blocks).
  static String _removeTagWithContent(
    String html,
    String tagName, {
    bool Function(String openingTag)? preserveWhen,
  }) {
    final openPattern = RegExp('<$tagName\\b', caseSensitive: false);
    final lowerHtml = html.toLowerCase();
    final closeTag = '</$tagName>';
    final result = StringBuffer();
    var searchStart = 0;

    while (searchStart < html.length) {
      final openMatch = openPattern.allMatches(html, searchStart).firstOrNull;
      if (openMatch == null) {
        result.write(html.substring(searchStart));
        break;
      }

      final absOpenStart = openMatch.start;
      final closeIdx = lowerHtml.indexOf(closeTag, absOpenStart);

      // Check if this tag should be preserved
      if (preserveWhen != null) {
        final tagEnd = html.indexOf('>', absOpenStart);
        if (tagEnd >= 0) {
          final openingTag = lowerHtml.substring(absOpenStart, tagEnd + 1);
          if (preserveWhen(openingTag)) {
            // Keep the entire block
            if (closeIdx >= 0) {
              result.write(
                  html.substring(searchStart, closeIdx + closeTag.length));
              searchStart = closeIdx + closeTag.length;
              continue;
            } else {
              result.write(html.substring(searchStart));
              break;
            }
          }
        }
      }

      // Write everything before the tag
      result.write(html.substring(searchStart, absOpenStart));

      if (closeIdx >= 0) {
        searchStart = closeIdx + closeTag.length;
      } else {
        // No close tag found — remove rest of content after open tag
        break;
      }
    }

    return result.toString();
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
  /// Uses contextual patterns to avoid false positives with quantities
  /// like "500 g mjöl" or "400 ml vatten".
  bool looksLikeErrorPage(String content) {
    // If it looks like recipe content, it's not an error page
    if (looksLikeRecipeContent(content)) return false;

    final lowerContent = content.toLowerCase();

    // Contextual error patterns (require error-related context)
    final errorPatterns = [
      RegExp(r'\b(error|http|status)\s*:?\s*404\b'),
      RegExp(r'\bnot\s+found\b'),
      RegExp(r'\bpage\s+not\s+found\b'),
      RegExp(r'\b(error|http|status)\s*:?\s*500\b'),
      RegExp(r'\binternal\s+server\s+error\b'),
      RegExp(r'\bsidan\s+kunde\s+inte\s+hittas\b'),
      RegExp(r'\baccess\s+denied\b'),
      RegExp(r'\bforbidden\b'),
      RegExp(r'\b(error|http|status)\s*:?\s*403\b'),
    ];

    for (final pattern in errorPatterns) {
      if (pattern.hasMatch(lowerContent)) {
        return true;
      }
    }

    return false;
  }

  static final _htmlUnescape = HtmlUnescape();

  static final _scriptPattern = RegExp(
    r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
    caseSensitive: false,
  );
  static final _stylePattern = RegExp(
    r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
    caseSensitive: false,
  );
  static final _blockElementPattern = RegExp(
    r'<(?:br|p|div|li|tr|h[1-6])[^>]*>',
    caseSensitive: false,
  );
  static final _tagPattern = RegExp(r'<[^>]+>');
  static final _tabPattern = RegExp(r'\t+');
  static final _multiSpacePattern = RegExp(r' +');
  static final _excessNewlinePattern = RegExp(r'\n{3,}');

  /// Strip HTML to plain text with entity decoding and whitespace normalization.
  ///
  /// Removes script/style blocks, replaces block elements with newlines,
  /// strips remaining tags, decodes HTML entities, and normalizes whitespace.
  static String stripToPlainText(String html) {
    var text =
        html.replaceAll(_scriptPattern, '').replaceAll(_stylePattern, '');

    text = text.replaceAll(_blockElementPattern, '\n');
    text = text.replaceAll(_tagPattern, '');
    text = _htmlUnescape.convert(text);

    return text
        .replaceAll(_tabPattern, ' ')
        .replaceAll(_multiSpacePattern, ' ')
        .replaceAll(_excessNewlinePattern, '\n\n')
        .trim();
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
