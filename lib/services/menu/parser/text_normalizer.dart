/// Text utilities for [MenuConstraintParser]. Pure functions, zero IO.
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';

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

/// Filler/discourse tokens common in SPOKEN Swedish (voice prompts arrive
/// via on-device transcription). Curated for the menu-prompt domain: every
/// entry is meaningless for constraint parsing, so stripping them from typed
/// prompts too is harmless. Standalone tokens only — matched per-token, never
/// as substrings.
const Set<String> kSpokenFillerWords = {
  'eh',
  'ehm',
  'öh',
  'öhm',
  'hmm',
  'mm',
  'äh',
  'alltså',
  'asså',
  'typ',
  'liksom',
  'ba',
  'va',
};

/// Multi-word spoken fillers, removed before token-level stripping.
const List<String> kSpokenFillerPhrases = ['du vet', 'så att säga'];

/// Correction markers that signal a spoken self-correction
/// ("tre, nej fyra middagar"). Multi-word entries must come first so the
/// alternation prefers them over their single-word suffixes.
const List<String> kCorrectionMarkers = [
  'nej vänta',
  'nej förlåt',
  'eller nej',
  'jag menar',
  'nej',
  'förlåt',
  'vänta',
  'ursäkta',
];

/// Removes spoken filler tokens/phrases from a normalized prompt.
/// Run BEFORE [resolveSelfCorrections] so a filler between the corrected
/// value and its marker ("tre eh nej fyra") doesn't hide the correction.
// Precompiled once — the parser runs per menu generation and per trace
// re-parse; recompiling constant regexes there is pure waste.
final List<RegExp> _fillerPhraseRes = [
  // Word-bounded, not raw substring — "kan du veta mer" must not lose
  // "du ve(ta)". Dart's \b is ASCII-only, hence explicit lookarounds.
  for (final phrase in kSpokenFillerPhrases)
    RegExp('$_noWordBefore${RegExp.escape(phrase)}$_noWordAfter'),
];
final RegExp _whitespaceRe = RegExp(r'\s+');
final RegExp _leadPunctRe = RegExp(r'^[,.–—-]+');
final RegExp _trailPunctRe = RegExp(r'[,.–—-]+$');

String stripSpokenFillers(String input) {
  var s = input;
  for (final re in _fillerPhraseRes) {
    s = s.replaceAll(re, ' ');
  }
  // Whisper attaches punctuation to tokens ("eh," / "liksom."). Compare the
  // punctuation-stripped core, but keep any punctuation of a dropped filler —
  // it may be the comma that separates two clauses.
  final out = <String>[];
  for (final token in s.split(_whitespaceRe)) {
    if (token.isEmpty) continue;
    final lead = _leadPunctRe.stringMatch(token).orEmpty();
    final trail = _trailPunctRe.stringMatch(token).orEmpty();
    if (lead.length + trail.length >= token.length) {
      // Pure punctuation (e.g. the comma a removed phrase left behind).
      out.add(token);
      continue;
    }
    final core = token.substring(lead.length, token.length - trail.length);
    if (kSpokenFillerWords.contains(core)) {
      final remnant = '$lead$trail';
      if (remnant.isNotEmpty) out.add(remnant);
    } else {
      out.add(token);
    }
  }
  return out.join(' ').replaceAll(_whitespaceRe, ' ').trim();
}

final String _correctionMarkerAlt = kCorrectionMarkers
    .map(RegExp.escape)
    .join('|');
const String _correctionSep = r'[\s,–—-]';

// Dart's \b treats å/ä/ö as NON-word characters (ASCII-only \w), so a \b
// anchor silently fails after "två" and matches inside "råtta". These
// explicit lookarounds are the Unicode-safe word boundary for Swedish.
const String _noWordBefore = '(?<![a-zåäö0-9])';
const String _noWordAfter = '(?![a-zåäö0-9])';

