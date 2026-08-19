import 'package:butlery/core/utils/crypto_utils.dart';

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
    final maskedDomain = lastDot > 0
        ? '***${domainPart.substring(lastDot)}'
        : '***';

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

  /// Masks a phone number for safe logging.
  /// Example: "+46701234567" -> "+467***4567"
  static String maskPhoneNumber(String? phone) {
    if (phone == null) return 'null';
    if (phone.isEmpty) return '[empty]';
    if (phone.length <= 4) return '***';
    return '${phone.substring(0, 4)}***${phone.substring(phone.length - 4)}';
  }

  /// Masks a conversation id for safe logging.
  ///
  /// A DIRECT conversation's id is derived from its two members —
  /// `direct_<uidA>_<uidB>` — so logging it raw prints two user ids in clear
  /// text. A group id is an opaque auto-id and carries nothing, so it passes
  /// through unchanged here.
  ///
  /// "Unchanged here" is the honest limit: on the Crashlytics path a 20-char
  /// group id still matches `AppLogger`'s bare-token rule and arrives as
  /// `abcd***`. Harmless for privacy, but it means a group id does NOT read
  /// identically in a crash report and a Cloud Functions log. Only the direct
  /// ids do, and that parity is pinned by a literal in both languages' tests.
  ///
  /// Mirrors `logSafeConversationId` in
  /// `functions/src/messaging/enforce-group-minor-membership.ts`, deliberately
  /// down to the `direct_#` shape and the 12-char SHA-256 prefix, so one
  /// conversation reads the same in a Crashlytics report and a Cloud Functions
  /// log. Change one and you must change the other, or correlating an incident
  /// across the two stops working.
  ///
  /// Hashed rather than blanked (`direct_***`) on purpose: these are ERROR
  /// logs, and being able to tell "this one conversation failed nine times"
  /// from "nine conversations failed once" is the whole reason the id is in the
  /// message. A stable hash keeps that and reveals neither uid.
  static String maskConversationId(String? conversationId) {
    if (conversationId == null) return 'null';
    if (conversationId.isEmpty) return '[empty]';
    if (!conversationId.startsWith('direct_')) return conversationId;
    return 'direct_#${CryptoUtils.sha256Hash(conversationId).substring(0, 12)}';
  }

  /// Masks a display name for safe logging.
  /// Example: "Anna Svensson" -> "An***"
  static String maskDisplayName(String? name) {
    if (name == null) return 'null';
    if (name.isEmpty) return '[empty]';
    if (name.length <= 2) return '${name[0]}***';
    return '${name.substring(0, 2)}***';
  }
}

/// Extension methods for convenient PII masking.
extension LogSanitizationExtensions on String? {
  /// Masks email for safe logging.
  String get maskedEmail => LogSanitizer.maskEmail(this);

  /// Masks userId for safe logging.
  String get maskedUserId => LogSanitizer.maskUserId(this);

  /// Masks a conversation id for safe logging (BUT-1872).
  String get maskedConversationId => LogSanitizer.maskConversationId(this);

  /// Masks phone number for safe logging.
  String get maskedPhone => LogSanitizer.maskPhoneNumber(this);

  /// Masks display name for safe logging.
  String get maskedName => LogSanitizer.maskDisplayName(this);
}
