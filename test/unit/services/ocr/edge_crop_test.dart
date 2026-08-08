import 'package:butlery/services/ocr/edge_crop.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line placed by its INK span, which is the only thing the rule reads.
///
/// The line's own `box` is deliberately given a different, wrong span (a full
/// page width) in every fixture below. If the implementation ever reads
/// `OcrLine.box` instead of walking the words, these tests go red — that
/// substitution is not cosmetic, because on a device `box` is ML Kit's line rect
/// while a replay derives it from the word union
/// (`docs/architecture/ACCEPTED_DEVIATIONS.md`).
OcrLine line(String text, {required double left, required double right}) {
  return OcrLine(
    text: text,
    box: const LayoutBox(left: 0, top: 0, width: 3000, height: 40),
    words: [
      OcrWord(
        text: text,
        box: LayoutBox(left: left, top: 0, width: right - left, height: 40),
      ),
    ],
  );
}

/// Eight body lines spanning 500..2600 — a plausible single column.
List<OcrLine> body({int count = 8}) => [
  for (var i = 0; i < count; i++)
    line('brodtextrad nummer $i', left: 500, right: 2600),
];

void main() {
  group('EdgeCrop', () {
    test('drops a bleed band pressed outside the body margins', () {
      // The shape from the corpus page the feature was reported on: a column of
      // 3-4 character slivers starting past where every body line ends.
      final page = PageLayout(
        lines: [
          ...body(),
          line('osc', left: 2875, right: 3000),
          line('frof', left: 2876, right: 3000),
          line('latt', left: 2880, right: 3000),
          line('lite', left: 2892, right: 3000),
        ],
      );

      final cropped = cropEdgeBleed(page);

      expect(cropped.lines.length, 8);
      expect(
        cropped.lines.map((l) => l.text),
        everyElement(startsWith('brodtextrad')),
      );
    });

    test('KEEPS a narrow line that sits inside the body margins', () {
      // The failure this rule exists to avoid. "2 dl" is as narrow as any bleed
      // fragment; what makes it content is WHERE it is. A width-only rule
      // deletes it.
      final page = PageLayout(
        lines: [...body(), line('2 dl', left: 500, right: 700)],
      );

      final cropped = cropEdgeBleed(page);

      expect(cropped.lines.length, 9);
      expect(cropped.lines.map((l) => l.text), contains('2 dl'));
    });

    test('keeps a WIDE line that lies entirely outside the body margins', () {
      // The catastrophic direction, and the reason the width gate exists at
      // all: a second column starting past where every body line ends is
      // "outside the margins" by the same test a four-character sliver is. Only
      // its WIDTH separates a column from bleed, so deleting that clause would
      // silently delete a whole column of the recipe.
      //
      // (This replaced a plain full-width line inside the margins, which killed
      // no mutant — every other fixture here already carries eight of those.)
      final page = PageLayout(
        lines: [
          ...body(),
          line('hela hoger spalt rad ett', left: 2700, right: 4400),
        ],
      );

      expect(cropEdgeBleed(page).lines.length, 9);
    });

    test(
      'narrow furniture does not get to define the margin it is judged by',
      () {
        // Six short ingredient rows outnumber the four running-text lines. They
        // must not join the margin vote: let them, and bodyRight collapses from
        // 2600 to 700, every span on the page becomes "wide" against the shrunken
        // body span, and the sliver at the frame's edge survives.
        final page = PageLayout(
          lines: [
            ...body(count: 4),
            for (var i = 0; i < 6; i++)
              line('2 dl mjolk $i', left: 500, right: 700),
            line('osc', left: 2875, right: 3000),
          ],
        );

        final cropped = cropEdgeBleed(page).lines;

        expect(cropped.length, 10);
        expect(cropped.map((l) => l.text), isNot(contains('osc')));
      },
    );

    test('keeps a line with no word boxes — no geometry, no verdict', () {
      final unmeasured = OcrLine(
        text: 'Tillbehor',
        box: LayoutBox(left: 2900, top: 0, width: 60, height: 40),
        words: [],
      );
      final page = PageLayout(lines: [...body(), unmeasured]);

      final cropped = cropEdgeBleed(page);

      expect(cropped.lines.length, 9);
      expect(cropped.lines.map((l) => l.text), contains('Tillbehor'));
    });

    test('crops nothing when the rule would claim more than a third', () {
      // Six body lines and six slivers: not a bleed band, a badly framed shot
      // or a genuinely narrow page. Fail closed.
      final page = PageLayout(
        lines: [
          ...body(count: 6),
          for (var i = 0; i < 6; i++) line('sk$i', left: 2875, right: 3000),
        ],
      );

      expect(cropEdgeBleed(page).lines.length, 12);
    });

    test('crops correctly when imageWidth is 0, as it always is on a device', () {
      // The regression that sank the first draft of this rule. ML Kit reports no
      // image size, so a rule dividing by imageWidth degenerates silently rather
      // than throwing. This page declares none and must still be cropped.
      final page = PageLayout(
        lines: [...body(), line('osc', left: 2875, right: 3000)],
      );

      expect(page.imageWidth, 0);
      expect(cropEdgeBleed(page).lines.length, 8);
    });

    test('carries imageWidth and imageHeight across the crop', () {
      final page = PageLayout(
        lines: [...body(), line('osc', left: 2875, right: 3000)],
        imageWidth: 3000,
        imageHeight: 4000,
      );

      final cropped = cropEdgeBleed(page);

      expect(cropped.lines.length, 8);
      expect(cropped.imageWidth, 3000);
      expect(cropped.imageHeight, 4000);
    });

    test(
      'crops nothing when there are too few body lines to find a margin',
      () {
        // Three wide lines cannot establish a median margin worth deleting
        // against, so the slivers stay.
        //
        // Only TWO slivers, plus one narrow line inside the margins to make up
        // the six measurable lines the rule needs. The obvious fixture — three
        // body lines and three slivers — is answered by the one-third cap
        // instead (3 of 6 rows), so it stays green with this guard removed;
        // measured. Two of six is under the cap, which leaves this guard as the
        // only thing that can refuse the crop.
        final page = PageLayout(
          lines: [
            ...body(count: 3),
            line('2 dl', left: 500, right: 700),
            line('1 tsk', left: 500, right: 690),
            line('osc', left: 2875, right: 3000),
            line('frof', left: 2876, right: 3000),
          ],
        );

        // 2 of 7 clears the one-third cap with slack (2 vs 2.33). The earlier
        // 2-of-6 fixture sat on the tie `2 > 2`, where flipping the cap to `>=`
        // would have re-disarmed this test on its own. Both fixtures kill the
        // `_minBodyLines` mutant; the move bought margin, not a new kill.
        expect(cropEdgeBleed(page).lines.length, 7);
      },
    );

    test('crops nothing on a page with too few measurable lines', () {
      final page = PageLayout(
        lines: [
          ...body(count: 4),
          line('osc', left: 2875, right: 3000),
        ],
      );

      expect(cropEdgeBleed(page).lines.length, 5);
    });

    test('returns the identical object when there is nothing to crop', () {
      final page = PageLayout(lines: body());

      expect(identical(cropEdgeBleed(page), page), isTrue);
    });

    test('a left-margin bleed band is dropped too', () {
      // Shooting the right-hand page catches the left neighbour instead. The
      // rule is symmetric; nothing about it privileges the right edge.
      final page = PageLayout(
        lines: [
          ...body(),
          line('ec', left: 0, right: 120),
          line('om', left: 0, right: 118),
          line('sk', left: 2, right: 130),
          line('tt', left: 0, right: 125),
        ],
      );

      expect(cropEdgeBleed(page).lines.length, 8);
    });
  });
}
