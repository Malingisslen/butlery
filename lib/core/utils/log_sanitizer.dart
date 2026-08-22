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
  /// group id still matches rule 2 of [maskIdentifiers] and arrives as
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

  /// Masks every identifier EMBEDDED in a free-text string.
  ///
  /// The other helpers here take one id and mask it. This one takes a sentence
  /// and finds the ids inside it, which is what an exception message, a
  /// resource path or a log line actually is. Moved here from `AppLogger` so
  /// the crash-report path and the exception classes apply ONE rule rather than
  /// two copies of it — this repo has paid repeatedly for the same decision
  /// spelled twice (BUT-1897).
  ///
  /// Two rules, and rule 1 MUST run first — that is a dependency, not a
  /// preference. Rule 2's lookarounds treat `_` as a boundary, so on a raw
  /// `direct_<a>_<b>` it would mask each half separately and leave
  /// `direct_aBcD***_zZyY***` for the minted-shape test's fixture, destroying
  /// the `direct_#<12 hex>` shape that
  /// `logSafeConversationId` in `functions/src` produces for the same
  /// conversation. Reordering these two breaks that parity — and it does NOT go
  /// unnoticed: five cases across four suites redden, the closest being
  /// `log_sanitizer_test.dart`'s minted-shape test, which asserts that this
  /// chokepoint and [maskConversationId] agree. (The cases that pin the literal
  /// hash call the helper directly and are invariant under a reorder — they are
  /// not the guard here.) Measured by actually swapping them, because the first
  /// version of this sentence claimed the suites stayed green and that was
  /// false in the dangerous direction: it would have told a maintainer the
  /// dependency was unguarded, so a red suite after a reorder reads as noise.
  ///
  /// (It was safe either way while rule 2 was `\b`-anchored, because `\b` does
  /// not fire beside an underscore. Widening the anchors for composite ids is
  /// what made the order load-bearing.)
  ///
  /// Two rules, in order:
  ///
  /// 1. `direct_<a>_<b>` — a DM's id is derived from its two members, so it is
  ///    a social-graph edge, not just an identifier. Hashed via
  ///    [maskConversationId] so one conversation still reads the same across a
  ///    Crashlytics report and a Cloud Functions log.
  ///
  ///    Unbounded halves and a left boundary, both deliberate. Bounding them to
  ///    {20,28} matched only well-formed live ids: a short one (test data, or
  ///    any future id scheme) passed through RAW, and a half LONGER than 28 got
  ///    its tail left behind outside the hash. The left boundary stops the
  ///    `direct_` inside a word like `redirect_` from being hashed as an id.
  ///
  ///    This rule and [maskConversationId] therefore agree on every id of the
  ///    MINTED SHAPE — exactly two segments, any length — rather than only on
  ///    today's 28+28 live ids. They still differ on shapes nothing mints:
  ///    `direct_abc` is hashed by the helper and untouched here, and
  ///    `direct_a_b_c` would have its tail left outside the hash. The single
  ///    mint site is `ConversationMutationModule`, so neither shape exists;
  ///    widening this would mean hashing arbitrary underscore-joined text.
  ///
  /// 2. Any 20-28 character alphanumeric token — the shape of a Firebase uid —
  ///    truncated to its first four characters. A uid is personal data: anyone
  ///    with console access joins it against `users/{uid}` in one step.
  ///
  ///    Bounded by explicit lookarounds rather than by `\b`, and that is the
  ///    difference between covering the case and missing it. `\b` counts `_` as
  ///    a word character, so a COMPOSITE document id built as `<uid>_<suffix>`
  ///    never matched — and those are everywhere: a weekly menu plan is
  ///    `${userId}_${weekKey}`, a retention row is `{uid}_{date}`. The rule was
  ///    written with `\b` first and let
  ///    `AbCdEfGhIjKlMnOpQrStUvWx1234_2026-W34` through whole, in a message
  ///    `base_firebase_repository` really throws.
  static String maskIdentifiers(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'(?<![a-zA-Z0-9_])direct_[a-zA-Z0-9]+_[a-zA-Z0-9]+'),
          (m) => maskConversationId(m.group(0)!),
        )
        .replaceAllMapped(
          RegExp(r'(?<![a-zA-Z0-9])[a-zA-Z0-9]{20,28}(?![a-zA-Z0-9])'),
          (m) => '${m.group(0)!.substring(0, 4)}***',
        );
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
