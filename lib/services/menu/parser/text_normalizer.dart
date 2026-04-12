/// Text utilities for [MenuConstraintParser]. Pure functions, zero IO.
library;

/// Normalizes a Swedish prompt for matching: lowercase, collapse whitespace,
/// strip trailing punctuation. Diacritics are preserved here — diacritic
/// stripping is a separate fallback step done by [stripDiacritics].
String normalize(String input) {
  var s = input.toLowerCase().trim();
  // Strip ALL sentence punctuation (periods, bangs, questions) — they're
  // never meaningful for Swedish meal-planning parse.
  s = s.replaceAll(RegExp(r'[.!?]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Replaces Swedish diacritic characters with their bare ASCII counterparts.
/// Used as a fallback when an exact lookup misses (handles "vagansk" → "vegansk"
/// after the original lookup fails).
String stripDiacritics(String input) {
  return input
      .replaceAll('å', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ü', 'u');
}

/// Strips polite preamble tokens from the head of the prompt.
/// Multi-word entries (e.g. "kan du") are matched longest-first.
String stripPolitePreamble(String input, Iterable<String> preambleWords) {
  var s = input;
  // Sort longest-first so "kan du" wins over "kan".
  final sorted = preambleWords.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  bool changed = true;
  while (changed) {
    changed = false;
    for (final word in sorted) {
      if (s.startsWith('$word ') || s.startsWith('$word,') || s == word) {
        s = s.substring(word.length).trimLeft();
        if (s.startsWith(',')) s = s.substring(1).trimLeft();
        changed = true;
        break;
      }
    }
  }
  return s;
}

/// Levenshtein distance ≤ 1 fallback lookup. Returns the canonical value
/// when exactly one candidate is within edit distance 1, or null otherwise.
///
/// Only call this on tokens with length ≥ 6 — shorter tokens have too many
/// false positives. The cost is O(candidates × token_length); fine for
/// per-category maps under 100 entries (sub-millisecond on a modern device).
String? levenshtein1Lookup(String token, Map<String, String> candidates) {
  if (token.length < 6) return null;
  String? match;
  for (final key in candidates.keys) {
    if ((key.length - token.length).abs() > 1) continue;
    if (_within1(token, key)) {
      if (match != null) return null; // ambiguous — bail
      match = candidates[key];
    }
  }
  return match;
}

/// True iff Levenshtein distance between [a] and [b] is ≤ 1.
bool _within1(String a, String b) {
  if (a == b) return true;
  final la = a.length;
  final lb = b.length;
  if ((la - lb).abs() > 1) return false;

  if (la == lb) {
    // Single substitution allowed.
    int diffs = 0;
    for (int i = 0; i < la; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
        diffs++;
        if (diffs > 1) return false;
      }
    }
    return true;
  }

  // One insertion: walk both pointers, allow exactly one skip in the longer.
  final shorter = la < lb ? a : b;
  final longer = la < lb ? b : a;
  int i = 0, j = 0;
  bool skipped = false;
  while (i < shorter.length && j < longer.length) {
    if (shorter.codeUnitAt(i) == longer.codeUnitAt(j)) {
      i++;
      j++;
    } else {
      if (skipped) return false;
      skipped = true;
      j++;
    }
  }
  return true;
}
