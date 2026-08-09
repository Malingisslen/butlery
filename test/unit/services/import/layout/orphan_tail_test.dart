import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/layout/orphan_tail.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line whose TYPE height is set by its word boxes, which is the only thing
/// `HeadingDetector` MEASURES — it also READS the text, because
/// `_readsLikeTitle` gates on length, word count, a quantity regex, terminal
/// punctuation and a capital initial. A fixture heading has to satisfy both,
/// and `IAUS` clears `_minTitleChars` (3) with one character to spare.
///
/// Body lines carry four words so they can establish the page's baseline; a
/// heading is one tall word. `words: 4` is `PageLayout._minBodyWords` EXACTLY,
/// with no headroom — bump that constant and every fixture page in this file
/// loses its baseline at once.
OcrLine line(String text, {required double wordHeight, int words = 4}) {
  final tokens = text.trim().split(RegExp(r'\s+'));
  return OcrLine(
    text: text,
    box: LayoutBox(
      left: 0,
      top: 0,
      width: text.length * 18,
      height: wordHeight,
    ),
    words: [
      for (var i = 0; i < words; i++)
        OcrWord(
          // NOT all one bucket: `heading()` passes `words: 1`, so a heading's
          // type height is 145 divided by `glyphSpan` of its FIRST token. The
          // rule a two-heading fixture must satisfy is that both first tokens
          // land in the SAME glyphSpan BUCKET — not that they share a token,
          // which is only one way to get there. Mixing buckets makes the
          // page-relative floor drop the shorter heading from `headingLines`
          // entirely and the test then passes for the wrong reason. Measured:
          // `Mandelbiskvi` and `Mandelforell` are both 1.45 (capital, tall
          // band, no descender), which is why the two-heading test below
          // works; `Inlagd` is 1.80, because a descender widens the span. So
          // renaming one heading to anything carrying a LOWERCASE g/j/p/q/y
          // silently disarms that test. A capital does not descend.
          text: i < tokens.length ? tokens[i] : 'ord',
          box: LayoutBox(
            left: i * 200,
            top: 0,
            width: 180,
            height: wordHeight,
          ),
        ),
    ],
  );
}

/// Six body lines — enough for a baseline, and 22 characters each
/// (`'brodtext rad med ord 0'`).
///
/// Two comments below size fixtures against the 120-character budget from that
/// 22, so it has to be right. Two successive drafts of this line got it wrong
/// — 24, then a wrong provenance for the 24 — which is the argument for keeping
/// the number bare: count the literal, do not narrate where a previous count
/// came from. The `text:` override renders a DIFFERENT length; measure that one
/// too rather than assuming it matches.
List<OcrLine> body({int count = 6, String text = 'brodtext rad med ord'}) => [
  for (var i = 0; i < count; i++) line('$text $i', wordHeight: 70),
];

/// A heading: same fixture shape, 2x the body's type height.
OcrLine heading(String text) => line(text, wordHeight: 145, words: 1);

DocumentLayout doc(List<OcrLine> lines) =>
    DocumentLayout([PageLayout(lines: lines)]);

