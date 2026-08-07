/// How tall a word is DRAWN, versus how big its type actually is.
///
/// A recognizer's bounding box is drawn around ink, not around the font. At one
/// and the same type size, "Fransk omelett" reaches from the cap line to the
/// baseline while the word "ägg" also reaches below it and spans about a
/// quarter more (1.80 against 1.45 — the figure `glyph_metrics_test` pins as
/// 1.24). Every rule comparing one line's height to another's is therefore
/// reading the alphabet unless it divides that out first.
///
/// ## The attainable spans, stated ONCE
///
/// With the constants below, [glyphSpan] returns 0 for a word holding no
/// letters — the caller then keeps the raw box — and otherwise exactly one
/// of six values:
///
///     0     no letters at all ................. '4-5', '123', ''
///     1.0   x-height only ..................... 'ananas'
///     1.35  descender, nothing tall ........... 'gam'
///     1.45  cap or ascender, no descender ..... 'Tomater', 'GRYTA',
///                                               'Provensalska'
///     1.60  uppercase Nordic diacritic ........ 'Ättika', 'ÄPPELKAKA'
///     1.80  tall + descender .................. 'ägg', 'Lägg'
///     1.95  uppercase diacritic + descender ... 'Ägg', 'Ångad'
///
/// `Provensalska` sits on the 1.45 row deliberately: its `P` is a CAPITAL, and
/// capitals take the cap branch before the descender test runs. Anyone
/// re-deriving the 137.9 that `glyph_metrics_test` ASSERTS (= 200 / 1.45), and
/// that `heading_detector_test`'s `realSpread` comment echoes, needs that row
/// to be right.
///
/// 1.15 and 1.50 are unreachable: an uppercase diacritic always implies the
/// tall band. So **everything from 1.60 up clears a 1.50 size bar on glyph
/// inflation alone, while 1.45 and below do not.**
///
/// ## This bounds a WORD, not a line
///
/// These are ink zones for one word. A LINE box carries a second inflation on
/// top, and that one is UNBOUNDED: an axis-aligned box around a tilted line
/// grows with the line's WIDTH, which `OcrWord`'s class doc in
/// `text_layout.dart` gives as the reason per-word measurement exists at all.
/// Both suites stage it — a 200-high box over 70-high words, and a 400-high
/// one. So a raw line box read as a type size is inflated by the glyph term
/// above TIMES an unbounded skew term, and no size bar is safe from it. That
/// is the whole reason `OcrLine.hasMeasuredWords` exists.
///
/// Every other file that needs any of this points HERE rather than restating
/// it. The numbers were written out in five places once, and three of the
/// copies were wrong within a single change.
///
/// Measured on the corpus page this whole layout feature was designed against:
/// its two sibling titles, set in one type, measured 166.5 and 129.0 raw. That
/// gap alone was enough for the page-relative floor in
/// `lib/services/import/layout/heading_detector.dart` (`titleSizeSpread`, 1.10
/// as of 2026-08-07) to reject one of the page's two recipes.
///
/// Same dependency-free discipline as `text_layout.dart` — no Flutter, no
/// `dart:ui`, nothing outside these two files — and for the same reason: stored
/// captures are replayed by `tools/` and by plain `dart test` for years.
library;