/// Resolves spoken self-corrections with a LAST-WINS policy: in
/// "tre, nej fyra middagar" the speaker's final value ("fyra") replaces the
/// retracted one. Deliberate rule (kb-whisper plan, Data/ML panel condition):
/// last mention wins, and ONLY when the retracted and replacing tokens belong
/// to the same vocabulary — a lone "nej" never deletes surrounding content.
///
/// Two correction shapes per vocabulary, restated phrase first:
/// - RESTATED: "tre middagar, nej fyra middagar" / "två middagar, nej en
///   middag" — value + noun on both sides, where the nouns must share a stem
///   (exact backreferences would miss the natural plural→singular shift).
/// - ADJACENT: "tre, nej fyra" — bare value on both sides.
///
/// [exactVocabularies] are matched as whole words only (Swedish count words
/// don't inflect — allowing suffixes let "trevliga" pose as a retraction of
/// "tre" and erase a real count); digits are folded into this alternation so
/// Whisper's inconsistent number rendering ("tre, nej 4") still pairs up.
/// [stemVocabularies] get an [a-zåäö]* suffix allowance so a stem key matches
/// its inflections ("vegetarisk" → "vegetariskt"), mirroring lexiconLookup's
/// tolerance. Pure function — the lexicon stays the caller's concern.
String resolveSelfCorrections(
  String input, {
  List<Iterable<String>> exactVocabularies = const [],
  List<Iterable<String>> stemVocabularies = const [],
}) {
  var s = input;

  // Whisper renders small numbers as words OR digits unpredictably, so all
  // exact (count-like) vocabularies and \d+ form ONE value domain.
  final exactTerms =
      exactVocabularies
          .expand((v) => v)
          .where((t) => t.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  final exactAlt = [r'\d+', ...exactTerms.map(RegExp.escape)].join('|');
  s = _resolveForVocabulary(s, exactAlt, allowSuffix: false);

  for (final vocab in stemVocabularies) {
    final terms = vocab.where((t) => t.trim().isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (terms.isEmpty) continue;
    final alt = terms.map(RegExp.escape).join('|');
    s = _resolveForVocabulary(s, alt, allowSuffix: true);
  }
  return s;
}

String _resolveForVocabulary(
  String input,
  String alt, {
  required bool allowSuffix,
}) {
  final suffix = allowSuffix ? '[a-zåäö]*' : '';
  final value = '$_noWordBefore(?:$alt)$suffix$_noWordAfter';
  final marker = '$_correctionSep*(?:$_correctionMarkerAlt)$_correctionSep+';

  // Restated phrase: group 1 = retracted noun, group 2 = kept text,
  // group 3 = replacing noun. Fires only when the nouns share a stem — the
  // mapper check replaces the regex backreference so "två middagar, nej en
  // middag" (plural→singular) resolves while "tre dagar nej fyra veckor"
  // stays untouched.
  final restated = RegExp(
    '$value\\s+([a-zåäö]+)$_noWordAfter$marker($value\\s+([a-zåäö]+)$_noWordAfter)',
  );
  var s = _replaceUntilStable(
    input,
    restated,
    (m) => _sameStem(m.group(1)!, m.group(3)!) ? m.group(2)! : m.group(0)!,
  );

  // Adjacent: group 1 = kept value.
  final adjacent = RegExp('$value$marker($value)');
  s = _replaceUntilStable(s, adjacent, (m) => m.group(1)!);
  return s;
}

/// True when one word is an inflection of the other (shared stem of ≥4
/// chars): middag/middagar, lunch/luncher — but not dagar/veckor.
bool _sameStem(String a, String b) {
  if (a == b) return true;
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  return shorter.length >= 4 && longer.startsWith(shorter);
}

String _replaceUntilStable(
  String input,
  RegExp re,
  String Function(Match) replace,
) {
  var s = input;
  String prev;
  do {
    prev = s;
    s = s.replaceAllMapped(re, replace);
  } while (s != prev);
  return s;
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
