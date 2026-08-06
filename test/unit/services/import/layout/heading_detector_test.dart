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
            box: LayoutBox(left: 0, top: 0, width: 40, height: height),
          ),
      ],
    );
  }

  /// Word heights measured from the capture of
  /// `butlery-corpus/blandat-svart/PXL_20260803_204246157` — a PROSE spread
  /// with no ingredient list anywhere, where every text rule fails and the two
  /// titles are the only lines over 100. This is the page the whole approach
  /// was designed against.
  PageLayout realSpread() => PageLayout(
    lines: [
      line('Provençalska ägg', height: 167),
      line('Lägg kokta, skalade 8-minuters-ägg — två per person', height: 72),
      line('i en ratatouille eller en fransk grönsaksröra', height: 69),
      line('servera med bröd till eller med råris', height: 74),
      line('Fransk omelett', height: 129),
      line('Få saker är så lättlagade som en fransk omelett', height: 67),
      line('blir omeletten om man inte vispar i smeten', height: 68),
      line('Räkna med fyra eller fem ägg för två personer', height: 74),
    ],
  );

  List<String> headingTexts(PageLayout page) => HeadingDetector.headingLines(
    page,
  ).map((i) => page.lines[i].text).toList();

  group('HeadingDetector on the page that motivated it', () {
    test('finds exactly the two dish titles', () {
      expect(
        headingTexts(realSpread()),
        equals(['Provençalska ägg', 'Fransk omelett']),
      );
    });

    test('returns INDICES into the page lines, not just the texts', () {
      // The splitter slices the page at these positions, so an off-by-one is a
      // recipe that starts mid-sentence.
      final page = realSpread();
      expect(HeadingDetector.headingLines(page), equals([0, 4]));
    });

    test('the smaller of the two titles is still well clear of the bar', () {
      // A control on the threshold itself. Six body lines at 67/68/69/72/74/74
      // give a median of 70.5, so the bar sits at 105.75 and "Fransk omelett"
      // clears it at 129 — with room, but not vast room. If K reached 1.83
      // this page would silently yield one recipe again (129/70.5 = 1.8298, so 1.83
      // already loses it).
      final page = realSpread();
      final body = page.bodyTypeHeight!;
      expect(body, equals(70.5));
      // Against the CONSTANT, never a restated 1.5 — otherwise this control
      // says nothing about the ratio it claims to control.
      expect(
        page.lines[4].typeHeight,
        greaterThan(body * HeadingDetector.headingSizeRatio),
      );
    });
  });

  group('the size bar', () {
    test('body-sized lines are never headings, however title-like', () {
      // Same words, same shape, ordinary size. Without the size test this
      // page would report three headings.
      final page = PageLayout(
        lines: [
          line('Provençalska ägg', height: 70),
          line('en lång rad brödtext som fortsätter här', height: 70),
          line('ännu en lång rad brödtext som fortsätter', height: 70),
          line('tredje raden brödtext som fortsätter', height: 70),
          line('fjärde raden brödtext som fortsätter', height: 70),
        ],
      );
      expect(HeadingDetector.headingLines(page), isEmpty);
    });

    test('a line just under the bar is refused, just over is taken', () {
      PageLayout pageWith(double titleHeight) => PageLayout(
        lines: [
          line('Pannkakor', height: titleHeight),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );

      // Body median 70 ⇒ bar 105. These two numbers are what pins K: 104 must
      // be refused (so K > 1.4857 — K = 1.35, the measured-and-rejected
      // setting that cuts one single-recipe page in four, reddens HERE) and
      // 105 must be taken (so K ≤ 1.50). Moving the constant without moving
      // the trade-off is not possible without editing this test.
      expect(headingTexts(pageWith(104)), isEmpty);
      expect(headingTexts(pageWith(105)), equals(['Pannkakor']));
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

    test('a chapter heading far above the titles is NOT excluded', () {
      // An upper bound was measured and made recall worse. This
      // pins that decision: the running header comes back as a heading, and it
      // is the splitter's job to survive that, not this detector's to guess.
      final page = PageLayout(
        lines: [
          line('Vilda grönsaker', height: 420),
          line('Nässelsoppa', height: 120),
          for (var i = 0; i < 4; i++)
            line('en lång rad brödtext som fortsätter $i', height: 70),
        ],
      );
      expect(
        headingTexts(page),
        equals(['Vilda grönsaker', 'Nässelsoppa']),
        reason: 'no ceiling — measured worse',
      );
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
        // Capitalized deliberately. A lowercase fragment is refused by the
        // capitalization guard before the trailing-hyphen one is consulted, so
        // the lowercase version of this row pinned nothing.
        'Lammstek eller-',
        // These two are refused by the capitalization guard (a digit and '('
        // are both equal to their own lowercase) rather than by the
        // leading-digit and fragment rules they read as. Kept as behavioural
        // documentation of the input, not as a pin on either guard.
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
