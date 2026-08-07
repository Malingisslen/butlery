import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// The whole value of this model is that a line INDEX addresses a line of the
/// produced text. Every test here exists to pin that, or to pin the one signal
/// the model adds over a plain string: type size.
void main() {
  OcrWord word(String t, double h, {double x = 0}) => OcrWord(
    text: t,
    box: LayoutBox(left: x, top: 0, width: t.length * h * 0.5, height: h),
  );

  OcrLine line(String text, {required double height, int words = 5}) {
    final parts = text.trim().isEmpty
        ? <String>[]
        : List.generate(words, (i) => 'w$i');
    return OcrLine(
      text: text,
      box: LayoutBox(left: 0, top: 0, width: 100, height: height),
      words: parts.map((p) => word(p, height)).toList(),
    );
  }

  /// A line the way a recognizer actually hands it over: per-word heights that
  /// vary, and a LINE box that is measured separately — on a skewed photo the
  /// line box is inflated by the line's WIDTH, so it must be settable
  /// independently of the type size, or the fixture cannot tell the two apart.
  OcrLine measured(
    String text,
    List<double> wordHeights, {
    required double boxHeight,
  }) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    return OcrLine(
      text: text,
      box: LayoutBox(
        left: 0,
        top: 0,
        width: text.length * 18,
        height: boxHeight,
      ),
      words: [
        for (var i = 0; i < wordHeights.length; i++)
          word(i < tokens.length ? tokens[i] : 'w$i', wordHeights[i]),
      ],
    );
  }

  /// Four lines of running text off a real spread — used wherever a test needs
  /// "enough body lines to be a baseline" without inventing page shapes.
  const prose = [
    'Lägg kokta, skalade 8-minuters-ägg',
    'i en ratatouille eller en fransk',
    'servera med bröd till eller med råris',
    'Räkna med 4-5 ägg för 2 personer',
  ];

  group('OcrLine.typeHeight', () {
    test('is the MEDIAN word height, not the line box', () {
      // The line box is deliberately wrong here: on a skewed photo an
      // axis-aligned box around a tilted line grows with the line's WIDTH, so
      // trusting it makes long body lines look like headings.
      final l = OcrLine(
        text: 'Provençalska ägg',
        box: const LayoutBox(left: 0, top: 0, width: 900, height: 400),
        words: [word('Provençalska', 70), word('ägg', 70)],
      );
      // Not 70: a word's height is divided by the vertical zones its glyphs
      // occupy (see `OcrWord.typeHeight`). These two words do NOT share a span
      // — 'ägg' descends and 'Provençalska' does not, its 'P' being a capital —
      // so an even-count median averages their two measurements. The point of
      // the test is the line BOX at 400 playing no part, so the expectation is
      // stated as those measurements rather than as a constant that would
      // silently re-encode the zone table.
      final expected =
          (word('Provençalska', 70).typeHeight + word('ägg', 70).typeHeight) /
          2;
      expect(l.typeHeight, equals(expected));
      expect(l.typeHeight, lessThan(100));
    });

    test('one mis-segmented giant word does not drag the line up', () {
      // OCR merging a glyph with the line above produces exactly this. A mean
      // would answer 130; the median holds the line at body size.
      final l = OcrLine(
        text: 'i en ratatouille eller en fransk grönsaksröra',
        box: const LayoutBox(left: 0, top: 0, width: 900, height: 70),
        words: [word('i', 68), word('en', 70), word('RATATOUILLE', 320)],
      );
      expect(l.typeHeight, equals(70));
    });

    test('falls back to the line box only when word boxes are absent', () {
      final l = OcrLine(
        text: 'no words',
        box: LayoutBox(left: 0, top: 0, width: 100, height: 42),
      );
      expect(l.typeHeight, equals(42));
    });

    test('averages the two middle words when the count is EVEN', () {
      // Word boxes arrive in reading order, not sorted by height, and an even
      // count has no single middle. Both halves matter: picking one middle
      // element answers 78 here, and averaging without sorting answers 61.
      final l = OcrLine(
        text: 'Räkna med 4-5 ägg',
        box: const LayoutBox(left: 0, top: 0, width: 900, height: 70),
        words: [
          word('Räkna', 80),
          word('med', 62),
          word('4-5', 60),
          word('ägg', 78),
        ],
      );
      // Sorted by NORMALISED height, the two middle words are 'ägg' and
      // 'Räkna'; 'med' is lowest and the digit group '4-5' highest (no letters,
      // so it keeps its raw box). Averaging without sorting, or picking one
      // middle element, both answer something else.
      final expected =
          (word('ägg', 78).typeHeight + word('Räkna', 80).typeHeight) / 2;
      expect(l.typeHeight, equals(expected));
    });
  });

  group('OcrWord.typeHeight normalises for glyphs', () {
    test('two words at the same type size measure the same', () {
      // The defect this exists for. At ONE type size a word that descends and
      // carries an umlaut draws MORE ink than one that does neither, so its box
      // is taller — 'ägg' against 'omelett' by about a quarter. A rule
      // comparing raw heights reads that as two different headings.
      //
      // The heights below are therefore in the ratio of the two words' zone
      // spans, which is what "the same type size" MEANS for a box drawn around
      // ink. (An earlier version of this test used 166.5/129 — the two LINE
      // heights off the real capture — applied to two words that share a span.
      // That pair is not a same-type-size pair at all, and the assertion only
      // passed because `glyphSpan` was miscounting a capital 'P' as a
      // descender.)
      final descending = OcrWord(
        text: 'ägg',
        box: const LayoutBox(left: 0, top: 0, width: 120, height: 180),
      );
      final plain = OcrWord(
        text: 'omelett',
        box: const LayoutBox(left: 0, top: 0, width: 300, height: 145),
      );

      expect(
        descending.box.height / plain.box.height,
        greaterThan(1.2),
        reason: 'raw boxes disagree by more than a fifth',
      );
      // Must land well under `HeadingDetector.titleSizeSpread`
      // (`lib/services/import/layout/heading_detector.dart`, 1.10 as of
      // 2026-08-07) or two sibling titles read as two different sizes. Nothing
      // enforces that cross-file number; importing the detector into the page
      // model's own test would be the wrong layering.
      //
      // Bounded on BOTH sides on purpose. A one-sided `lessThan` is satisfied
      // by any descender depth above the true one, including absurd ones —
      // measured, `_descenderDrop = 2.0` passes it while inverting the pair.
      final ratio = descending.typeHeight / plain.typeHeight;
      expect(ratio, lessThan(1.05));
      expect(ratio, greaterThan(0.95));
    });

    test('an ALL-CAPS word is not mistaken for a bigger one', () {
      // 'TUSENBLADSTÅRTA' set as a component heading was one of the eight false
      // splits. An all-caps word has no x-height band at all: its box spans cap
      // to baseline, so at the SAME type size it out-measures a lowercase word
      // that reaches neither above nor below the x-height by about the cap
      // ratio — which is why the two raw heights below differ by design.
      final caps = OcrWord(
        text: 'TUSENBLADSTARTA',
        box: const LayoutBox(left: 0, top: 0, width: 400, height: 145),
      );
      final lowercase = OcrWord(
        text: 'ananas',
        box: const LayoutBox(left: 0, top: 0, width: 300, height: 100),
      );

      expect(caps.typeHeight / lowercase.typeHeight, closeTo(1.0, 0.05));
    });

    test('a word with no letters keeps its raw box', () {
      // '4-5', '½', a stray rule. There is no glyph zone to divide by, and
      // answering zero would make it the smallest thing on every page.
      final digits = OcrWord(
        text: '4-5',
        box: const LayoutBox(left: 0, top: 0, width: 60, height: 60),
      );
      expect(digits.typeHeight, equals(60));
    });

    test('a genuinely larger heading still measures larger', () {
      // The control. Normalisation must remove the ALPHABET, not the signal —
      // if it flattened everything the detector would have nothing to read.
      //
      // TWO DIFFERENT WORDS deliberately. With the same string on both sides
      // the ratio is `150/70` for any implementation of the shape
      // `height / f(text)`, whatever `f` returns — measured, that version
      // reddened under none of 14 mutants including no-normalisation itself.
      final heading = OcrWord(
        text: 'Pannkakor',
        box: const LayoutBox(left: 0, top: 0, width: 400, height: 150),
      );
      final bodyWord = OcrWord(
        text: 'omelett',
        box: const LayoutBox(left: 0, top: 0, width: 200, height: 70),
      );
      expect(
        heading.typeHeight / bodyWord.typeHeight,
        closeTo(150 / 70, 0.001),
      );
    });

    test('a word with no plain x-height letter is not read as huge', () {
      // Every letter in `Kött` stops at the ascender line or above, but the box
      // still covers the x-height band beneath them. Dropping that band made
      // this measure 2.2 times its neighbour, which is worse than the defect
      // the whole file was written to fix. Bucket coverage of `glyphSpan`
      // itself lives in `glyph_metrics_test.dart`.
      final tricky = OcrWord(
        text: 'Kött',
        box: const LayoutBox(left: 0, top: 0, width: 200, height: 100),
      );
      final plain = OcrWord(
        text: 'Tomater',
        box: const LayoutBox(left: 0, top: 0, width: 300, height: 100),
      );
      expect(tricky.typeHeight, equals(plain.typeHeight));

      // The ROUTING control, and it needs two words that DISAGREE on the axis
      // being routed. The pair above both span 1.45, so removing normalisation
      // from `OcrWord.typeHeight` altogether leaves them equal and the
      // assertion green — it pins the x-band and nothing else. `ägg` descends,
      // so at the same box height it must measure shorter than `Kött`, and an
      // unnormalised `typeHeight` would report the two as identical.
      final descending = OcrWord(
        text: 'ägg',
        box: const LayoutBox(left: 0, top: 0, width: 120, height: 100),
      );
      expect(tricky.typeHeight, greaterThan(descending.typeHeight));
    });
  });

  group('OcrLine.wordCount', () {
    test(
      'counts boxes when present, whitespace tokens when they are absent',
      () {
        expect(
          line('Fransk omelett', height: 70, words: 5).wordCount,
          equals(5),
        );

        // A provider that returns lines but no word geometry is the degraded
        // case the body-line filter still has to work under. Padding and runs of
        // whitespace must not inflate the count into "this is running text".
        final noBoxes = OcrLine(
          text: '  Räkna med  4-5 ägg  ',
          box: LayoutBox(left: 0, top: 0, width: 900, height: 70),
        );
        expect(noBoxes.wordCount, equals(4));

        // `''.split(...)` yields [''], so a blank line would otherwise report
        // ONE word — and one word is the heading-shaped case this signal
        // exists to name.
        final blank = OcrLine(
          text: '   ',
          box: LayoutBox(left: 0, top: 0, width: 900, height: 70),
        );
        expect(blank.wordCount, equals(0));
      },
    );
  });

  group('PageLayout.bodyTypeHeight', () {
    test('ignores short lines, so headings cannot set the baseline', () {
      // Four body lines around 70 plus two big short headings. The body
      // heights are deliberately DISTINCT and out of order: with the headings
      // counted the baseline answers 73, and taking the median without sorting
      // answers 69, so only the shipped filter answers 70. If the headings
      // counted, they would stop looking like headings — the signal would eat
      // itself.
      final page = PageLayout(
        lines: [
          line('Provençalska ägg', height: 160, words: 2),
          line('en lång rad brödtext som fortsätter', height: 74),
          line('ännu en lång rad brödtext', height: 66),
          line('Fransk omelett', height: 130, words: 2),
          line('tredje raden brödtext här', height: 72),
          line('fjärde raden brödtext här', height: 68),
        ],
      );
      expect(page.bodyTypeHeight, equals(70));
    });

    test('a line needs four words before it counts as running text', () {
      // Declining to judge is the contract, and this is the threshold that
      // decides it. A three-word line is a label, a portion count or OCR
      // noise; treating it as body text would let short lines set the
      // baseline that short lines are supposed to be measured against.
      PageLayout pageOf(int wordsPerLine) => PageLayout(
        lines: [
          for (final t in prose) line(t, height: 70, words: wordsPerLine),
        ],
      );

      expect(pageOf(3).bodyTypeHeight, isNull);
      expect(pageOf(4).bodyTypeHeight, equals(70));
    });

    test('three body lines are not a baseline, four are', () {
      // The other half of "decline rather than guess": a median over three
      // lines is an accident, and a caller that treated it as a baseline would
      // split a page on noise.
      PageLayout pageOf(int n) => PageLayout(
        lines: [for (final t in prose.take(n)) line(t, height: 70)],
      );

      expect(pageOf(3).bodyTypeHeight, isNull);
      expect(pageOf(4).bodyTypeHeight, equals(70));
    });

    test('one badly measured line does not move the page baseline', () {
      // A whole line mis-measured (OCR swallowing the line above) is the page
      // -level version of the mis-segmented word. A mean baseline would answer
      // 133 and call every real heading body text.
      final page = PageLayout(
        lines: [
          line(prose[0], height: 70),
          line(prose[1], height: 320),
          line(prose[2], height: 70),
          line(prose[3], height: 72),
        ],
      );
      expect(page.bodyTypeHeight, equals(71));
    });

    test('a page with no word boxes at all still measures from line boxes', () {
      // The degraded provider: lines but no per-word geometry. The body filter
      // has to fall back to counting the text's own words, or the whole page
      // reads as "no body lines" and the caller declines on a usable page.
      final page = PageLayout(
        lines: [
          for (var i = 0; i < prose.length; i++)
            OcrLine(
              text: prose[i],
              box: LayoutBox(left: 0, top: 0, width: 900, height: 68 + i * 2),
            ),
        ],
      );
      expect(page.bodyTypeHeight, equals(71));
    });

    test('the real page that motivated this model separates cleanly', () {
      // Line type sizes measured from butlery-corpus/blandat-svart/
      // PXL_20260803_204246157 — a prose spread with NO ingredient list, where
      // every text rule fails and the two titles are the only lines over 100.
      //
      // The per-word spread around each measured median, the inflated LINE
      // boxes on the long body lines, and the one mis-segmented word are
      // constructed — they are the photo conditions this model exists to
      // survive, and without them the fixture is answered identically by
      // reading the line box (a body baseline of 172.5, no headings found at
      // all) or by taking the mean (which promotes a body line to a heading).
      final page = PageLayout(
        lines: [
          measured('Provençalska ägg', [165, 169], boxHeight: 172),
          measured(
            'Lägg kokta, skalade 8-minuters-ägg',
            [70, 74, 71, 73, 72],
            boxHeight: 168,
          ),
          measured(
            'i en ratatouille eller en fransk',
            [68, 70, 69, 71, 320],
            boxHeight: 175,
          ),
          measured(
            'servera med bröd till eller med råris',
            [73, 75, 74, 76, 72],
            boxHeight: 180,
          ),
          measured('Fransk omelett', [127, 131], boxHeight: 134),
          measured(
            'Få saker är så lättlagade som en',
            [66, 68, 67, 69, 65],
            boxHeight: 165,
          ),
          measured(
            'blir omeletten om man inte vispar',
            [67, 69, 68, 70, 66],
            boxHeight: 170,
          ),
          measured(
            'Räkna med 4-5 ägg för 2 personer',
            [73, 75, 74, 76, 72],
            boxHeight: 178,
          ),
        ],
      );
      final body = page.bodyTypeHeight!;
      final headings = page.lines.where((l) => l.typeHeight >= body * 1.5);
      expect(
        headings.map((l) => l.text),
        equals(['Provençalska ägg', 'Fransk omelett']),
      );
    });
  });

  group('a DECODED page with no measurements declines to judge', () {
    // These go through fromJson on purpose. Every other degraded-page fixture
    // in this file is CONSTRUCTED with a real line box, so it exercises the one
    // path nothing produces and skips the only path anything can currently
    // reach the model by.
    PageLayout decoded(List<Map<String, dynamic>> lines) =>
        PageLayout.fromJson({'lines': lines});

    test('a fully unmeasured page yields no baseline at all', () {
      // With the zero heights left in the sample this answered 0.0, and every
      // `typeHeight >= body * k` rule then said TRUE for every line on the page
      // — the guard failing on exactly the event it exists for.
      final page = decoded([
        for (final t in prose) {'text': t},
      ]);

      expect(page.lines, hasLength(4));
      expect(page.bodyTypeHeight, isNull);
    });

    test('unmeasured lines are dropped from the sample, not counted as 0', () {
      // The measured heights are DISTINCT and the zeros outnumber nothing by
      // accident: with four identical 70s the two zeros sort below the middle
      // pair and never touch an even median, so the fixture answered 70 with
      // the defect live. Measured 66/70/72/74 plus two zeros: keeping the
      // zeros gives 68 (the median slides down two places), dropping them
      // gives 71. Only the shipped filter answers 71.
      Map<String, dynamic> withWords(String t, int h) => {
        'text': t,
        'words': [
          for (var i = 0; i < 5; i++) {'t': 'w', 'h': h, 'w': 30},
        ],
      };
      final page = decoded([
        withWords(prose[0], 66),
        withWords(prose[1], 70),
        {'text': 'en orad rad utan matt alls'},
        withWords(prose[2], 72),
        {'text': 'annu en orad rad utan matt'},
        withWords(prose[3], 74),
      ]);

      expect(page.bodyTypeHeight, equals(71));
    });

    test('too few MEASURED lines declines, even with plenty of lines', () {
      // The line count is not the sample size. Six lines of which two carry
      // measurements is still a two-line sample, and two is not a baseline.
      final page = decoded([
        {
          'text': prose[0],
          'words': [
            for (var i = 0; i < 5; i++) {'t': 'w', 'h': 70, 'w': 30},
          ],
        },
        {
          'text': prose[1],
          'words': [
            for (var i = 0; i < 5; i++) {'t': 'w', 'h': 70, 'w': 30},
          ],
        },
        {'text': prose[2]},
        {'text': prose[3]},
      ]);

      expect(page.lines, hasLength(4));
      expect(page.bodyTypeHeight, isNull);
    });
  });

  group('the text is DERIVED from the lines', () {
    test('a page joins its own lines with newlines', () {
      final page = PageLayout(
        lines: [line('första', height: 70), line('andra', height: 70)],
      );
      expect(page.text, equals('första\nandra'));
      expect(page.text.split('\n')[1], equals(page.lines[1].text));
    });

    test('textLineIndex maps a flat line index onto the document text', () {
      final a = PageLayout(
        lines: [line('a1', height: 70), line('a2', height: 70)],
      );
      final b = PageLayout(lines: [line('b1', height: 70)]);
      final doc = DocumentLayout([a, b]);

      final split = doc.text!.split('\n');
      for (var i = 0; i < doc.lines.length; i++) {
        // The conversion has to live in the model. Doing this arithmetic at the
        // call site is what the offsets exist to prevent, and it is right for
        // page one either way — only page two exposes a mistake.
        expect(split[doc.textLineIndex(i)!], equals(doc.lines[i].text));
      }
      expect(doc.textLineIndex(2), equals(3), reason: 'b1 sits after a blank');
      expect(doc.textLineIndex(3), isNull, reason: 'past the last line');
      expect(doc.textLineIndex(-1), isNull);
    });

    test('an EMPTY page still occupies one row, so later pages stay aligned', () {
      // A page with zero lines is reachable from a malformed capture and from a
      // blank photo. Counting `lines.length` instead of the rows the page
      // actually contributes put every later page one line early while
      // isComplete still reported true — a silent, confident wrong answer.
      final a = PageLayout(
        lines: [line('a1', height: 70), line('a2', height: 70)],
      );
      final b = PageLayout(lines: [line('b1', height: 70)]);
      final doc = DocumentLayout([a, const PageLayout(lines: []), b]);

      expect(doc.lineOffsets, equals([0, 3, 5]));
      expect(doc.text!.split('\n')[5], equals('b1'));
    });

    test('a document with any geometry-less page yields NO text at all', () {
      // Not a best effort. A page a paid tier read contributes its OWN lines to
      // the real combined string and this object cannot know how many, so any
      // string produced here would be wrong by an unbounded amount and would
      // look exactly like a correct one.
      final a = PageLayout(lines: [line('a1', height: 70)]);
      final doc = DocumentLayout([a, null]);

      expect(doc.text, isNull);
      expect(doc.lineOffsets, isNull);
      expect(doc.textLineIndex(0), isNull);
    });

    test('a line carrying an embedded newline still occupies ONE row', () {
      // A recognizer hands back a "line" with a newline in it often enough to
      // matter, and one line that occupies two rows breaks the whole contract:
      // lineOffsets counts ROWS, textLineIndex counts LIST ENTRIES, and past
      // that line every answer is confidently one row early. Normalising at
      // construction is what makes the two counts the same count.
      final page = PageLayout(
        lines: [
          line('Provençalska\nägg', height: 70),
          line('serveras ljumna', height: 70),
        ],
      );
      final doc = DocumentLayout([page]);

      expect(page.lines.first.text, equals('Provençalska ägg'));
      expect(doc.text!.split('\n'), hasLength(2));
      expect(
        doc.text!.split('\n')[doc.textLineIndex(1)!],
        equals('serveras ljumna'),
      );
    });

    test('a one-page import gets no separator at all', () {
      // The common case is a single photo. A separator emitted anyway would
      // put a blank line at the end of every one-page import and shift nothing
      // visibly — which is exactly how it would survive to the two-page case.
      final only = PageLayout(
        lines: [line('a1', height: 70), line('a2', height: 70)],
      );
      final doc = DocumentLayout([only]);

      expect(doc.lineOffsets, equals([0]));
      expect(doc.text, equals(only.text));
      expect(doc.text!.split('\n'), hasLength(2));
    });
  });

  group('matchesLineCountOf — the gate on trusting any index', () {
    PageLayout pageOf(List<String> texts) => PageLayout(
      lines: [
        for (final t in texts)
          OcrLine(
            text: t,
            box: const LayoutBox(left: 0, top: 0, width: 100, height: 20),
          ),
      ],
    );

    test('the same rows match even when the BYTES differ', () {
      // The whole reason it counts rows. The fixture carries a Cyrillic 'e'
      // (code point 0435, which HtmlSanitizer maps to Latin 'e') and a BEL
      // byte (0x07, which its control-character strip removes), so
      // `sanitized` below is exactly what `sanitizeText` returns for this
      // text. Check that homoglyph table before editing either side, or the
      // constant stops being a real round trip: the earlier 0430 spelling
      // mapped to Latin 'a' and could never produce the 'e' this constant
      // claims. Bytes change, not one row. A byte comparison would fail on
      // this healthy page and disable the layout path permanently.
      final doc = DocumentLayout([
        pageOf(['Prov\u0435ncalska agg', 'Lagg kokta agg\u0007']),
      ]);
      const sanitized = 'Provencalska agg\nLagg kokta agg';

      expect(doc.text, isNot(equals(sanitized)), reason: 'bytes differ');
      expect(doc.matchesLineCountOf(sanitized), isTrue, reason: 'rows do not');
    });

    test('one row more or fewer does NOT match', () {
      final doc = DocumentLayout([
        pageOf(['a', 'b', 'c']),
      ]);
      expect(doc.matchesLineCountOf('a\nb\nc'), isTrue);
      expect(doc.matchesLineCountOf('a\nb\nc\n'), isFalse);
      expect(doc.matchesLineCountOf('a\nb'), isFalse);
    });

    test('a TRIMMED input does not match, and must not', () {
      // The tier-0 path trims the provider's string. Forgiving that here would
      // hide the row shift that makes every converted index wrong — which is
      // the one failure this method exists to catch.
      final doc = DocumentLayout([
        pageOf(['', 'Pannkakor', 'Vispa smeten', '']),
      ]);
      final own = doc.text!;

      expect(doc.matchesLineCountOf(own), isTrue);
      expect(doc.matchesLineCountOf(own.trim()), isFalse);

      // The LEADING half, separately. `trim()` removes a row at BOTH ends, so
      // the counts still differ there and the assertion above still PASSES
      // under an implementation that forgives only the leading one — which is
      // exactly why the leading half needs an assertion of its own. (An earlier
      // version of this sentence said that assertion "stays red", i.e. catches
      // it. It does not.) Measured: `_newlineCount(own.trimLeft()) ==
      // _newlineCount(input.trimLeft())` reddens exactly TWO assertions in this
      // six-test group — the one below, and `matchesLineCountOf('\n')` in the
      // empty-document test. Everything else survives it, so those two are the
      // whole defence. (An earlier version of this comment claimed the mutant
      // passed the entire group; it did not, and the claim was about a
      // four-test group that had since grown.)
      // That is the worst shift of the set: a row lost at the START moves
      // EVERY index in the document, not the tail.
      expect(
        doc.matchesLineCountOf(own.trimLeft()),
        isFalse,
        reason: 'one row short at the start',
      );
    });

    test('the blank row BETWEEN pages counts', () {
      // The only reason this lives on DocumentLayout rather than PageLayout.
      // A multi-page import's text carries a separator row per boundary, so
      // the comparison must be against the joined string, never against the
      // pages' own rows — and never against `lines.length`, which is the
      // defect lineOffsets already records having shipped once (here: three
      // lines, four rows).
      final doc = DocumentLayout([
        pageOf(['a1', 'a2']),
        pageOf(['b1']),
      ]);

      expect(doc.matchesLineCountOf(doc.text!), isTrue);
      expect(doc.lines, hasLength(3), reason: 'list entries, not rows');
      expect(
        doc.matchesLineCountOf(['a1', 'a2', 'b1'].join('\n')),
        isFalse,
        reason: 'the separator row is missing',
      );
    });

    test('a document whose text is EMPTY is still judgeable', () {
      // The boundary the null case above must not swallow: a complete document
      // of one blank page has text '', which is one EMPTY row, not no rows. It
      // matches an empty input and nothing else. Counting list entries answers
      // zero here and would refuse a page the caller can safely index.
      final blank = DocumentLayout([pageOf([])]);

      expect(blank.text, isEmpty, reason: 'empty, not null');
      expect(blank.matchesLineCountOf(''), isTrue);
      expect(blank.matchesLineCountOf('\n'), isFalse);
    });

    test('an unjudgeable document never passes', () {
      // text is null, so there is nothing to compare — false, not a throw and
      // not an accidental true on the empty string.
      final incomplete = DocumentLayout([
        pageOf(['a']),
        null,
      ]);
      expect(incomplete.text, isNull);
      expect(incomplete.matchesLineCountOf('a'), isFalse);
      expect(incomplete.matchesLineCountOf(''), isFalse);
      expect(const DocumentLayout([]).matchesLineCountOf(''), isFalse);
    });
  });

  group('DocumentLayout.isComplete fails closed', () {
    test('true only when every page carries geometry', () {
      final page = PageLayout(lines: [line('x', height: 70)]);
      expect(DocumentLayout([page, page]).isComplete, isTrue);
      expect(DocumentLayout([page, null]).isComplete, isFalse);
      expect(DocumentLayout([null]).isComplete, isFalse);
    });

    test('an empty document is not complete', () {
      // Otherwise "no pages at all" would read as "every page has geometry"
      // and the layout path would run on nothing.
      expect(const DocumentLayout([]).isComplete, isFalse);
    });
  });

  group('JSON is the contract with tools/', () {
    test('a page survives a round trip with its geometry intact', () {
      final page = PageLayout(
        imageWidth: 2048,
        imageHeight: 1536,
        lines: [
          line('Provençalska ägg', height: 167, words: 2),
          line('en rad brödtext som fortsätter', height: 70),
        ],
      );

      final back = PageLayout.fromJson(
        jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
      );

      expect(back.text, equals(page.text));
      expect(back.imageWidth, equals(2048));
      expect(back.lines.first.typeHeight, equals(167));
      expect(back.lines.first.words.first.text, equals('w0'));
    });

    test('a line with no word boxes round-trips as a usable line box', () {
      // The degraded capture must replay as the degraded case, not as a line
      // with no size at all — the line box IS the type-size signal here, and
      // it travels in its own key that no other assertion reads.
      final bare = OcrLine(
        text: 'no words',
        box: const LayoutBox(left: 0, top: 0, width: 100, height: 42),
      );
      final json = bare.toJson();

      // Absent, not an empty list: a replay file carries one row per word for
      // a whole cookbook, so the empty case must not pay for a key.
      expect(json.containsKey('words'), isFalse);

      final back = OcrLine.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.words, isEmpty);
      expect(back.typeHeight, equals(42));
    });

    test('a stored line with no box of its own derives one from its words', () {
      // No capture records a line box, so this is the path EVERY replayed line
      // takes — decoding the absent box as a zero would hand the column
      // orderer a page whose lines all sit at the origin with no size.
      //
      // The words arrive in CAPTURE order, which the library warns is not
      // reading order, so the box may not lean on the first word for anything:
      // here the first word is interior on all four edges, and left, top,
      // right and bottom each come from one of the others.
      final l = OcrLine.fromJson(const {
        'text': 'ägg i ratatouille',
        'words': [
          {'t': 'i', 'x': 200.0, 'y': 110.0, 'w': 40.0, 'h': 40.0},
          {'t': 'ägg', 'x': 40.0, 'y': 100.0, 'w': 100.0, 'h': 70.0},
          {'t': 'ratatouille', 'x': 320.0, 'y': 96.0, 'w': 90.0, 'h': 60.0},
        ],
      });

      expect(l.box.left, equals(40));
      expect(l.box.top, equals(96));
      expect(l.box.right, equals(410));
      expect(l.box.bottom, equals(170));
    });

    test('numbers written as strings replay as geometry, not as zeros', () {
      // A capture re-encoded by a tool that quotes its numbers is the
      // commonest round-trip corruption, and decoding those to 0 is worse
      // than throwing: the page replays looking complete, with every line
      // stacked at the origin and no type size to judge it by.
      final page = PageLayout.fromJson(const {
        'width': '2048',
        'height': '1536',
        'lines': [
          {
            'text': 'Provençalska ägg',
            'x': '40',
            'y': '100',
            'w': '260',
            'h': '167',
          },
          // A dimension that is not a number at all must land on ZERO, not on
          // some small positive value: zero is what the baseline sample drops,
          // so garbage declines to be measured instead of quietly joining the
          // median as a tiny line.
          {'text': 'i en ratatouille', 'h': 'inte ett tal'},
        ],
      });

      expect(page.imageWidth, equals(2048));
      expect(page.lines.first.typeHeight, equals(167));
      expect(page.lines.first.box.right, equals(300));
      expect(page.lines.last.typeHeight, equals(0));
    });

    test('a malformed page decodes to something empty, never a throw', () {
      // Replaying a capture must degrade to "no geometry" so the caller falls
      // back to the text path, not crash an import.
      final back = PageLayout.fromJson(const {'lines': 'nonsense'});
      expect(back.lines, isEmpty);
      expect(back.text, isEmpty);

      // Text that is missing, or present but of the wrong TYPE, must decode to
      // an EMPTY line — never to a stringified version of the corruption. This
      // text is not incidental: it IS what PageLayout.text hands the parser, so
      // a decoder that stringifies whatever it finds puts the word "null", or
      // the fragment "[Provençalska, ägg]", into the middle of a recipe on a
      // page that still reports itself complete. Same standard the numeric
      // fields already hold ('inte ett tal' above lands on zero, not on a
      // plausible small number).
      final partial = PageLayout.fromJson(const {
        'lines': [
          {
            'words': [
              {'x': 40.0, 'y': 100.0, 'w': 90.0, 'h': 70.0},
            ],
          },
          {
            'text': ['Provençalska', 'ägg'],
            'words': [
              {'t': 42, 'x': 40.0, 'y': 100.0, 'w': 90.0, 'h': 70.0},
            ],
          },
        ],
      });
      expect(partial.lines.first.text, isEmpty, reason: 'text key absent');
      expect(partial.lines.first.words.single.text, isEmpty);
      expect(partial.lines.last.text, isEmpty, reason: 'text key is a list');
      expect(partial.lines.last.words.single.text, isEmpty);
      // Two empty rows, not two fabricated ones.
      expect(partial.text.trim(), isEmpty);
    });
  });
}