void main() {
  group('withoutOrphanTail', () {
    test('drops a trailing heading with almost nothing under it', () {
      final lines = [
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc(lines);
      final input = layout.text!;

      final cut = withoutOrphanTail(input, layout);

      expect(cut.text.contains('Mandelforell'), isFalse);
      expect(cut.layout!.pages.first!.lines.length, 6);
      // The invariant the splitter depends on: text and page lose the SAME
      // number of rows, so the row-count gate still accepts the pair.
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('KEEPS a trailing heading that carries a real recipe under it', () {
      // Over the budget, so it is a recipe of its own and not furniture.
      final lines = [
        ...body(),
        heading('Annas hurtbullar'),
        for (var i = 0; i < 8; i++)
          line('ingrediensrad med flera ord $i', wordHeight: 70),
      ];
      final layout = doc(lines);
      final input = layout.text!;

      final cut = withoutOrphanTail(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(cut.text.contains('Annas hurtbullar'), isTrue);
    });

    test('cuts at the LAST heading, never an earlier one', () {
      // TWO headings, which is the whole point: a single-heading fixture cannot
      // tell `headings.last` from `headings.first` and proves only the budget.
      // Measured — the earlier version of this test killed no mutant.
      //
      // Both headings sit in the SAME glyphSpan bucket on purpose — measured
      // 1.45 each, and `headingLines` really does return both (indices 6 and
      // 13). They do NOT share a token: `heading()` passes `words: 1`, so the
      // divisor is the whole one-word title, and `Mandelbiskvi`/`Mandelforell`
      // agree only because neither carries a LOWERCASE descender. Give one of
      // them a g/j/p/q/y and its span jumps to 1.80, the page-relative floor
      // drops the shorter heading, and this test passes for the wrong reason.
      // (A capital G/J/P/Q/Y does not descend and is safe.) See the `line()`
      // helper for the measured bucket table.
      final lines = [
        ...body(count: 6),
        heading('Mandelbiskvi'),
        ...body(count: 6, text: 'mellan brodtext med ord'),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc(lines);

      // The premise. Several fixtures in this file decay silently; what is
      // particular here is the MECHANISM. If `Mandelbiskvi` ever leaves
      // `headingLines`, `.first` COLLAPSES ONTO `.last`, so the cut comes out
      // byte-identical and both assertions below still pass — including
      // `contains('Mandelbiskvi')`, which is satisfied by the row's text
      // whether or not it was ever classed as a heading. The test quietly
      // becomes a third budget test, exactly what the paragraph above says must
      // not happen.
      expect(
        HeadingDetector.headingLines(layout.pages.first!),
        [6, 13],
        reason: 'premise: BOTH titles must be detected, or first == last',
      );

      final cut = withoutOrphanTail(layout.text!, layout);

      expect(cut.text.contains('Mandelforell'), isFalse);
      expect(cut.text.contains('Mandelbiskvi'), isTrue);
      expect(cut.text.contains('mellan brodtext med ord 5'), isTrue);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test("a heading on the LAST PAGE's first row is not a cut point", () {
      // The `pageRow == 0` guard is NOT redundant here, whatever it looks like
      // on a single page. With two pages the heading sits at page two's row 0,
      // `textRow` resolves to a POSITIVE document row, the `textRow <= 0` bound
      // never fires, and without this guard the last page is emptied while the
      // text keeps its rows — the pair's counts then disagree and the splitter
      // silently declines geometry for the whole import.
      final pageOne = PageLayout(lines: [...body(count: 8)]);
      final pageTwo = PageLayout(
        lines: [heading('Mandelforell'), ...body(count: 4)],
      );
      final layout = DocumentLayout([pageOne, pageTwo]);
      final input = layout.text!;

      expect(
        pageTwo.bodyTypeHeight,
        isNotNull,
        reason: 'premise: page two must be judgeable at all',
      );
      // The other half of the premise, and the one that decays silently. Four
      // body lines is EXACTLY `_minBodyLines`, so a nudge to the detector makes
      // page two unjudgeable, `headingLines` returns empty, and this degrades
      // into a duplicate of the no-headings test while staying green — the only
      // fixture that pins `pageRow == 0` would then pin nothing.
      expect(
        HeadingDetector.headingLines(pageTwo),
        [0],
        reason: 'premise: the heading must be FOUND, at page two row 0',
      );
      // And the third premise, the quietest of them: this fixture only pins
      // `pageRow == 0` because its tail sums to 88 characters, under the 120
      // budget. Push it over — `body(count: 6)` is 132 — and the budget guard
      // six lines below would answer identically, the mutant would survive, and
      // everything here would still be green.
      expect(
        pageTwo.lines.skip(1).fold<int>(0, (a, l) => a + l.text.trim().length),
        lessThan(120),
        reason: 'premise: the budget must NOT be what answers this fixture',
      );

      expect(identical(withoutOrphanTail(input, layout).text, input), isTrue);
    });

    test('does nothing without a layout', () {
      const input = 'Nagon text\nutan geometri';

      final cut = withoutOrphanTail(input, null);

      expect(identical(cut.text, input), isTrue);
      expect(cut.layout, isNull);
    });

    test('does nothing when the input has FEWER rows than the layout', () {
      final lines = [...body(), heading('Mandelforell')];
      final layout = doc(lines);

      const short = 'bara en rad';
      expect(identical(withoutOrphanTail(short, layout).text, short), isTrue);
    });

    test('does nothing when the input has MORE rows than the layout', () {
      // The dangerous direction, and the one the length bound cannot catch:
      // extra rows shift every row number, so a heading index resolved against
      // the geometry addresses the WRONG row of the text — and the pair that
      // comes back is still row-count-consistent, so the splitter accepts it
      // and real content is gone silently.
      //
      // Its sibling above is answered by the `textRow > rows.length` bound even
      // with the gate deleted, so it pins the gate's SHAPE and not its
      // existence. This one is what makes the gate load-bearing.
      final lines = [
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc(lines);
      final input = 'Ur kokboken, sidan 42\n${layout.text!}';

      expect(identical(withoutOrphanTail(input, layout).text, input), isTrue);
    });

    test('still cuts when text and geometry differ in BYTES but not in rows', () {
      // The regression that would have shipped a byte comparison: in production
      // `HtmlSanitizer` rewrites the text and never the geometry, so the two
      // strings differ on every sanitized page while their row counts match.
      final lines = [
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc(lines);
      final sanitized = layout.text!.replaceAll('brodtext', 'brOdtext');

      final cut = withoutOrphanTail(sanitized, layout);

      expect(cut.text.contains('Mandelforell'), isFalse);
      // And the text it returns is the SANITIZED one, not one re-derived from
      // the page — otherwise the trim would quietly undo the sanitizer.
      expect(cut.text.contains('brOdtext'), isTrue);
    });

    test('only the LAST page of a multi-page document may be trimmed', () {
      // Page one's trailing heading is continued on page two — it is spliced,
      // not orphaned, so cutting it would delete a real recipe's title.
      //
      // Page two is deliberately longer than page one's HEADING ROW (not than
      // its flat offset — those are equal at 8), so that
      // reading `pages.first` does not merely overshoot into a no-op: it lands
      // inside page two and removes rows. An earlier version of this fixture
      // had page two too short, the mutant self-masked, and the test protected
      // nothing — measured, not guessed.
      final pageOne = PageLayout(
        lines: [
          ...body(count: 6),
          heading('Fortsatter pa nasta sida'),
          line('2 dl', wordHeight: 70, words: 2),
        ],
      );
      final pageTwo = PageLayout(
        lines: [...body(count: 8, text: 'sida tva brodtext ord')],
      );
      final layout = DocumentLayout([pageOne, pageTwo]);
      final input = layout.text!;

      // All of this test's mutation value comes from page ONE's heading being
      // detected — the `pages.first` mutant has to have something to cut. If
      // that title ever drifts out of `headingLines` (a renamed word with a
      // descender is enough), the test stays green and pins nothing.
      expect(
        HeadingDetector.headingLines(pageOne),
        isNotEmpty,
        reason: "fixture premise: page one's heading must be detected",
      );

      final cut = withoutOrphanTail(input, layout);

      // Page two has no heading, so there is nothing to trim anywhere.
      expect(identical(cut.text, input), isTrue);
      expect(cut.text.contains('Fortsatter pa nasta sida'), isTrue);
    });

    test('the page index is flattened before it addresses a text row', () {
      // `headingLines` indexes the PAGE; `textLineIndex` wants an index into
      // the flattened document. Feeding one to the other resolves to a row on
      // page ONE, cutting the input mid-page-one and taking page two with it.
      // Page one is long so the mistake is unmistakable in the output.
      final pageOne = PageLayout(
        lines: [...body(count: 8, text: 'sida ett brodtext ord')],
      );
      final pageTwo = PageLayout(
        lines: [
          ...body(count: 6, text: 'sida tva brodtext ord'),
          heading('Mandelforell'),
          line('2 dl', wordHeight: 70, words: 2),
        ],
      );
      final layout = DocumentLayout([pageOne, pageTwo]);

      final cut = withoutOrphanTail(layout.text!, layout);

      // The tail is gone...
      expect(cut.text.contains('Mandelforell'), isFalse);
      // ...and NOTHING of page one or page two's body went with it.
      expect(cut.text.contains('sida ett brodtext ord 7'), isTrue);
      expect(cut.text.contains('sida tva brodtext ord 5'), isTrue);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('does nothing when a single page opens on its heading', () {
      // Honest about what this proves: NOT the `pageRow == 0` guard. The tail
      // here is 132 characters, so the BUDGET answers it, and with the budget
      // also removed `textRow` resolves to 0 and the bound answers it. Three
      // guards must go before it reddens — measured, not assumed. The fixture
      // that actually pins `pageRow == 0` is the two-page one above; this one
      // stays because a single page opening on a heading is the commonest real
      // shape and something should assert it survives untouched.
      final lines = [heading('Mandelforell'), ...body()];
      final layout = doc(lines);
      final input = layout.text!;

      expect(identical(withoutOrphanTail(input, layout).text, input), isTrue);
    });

    test('cuts a heading that IS the last row, with nothing under it', () {
      // Three of the ten corpus tails the rule cuts have this exact shape:
      // `IAUS`, `Sina ingredienser`, `Sina ingr` — a heading at the very bottom
      // of the frame with zero characters after it. No fixture built it until
      // the coverage matrix of 2026-08-09 pointed out the commonest documented
      // case was the untested one.
      final lines = [...body(count: 8), heading('IAUS')];
      final layout = doc(lines);
      final input = layout.text!;

      final cut = withoutOrphanTail(input, layout);

      expect(cut.text.contains('IAUS'), isFalse);
      expect(cut.layout!.pages.first!.lines.length, 8);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    group('the 120-character budget is the decision, so pin its edge', () {
      // `_tailBudget` is private and every measured verdict in
      // `ACCEPTED_DEVIATIONS.md` rests on its value. Without a boundary pair it
      // could drift to 200 — the value that entry explicitly DECLINED, and the
      // one where the corpus loses a page — with the suite green.
      //
      // `tailOf` builds a tail of exactly [chars] characters as counted by the
      // rule: it sums `text.trim().length` over the rows AFTER the heading.
      //
      // Filler is `l`, not `x`, and that is not arbitrary. `x` has no ascender,
      // so its glyphSpan is 1.0 and the row's TYPE height comes out 70.0 —
      // only 3.3 % under the 72.41 heading bar, a margin that lives on the gap
      // between two constants in two different files (`headingSizeRatio` 1.50
      // and `_ascenderRise` 0.45). `l` spans 1.45 like the body text, so the
      // row measures 48.28 and the pair differs in exactly one reachable
      // quantity: `tailChars`.
      List<OcrLine> tailOf(int chars) => [
        line('l' * chars, wordHeight: 70, words: 1),
      ];

      test('a 119-character tail is furniture and goes', () {
        final layout = doc([
          ...body(),
          heading('Mandelforell'),
          ...tailOf(119),
        ]);
        final input = layout.text!;

        expect(
          withoutOrphanTail(input, layout).text.contains('Mandelforell'),
          isFalse,
        );
      });

      test('a 120-character tail is content and stays', () {
        final layout = doc([
          ...body(),
          heading('Mandelforell'),
          ...tailOf(120),
        ]);
        final input = layout.text!;

        expect(identical(withoutOrphanTail(input, layout).text, input), isTrue);
      });
    });

    test('does nothing on a page with no headings at all', () {
      final layout = doc(body(count: 8));
      final input = layout.text!;

      expect(identical(withoutOrphanTail(input, layout).text, input), isTrue);
    });

    test('carries imageWidth and imageHeight across the trim', () {
      final page = PageLayout(
        lines: [
          ...body(),
          heading('Mandelforell'),
          line('2 dl', wordHeight: 70, words: 2),
        ],
        imageWidth: 3000,
        imageHeight: 4000,
      );
      final layout = DocumentLayout([page]);

      final cut = withoutOrphanTail(layout.text!, layout);

      expect(cut.layout!.pages.first!.imageWidth, 3000);
      expect(cut.layout!.pages.first!.imageHeight, 4000);
    });
  });
}