/// The vertical span [word] occupies, in units of the font's x-height, or 0
/// when it holds no letters at all (a digit group, an empty string, a stray
/// rule) — the caller then has nothing to divide by and should keep the raw box.
///
/// The x-height band is always 1.0, because a box around ANY word covers it. A
/// capital or a lowercase ascender (`b d f h k l t`) adds [_ascenderRise]; a
/// LOWERCASE descender (`g j p q y`) adds [_descenderDrop]; a lowercase Swedish
/// diacritic (`å ä ö`, and `é è ü`) rises about as high as an ascender, while an
/// UPPERCASE one clears the cap line by [_capDiacriticRise] more again.
///
/// An ALL-CAPS word needs no special case: it spans the cap line to the
/// baseline, which is exactly `1.0 + `[_ascenderRise]. That matters because
/// `TUSENBLADSTÅRTA`, one of the eight component headings that used to split a
/// working recipe in two, must not out-measure a mixed-case title of the same
/// size.
///
/// Capitals do NOT descend, so `Potatis` and `Grädde` are cap-to-baseline like
/// any other capitalised word.
///
/// Deliberately crude and deliberately deterministic: these are typographic
/// constants, not per-font metrics, which a bounding box cannot recover. Being
/// a few percent wrong everywhere is harmless; being 30 % wrong on words with
/// descenders is what broke the detector.
double glyphSpan(String word) {
  var hasLetter = false, hasTall = false;
  var hasDescender = false, hasCapDiacritic = false;

  var lastLetterWasCapital = false;

  for (final c in word.split('')) {
    // A combining mark from [_isModelledMark] belongs to the letter before it
    // and raises the same ink its precomposed form would. Without this an NFD
    // `ägg` decomposes to `a` + U+0308 and measures 33 % tall, while an NFD
    // `TUSENBLADSTÅRTA` loses [_capDiacriticRise] and comes back 10 % tall —
    // straight across `HeadingDetector.titleSizeSpread`. ML Kit returns NFC
    // today, but a stored capture is replayed for years and the project has
    // been bitten by NFC versus NFD on å/ä/ö before.
    if (_isModelledMark(c)) {
      if (!hasLetter) continue;
      hasTall = true;
      if (lastLetterWasCapital) hasCapDiacritic = true;
      continue;
    }

    final lower = c.toLowerCase();
    // A skipped character does not clear `lastLetterWasCapital`, so a mark
    // separated from its capital by a digit would still take the cap rise. No
    // NFD string can produce that; noted so it does not read as intent.
    if (!_letters.contains(lower)) continue;
    hasLetter = true;
    lastLetterWasCapital = c != lower;

    if (c != lower) {
      // A capital reaches the cap line, which sits at about ascender height —
      // and it does NOT descend. Testing `g j p q y` before the case split is
      // how an earlier version made every `Potatis`, `Grädde` and `GRYTA`
      // measure 18 % short, which is the exact defect this file exists to
      // remove.
      hasTall = true;
      if (_lowDiacritics.contains(lower)) hasCapDiacritic = true;
      continue;
    }
    if (_descenders.contains(lower)) hasDescender = true;
    if (_ascenders.contains(lower) || _lowDiacritics.contains(lower)) {
      hasTall = true;
    }
  }

  if (!hasLetter) return 0;

  // The x-height band is UNCONDITIONAL. A box drawn around `lätt` or `GRYTA`
  // still covers it even though no letter stops there — an earlier version
  // added the band only when a plain x-height letter was present, and so
  // measured `Kött` 2.2 times too tall. It also makes an all-caps word fall
  // out of the general case (cap line to baseline = 1.0 + the rise) instead of
  // needing a branch of its own.
  var span = 1.0;
  if (hasTall) span += _ascenderRise;
  if (hasCapDiacritic) span += _capDiacriticRise;
  if (hasDescender) span += _descenderDrop;
  return span;
}

/// The four combining marks that decompose from the letters this model knows —
/// grave, acute, diaeresis, ring — all of which sit ABOVE their letter.
///
/// Deliberately not the whole U+0300–U+036F block, which was the first
/// attempt. That block also holds the marks that sit BELOW the baseline —
/// cedilla U+0327, ogonek, dot below — and raising the tall band for one of
/// those puts the word on a different measurement from its own precomposed
/// twin: an NFD `garçon` spans 1.80 against 1.35, so it measures 25 % SHORTER
/// (equivalently, the precomposed one reads 33 % taller). The load-bearing
/// case is the all-caps one: an NFD `PROVENÇALSKA` SPANS 1.103 times its plain
/// sibling, so it MEASURES 0.906 of it — under the 0.909 floor
/// `HeadingDetector.titleSizeSpread` implies, which drops a real co-title.
/// Span and measurement are reciprocal, and saying "lands at 1.103" without
/// saying WHICH is how the sentence above it got inverted once already.
/// An unmodelled mark is skipped for exactly the reason a precomposed `ç` or
/// `ñ` is: its zone is not modelled here.
bool _isModelledMark(String c) {
  if (c.isEmpty) return false;
  final u = c.codeUnitAt(0);
  return u == 0x0300 || u == 0x0301 || u == 0x0308 || u == 0x030A;
}

