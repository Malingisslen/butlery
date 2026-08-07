import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// The LAYOUT path of the splitter — boundaries from type size rather than from
/// an ingredient cluster.
///
/// Every test here builds the input FROM the layout (`layout.text`), because
/// that is what production does and because a hand-typed input would fail the
/// row-count precondition for the wrong reason and make the whole path look
/// broken.
///
/// **Every heading below is written with the same GLYPH SHAPE on purpose** —
/// capital initial, at least one ascender, no descender, no diacritic — so each
/// one normalises by the same factor and the `height` argument is the only
/// thing that varies. `OcrWord.typeHeight` divides a box by the vertical zones
/// its letters occupy, so 'Provencalska agg' and 'Fransk omelett' at identical
/// type size do NOT measure identical; a fixture ignoring that measures the
/// alphabet instead of the layout rule it names.
void main() {
  late MultiRecipeSplitter splitter;
  setUp(() => splitter = MultiRecipeSplitter());

  OcrLine row(String text, double height) => OcrLine(
    text: text,
    box: LayoutBox(left: 0, top: 0, width: text.length * 18, height: height),
    words: [
      for (final w in text.trim().isEmpty ? <String>[] : text.trim().split(' '))
        OcrWord(
          text: w,
          box: LayoutBox(left: 0, top: 0, width: 40, height: height),
        ),
    ],
  );

  /// Body prose long enough to clear the 200-char block minimum and to carry an
  /// instruction signal, which a layout block must have.
  ///
  List<OcrLine> body(String dish) => [
    row('Lagg kokta skalade agg i en ratatouille och servera', 70),
    row('med brod till eller med raris och en fransk gronsaksrora', 70),
    row('Vispa ihop smeten och grada den i ugnen tills $dish ar klar', 70),
    row('Koka upp och lat sjuda under lock i ungefar tjugo minuter', 70),
  ];

  PageLayout spread() => PageLayout(
    lines: [
      row('Italiensk frittata', 167),
      ...body('ratten'),
      row('Fransk omelett', 167),
      ...body('omeletten'),
    ],
  );

  group('the layout path splits what the text rules cannot', () {
    test('a prose spread with NO ingredient list becomes two recipes', () {
      // The page the whole approach exists for: on a prose spread the text
      // rules return ONE block, and no rewording of them would fix it.
      final doc = DocumentLayout([spread()]);
      final input = doc.text!;

      // The control holds for ONE reason — the fixture carries no quantities
      // anywhere, so `_ingredientClusterAhead` never fires and no boundary
      // opens. Both titles DO pass the text path's own title test (measured:
      // `looksLikeIngredient` is false for each), so the ingredient-word guard
      // an earlier version of this comment credited is not what saves it.
      // Consequence: adding "2 dl grädde" to the body would flip the control
      // and this test would then prove nothing.
      expect(
        splitter.split(input),
        equals([input]),
        reason: 'control — the text rules alone still merge this page',
      );

      final blocks = splitter.split(input, layout: doc);
      expect(blocks, hasLength(2));
      expect(blocks[0], startsWith('Italiensk frittata'));
      expect(blocks[1], startsWith('Fransk omelett'));
    });

    test('every block keeps its own body', () {
      final doc = DocumentLayout([spread()]);
      final blocks = splitter.split(doc.text!, layout: doc);

      // The negative anchors on the next block's HEADING, not on its body: the
      // heading is the first row of block 2, so this pins block 1's end row
      // exactly. Anchoring on 'omeletten ar klar' (three rows further down) let
      // an end-boundary off-by-one through — measured, it killed nothing.
      // A `blocks[0] contains 'ratten ar klar'` assertion was dropped here for
      // the same reason: it reddened under none of 18 mutants, because a
      // fallback returns the whole input and satisfies it too.
      expect(blocks[0], isNot(contains('Fransk omelett')));
      expect(blocks[1], contains('omeletten ar klar'));
    });

    test('a two-page import opens its second block on the right row', () {
      // The only fixture in this file where `DocumentLayout.textLineIndex` does
      // anything: on one page a flat line index IS a text row, so dropping the
      // conversion entirely is invisible. Page two's heading is deliberately
      // NOT its first line — with the heading first, the one-row page separator
      // shift lands on the blank row and `trim()` erases the evidence, so a
      // two-page fixture written the obvious way still kills nothing.
      final continuation = PageLayout(
        lines: [
          row('Fortsattning fran foregaende sida om maten', 70),
          row('Fransk omelett', 167),
          ...body('omeletten'),
        ],
      );
      final doc = DocumentLayout([
        PageLayout(lines: [row('Italiensk frittata', 167), ...body('ratten')]),
        continuation,
      ]);

      final blocks = splitter.split(doc.text!, layout: doc);
      expect(blocks, hasLength(2));
      expect(blocks[1], startsWith('Fransk omelett'));
      // The continuation row belongs to the recipe it continues, not to the
      // next one — which is what makes the off-by-one visible at all.
      expect(blocks[0], endsWith('om maten'));
    });

    test('a rejected block is DROPPED — the good ones still ship', () {
      // Page furniture at the foot of a spread: an index heading with nothing
      // under it. Its block is too short, and the contract is that it is
      // skipped while the two real recipes still split — not that one piece of
      // furniture cancels the whole page. Turning that `continue` into a
      // `return null` reddens nothing else in this file.
      //
      // Its 8 characters are also what keeps the discard budget below its
      // limit; that is the boundary the next group pins from the other side.
      final page = PageLayout(
        lines: [
          row('Italiensk frittata', 167),
          ...body('ratten'),
          row('Fransk omelett', 167),
          ...body('omeletten'),
          row('Innehall', 167),
        ],
      );
      final doc = DocumentLayout([page]);

      final blocks = splitter.split(doc.text!, layout: doc);
      expect(blocks, hasLength(2));
      expect(blocks[1], isNot(contains('Innehall')));
    });
  });

  group('the discard budget — furniture may vanish, a recipe may not', () {
    /// Prose with no cooking verb in it, so a block built from these lines is
    /// long enough to be a recipe and still fails the instruction test.
    List<OcrLine> silentProse(int n) => List.generate(
      n,
      (i) => row(
        'Detta ar en beskrivande text om kokbokens historia nummer $i som '
        'fortsatter en bra bit utan att namna nagon tillagning',
        70,
      ),
    );

    test('a recipe-sized block that is dropped cancels the whole split', () {
      // The middle recipe's method OCR'd as description, so its block clears
      // the length rule and fails the instruction one. Dropping it would hand
      // over two confident recipes and eat the third — a WORSE answer than the
      // text path's, which returns the page whole. Measured: without the
      // budget this returns 2 blocks.
      final page = PageLayout(
        lines: [
          row('Italiensk frittata', 167),
          ...body('ratten'),
          row('Mellanratten', 167),
          ...silentProse(2),
          row('Fransk omelett', 167),
          ...body('omeletten'),
        ],
      );
      final doc = DocumentLayout([page]);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('an INDENTED instruction row still counts', () {
      // The per-line `.trim()` in `_splitByLayout`. `instructionScore` matches
      // its verb with `startsWith`, so a leading space costs the +3 the verb is
      // worth — measured, 'Vispa smeten.' scores 3 and ' Vispa smeten.' scores
      // 0, against a gate of 2.
      //
      // It takes this shape of block to see it. The `body()` helper's rows are
      // long enough and contextual enough to clear the gate on length and
      // sequencing alone, so indenting THEM leaves the mutant alive — measured
      // twice. Here the prose carries no cooking signal at all and one short
      // indented line is the block's only instruction, so dropping the trim
      // drops both blocks and the whole path declines.
      List<OcrLine> blockBody() => [
        ...silentProse(2),
        row('  Vispa smeten.', 70),
      ];
      final page = PageLayout(
        lines: [
          row('Italiensk frittata', 167),
          ...blockBody(),
          row('Fransk omelett', 167),
          ...blockBody(),
        ],
      );
      final doc = DocumentLayout([page]);

      expect(splitter.split(doc.text!, layout: doc), hasLength(2));
    });

    test('a recipe BEFORE the first heading cancels the split', () {
      // `HeadingDetector` caps a title at 60 characters. One character over and
      // the whole first recipe sits in front of the first boundary, inside no
      // block at all — the failure that is invisible without counting it.
      final page = PageLayout(
        lines: [
          ...body('den forsta ratten'),
          row('Italiensk frittata', 167),
          ...body('ratten'),
          row('Fransk omelett', 167),
          ...body('omeletten'),
        ],
      );
      final doc = DocumentLayout([page]);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });
  });

  group('every doubt falls back to the text rules', () {
    // Every test in this group asserts `equals([input])`, never `hasLength(1)`.
    // Measured: relaxing the layout path's `blocks.length < 2` to `< 1` returns
    // ONE block that is a TRUNCATED slice of the page — the first heading and
    // its lines are silently gone — and a length-only assertion stays green on
    // it. Falling back means handing the input back untouched, so that is what
    // these say.
    test('a layout describing a DIFFERENT string is discarded', () {
      // The precondition. Confident line numbers against the wrong string is
      // the one outcome worse than not splitting: it would open recipes
      // mid-sentence and nothing would report it.
      final doc = DocumentLayout([spread()]);
      final shifted = 'En extra rad forst\n${doc.text!}';

      expect(splitter.split(shifted, layout: doc), equals([shifted]));
    });

    test('a page with no measurable baseline declines', () {
      // Too few body lines to establish what "body size" means. The detector
      // returns nothing, and nothing is not "one recipe" — it is "ask the text
      // rules".
      final page = PageLayout(
        lines: [row('Italiensk frittata', 167), row('kort rad', 70)],
      );
      final doc = DocumentLayout([page]);

      expect(page.bodyTypeHeight, isNull);
      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('blocks under the 200-char minimum are not recipes', () {
      // Each block here CARRIES a cooking verb, so the instruction rule is
      // satisfied and only the length rule can refuse them — measured: with the
      // minimum dropped to 1 this fixture yields two blocks. The text path
      // allows 40 chars because its boundaries already cleared an ingredient
      // cluster; a size-derived boundary has no such evidence, so the block
      // itself must carry the weight.
      final page = PageLayout(
        lines: [
          row('Italiensk frittata', 167),
          row('Vispa och grada.', 70),
          row('Fransk omelett', 167),
          row('Koka och stek.', 70),
          row('en lang rad brodtext som fortsatter har ett tag till', 70),
          row('annu en lang rad brodtext som fortsatter har ocksa', 70),
          row('tredje raden brodtext som fortsatter har lite till', 70),
          row('fjarde raden brodtext som fortsatter har ocksa den', 70),
        ],
      );
      final doc = DocumentLayout([page]);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('a block with no instruction signal is not a recipe', () {
      // Long enough, but nothing in it reads as cooking. A page of prose about
      // a cookbook is not a page of recipes.
      final flat = List.generate(
        6,
        (i) => row(
          'Detta ar en beskrivande text om kokbokens historia nummer $i som '
          'fortsatter en bra bit utan att namna nagon tillagning',
          70,
        ),
      );
      final page = PageLayout(
        lines: [row('Forordet', 167), ...flat, row('Efterordet', 167), ...flat],
      );
      final doc = DocumentLayout([page]);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('an import with no geometry still splits on the text rules', () {
      // The rollback: the new optional parameter must not disturb the path that
      // ships today. `split(page, layout: null)` compared against `split(page)`
      // used to stand here as well — `layout` DEFAULTS to null, so that was the
      // same call twice and could not fail. The behavioural half is what is
      // left; `test/services/import/multi_recipe_splitter_test.dart` owns the
      // text path's real coverage.
      //
      // Real Swedish throughout, deliberately: the text path's instruction
      // scoring is diacritic-sensitive, and a fixture written half in ASCII
      // measures the wrong thing while still looking fine.
      const page =
          'Pannkakor\n'
          'Ingredienser:\n'
          '3 dl vetemjöl\n'
          '2 ägg\n'
          'Gör så här:\n'
          'Vispa ihop smeten och stek i smör.\n'
          '\n'
          'Våfflor\n'
          'Ingredienser:\n'
          '4 dl vetemjöl\n'
          '3 dl grädde\n'
          'Gör så här:\n'
          'Grädda i våffeljärn tills gyllene.';

      expect(splitter.split(page, layout: null), hasLength(2));
    });
  });

  group('the block cap', () {
    DocumentLayout headings(int n) {
      final lines = <OcrLine>[];
      for (var i = 0; i < n; i++) {
        lines.add(row('Kalvfilet $i', 167));
        lines.addAll(body('ratten'));
      }
      return DocumentLayout([PageLayout(lines: lines)]);
    }

    test('a layout suggesting nine recipes is describing noise', () {
      // Nine headings on one page is not a cookbook spread. Falling back beats
      // handing the user nine half-recipes, all pre-ticked, with no way to
      // merge them.
      final doc = headings(9);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('the cap is per page, so a two-photo import of nine is not noise', () {
      // Nine recipes on ONE page is noise; nine across TWO photographed pages
      // is an ordinary import of a cookbook someone shot twice. The detector
      // works document-wide, so a flat document cap would have switched the
      // layout path off for exactly the case it exists for.
      final doc = DocumentLayout([
        PageLayout(lines: headings(5).pages.first!.lines),
        PageLayout(lines: headings(4).pages.first!.lines),
      ]);

      expect(splitter.split(doc.text!, layout: doc), hasLength(9));
    });

    test('nine on ONE page is noise even when a second page is quiet', () {
      // The skewed distribution. A document total scaled by the page count —
      // which is what this cap was until 2026-08-07 — passes 9 blocks across
      // two pages without ever asking where they sit, so the noisy page slips
      // through behind a quiet neighbour. The cap has to be counted against the
      // page each block actually opens on. (Quiet, not EMPTY: a page with no
      // lines at all declines for a different reason and the whole document
      // falls back, which would prove nothing about the cap.)
      final quiet = PageLayout(
        lines: [
          row('Fortsattning fran foregaende sida om maten', 70),
          ...body('ratten'),
        ],
      );
      final doc = DocumentLayout([
        PageLayout(lines: headings(9).pages.first!.lines),
        quiet,
      ]);

      expect(splitter.split(doc.text!, layout: doc), equals([doc.text!]));
    });

    test('a block opening on a page FIRST row belongs to that page', () {
      // The `<=` in the page lookup, which nothing else pins. Eight blocks on
      // page one is exactly at the cap; the ninth opens on page two's very
      // first row. Attribute it to the previous page — which a `<` does — and
      // page one counts nine, so the whole import falls back and two ordinary
      // photos of a cookbook produce one blob.
      final doc = DocumentLayout([
        PageLayout(lines: headings(8).pages.first!.lines),
        PageLayout(lines: [row('Kalvfilet 9', 167), ...body('ratten')]),
      ]);

      expect(splitter.split(doc.text!, layout: doc), hasLength(9));
    });

    test('eight is still a cookbook spread', () {
      // The other side of the bound. Measured: tightening the cap from 8 to 2
      // reddens three tests, two of them elsewhere in this file — so this one
      // is not the sole guard its earlier comment claimed. It is the tightest
      // statement of the accepted case, and the number carries a measured
      // rationale in `HeadingDetector`, so it should not drift by accident.
      final doc = headings(8);

      expect(splitter.split(doc.text!, layout: doc), hasLength(8));
    });
  });
}
