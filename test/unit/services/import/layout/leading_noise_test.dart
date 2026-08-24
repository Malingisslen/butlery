import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/layout/leading_noise.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line whose TYPE height is set by its word boxes, which is the only thing
/// `HeadingDetector` MEASURES — it also READS the text, because
/// `_readsLikeTitle` gates on length, word count, a quantity regex, terminal
/// punctuation and a capital initial. A fixture heading has to satisfy both.
///
/// Body lines carry four words by default so they can establish the page's
/// baseline; `words: 4` is `PageLayout._minBodyWords` EXACTLY, with no
/// headroom — a furniture fixture deliberately uses FEWER words so it never
/// contaminates the baseline median, same convention as `orphan_tail_test.dart`.
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
          text: i < tokens.length ? tokens[i] : 'ord',
          box: LayoutBox(left: i * 200, top: 0, width: 180, height: wordHeight),
        ),
    ],
  );
}

/// Six body lines — enough for a baseline, and 22 characters each, matching
/// `orphan_tail_test.dart`'s `body()` exactly (the two suites' fixtures are
/// deliberately kept in the same shape rather than shared, so each stays
/// readable standalone — see `frame_trim_test.dart` for where the two rules
/// actually meet, and `import_manager_orphan_tail_test.dart` for the wiring).
List<OcrLine> body({int count = 6, String text = 'brodtext rad med ord'}) => [
  for (var i = 0; i < count; i++) line('$text $i', wordHeight: 70),
];

/// A heading: same fixture shape, 2x the body's type height.
OcrLine heading(String text) => line(text, wordHeight: 145, words: 1);

DocumentLayout doc(List<PageLayout> pages) => DocumentLayout(pages);

PageLayout page(List<OcrLine> lines) => PageLayout(lines: lines);

