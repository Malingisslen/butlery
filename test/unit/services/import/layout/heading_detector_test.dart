import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// The detector's whole job is to separate a dish title from the body text
/// around it using type size. Every fixture here therefore sets word heights
/// and line text INDEPENDENTLY — a helper that derived one from the other
/// would let a detector that ignored size entirely pass.
void main() {
  /// [height] is the height of every WORD box; [boxHeight] overrides the LINE
  /// box independently, because the two are the same number on a flat capture
  /// and different numbers on a skewed one — which is the whole reason
  /// [OcrLine.typeHeight] exists.
  OcrLine line(
    String text, {
    required double height,
    int? words,
    double? boxHeight,
    List<double>? wordHeights,
  }) {
    final tokens = text.trim().isEmpty
        ? <String>[]
        : text.trim().split(RegExp(r'\s+'));
    final count = words ?? tokens.length;
    return OcrLine(
      text: text,
      box: LayoutBox(
        left: 0,
        top: 0,
        width: text.length * 18,
        height: boxHeight ?? height,
      ),
      words: [
        for (var i = 0; i < count; i++)
          OcrWord(
            text: i < tokens.length ? tokens[i] : 'w$i',
            box: LayoutBox(
              left: 0,
              top: 0,
              width: 40,
              height: (wordHeights != null && i < wordHeights.length)
                  ? wordHeights[i]
                  : height,
            ),
          ),
      ],
    );
  }

  /// Word heights measured from the capture of
  /// `butlery-corpus/blandat-svart/PXL_20260803_204246157` — a PROSE spread
  /// with no ingredient list anywhere, where every text rule fails. This is the
  /// page the whole approach was designed against.
  ///
  /// The two titles' word boxes are transcribed INDIVIDUALLY (200/133 and
  /// 139/119) because that is what the capture holds and because giving both
  /// words of a line one height — as this fixture did until 2026-08-07 — hides
  /// the effect that actually decides this page. See the group below.
  PageLayout realSpread() => PageLayout(
    lines: [
      line('Provençalska ägg', height: 167, wordHeights: [200, 133]),
      line('Lägg kokta, skalade 8-minuters-ägg — två per person', height: 72),
      line('i en ratatouille eller en fransk grönsaksröra', height: 69),
      line('servera med bröd till eller med råris', height: 74),
      line('Fransk omelett', height: 129, wordHeights: [139, 119]),
      line('Få saker är så lättlagade som en fransk omelett', height: 67),
      line('blir omeletten om man inte vispar i smeten', height: 68),
      line('Räkna med fyra eller fem ägg för två personer', height: 74),
    ],
  );

  List<String> headingTexts(PageLayout page) => HeadingDetector.headingLines(
    page,
  ).map((i) => page.lines[i].text).toList();

  group('HeadingDetector on the page that motivated it', () {
    test('finds the larger title, and — measured — MISSES the smaller', () {
      // Recorded as a known miss rather than hidden, because this is the page
      // the whole approach was designed against and the reason is worth
      // keeping.
      //
      // Its two titles ARE set in one type. The capture measures
      // 'Provensalska' at 200 and 'ägg' at 133 — but 'ägg' occupies MORE
      // vertical ink (umlaut plus two descenders), so at equal type size it
      // should measure taller, not shorter. `glyphSpan` divides those zones out
      // and the two words come back 137.9 and 73.9 — a factor of 1.9, WIDER
      // than the 1.50 of the raw boxes, which is the correct direction and
      // shows how much shorter `ägg`'s box really was. Glyphs are therefore not
      // the remaining error. Word WIDTH is —
      // an axis-aligned box around a slightly tilted word grows with its
      // length, exactly as the `OcrWord` class doc says of LINE boxes, and
      // 'Provensalska' is four times the width of 'ägg'. The line median then
      // lands at 105.9 against 'Fransk omelett' at 89.0, which is outside
      // `titleSizeSpread`.
      //
      // NOT tuned around. Three line estimators were measured over the corpus
      // — median (ships), max and min — and median wins on every axis. Nor is
      // the constant the answer: the two lines measure 105.9 against 89.0, a
      // ratio of 1.19, so 1.15 does NOT recover this page (its floor is 92.1)
      // and 1.20 would — a row the table records as no better on spreads, TWO
      // spurious blocks worse, and a point down on single pages, which is the
      // axis this whole plan refuses to trade. Deskewing the word boxes is the
      // real fix and belongs to the column-ordering step, not here.
      expect(headingTexts(realSpread()), equals(['Provençalska ägg']));
    });

    test('returns INDICES into the page lines, not just the texts', () {
      // The splitter slices the page at these positions, so an off-by-one is a
      // recipe that starts mid-sentence.
      //
      // The page repeats the dish name as a running header at body size, which
      // is the only thing that makes this test distinct. Against `realSpread`
      // — where every line text is unique — its kill set was byte-identical to
      // the test above: `headingTexts` IS `headingLines` mapped through the
      // texts, so "index 0" and "the text at index 0" were one fact and no
      // mutant could separate them. Now an implementation returning the header
      // instead of the title answers [0] where [1] is correct.
      final page = PageLayout(
        lines: [
          line('Provençalska ägg', height: 70),
          line('Provençalska ägg', height: 167, wordHeights: [200, 133]),
          line(
            'Lägg kokta, skalade 8-minuters-ägg — två per person',
            height: 72,
          ),
          line('i en ratatouille eller en fransk grönsaksröra', height: 69),
          line('servera med bröd till eller med råris', height: 74),
          line('Räkna med fyra eller fem ägg för två personer', height: 74),
        ],
      );
      expect(HeadingDetector.headingLines(page), equals([1]));
    });

    test('the smaller of the two titles is still well clear of the bar', () {
      // A control on the threshold itself, stated against the measured
      // baseline rather than against a transcribed constant: every height here
      // is glyph-normalised (`OcrWord.typeHeight`), so a literal 70.5 would
      // pin the zone table rather than the size bar it claims to control.
      final page = realSpread();
      final body = page.bodyTypeHeight!;
      // Against the CONSTANT, never a restated 1.5 — otherwise this control
      // says nothing about the ratio it claims to control.
      expect(
        page.lines[4].typeHeight,
        greaterThan(body * HeadingDetector.headingSizeRatio),
      );
    });
  });

  group('the size bar', () {
    test('a line measuring EXACTLY body size is never a heading', () {
      // 'Pannkakor' clears every text guard, so the size bar is the only rule
      // that can refuse it — which is what makes this a size-bar test.
      //
      // Its height is DERIVED so the line measures exactly the body baseline.
      // The previous fixture used a raw 70 for 'Provençalska ägg' and claimed
      // "without the size test this page would report three headings"; both
      // halves were false. That line normalises to 43.6 against a baseline of
      // 48.3 — smaller than body text, so the bar was never the thing refusing
      // it — and the four body rows start lowercase, so the page reports ONE
      // candidate, not three.
      PageLayout pageWith(double titleHeight) => PageLayout(
        lines: [
          line('Pannkakor', height: titleHeight),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      final probe = pageWith(100);
      final perRawUnit = probe.lines.first.typeHeight / 100;
      final atBody = probe.bodyTypeHeight! / perRawUnit;

      expect(headingTexts(pageWith(atBody)), isEmpty);
    });

    test('a line just under the bar is refused, just over is taken', () {
      PageLayout pageWith(double titleHeight) => PageLayout(
        lines: [
          line('Pannkakor', height: titleHeight),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );

      // `perRawUnit` converts a raw word height into the normalised scale the
      // detector works in, so every number below says something about K and
      // nothing about which letters 'Pannkakor' happens to contain. Hard-coding
      // the old 104/105 would pin the glyph zone table instead.
      final probe = pageWith(100);
      final perRawUnit = probe.lines.first.typeHeight / 100;
      final body = probe.bodyTypeHeight!;

      // The bar's SHAPE: one raw unit under is refused, one over is taken.
      final atBar = body * HeadingDetector.headingSizeRatio / perRawUnit;
      expect(headingTexts(pageWith(atBar - 1)), isEmpty);
      expect(headingTexts(pageWith(atBar + 1)), equals(['Pannkakor']));

      // The bar's VALUE. The two assertions above are derived FROM the constant
      // and therefore hold for every positive K — including 1.35, the setting
      // this file argues at length was measured and rejected for cutting one
      // single-recipe page in four. These bracket K to (1.40, 1.60] so that
      // moving it there cannot pass in silence.
      expect(
        headingTexts(pageWith(body * 1.40 / perRawUnit)),
        isEmpty,
        reason: 'K = 1.35 would take this line',
      );
      expect(
        headingTexts(pageWith(body * 1.60 / perRawUnit)),
        equals(['Pannkakor']),
        reason: 'a K above 1.60 would lose a real title',
      );
    });

    test('two sibling titles a few percent apart BOTH survive the floor', () {
      // The loose side of `titleSizeSpread`, which nothing else guards. Every
      // other fixture in both suites sets sibling headings to one identical
      // height and one identical glyph shape, so they measure exactly equal and
      // the constant could be tightened to 1.001 with the whole suite green.
      //
      // Real sibling titles are not exactly equal: the recognizer's boxes wobble
      // by a few percent on one page. 8 % apart must still be one spread.
      final page = PageLayout(
        lines: [
          line('Pannkakor', height: 150),
          line('Vafflor', height: 138),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(headingTexts(page), equals(['Pannkakor', 'Vafflor']));
    });

    test('an UNSEGMENTED line is never a heading, however tall it reads', () {
      // The cross-file defect the whole-diff review caught, and the reason
      // batched reviews could not: `OcrLine.typeHeight` is glyph-normalised
      // when the line has word boxes and a RAW line box when it does not, and
      // those are different scales — `glyphSpan`'s doc lists the six attainable
      // inflations and which clear a size bar on their own. One page can carry
      // both kinds because element absence is per LINE, not per platform: the
      // ML Kit adapter maps each line's elements independently, and
      // `device_text_recognizer_mlkit_test` stages a page of exactly that
      // shape.
      //
      // 'Tillbehör' below carries no word boxes, so its box spans the line's
      // full ink — 85, where the segmented body lines beside it normalise to
      // 48.3. Measured on this fixture: the bar sits at 72.4 and the
      // page-relative floor at 81.5, so unfiltered it clears BOTH and becomes a
      // second heading.
      //
      // Precisely how far above body it is, because the bound matters and an
      // earlier version of this comment rounded it away: `glyphSpan('Tillbehör')`
      // is 1.45 (no descender), so 85 is a type of 58.6 — about a fifth above
      // body, not exactly at it. A genuinely body-sized unsegmented line of this
      // shape would measure 70 and stay UNDER the bar. So the defect needs a
      // line either somewhat larger than body, or one whose ink includes a
      // descender (span 1.80, which reads 1.80x rather than 1.45x). That bounds
      // its reach; it does not make it rare — a running header or a section
      // label is usually set a little larger than body.
      //
      // The title's height is 130 for a separate reason: at 150 the floor rises
      // to 94 and masks the defect entirely, which is how an earlier version of
      // this fixture passed with the guard deleted. The corpus can never show
      // any of it — every stored capture has word boxes.
      final page = PageLayout(
        lines: [
          line('Pannkakor', height: 130),
          OcrLine(
            text: 'Tillbehör',
            box: const LayoutBox(left: 0, top: 0, width: 300, height: 85),
          ),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(headingTexts(page), equals(['Pannkakor']));

      // The guard's SECOND claim, which the page above cannot see. Its
      // production comment says such a line would also SET `tallest` and push
      // real titles under the floor — a different, worse outcome than gaining a
      // false heading, because the page loses the title it did have. Measured
      // on these bytes: moving the guard below the `tallest` update (line still
      // refused, but it still sets the reference) reddens exactly ONE assertion
      // in these three suites — the one below. The page above stays green under
      // it, which is the whole reason this second page exists; an earlier
      // version of this sentence said the mutant left all 75 tests green, which
      // stopped being true the moment this page was added to defend against it.
      // At 200 the floor rises to 181.8 and
      // 'Pannkakor' at 89.7 falls under it, so the detector answers nothing at
      // all.
      final tallNoise = PageLayout(
        lines: [
          line('Pannkakor', height: 130),
          OcrLine(
            text: 'Tillbehör',
            box: const LayoutBox(left: 0, top: 0, width: 300, height: 200),
          ),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(headingTexts(tallNoise), equals(['Pannkakor']));
    });

    test('a heading on the LAST line of the page is still found', () {
      // The splitter opens its final block here. An off-by-one in the loop
      // bound loses the last recipe on every page and nothing else notices.
      final page = PageLayout(
        lines: [
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
          line('Pannkakor', height: 140),
        ],
      );
      expect(HeadingDetector.headingLines(page), equals([4]));
    });

    test('type size is measured from the WORDS, not the line box', () {
      // On a skewed photo an axis-aligned line box grows with the line's
      // WIDTH, so a long body line can out-measure a short heading. Both
      // directions are on this page: the title's line box is body-sized while
      // its words are large, and the body line's box is huge while its words
      // are ordinary. Reading `box.height` here returns the body line and
      // loses the title.
      final page = PageLayout(
        lines: [
          line('Pannkakor', height: 140, boxHeight: 70),
          line(
            'En lång rad brödtext som fortsätter',
            height: 70,
            boxHeight: 200,
          ),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(headingTexts(page), equals(['Pannkakor']));
    });

    test('a chapter heading suppresses a smaller title below it', () {
      // The known COST of `titleSizeSpread`, recorded rather than hidden.
      //
      // No ceiling was added — a ceiling drops the biggest line and was
      // measured worse, and that decision stands. But a page-relative FLOOR
      // reaches the same page from the other end: a chapter header set far
      // above the dish titles becomes the page's reference, and a real title
      // falls under the floor. This test used to assert both lines came back.
      //
      // Kept anyway, on measured grounds. Against no spread rule at all, the
      // floor saves 5 working pages from being cut in half and removes 9
      // spurious blocks, at the cost of 5 recipes not emitted — and the whole
      // page then falls back to the text rules rather than splitting wrongly,
      // which is the safe direction. If chapter headers turn out common in a
      // real cookbook, this is where the cost is visible.
      final page = PageLayout(
        lines: [
          line('Vilda grönsaker', height: 420),
          line('Nässelsoppa', height: 160),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(headingTexts(page), equals(['Vilda grönsaker']));
    });
  });

  group('the text guards', () {
    PageLayout pageWithBigLine(String text, {int? words}) => PageLayout(
      lines: [
        line(text, height: 140, words: words),
        for (var i = 0; i < 4; i++)
          line('en lång rad brödtext som fortsätter $i', height: 70),
      ],
    );

    test('a dish named after its main ingredient IS a title', () {
      // The guard this replaces (`looksLikeIngredient`) rejected 15 of the 16
      // real titles it threw away, because it fires on a bare ingredient word.
      for (final title in const [
        'Dillstuvad potatis',
        'Förlorade ägg',
        'Hasselbackspotatis',
        'Nässelägg',
      ]) {
        expect(
          headingTexts(pageWithBigLine(title)),
          equals([title]),
          reason: '$title is a dish, not an ingredient row',
        );
      }
    });

    test('a line carrying a QUANTITY is an ingredient row, however large', () {
      expect(headingTexts(pageWithBigLine('2 dl vetemjöl')), isEmpty);
      expect(headingTexts(pageWithBigLine('Ca 1,5 dl grädde')), isEmpty);
    });

    test('sentence punctuation and fragments are refused', () {
      for (final noise in const [
        'Blanda smeten,',
        'Vispa ihop och grädda.',
        'För såsen:',
        // Capitalized deliberately. The trailing-hyphen guard runs BEFORE the
        // capitalization one, so a lowercase version of this row would be
        // refused either way and would pin neither.
        'Lammstek eller-',
        // These two ARE refused by the leading-digit and fragment rules they
        // read as — both run before the capitalization guard. They still pin
        // nothing, because a digit and '(' are each equal to their own
        // lowercase, so capitalization would refuse them too. Behavioural
        // documentation of the input, not coverage. (An earlier version of this
        // comment had the guard order backwards in both halves.)
        '(se sidan 10)',
        '4 portioner',
      ]) {
        expect(
          headingTexts(pageWithBigLine(noise)),
          isEmpty,
          reason: 'refused: $noise',
        );
      }
    });

    test('a section header set at heading size is still not a dish', () {
      expect(headingTexts(pageWithBigLine('Ingredienser')), isEmpty);
      expect(headingTexts(pageWithBigLine('Gör så här')), isEmpty);
    });

    test('a lowercase line is column bleed, not a title', () {
      expect(headingTexts(pageWithBigLine('och lite salt i pannan')), isEmpty);
    });

    // A 'too long or too many words' test lived here. Deleted 2026-08-06:
    // 'each length bound refuses on its own' below covers the same two guards
    // through the same seam, and asserts its fixtures' lengths as premises.
    // Measured: the char bound and the word bound each survive alone unless
    // the fixtures separate them, which is what that test does.

    test('a single huge letter is a drop cap, not a title', () {
      // Cookbooks open a chapter with an initial set several times body size.
      // It clears every other guard — one word, capitalized, no punctuation —
      // so the minimum length is the only thing standing between it and a
      // recipe block that starts one letter before the real title.
      expect(headingTexts(pageWithBigLine('V')), isEmpty);
    });

    test('word count comes from the word boxes, not the visible text', () {
      // Four tokens on screen, nine word boxes underneath: OCR split the row.
      // Counting the text instead would call this a title.
      expect(
        headingTexts(pageWithBigLine('Kort titel med ord', words: 9)),
        isEmpty,
      );
    });

    test(
      'the longest REAL corpus title still passes, with 1 char to spare',
      () {
        // Measured over the 242 verified golds, not guessed: 59 characters, 6
        // words, and nothing in the corpus is longer. The bound is 60, so this
        // fixture is what stands between a real dish name and the guard.
        const longest =
            'Smörstekta äppelringar med kardemummasmulor och vaniljglass';
        expect(longest.length, equals(59));
        expect(headingTexts(pageWithBigLine(longest)), equals([longest]));
      },
    );

    test('each length bound refuses on its own', () {
      // Both fixtures in the older test tripped the OTHER bound, so raising
      // either limit to absurdity left the suite green. These separate them.
      final tooLong = 'A${'a' * 60} b'; // 63 chars, 2 words
      expect(tooLong.length, greaterThan(60));
      expect(headingTexts(pageWithBigLine(tooLong)), isEmpty);

      const tooMany = 'Ett tva tre fyra fem sex sju atta nio'; // 9 words, 37 ch
      expect(tooMany.length, lessThan(60));
      expect(tooMany.split(' ').length, equals(9));
      expect(headingTexts(pageWithBigLine(tooMany)), isEmpty);
    });
  });

  group('a whole import, not one page', () {
    PageLayout spreadWith(String title) => PageLayout(
      lines: [
        line(title, height: 140),
        for (var i = 0; i < 4; i++)
          line('en lang rad brodtext som fortsatter $i', height: 70),
      ],
    );

    test('indices are flat across pages, not per page', () {
      // The trap this method exists for: converting a PAGE index without
      // adding the preceding pages' line counts puts every boundary from page
      // two onward five rows early, and a one-page test can never show it.
      final doc = DocumentLayout([
        spreadWith('Pannkakor'),
        spreadWith('Vafflor'),
      ]);
      final flat = HeadingDetector.headingLinesForDocument(doc)!;

      expect(flat, equals([0, 5]));
      expect(doc.lines[flat[1]].text, equals('Vafflor'));
    });

    test('one DECLINING page condemns the whole document', () {
      // The silent one. The declining page still reports `isComplete`, so
      // without this rule the first block would open on page two and page
      // one's entire content would vanish from every block.
      final declining = PageLayout(
        lines: [line('Pannkakor', height: 140), line('kort rad', height: 70)],
      );
      expect(declining.bodyTypeHeight, isNull);

      final doc = DocumentLayout([declining, spreadWith('Vafflor')]);
      expect(
        doc.isComplete,
        isTrue,
        reason: 'geometry present, just unjudgeable',
      );
      expect(HeadingDetector.headingLinesForDocument(doc), isNull);
    });

    test('a page with NO geometry also yields null, not a partial answer', () {
      final doc = DocumentLayout([spreadWith('Pannkakor'), null]);
      expect(HeadingDetector.headingLinesForDocument(doc), isNull);
    });

    test(
      'null means CANNOT JUDGE; an empty list means judged and found none',
      () {
        // The distinction the caller needs: both send it to the text path today,
        // but only one of them may ever stop doing so.
        final noHeadings = PageLayout(
          lines: [
            for (var i = 0; i < 5; i++)
              line('en lang rad brodtext som fortsatter $i', height: 70),
          ],
        );
        expect(
          HeadingDetector.headingLinesForDocument(DocumentLayout([noHeadings])),
          isEmpty,
        );
        expect(
          HeadingDetector.headingLinesForDocument(const DocumentLayout([])),
          isNull,
        );
      },
    );
  });

  group('declining is the contract', () {
    test('a page with no measurable baseline yields NO headings', () {
      // Not "this page has no headings" — "this page cannot be judged". The
      // caller must fall back to the text path. Roughly a quarter of the
      // corpus's multi-recipe captures land here.
      final page = PageLayout(
        lines: [
          line('Provençalska ägg', height: 167),
          line('kort rad', height: 70),
        ],
      );
      expect(page.bodyTypeHeight, isNull);
      expect(HeadingDetector.headingLines(page), isEmpty);
    });

    test('an empty page is not a crash', () {
      expect(
        HeadingDetector.headingLines(const PageLayout(lines: [])),
        isEmpty,
      );
    });

    test('a page whose lines carry no measurements declines', () {
      // The degraded provider. Every height is 0, so there is no baseline and
      // nothing may be called a heading — the failure that would otherwise
      // make EVERY line a heading.
      final page = PageLayout.fromJson({
        'lines': [
          for (var i = 0; i < 5; i++)
            {'text': 'en rad brödtext som fortsätter'},
        ],
      });
      expect(page.lines, hasLength(5));
      expect(HeadingDetector.headingLines(page), isEmpty);
    });
  });
}
