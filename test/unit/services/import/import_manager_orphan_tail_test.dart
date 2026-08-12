import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/unified/types/recipe_types.dart'
    hide ImportResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// The WIRING test.
///
/// `orphan_tail_test.dart` proves the RULE; nothing there proves the rule is
/// CALLED. `withoutOrphanTail` is one line in `ImportManager.autoParseMulti`,
/// and the corpus arm calls the function itself — so deleting that line would
/// leave the unit tests and the eval both green while the feature was dead in
/// the app.
///
/// It asserts on what the strategy RECEIVES, not on what the parse emits. That
/// is not a stylistic choice: two earlier versions asserted over the parsed
/// recipe and both stayed green with the wiring deleted, because the parser
/// discards a short trailing fragment for its own reasons. The trim's effect is
/// real — `dart run tools/corpus_split_eval.dart --trim` prints the ten pages
/// it fires on, each with the heading cut and its CHARACTER count (tokens
/// appear only in that arm's aggregate line) — but it is invisible at the parse
/// layer on a synthetic page. Measured, twice, before this shape was chosen.
class _SpyStrategy implements ImportStrategy {
  final List<String> seen = [];

  @override
  String get strategyName => 'spy';

  @override
  bool canHandle(String input) {
    seen.add(input);
    return true;
  }

  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) {
    seen.add(input);
    return Future.value(ImportResult.failure('spy'));
  }

  @override
  bool validateInput(String input) => true;

  @override
  String get inputExample => 'spy';

  @override
  String get description => 'records what the manager hands it';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeFactory.build());
  });

  /// A line whose TYPE height is set by its word boxes — which is what
  /// `HeadingDetector` measures. It also READS the text (`_readsLikeTitle`
  /// gates on length, word count, a quantity regex, terminal punctuation and a
  /// capital initial), so a fixture title has to satisfy both.
  ///
  /// Carries the same glyphSpan trap as its twin in `orphan_tail_test.dart`,
  /// and this copy learned it the hard way: a heading token with a DESCENDER
  /// (g/j/p/q/y) spans 1.80 instead of 1.45, so its type height comes out
  /// ~20 % short and the page-relative floor drops it from `headingLines`
  /// silently. `Frukostgrot` did exactly that here for a while — the fixture
  /// read as a two-heading page and was a one-heading page. `words: 4` is
  /// `PageLayout._minBodyWords` exactly, with no headroom.
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

  PageLayout pageWithTail() => PageLayout(
    lines: [
      // Descender-free on purpose — see the trap in `line()`. `Frukostmat`
      // spans 1.45, the same bucket as `Mandelforell`, so both survive the
      // page-relative floor and this really is the two-heading page it looks
      // like. `Frukostgrot` did not, because of the `g`.
      line('Frukostmat med havre', wordHeight: 145, words: 1),
      line('2 dl havregryn i skalen', wordHeight: 70),
      line('4 dl vatten i kastrullen', wordHeight: 70),
      line('1 krm salt att strossla', wordHeight: 70),
      line('Koka upp vattnet och salta', wordHeight: 70),
      line('Ror ner grynen och koka', wordHeight: 70),
      line('Servera med mjolk och bar', wordHeight: 70),
      // The next recipe's heading, with less than 120 characters under it.
      line('Mandelforell', wordHeight: 145, words: 1),
      line('Lag en lag av attika', wordHeight: 70),
    ],
  );

  ({ImportManager manager, _SpyStrategy spy}) build() {
    final ops = MockPersonalRecipeOperations();
    when(
      () => ops.addUnifiedRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
    final spy = _SpyStrategy();
    return (manager: ImportManager.withStrategies(ops, [spy]), spy: spy);
  }

  test('the text handed on has the orphan tail cut off', () async {
    final h = build();
    final doc = DocumentLayout([pageWithTail()]);
    final input = doc.text!;
    expect(input.contains('Mandelforell'), isTrue, reason: 'fixture premise');
    // The premise that decays silently, and it is the FIRST title only: if
    // `Frukostmat` drifts out of `headingLines` — a renamed word with a
    // lowercase descender is enough — the page stops being the two-heading
    // page this test reads as and nothing else here notices. `Mandelforell`
    // dropping out is loud instead: `headings` becomes `[0]`, the
    // `pageRow == 0` guard returns unchanged, the tail survives, and the
    // per-block negative below reddens.
    expect(
      HeadingDetector.headingLines(pageWithTail()),
      [0, 7],
      reason: 'fixture premise: BOTH titles must be detected headings',
    );

    await h.manager.autoParseMulti(input, layout: doc);

    expect(h.spy.seen, isNotEmpty);
    for (final received in h.spy.seen) {
      expect(
        received.contains('Mandelforell'),
        isFalse,
        reason: "the next recipe's title reached the parser",
      );
    }
    // The recipe itself must survive the cut whole. Asserted over the JOINED
    // text, not per block: the negative above belongs per block (it is stronger
    // there), but this positive would redden if the text rules ever returned
    // two blocks for the trimmed page — a splitter change, nothing to do with
    // the trim.
    expect(h.spy.seen.join('\n').contains('havregryn'), isTrue);
  });

  PageLayout pageWithLeadingFurniture() => PageLayout(
    lines: [
      // A running header / folio stand-in: short, not ingredient- or
      // instruction-shaped, well under the 60-char budget.
      line('Kokboken 2024', wordHeight: 70, words: 2),
      line('Frukostmat med havre', wordHeight: 145, words: 1),
      line('2 dl havregryn i skalen', wordHeight: 70),
      line('4 dl vatten i kastrullen', wordHeight: 70),
      line('1 krm salt att strossla', wordHeight: 70),
      line('Koka upp vattnet och salta', wordHeight: 70),
      line('Ror ner grynen och koka', wordHeight: 70),
      line('Servera med mjolk och bar', wordHeight: 70),
    ],
  );

  test('the text handed on has the leading furniture cut off', () async {
    final h = build();
    final doc = DocumentLayout([pageWithLeadingFurniture()]);
    final input = doc.text!;
    expect(input.contains('Kokboken'), isTrue, reason: 'fixture premise');
    expect(
      HeadingDetector.headingLines(pageWithLeadingFurniture()),
      [1],
      reason: 'fixture premise: one detected heading, at row 1',
    );

    await h.manager.autoParseMulti(input, layout: doc);

    expect(h.spy.seen, isNotEmpty);
    for (final received in h.spy.seen) {
      expect(
        received.contains('Kokboken'),
        isFalse,
        reason: 'the running header reached the parser',
      );
    }
    expect(h.spy.seen.join('\n').contains('havregryn'), isTrue);
  });

  /// A single-photo import means page zero and the last page are the SAME
  /// [PageLayout] — this page carries furniture BEFORE its title AND an
  /// orphaned heading with almost nothing under it AFTER its body, so both
  /// trims fire on one page in sequence. Proves the composition
  /// `leading_noise.dart`'s library doc describes rather than just each rule
  /// in isolation.
  test('leading furniture and an orphan tail both get cut on one page', () async {
    final h = build();
    final lines = [
      line('Kokboken 2024', wordHeight: 70, words: 2),
      ...pageWithTail().lines,
    ];
    final doc = DocumentLayout([PageLayout(lines: lines)]);
    final input = doc.text!;
    expect(
      HeadingDetector.headingLines(PageLayout(lines: lines)),
      [1, 8],
      reason: 'fixture premise: two detected headings, shifted by the '
          'furniture row',
    );

    await h.manager.autoParseMulti(input, layout: doc);

    expect(h.spy.seen, isNotEmpty);
    final seen = h.spy.seen.join('\n');
    expect(seen.contains('Kokboken'), isFalse, reason: 'leading furniture');
    expect(seen.contains('Mandelforell'), isFalse, reason: 'orphan tail');
    expect(seen.contains('havregryn'), isTrue, reason: 'the real recipe');
  });

  test('without a layout the text is handed on untouched', () async {
    final h = build();
    const input =
        'Frukostgrot\n2 dl havregryn\n4 dl vatten\n'
        'Koka upp vattnet\nRor ner grynen\nMandelforell';

    await h.manager.autoParseMulti(input);

    // No geometry means no verdict — the trim must never guess from text alone.
    // Asserted over the JOINED text, not per block: whether the text rules
    // return one block or two is the splitter's business, and coupling to it
    // would make this test redden for a reason that has nothing to do with the
    // trim.
    expect(h.spy.seen, isNotEmpty);
    expect(h.spy.seen.join('\n').contains('Mandelforell'), isTrue);
  });
}