/// How far a cap or an ascender rises above the x-height. An all-caps word
/// therefore spans `1.0 + this` — cap line to baseline — with no special case.
const double _ascenderRise = 0.45;

/// How far below the baseline a descender drops.
///
/// 0.35 because it was SWEPT, not because it was guessed. Over `dart run
/// tools/corpus_split_eval.dart --layout`, 0.32–0.38 is a flat optimum — 16 of
/// 48 spreads read correctly at either end, against 14 at 0.20 — and 0.35 is
/// its midpoint rather than an edge. Typographic metrics agree: a descender
/// runs about 0.2 em against an x-height of about 0.5 em.
///
/// **Both earlier values were measured against arithmetic that was wrong**, so
/// neither number transfers. 0.22 was a pure guess; 0.32 was swept while
/// `glyphSpan` still (a) counted an UPPERCASE `P G J Q Y` as descending, which
/// made every `Potatis`/`Grädde`/`GRYTA` measure 18 % short, and (b) dropped the
/// x-height band for any word without a plain x-height letter, which made `Kött`
/// and `lätt` measure 2.2 times too tall. Two reviewers found (a) independently
/// and one found (b). Re-sweeping after the fixes is what turned the layout arm
/// from "breaks 8 working pages" into "breaks none".
const double _descenderDrop = 0.35;

/// How much further an uppercase diacritic (`Å Ä Ö É È Ü`) clears the cap line.
///
/// **Swept, and the corpus cannot see it.** 0.0, 0.08, 0.15 and 0.25 all give
/// byte-identical scores on every axis — no page on the corpus turns on this
/// number. So unlike its two neighbours it is NOT a measured value; it is a
/// typographic one, kept because a Nordic capital genuinely does rise above the
/// cap line and zero would over-measure such a word.
///
/// The case to watch, since no test on this corpus can: an all-caps
/// `TUSENBLADSTÅRTA` spans 1.60 against a plain all-caps sibling's 1.45, a
/// ratio of 1.103 — three thousandths outside
/// `HeadingDetector.titleSizeSpread`. Two co-titles differing only in whether
/// one carries an Å therefore sit exactly on the boundary. If a real cookbook
/// starts losing all-caps titles, look here first.
const double _capDiacriticRise = 0.15;

/// Letters this model knows how to place. Anything else — digits, punctuation,
/// a non-Latin script — is skipped, and a word made only of such characters
/// keeps its raw box.
///
/// Skipping a digit is itself an ASSUMPTION, not a neutral act, and it errs in
/// the DANGEROUS direction — it inflates, never shortens. Lining figures are
/// drawn at about cap height but contribute no span, so `500g` is drawn 1.80
/// and divided by 1.35, coming back 33 % TALL, and so does `3ggr`; an all-digit
/// word keeps its raw box, about 45 % above a normalised neighbour.
/// A quantity-heavy row can therefore median onto an inflated word and read as
/// a heading.
///
/// Left as it is because the corpus sweep shows the spurious-block count
/// unmoved either way, and because the detector refuses a LINE that starts with
/// a digit, or carries a quantity in a RECOGNISED unit
/// (`HeadingDetector._measurement`), before it can be called a heading. Note
/// that is narrower than it sounds: an unlisted unit passes, so `Ugn 200
/// grader`, `Vispa 30 min` and `Sats 4 portioner` are all accepted as titles.
/// (`3ggr` above is the WORD case — as a whole line it starts with a digit
/// and is refused.)
const String _letters = 'abcdefghijklmnopqrstuvwxyzåäöéèüæø';

/// `i` and `j` are deliberately absent, even though their dots sit near the
/// ascender line. Measured both ways over the corpus: including them moves
/// nothing except one more recipe lost, so the simpler model stays.
const String _ascenders = 'bdfhklt';
const String _descenders = 'gjpqy';
const String _lowDiacritics = 'åäöéèü';
