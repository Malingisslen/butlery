/// Log sanitization utilities for PII protection in logs and exports.
/// Provides consistent masking patterns for sensitive data like emails
/// and user IDs that should not appear in production logs.
class LogSanitizer {
  LogSanitizer._(); // Private constructor - utility class

  /// Masks an email address for safe logging.
  /// Example: "user@example.com" -> "use***@***.com"
  /// Returns "null" for null input, "[empty]" for empty strings.
  static String maskEmail(String? email) {
    if (email == null) return 'null';
    if (email.isEmpty) return '[empty]';

    final atIndex = email.indexOf('@');
    if (atIndex < 0) return '***@invalid';

    final localPart = email.substring(0, atIndex);
    final domainPart = email.substring(atIndex + 1);

    // Show first 3 chars of local part (or less if shorter)
    final visibleLocal = localPart.length <= 3
        ? '${localPart[0]}**'
        : '${localPart.substring(0, 3)}***';

    // Show TLD only (e.g., ".com")
    final lastDot = domainPart.lastIndexOf('.');
    final maskedDomain =
        lastDot > 0 ? '***${domainPart.substring(lastDot)}' : '***';

    return '$visibleLocal@$maskedDomain';
  }

  /// Truncates userId to first 8 characters for safe logging.
  /// Returns "null" for null input, "[empty]" for empty strings.
  static String maskUserId(String? userId) {
    if (userId == null) return 'null';
    if (userId.isEmpty) return '[empty]';
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 8)}...';
  }
}

/// Extension methods for convenient PII masking.
extension LogSanitizationExtensions on String? {
  /// Masks email for safe logging.
  String get maskedEmail => LogSanitizer.maskEmail(this);

  /// Masks userId for safe logging.
  String get maskedUserId => LogSanitizer.maskUserId(this);
}
