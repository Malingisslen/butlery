/// The one Unicode-safe word boundary for Swedish regex matching.
///
/// Dart's `\b` is ASCII-only — `\w` is `[A-Za-z0-9_]`, so å/ä/ö count as
/// NON-word characters. That breaks Swedish token matching in both directions:
///
/// - **Missing boundary.** A trailing `\b` never fires after "två" or "påse",
///   so a `\b`-wrapped token silently matches nothing.
/// - **Phantom boundary.** A single-letter token borders å/ä/ö as if it stood
///   alone, so `\bl\b` matches inside "kål", "mjöl" and "öl", and `\bst\b`
///   matches inside "höst".
///
/// Both failures are silent — the regex compiles and simply decides wrong — so
/// the boundary is spelled out as an explicit lookaround everywhere instead.
/// Four call sites had hand-rolled the same two strings before this became
/// shared (BUT-1691).
///
/// The character class is lowercase-only by design: callers lowercase the
/// subject (or compile case-insensitively) before matching.
class SwedishWordBoundary {
  const SwedishWordBoundary._();

  /// Characters that count as "still inside the same word".
  static const String letters = 'a-zåäö0-9';

  /// Negative lookbehind — the match must not continue a word to its left.
  static const String before = '(?<![$letters])';

  /// Negative lookahead — the match must not continue into a word to its right.
  static const String after = '(?![$letters])';

  /// [before] with [extraLetters] folded into the class, for callers that must
  /// also exclude loan-word characters — e.g. `é`, so a `fil` rule does not
  /// fire inside "filé".
  static String beforeWith(String extraLetters) =>
      extraLetters.isEmpty ? before : '(?<![$letters$extraLetters])';

  /// [after] with [extraLetters] folded in. See [beforeWith].
  static String afterWith(String extraLetters) =>
      extraLetters.isEmpty ? after : '(?![$letters$extraLetters])';

  /// [pattern] bounded on both sides. The pattern is wrapped in a
  /// non-capturing group so a top-level alternation binds inside the
  /// boundaries rather than swallowing them.
  static String bounded(String pattern, {String extraLetters = ''}) =>
      '${beforeWith(extraLetters)}(?:$pattern)${afterWith(extraLetters)}';

  /// Compiled [bounded] pattern.
  static RegExp boundedRegExp(
    String pattern, {
    String extraLetters = '',
    bool caseSensitive = true,
  }) => RegExp(
    bounded(pattern, extraLetters: extraLetters),
    caseSensitive: caseSensitive,
  );
}
