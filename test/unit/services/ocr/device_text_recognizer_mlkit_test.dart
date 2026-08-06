import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:butlery/services/ocr/device_text_recognizer_mlkit.dart';

/// The mapper that decides WHICH STRING every tier-0 consumer parses.
///
/// `recognize()` returns early unless `Platform.isAndroid || Platform.isIOS`,
/// so no test host can drive this through the public API — which is why
/// `toPageLayout` is `@visibleForTesting`. ML Kit's value types are plain Dart
/// with public constructors and no method channel, so the INPUT stages fine
/// off-device; only the seam was ever missing.
///
/// Everything here pins one law: the page's text is DERIVED from the lines, so
/// a line index is a row number of that text by construction. `recognized.text`
/// is ML Kit's own assembly and is not that string — it separates blocks, and
/// on a two-column spread its block order is the thing this whole feature
/// exists to stop trusting.
void main() {
  TextElement element(String text, Rect box) => TextElement(
    text: text,
    symbols: const [],
    boundingBox: box,
    recognizedLanguages: const [],
    cornerPoints: const [],
    confidence: null,
    angle: null,
  );

  TextLine line(
    String text, {
    required Rect box,
    List<TextElement> elements = const [],
  }) => TextLine(
    text: text,
    elements: elements,
    boundingBox: box,
    recognizedLanguages: const [],
    cornerPoints: const [],
    confidence: null,
    angle: null,
  );

  TextBlock block(List<TextLine> lines) => TextBlock(
    // ML Kit fills a block's own text with its lines joined by a newline. It is
    // never read by the mapper — the block level is dropped on purpose — but a
    // fixture that left it empty would not resemble what the platform hands
    // over.
    text: lines.map((l) => l.text).join('\n'),
    lines: lines,
    boundingBox: const Rect.fromLTWH(0, 0, 900, 600),
    recognizedLanguages: const [],
    cornerPoints: const [],
  );

  TextLine plain(String text, {double top = 0}) => line(
    text,
    box: Rect.fromLTWH(40, top, 820, 76),
    elements: [element(text, Rect.fromLTWH(40, top, 820, 70))],
  );

  test('the page text is the PER-LINE join, never ML Kit own assembly', () {
    // Two blocks off a cookbook spread. ML Kit's own string separates them with
    // a blank row; the layout's does not, because a row of the layout's string
    // must correspond to exactly one measured line or every index downstream is
    // off by however many blocks preceded it.
    final recognized = RecognizedText(
      text:
          'Provençalska ägg\n4 ägg\n'
          '\n'
          'Koka äggen i 8 minuter\nServera med bröd',
      blocks: [
        block([plain('Provençalska ägg'), plain('4 ägg', top: 90)]),
        block([
          plain('Koka äggen i 8 minuter', top: 300),
          plain('Servera med bröd', top: 380),
        ]),
      ],
    );

    final layout = MlKitTextRecognizer.toPageLayout(recognized);

    expect(
      layout.text,
      equals(
        'Provençalska ägg\n'
        '4 ägg\n'
        'Koka äggen i 8 minuter\n'
        'Servera med bröd',
      ),
    );
    expect(
      layout.text,
      isNot(equals(recognized.text)),
      reason:
          'the whole point of the seam — if these are ever equal the mapper '
          'has started trusting ML Kit assembly and the geometry buys nothing',
    );
    // Blocks flattened in order, all four rows kept.
    expect(layout.lines.map((l) => l.text).toList(), hasLength(4));
    // (A row-by-row `text.split('\n')[i] == lines[i].text` loop stood here and
    // was removed: `PageLayout.text` IS that join and `OcrLine` refuses an
    // embedded newline, so no mapper mutant can break it — measured, it killed
    // none of five. The law belongs to `text_layout_test`, which owns the model.)
  });

  test('a line ML Kit measured but did not segment still becomes a row', () {
    // Elements are per-word; a line can arrive with none (ML Kit returns them
    // per platform, and iOS is the thin one). Dropping such a line would shift
    // every index after it — strictly worse than a row with no word geometry,
    // which the model already reads as an absence rather than as a zero.
    final recognized = RecognizedText(
      text: 'ignored',
      blocks: [
        block([
          plain('Ingredienser'),
          line('2 dl grädde', box: const Rect.fromLTWH(40, 90, 400, 64)),
          plain('Vispa smeten', top: 180),
        ]),
      ],
    );

    final layout = MlKitTextRecognizer.toPageLayout(recognized);

    expect(layout.lines, hasLength(3));
    expect(layout.lines[1].text, equals('2 dl grädde'));
    expect(layout.lines[1].words, isEmpty);
    expect(
      layout.lines[2].text,
      equals('Vispa smeten'),
      reason: 'the row after the unsegmented one must not have moved up',
    );
    expect(
      layout.lines[1].typeHeight,
      equals(64),
      reason: 'with no words the line box is the only measurement there is',
    );
  });

  test('a line whose own text carries a newline still occupies ONE row', () {
    // ML Kit does emit these. Two rows of the produced string for one entry of
    // `lines` desynchronises the two ways of counting, and the mapper is a
    // producer, so the invariant has to hold here and not only on replay.
    final recognized = RecognizedText(
      text: 'ignored',
      blocks: [
        block([
          plain('Smörstekt\npotatis'),
          plain('Salt och peppar', top: 120),
        ]),
      ],
    );

    final layout = MlKitTextRecognizer.toPageLayout(recognized);

    // These two are the whole proof: two entries in `lines`, and the newline
    // collapsed INTO the first one rather than splitting it.
    expect(layout.lines, hasLength(2));
    expect(layout.lines.first.text, equals('Smörstekt potatis'));
    // (`layout.text.split('\n').length == layout.lines.length` stood here and
    // was removed for the same reason as the row-by-row loop above: it is the
    // model's own invariant, not the mapper's, and it killed none of the six
    // mapper mutants when measured. `text_layout_test` owns it.)
  });

  test('the order is ML Kit CAPTURE order, never reading order', () {
    // The mapper must not sort. Ordering a two-column spread by geometry is a
    // separate, deliberately later step, because it changes the text of EVERY
    // on-device import — including the single-recipe pages that already work —
    // and no measurement covers it yet. A sort quietly added here would be
    // invisible: the page would still hold every row, in a nicer-looking
    // order, and every other test in this file would stay green.
    //
    // So block two is the one printed HIGHER on the page (top 20 against 300):
    // sorting by `top` and preserving capture order give different answers.
    final recognized = RecognizedText(
      text: 'ignored',
      blocks: [
        block([plain('Vänster spalt', top: 300)]),
        block([plain('Höger spalt', top: 20)]),
      ],
    );

    final layout = MlKitTextRecognizer.toPageLayout(recognized);

    expect(layout.lines.map((l) => l.text).toList(), [
      'Vänster spalt',
      'Höger spalt',
    ]);
  });

  test('word geometry survives into the page model', () {
    // typeHeight is the signal the whole layout path is being built for — a
    // heading is LARGER than body text and no text rule can see that. The line
    // box is deliberately far too tall (an axis-aligned box around a tilted
    // line grows with its WIDTH), so a mapper that carried only the line box
    // would answer 300 here.
    final recognized = RecognizedText(
      text: 'ignored',
      blocks: [
        block([
          line(
            'Provençalska ägg nu',
            box: const Rect.fromLTWH(40, 20, 820, 300),
            elements: [
              element('Provençalska', const Rect.fromLTWH(120, 40, 260, 90)),
              element('ägg', const Rect.fromLTWH(400, 44, 90, 70)),
              element('nu', const Rect.fromLTWH(510, 42, 70, 74)),
            ],
          ),
        ]),
      ],
    );

    final layout = MlKitTextRecognizer.toPageLayout(recognized);
    final words = layout.lines.single.words;

    expect(words.map((w) => w.text).toList(), ['Provençalska', 'ägg', 'nu']);
    // A Rect exposes left/top/width/height AND right/bottom; reading the wrong
    // pair silently moves and resizes every box, so all four edges are pinned
    // on a word whose four values are mutually distinct.
    expect(words.first.box.left, equals(120));
    expect(words.first.box.top, equals(40));
    expect(words.first.box.width, equals(260));
    expect(words.first.box.height, equals(90));
    // Median of 90/70/74, not the mean (78) and not the line box (300).
    expect(layout.lines.single.typeHeight, equals(74));
  });
}
