import 'package:butlery/services/import/layout/frame_trim.dart';
import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/layout/leading_noise.dart';
import 'package:butlery/services/import/layout/orphan_tail.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same fixture shape as `orphan_tail_test.dart` and `leading_noise_test.dart`
/// — see either for the glyphSpan trap (a lowercase descender moves a token
/// from the 1.45 bucket to 1.80 and silently drops the line out of
/// `headingLines`). Every heading token below is descender-free on purpose.
OcrLine line(String text, {required double wordHeight, int words = 4}) {
  final tokens = text.trim().split(RegExp(r'\s+'));
  return OcrLine(
    text: text,
    box: LayoutBox(left: 0, top: 0, width: text.length * 18, height: wordHeight),
    words: [
      for (var i = 0; i < words; i++)
        OcrWord(
          text: i < tokens.length ? tokens[i] : 'ord',
          box: LayoutBox(left: i * 200, top: 0, width: 180, height: wordHeight),
        ),
    ],
  );
}

List<OcrLine> body({int count = 6, String text = 'brodtext rad med ord'}) => [
  for (var i = 0; i < count; i++) line('$text $i', wordHeight: 70),
];

OcrLine heading(String text) => line(text, wordHeight: 145, words: 1);

PageLayout page(List<OcrLine> lines) => PageLayout(lines: lines);

DocumentLayout doc(List<PageLayout> pages) => DocumentLayout(pages);

