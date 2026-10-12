/// What a new password must be: at least twelve characters, or a phrase of
/// at least three words.
///
/// One rule for every place that sets a password, so the helper text under
/// the field and the check behind the button cannot disagree.
class PasswordRule {
  PasswordRule._();

  static const int minLength = 12;
  static const int minWords = 3;

  /// The shortest phrase accepted. Three one-letter "words" are not a phrase.
  static const int minPhraseLength = 10;

  static bool accepts(String password) {
    if (password.trim().length >= minLength) return true;
    final words = password
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return words >= minWords && password.trim().length >= minPhraseLength;
  }
}