void main() {
  group('withoutLeadingNoise', () {
    test('drops a short furniture line before the first heading', () {
      final lines = [
        // 13 characters, well under the 60-char budget, and not shaped like
        // an ingredient or instruction — a running header/folio stand-in.
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [1],
        reason: 'premise: exactly one detected heading, at row 1',
      );

      final cut = withoutLeadingNoise(input, layout);

      expect(cut.text.contains('Kokboken'), isFalse);
      expect(cut.text.startsWith('Mandelforell'), isTrue);
      expect(cut.layout!.pages.first!.lines.length, 7);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('keeps an ingredient-shaped leading line even under budget', () {
      final lines = [
        // Short (10 chars, under budget) but reads as an ingredient row via
        // `RecipeSectionDetector.looksLikeIngredient`'s measurement pattern —
        // the guard this rule carries specifically so a stray ingredient line
        // is never mistaken for furniture.
        line('2 dl mjolk', wordHeight: 70, words: 3),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(cut.text.contains('2 dl mjolk'), isTrue);
    });

    test('keeps an instruction-shaped leading line even under budget', () {
      final lines = [
        // Under budget, but contains a cooking-instruction keyword
        // (`RecipeSectionDetector.hasInstructionKeywords`).
        line('Koka upp vattnet', wordHeight: 70, words: 3),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(cut.text.contains('Koka upp vattnet'), isTrue);
    });

    test('leaves a long leading passage alone — over the budget', () {
      final lines = [
        // Three 22-character lines = 66 characters, over the 60-char budget,
        // and shaped like neither an ingredient nor an instruction — isolates
        // the budget gate from the content gate above.
        line('brodtext rad med ord 0', wordHeight: 70),
        line('brodtext rad med ord 1', wordHeight: 70),
        line('brodtext rad med ord 2', wordHeight: 70),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [3],
        reason: 'premise: exactly one detected heading, at row 3',
      );

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
    });

    test('does nothing when the heading is already the first row', () {
      final lines = [heading('Mandelforell'), ...body()];
      final layout = doc([page(lines)]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(identical(cut.layout, layout), isTrue);
    });

    test('does nothing when no heading is detected on the page', () {
      final layout = doc([page(body())]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
    });

    test('cuts at the FIRST heading, never a later one', () {
      // TWO headings, which is the whole point: a single-heading fixture
      // cannot tell `headings.first` from `headings.last` and proves only
      // the budget — same trap `orphan_tail_test.dart` names for its own
      // `.last` selection. Both headings sit in the same glyphSpan bucket
      // (no lowercase descender in either), so both are really detected.
      final lines = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Forsta Ratten'),
        ...body(count: 6, text: 'forsta rattens text'),
        heading('Andra Ratten'),
        ...body(count: 6, text: 'andra rattens text'),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [1, 8],
        reason: 'premise: BOTH titles must be detected headings',
      );

      final cut = withoutLeadingNoise(input, layout);

      // If this ever regresses to `headings.last`, `pageRow` becomes 8 and
      // the region it would try to CUT is rows 0 through 7 — 152 characters
      // (13 + 13 + 6x21), over budget — so
      // the function would return UNCHANGED instead of wrongly swallowing
      // the first recipe. Either way the correct behaviour and the `.last`
      // mutant disagree on whether "Kokboken" survives, which is what this
      // test reads.
      expect(cut.text.contains('Kokboken'), isFalse);
      expect(cut.text.startsWith('Forsta Ratten'), isTrue);
      expect(cut.text.contains('Andra Ratten'), isTrue);
    });

    group('the 60-character budget is the decision, so pin its edge', () {
      // `_leadingBudget` is private and every claim in `leading_noise.dart`'s
      // own doc about it ("half of `_tailBudget`", "the tail trim's OTHER
      // measured row") rests on its value staying 60. Without a boundary
      // pair it could drift with the suite green — same rationale
      // `orphan_tail_test.dart` states for its own 119/120 pair.
      //
      // Filler is `l`, not `x`, for the same reason as the tail suite: `l`'s
      // glyphSpan (1.45, ascender) keeps the row's TYPE height at the body
      // baseline (~48.28) rather than drifting toward the heading threshold,
      // so the filler can never be misread as a heading itself.
      List<OcrLine> headOf(int chars) => [
        line('l' * chars, wordHeight: 70, words: 1),
      ];

      test('a 59-character lead is furniture and goes', () {
        final layout = doc([
          page([...headOf(59), heading('Mandelforell'), ...body()]),
        ]);
        final input = layout.text!;

        expect(
          withoutLeadingNoise(input, layout).text.contains('l' * 59),
          isFalse,
        );
      });

      test('a 60-character lead is content and stays', () {
        final layout = doc([
          page([...headOf(60), heading('Mandelforell'), ...body()]),
        ]);
        final input = layout.text!;

        expect(
          identical(withoutLeadingNoise(input, layout).text, input),
          isTrue,
        );
      });
    });

    test('carries imageWidth and imageHeight across the trim', () {
      final pageLayout = PageLayout(
        lines: [
          line('Kokboken 2024', wordHeight: 70, words: 2),
          heading('Mandelforell'),
          ...body(),
        ],
        imageWidth: 3000,
        imageHeight: 4000,
      );
      final layout = DocumentLayout([pageLayout]);

      final cut = withoutLeadingNoise(layout.text!, layout);

      expect(cut.layout!.pages.first!.imageWidth, 3000);
      expect(cut.layout!.pages.first!.imageHeight, 4000);
    });

    test('only page zero is eligible — a later page keeps its furniture', () {
      final firstPage = [heading('Recept Ett'), ...body()];
      final secondPage = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(firstPage), page(secondPage)]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      // Page zero already starts on its heading (nothing to cut there), and
      // this rule never inspects any page but the first — so the whole
      // document comes back UNTOUCHED and the second page's furniture
      // survives, even though it is the same shape as the case this rule
      // cuts on page zero.
      //
      // `identical` is the load-bearing assertion, and the weaker
      // `contains('Kokboken')` alone was VACUOUS here — measured 2026-08-12.
      // Under a `pages.first` -> `pages.last` mutant the rule reads page
      // ONE's headings, gets `pageRow == 1`, and then feeds that PAGE index
      // to `textLineIndex` as if it were a FLAT one — which lands inside
      // page ZERO and cuts `Recept Ett` instead. `Kokboken` survives that
      // too, so the old assertion passed on a mutant that both deleted a
      // real heading AND broke the row-count invariant.
      expect(identical(cut.text, input), isTrue);
      expect(identical(cut.layout, layout), isTrue);
      expect(cut.text.contains('Kokboken'), isTrue);
      expect(cut.text.contains('Recept Ett'), isTrue);
    });

    test('a trimmed page zero keeps the row-count invariant on a SPREAD', () {
      // The invariant assertion elsewhere in this file is single-page, where
      // it cannot see a page-separator mistake. Here page zero is really
      // trimmed and a second page follows it, so the returned text and the
      // returned geometry have to agree across the separator too — the gate
      // `MultiRecipeSplitter` refuses geometry on when it fails.
      final firstPage = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Recept Ett'),
        ...body(),
      ];
      final secondPage = [heading('Recept Tva'), ...body()];
      final layout = doc([page(firstPage), page(secondPage)]);
      final input = layout.text!;

      final cut = withoutLeadingNoise(input, layout);

      expect(cut.text.contains('Kokboken'), isFalse);
      expect(cut.text.contains('Recept Tva'), isTrue);
      expect(cut.layout!.pages.first!.lines.length, 7);
      expect(cut.layout!.pages.last!.lines.length, 7);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('a row-count mismatch between text and layout no-ops', () {
      final lines = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Mandelforell'),
        ...body(),
      ];
      final layout = doc([page(lines)]);
      const input = 'not the same text\nat all';

      final cut = withoutLeadingNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(identical(cut.layout, layout), isTrue);
    });

    test('without a layout the text is handed back untouched', () {
      const input = 'Kokboken 2024\nMandelforell\nnagot mer';

      final cut = withoutLeadingNoise(input, null);

      expect(identical(cut.text, input), isTrue);
      expect(cut.layout, isNull);
    });
  });
}
