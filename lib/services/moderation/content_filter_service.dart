import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Result of a `ContentFilterService.ensureClean` check.
///
/// Construct via `ContentFilterResult.clean()` or
/// `ContentFilterResult.rejected(reason)` so callers always handle both.
class ContentFilterResult {
  final bool isClean;

  /// Localized, user-facing reason when rejected; `null` when clean.
  final String? reason;

  /// Field that triggered the rejection (for log/telemetry); `null` when clean.
  final String? fieldName;

  const ContentFilterResult._(this.isClean, this.reason, this.fieldName);

  factory ContentFilterResult.clean() =>
      const ContentFilterResult._(true, null, null);

  factory ContentFilterResult.rejected({
    required String reason,
    required String fieldName,
  }) =>
      ContentFilterResult._(false, reason, fieldName);
}

/// Client-side profanity filter for Swedish and English content.
/// Word-boundary matching to avoid false positives on substrings.
/// Server-side filtering is deferred — this is baseline trust & safety.
///
/// Use `ensureClean(text, fieldName)` as the canonical pre-publish gate on
/// every UGC surface (recipe titles, group names, profile bios, comments,
/// chat messages, cook-snap captions). Validators and services should call
/// this BEFORE the network/Firebase write, not after.
class ContentFilterService extends BaseService {
  @override
  String get serviceName => 'ContentFilterService';

  // Word-boundary regex pattern cache
  late final RegExp _filterPattern;

  ContentFilterService() {
    _filterPattern = _buildPattern();
  }

  /// Check if text contains profanity. Case-insensitive, word-boundary matching.
  /// `_filterPattern` is built with `caseSensitive: false`, so no `.toLowerCase()`
  /// allocation is needed even on multi-KB UGC text fields.
  bool containsProfanity(String text) {
    if (text.trim().isEmpty) return false;
    return _filterPattern.hasMatch(text);
  }

  /// Replace profanity with asterisks, preserving word length.
  String filterText(String text) {
    if (text.trim().isEmpty) return text;
    return text.replaceAllMapped(_filterPattern, (match) {
      return '*' * match.group(0)!.length;
    });
  }

  /// Canonical pre-publish gate. Returns `clean` for empty/whitespace input
  /// (length-required is a separate validator's job) and for profanity-free
  /// text; returns `rejected` with the localized `contentFilterWarning` when
  /// profanity is detected.
  ///
  /// `fieldName` is recorded on the result for log/telemetry only — the
  /// user-facing message is intentionally generic (no field-name leak in the
  /// rejection text) so it works in both inline `errorText` and SnackBar
  /// surfaces without further composition.
  ContentFilterResult ensureClean(String text, {required String fieldName}) {
    if (text.trim().isEmpty) return ContentFilterResult.clean();
    if (!containsProfanity(text)) return ContentFilterResult.clean();
    return ContentFilterResult.rejected(
      reason: AppLocale.current.contentFilterWarning,
      fieldName: fieldName,
    );
  }

  RegExp _buildPattern() {
    final allWords = [..._swedishProfanity, ..._englishProfanity];
    // Escape special regex characters, join with alternation, add word boundaries
    final escaped = allWords.map(RegExp.escape).join('|');
    return RegExp('\\b($escaped)\\b', caseSensitive: false);
  }

  // Swedish profanity — common terms that would violate community guidelines
  static const _swedishProfanity = [
    'fan',
    'jävla',
    'jävlar',
    'helvete',
    'skit',
    'fitta',
    'kuk',
    'hora',
    'bög',
    'knulla',
    'satans',
    'förbannad',
    'horunge',
    'cp',
    'mongo',
    'blansen',
  ];

  // English profanity — common terms
  static const _englishProfanity = [
    'fuck',
    'fucking',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'dick',
    'pussy',
    'cunt',
    'nigger',
    'faggot',
    'retard',
    'whore',
    'slut',
  ];
}
