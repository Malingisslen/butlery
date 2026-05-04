import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/moderation/content_filter_words.dart';

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

  /// Check if text contains profanity. Case-insensitive, word-boundary
  /// matching, with [_normalize] applied first so leetspeak/repeats/diacritics
  /// can't bypass the filter (`F4N`, `fääaan`, `5h1t`, `fuuuck` all match).
  bool containsProfanity(String text) {
    if (text.trim().isEmpty) return false;
    return _filterPattern.hasMatch(_normalize(text));
  }

  /// Replace profanity with asterisks, preserving word length.
  ///
  /// BUT-525: matching runs against the normalized form, but replacement is
  /// applied to the **original** text at the matched span so the user's
  /// original casing/diacritics survive on the surrounding text. We rebuild
  /// the output by walking matches on the normalized string and slicing the
  /// original at the same offsets — character indices align because the
  /// normalizer is length-preserving (it folds 1→1 char, never adds or
  /// removes).
  String filterText(String text) {
    if (text.trim().isEmpty) return text;
    final normalized = _normalize(text);
    final matches = _filterPattern.allMatches(normalized).toList();
    if (matches.isEmpty) return text;
    final buf = StringBuffer();
    var cursor = 0;
    for (final m in matches) {
      buf.write(text.substring(cursor, m.start));
      buf.write('*' * (m.end - m.start));
      cursor = m.end;
    }
    buf.write(text.substring(cursor));
    return buf.toString();
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
    final allWords = [...swedishProfanity, ...englishProfanity];
    // BUT-525: each character is expanded to `c+` so the regex catches
    // run-collapse variants (`fuuuck`, `shitt`, `fffan`) without needing
    // a length-changing normalization step. Word boundaries still anchor
    // matches so `fantastisk` doesn't collide with `fan`.
    final patterns = allWords.map((w) {
      final chars = w.split('').map(RegExp.escape).map((c) => '$c+').join();
      return chars;
    }).join('|');
    // Inputs are lowercased by [_normalize] before matching, so the regex
    // doesn't need `caseSensitive: false`. Words above are stored in
    // canonical lowercase form.
    return RegExp('\\b(?:$patterns)\\b');
  }

  /// BUT-525: fold leetspeak / diacritics / case onto canonical form before
  /// matching. **Length-preserving:** every input rune maps to exactly one
  /// output rune so `filterText` can replace the matched span at the same
  /// offsets in the original input. Run-collapse (`fuuuck` → `fuck`) is
  /// handled at regex-build time via `+` quantifiers — keeping it out of
  /// the normalizer is what preserves the offset-alignment property.
  ///
  /// Deliberately not reusing `SwedishCharacterNormalizer.normalize` or
  /// `text_normalizer.stripDiacritics` — those have a cross-port contract
  /// with TS-side ingredient cascade-retag logic and a narrower diacritic
  /// set. Coupling profanity-filter scope to that contract would force
  /// silent expansion of the canonical-text pipeline. Local helper is
  /// the right call.
  String _normalize(String text) {
    final lower = text.toLowerCase();
    final buf = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final c = lower[i];
      buf.write(_diacriticMap[c] ?? _leetMap[c] ?? c);
    }
    return buf.toString();
  }

  /// Subset of Swedish/Latin diacritics that recurs in profanity stems
  /// after the canonical-form contract is applied. Includes `ä/å/ö/é/ü`
  /// and a few neighbouring Latin variants so users from other locales
  /// don't bypass with `é` / `ú` / `ç`.
  static const Map<String, String> _diacriticMap = {
    'ä': 'a',
    'å': 'a',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ü': 'u',
    'ú': 'u',
    'ù': 'u',
    'í': 'i',
    'ì': 'i',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Common leetspeak digit→letter substitutions. Conservative on purpose:
  /// `1→i` (not `→l`) and no `4→a/h` ambiguity — picked the dominant
  /// reading that drives the most real-world bypass attempts seen on
  /// Apple App Review's UGC test corpus.
  static const Map<String, String> _leetMap = {
    '4': 'a',
    '3': 'e',
    '1': 'i',
    '0': 'o',
    '5': 's',
    '7': 't',
  };
}
