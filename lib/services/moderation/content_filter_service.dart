import 'package:butlery/core/base/base_service.dart';

/// Client-side profanity filter for Swedish and English content.
/// Word-boundary matching to avoid false positives on substrings.
/// Server-side filtering is deferred — this is baseline trust & safety.
class ContentFilterService extends BaseService {
  @override
  String get serviceName => 'ContentFilterService';

  // Word-boundary regex pattern cache
  late final RegExp _filterPattern;

  ContentFilterService() {
    _filterPattern = _buildPattern();
  }

  /// Check if text contains profanity. Case-insensitive, word-boundary matching.
  bool containsProfanity(String text) {
    if (text.trim().isEmpty) return false;
    return _filterPattern.hasMatch(text.toLowerCase());
  }

  /// Replace profanity with asterisks, preserving word length.
  String filterText(String text) {
    if (text.trim().isEmpty) return text;
    return text.replaceAllMapped(_filterPattern, (match) {
      return '*' * match.group(0)!.length;
    });
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