void main() {
  group('withoutFrameNoise', () {
    test('cuts both ends of a single page at once', () {
      final lines = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Frukostmat'),
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [1, 8],
        reason: 'premise: both titles are detected headings',
      );

      final cut = withoutFrameNoise(input, layout);

      expect(cut.text.contains('Kokboken'), isFalse, reason: 'leading');
      expect(cut.text.contains('Mandelforell'), isFalse, reason: 'tail');
      expect(cut.text.startsWith('Frukostmat'), isTrue);
      expect(cut.layout!.pages.first!.lines.length, 7);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('cuts each end on the RIGHT page of a spread', () {
      final firstPage = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Recept Ett'),
        ...body(),
      ];
      final secondPage = [
        heading('Recept Tva'),
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc([page(firstPage), page(secondPage)]);
      final input = layout.text!;

      final cut = withoutFrameNoise(input, layout);

      expect(cut.text.contains('Kokboken'), isFalse);
      expect(cut.text.contains('Mandelforell'), isFalse);
      expect(cut.text.contains('Recept Ett'), isTrue);
      expect(cut.text.contains('Recept Tva'), isTrue);
      expect(cut.layout!.pages.first!.lines.length, 7);
      expect(cut.layout!.pages.last!.lines.length, 7);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('cuts the tail alone when there is no leading furniture', () {
      final lines = [
        heading('Frukostmat'),
        ...body(),
        heading('Mandelforell'),
        line('2 dl', wordHeight: 70, words: 2),
      ];
      final layout = doc([page(lines)]);

      final cut = withoutFrameNoise(layout.text!, layout);

      expect(cut.text.contains('Mandelforell'), isFalse);
      expect(cut.text.startsWith('Frukostmat'), isTrue);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('cuts the head alone when there is no orphan tail', () {
      final lines = [
        line('Kokboken 2024', wordHeight: 70, words: 2),
        heading('Frukostmat'),
        ...body(),
      ];
      final layout = doc([page(lines)]);

      final cut = withoutFrameNoise(layout.text!, layout);

      expect(cut.text.contains('Kokboken'), isFalse);
      expect(cut.text.startsWith('Frukostmat'), isTrue);
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    /// The crossing guard, which is a product decision with no other cover.
    ///
    /// One heading, at row 1: it is `headings.first` AND `headings.last`, so
    /// both rules choose the same row and the two cuts meet. The rule is that
    /// the TAIL cut wins, because that one is corpus-measured and the leading
    /// one is not — so the output here must be byte-identical to running
    /// `withoutOrphanTail` alone, which is what this asserts.
    test('when the two cuts cross, the measured tail cut is the one kept', () {
      final lines = [
        line('42', wordHeight: 70, words: 1),
        heading('Frukostmat'),
        ...body(count: 4, text: 'kort rad har'),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [1],
        reason: 'premise: ONE heading, so first and last are the same row',
      );
      expect(
        orphanTailCutRow(input, layout),
        leadingNoiseCutRow(input, layout),
        reason: 'premise: both rules really do choose the same row',
      );

      final cut = withoutFrameNoise(input, layout);
      final tailOnly = withoutOrphanTail(input, layout);

      expect(cut.text, tailOnly.text);
      expect(cut.text.contains('42'), isTrue, reason: 'the head cut is dropped');
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });

    test('carries imageWidth and imageHeight across both cuts', () {
      final pageLayout = PageLayout(
        lines: [
          line('Kokboken 2024', wordHeight: 70, words: 2),
          heading('Frukostmat'),
          ...body(),
          heading('Mandelforell'),
          line('2 dl', wordHeight: 70, words: 2),
        ],
        imageWidth: 3000,
        imageHeight: 4000,
      );
      final layout = DocumentLayout([pageLayout]);

      final cut = withoutFrameNoise(layout.text!, layout);

      expect(cut.layout!.pages.first!.imageWidth, 3000);
      expect(cut.layout!.pages.first!.imageHeight, 4000);
    });

    test('returns the originals untouched when neither rule fires', () {
      final layout = doc([
        page([heading('Frukostmat'), ...body()]),
      ]);
      final input = layout.text!;

      final cut = withoutFrameNoise(input, layout);

      expect(identical(cut.text, input), isTrue);
      expect(identical(cut.layout, layout), isTrue);
    });

    test('without a layout the text is handed back untouched', () {
      const input = 'Kokboken 2024\nFrukostmat\nnagot mer';

      final cut = withoutFrameNoise(input, null);

      expect(identical(cut.text, input), isTrue);
      expect(cut.layout, isNull);
    });

    /// THE REGRESSION. This is the case that made `frame_trim.dart` exist.
    ///
    /// The fixture is built so the tail cut MOVES `bodyTypeHeight`: the four
    /// rows below the orphan heading are body-qualifying (4 words) and SHORTER
    /// than the recipe's own body rows, so removing them raises the median and
    /// with it `HeadingDetector`'s absolute bar. The real title then falls out
    /// of the heading list, `headings.first` moves to the SECOND title, and a
    /// chained leading trim measures the real recipe as furniture.
    ///
    /// The test asserts the fix and the fault in one place: chaining the two
    /// appliers (expressed inline, exactly as `import_manager` used to) loses
    /// the real title, and `withoutFrameNoise` keeps it. If the fixture ever
    /// stops reproducing the fault, the FIRST expectation reddens rather than
    /// the test quietly becoming a second happy-path case.
    test('a baseline shift cannot make the leading cut eat a real title', () {
      // Every token here spans 1.45 (measured: `ab`, `Abb`, `Ratt`, `Katt`
      // all carry an ascender and no descender), so `typeHeight` is just
      // `wordHeight / 1.45` and the arithmetic below is readable in raw
      // wordHeight units. `42` is the folio, and it sits outside that
      // arithmetic entirely: `glyphSpan` returns 0 for a word with no
      // letters, so `OcrWord.typeHeight` keeps the raw box. It never matters —
      // `_readsLikeTitle` rejects a leading digit, so the row is never a
      // heading, and at one word it never enters `bodyTypeHeight` either.
      //
      // The numbers are solved, not guessed. Body median before the tail cut
      // is (70 + 30) / 2 = 50, so the heading bar is 75; after it, only the
      // four 70s remain, the median is 70 and the bar is 105. `Abb` at 100
      // therefore sits ABOVE the bar before the cut and BELOW it after —
      // which is the whole mechanism. `Ratt`/`Katt` at 108 stay above both,
      // and 108 / 1.10 = 98.2 keeps `Abb` inside the page-relative floor
      // beforehand, so all three really are detected to begin with.
      final lines = [
        line('42', wordHeight: 70, words: 1),
        line('Abb', wordHeight: 100, words: 1),
        line('ab ab ab ab', wordHeight: 70),
        line('ab ab ab ab', wordHeight: 70),
        line('ab ab ab ab', wordHeight: 70),
        line('ab ab ab ab', wordHeight: 70),
        line('Ratt', wordHeight: 108, words: 1),
        line('Katt', wordHeight: 108, words: 1),
        line('ab ab ab ab', wordHeight: 30),
        line('ab ab ab ab', wordHeight: 30),
        line('ab ab ab ab', wordHeight: 30),
        line('ab ab ab ab', wordHeight: 30),
      ];
      final layout = doc([page(lines)]);
      final input = layout.text!;
      expect(
        HeadingDetector.headingLines(page(lines)),
        [1, 6, 7],
        reason: 'premise: all three titles are detected on the ORIGINAL page',
      );

      // The fault, reproduced through the OLD chained order.
      final chainedTail = withoutOrphanTail(input, layout);
      final chained = withoutLeadingNoise(
        chainedTail.text,
        chainedTail.layout,
      );
      expect(
        chained.text.contains('Abb'),
        isFalse,
        reason:
            'premise: the chained order must still LOSE the real title, or '
            'this fixture has stopped exercising the bug and the assertion '
            'below proves nothing',
      );

      // The fix.
      final cut = withoutFrameNoise(input, layout);

      expect(cut.text.contains('Abb'), isTrue, reason: 'the real title');
      expect(cut.text.contains('Ratt'), isTrue, reason: 'the second title');
      expect(cut.text.contains('42'), isFalse, reason: 'the folio still goes');
      expect(cut.text.contains('Katt'), isFalse, reason: 'the orphan tail');
      expect(cut.layout!.matchesLineCountOf(cut.text), isTrue);
    });
  });
}
