import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/ocr/glyph_metrics.dart';

/// `glyphSpan` decides how tall a word is DRAWN so that callers can recover how
/// big its TYPE is. It is branchy, it is consumed only through
/// `OcrWord.typeHeight`, and it shipped with two defects that 1087 green tests
/// did not see — an uppercase `P G J Q Y` counted as descending (18 % short on
/// every `Potatis`, `Grädde`, `GRYTA`) and a missing x-height band for words
/// with no plain x-height letter (`Kött` 2.2 times too tall). Both were found by
/// review, not by a test. Hence this file: the function is tested directly, in
/// buckets, by the property that actually matters.
///
/// That property is ONE sentence: two words set in the SAME type must come back
/// with the same span, whatever letters they happen to contain. Every group
/// below is an instance of it.
void main() {
  /// The span of a word set in one nominal type size.
  ///
  /// Assertions compare these to EACH OTHER wherever the claim is about the
  /// zone table, so that the test states the property rather than restating the
  /// constants. Two groups do use literals, deliberately: they assert against
  /// numbers transcribed from a real capture, where the literal is the evidence
  /// and re-deriving it from the table would make the test agree with itself.
  double span(String word) => glyphSpan(word);

  group('words set in one type measure the same', () {
    test('a capital initial does not make a word descend', () {
      // Defect 1, and the reason this file exists. `Potatis` and `Grädde` start
      // with letters that descend in LOWERCASE only; testing the lowercased
      // character before the case split gave them a descender they do not have.
      for (final w in [
        'Potatis',
        'Grädde',
        'Pannkakor',
        'Janssons',
        'Quiche',
      ]) {
        expect(
          span(w),
          equals(span('Tomater')),
          reason: '$w is cap-to-baseline, exactly like Tomater',
        );
      }
    });

    test('an all-caps word does not out-measure a mixed-case one', () {
      // Defect 1 again, in its loudest form: two all-caps titles in one type
      // differing by 22 % would make the detector throw one of them away.
      expect(span('GRYTA'), equals(span('RATATOUILLE')));
      expect(span('GRYTA'), equals(span('Tomater')));
    });

    test('a word with no plain x-height letter keeps the x-height band', () {
      // Defect 2. Every letter in `Kött` and `lätt` stops at the ascender line
      // or above, but the BOX still covers the x-height band beneath them.
      // Dropping it measured these 2.2 times too tall.
      for (final w in ['Kött', 'lätt', 'Kål', 'Håll', 'blött']) {
        expect(span(w), equals(span('Tomater')), reason: w);
      }
    });

    test('a lowercase ascender alone makes a word tall', () {
      // Every other fixture here gets its tall band from a CAPITAL or a
      // diacritic, so emptying `_ascenders` left them all green while `bok`
      // measured 45 % tall. These two are the only words whose tall band comes
      // from a plain lowercase ascender: `bok` discriminates a PARTIAL loss of
      // `b d f h k` (it has no `l` or `t`), `bakelse` the full emptying.
      expect(span('bakelse'), equals(span('Tomater')));
      expect(span('bok'), equals(span('Tomater')));
    });

    test('a lowercase descender really does add depth', () {
      // The control on the two above: normalisation must remove the ALPHABET,
      // not the signal. If every word answered the same the function would be
      // doing nothing and the detector would have nothing to read.
      //
      // Bounded on BOTH sides. The two `greaterThan`s below are satisfied by
      // any positive depth, absurd ones included — measured, `_descenderDrop =
      // 2.0` passes both — and this is the file that owns the constant. (It
      // does NOT pass every one-sided assertion here: the `juice` bound and the
      // motivating-page numbers both redden. An earlier version of this comment
      // claimed it did.)
      expect(span('ägg') / span('Tomater'), closeTo(1.24, 0.02));
      expect(span('ägg'), greaterThan(span('Tomater')));
      expect(span('ananas'), lessThan(span('Tomater')));
      // `juice` descends but reaches no higher than the x-height — the dots on
      // `i` and `j` are NOT modelled as tall. That is a measured choice, not an
      // oversight: adding them changes nothing on the corpus except one more
      // recipe lost. So it sits between the two above, not above both.
      expect(span('juice'), greaterThan(span('ananas')));
      expect(span('juice'), lessThan(span('Tomater')));
    });

    test('an uppercase diacritic clears the cap line', () {
      // `TUSENBLADSTÅRTA` is one of the eight component headings that used to
      // split a working recipe in two — with the Å, which the fixture in
      // `text_layout_test.dart` deliberately spells without.
      // Bounded, not merely signed. The all-caps ratio is the number
      // `_capDiacriticRise`'s own doc names as sitting three thousandths
      // outside the detector's 1.10 floor — so the constant must not be free to
      // drift across it. Measured: `greaterThan` alone lets 0.15 become 0.40.
      expect(
        span('TUSENBLADSTÅRTA') / span('RATATOUILLE'),
        closeTo(1.103, 0.002),
      );
      expect(span('TUSENBLADSTÅRTA'), greaterThan(span('RATATOUILLE')));
      expect(span('Ägg'), greaterThan(span('Tomater')));
    });
  });

  group('the motivating page', () {
    test('glyphs are NOT the remaining error there', () {
      // Word boxes 200 and 133, from the capture of
      // `butlery-corpus/blandat-svart/PXL_20260803_204246157` (which spells the
      // title without its cedilla — that is what the recognizer read, and `ç`
      // is skipped either way).
      //
      // These two words are one heading set in ONE type, so normalisation
      // should bring them together. It does not — it ends them 1.9 apart, wider
      // than the 1.50 their raw boxes showed, and that is the CORRECT
      // direction: `ägg` carries more ink, so at equal type it ought to measure
      // taller, and dividing that out exposes how much shorter its box actually
      // was. The residual error is word WIDTH on a tilted box, not glyphs.
      // `heading_detector_test.dart` pins the consequence — that page's smaller
      // title is still MISSED — and holds the SAME two transcribed numbers in
      // its `realSpread` fixture. Re-shoot or re-recognize the capture and both
      // must move together; nothing links them but this sentence. Do not let this file grow an assertion claiming
      // otherwise; it had one, and it was a tautology (both words span
      // `1.0 + _ascenderRise`, so the ratio was 1.0 for every possible value of
      // every constant here).
      expect(200 / span('Provensalska'), closeTo(137.9, 0.1));
      expect(133 / span('ägg'), closeTo(73.9, 0.1));
    });
  });

  group('nothing to measure', () {
    test('a word with no letters returns zero, not a span', () {
      // The caller keeps the raw box in this case. Answering a span would
      // divide a real height by a made-up number; answering 1.0 would silently
      // claim the box is pure x-height.
      expect(span('4-5'), equals(0));
      expect(span('123'), equals(0));
      expect(span(''), equals(0));
      expect(span('—'), equals(0));
    });

    test('a decomposed diacritic still counts', () {
      // NFD: `a` + U+0308 rather than a precomposed `ä`. ML Kit returns NFC
      // today, but a stored capture is replayed for years and this project has
      // been bitten by NFC-versus-NFD on å/ä/ö before. Without the combining
      // branch these measure 33 % and 10 % tall respectively — and the second
      // lands straight across `HeadingDetector.titleSizeSpread`.
      // Composed with fromCharCode on purpose. Written as a literal, a
      // decomposed and a precomposed a-umlaut are indistinguishable in every
      // editor and diff, so the assertion would compare a string to itself
      // while appearing to test the opposite. (A first attempt used Dart
      // backslash-u escapes and they were flattened into the real bytes before
      // it ever ran, which is the same trap one layer down.)
      final diaeresis = String.fromCharCode(0x0308);
      final ring = String.fromCharCode(0x030A);
      final nfdAgg = 'a${diaeresis}gg';
      final nfdCaps = 'TUSENBLADSTA${ring}RTA';
      expect(
        nfdAgg.length,
        greaterThan('ägg'.length),
        reason: 'premise: the fixture really is decomposed',
      );

      expect(span(nfdAgg), equals(span('ägg')));
      expect(span(nfdCaps), equals(span('TUSENBLADSTÅRTA')));
      // A mark that sits BELOW the baseline must NOT reach the tall branch.
      // The first version of this accepted the whole U+0300-U+036F block, which
      // holds the cedilla — so an NFD 'garcon' measured 33 % taller than its
      // precomposed twin, and an all-caps one landed at 1.103 against a plain
      // sibling, across the detector's floor. Unmodelled marks are skipped for
      // the same reason a precomposed cedilla is.
      final cedilla = String.fromCharCode(0x0327);
      expect(span('garc${cedilla}on'), equals(span('garçon')));
      expect(span('PROVENC${cedilla}ALSKA'), equals(span('PROVENÇALSKA')));

      // A mark arriving BEFORE any letter is dropped rather than attached to
      // whatever follows. Without a word after it the guard is invisible —
      // `span` answers 0 either way — so the second line is what pins it.
      expect(span('${diaeresis}ananas'), equals(span('ananas')));
      // A stray mark with no letter before it is still nothing to measure.
      expect(span(diaeresis), equals(0));
    });

    test('a non-Latin word returns zero rather than a guess', () {
      // Tier 0 is Latin-script only, but a stored capture is replayed for years
      // and nothing stops one holding this. Guessing a zone for a script whose
      // metrics are not modelled here would be worse than declining.
      expect(span('Привет'), equals(0));
      expect(span('日本語'), equals(0));
    });

    test('letters mixed with digits are measured on the letters', () {
      // Not zero: `500g` has a letter, so it is placed. The digits are skipped,
      // which is documented as an assumption rather than a neutral act.
      expect(span('500g'), equals(span('g')));
    });
  });
}
