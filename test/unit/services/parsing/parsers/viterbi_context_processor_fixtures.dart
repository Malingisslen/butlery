import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

/// Golden-set fixtures for `ViterbiContextProcessor`.
///
/// These are short, real-style Swedish recipes with hand-labeled expected
/// classifications per line. They exist as the regression gate for refactors
/// of the transition matrix, emission weights, or the section-header boost
/// logic.
///
/// **How to use these fixtures.**
/// - The test runs each recipe through `SwedishLineClassifier.classifyLine`
///   per line, then feeds the result through `ViterbiContextProcessor`.
/// - The post-Viterbi `LineType` is compared to the `expected` field.
/// - Setting `expected: null` opts a line out of scoring (use only for
///   genuinely ambiguous lines where multiple labels are reasonable).
///
/// **Why hand-labeled live data, not generated.**
/// Generated fixtures only exercise the patterns the generator knows about,
/// which is the same set the classifier knows about — circular. Real recipe
/// snippets carry the awkward edges (short food-only lines, units glued to
/// numbers, mid-sentence headers) that catch real bugs.
///
/// **What each recipe targets.** Each fixture name documents the structural
/// shape it exercises (header-driven, no-header-mixed, unit-only ingredients,
/// numbered steps, etc.) so a future maintainer can tell at a glance whether
/// the set still covers the necessary variety.

class GoldenLine {
  final String line;

  /// Expected post-Viterbi `LineType`. `null` means "don't score this line".
  final LineType? expected;

  const GoldenLine(this.line, this.expected);
}

class GoldenRecipe {
  final String name;
  final List<GoldenLine> lines;
  const GoldenRecipe(this.name, this.lines);
}

const goldenRecipes = <GoldenRecipe>[
  // 1. Canonical headered structure: ingredient header + instruction header
  // both present, both runs unambiguous. The base case Viterbi must handle.
  GoldenRecipe('canonical_headered_pasta', [
    GoldenLine('Pasta carbonara', LineType.title),
    GoldenLine('4 portioner', LineType.metadata),
    GoldenLine('', LineType.empty),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('400 g spaghetti', LineType.ingredient),
    GoldenLine('200 g pancetta', LineType.ingredient),
    GoldenLine('4 ägg', LineType.ingredient),
    GoldenLine('100 g pecorino', LineType.ingredient),
    GoldenLine('1 tsk svartpeppar', LineType.ingredient),
    GoldenLine('', LineType.empty),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Koka pastan al dente i saltat vatten enligt paketet.',
      LineType.instruction,
    ),
    GoldenLine(
      'Stek pancetta i en stekpanna tills knaprig.',
      LineType.instruction,
    ),
    GoldenLine(
      'Vispa ihop ägg och riven pecorino i en bunke.',
      LineType.instruction,
    ),
    GoldenLine(
      'Blanda allt med pastan och servera direkt.',
      LineType.instruction,
    ),
  ]),

  // 2. Header-driven boost: short food-only lines after "Ingredienser:" must
  // be pulled to ingredient, not left as title.
  GoldenRecipe('header_boost_short_foodwords', [
    GoldenLine('Klassisk köttfärssås', LineType.title),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('smör', LineType.ingredient),
    GoldenLine('lök', LineType.ingredient),
    GoldenLine('vitlök', LineType.ingredient),
    GoldenLine('morot', LineType.ingredient),
    GoldenLine('selleri', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Hacka grönsakerna fint och stek dem i smöret.',
      LineType.instruction,
    ),
    GoldenLine(
      'Tillsätt köttfärsen och bryn ordentligt.',
      LineType.instruction,
    ),
  ]),

  // 3. No headers — ingredients and instructions interleaved by structure
  // alone. Tests that the per-line classifier carries enough signal that
  // Viterbi at least preserves clear runs without a header to lean on.
  GoldenRecipe('no_header_unstructured', [
    GoldenLine('Pannkakor', LineType.title),
    GoldenLine('3 ägg', LineType.ingredient),
    GoldenLine('6 dl mjölk', LineType.ingredient),
    GoldenLine('3 dl vetemjöl', LineType.ingredient),
    GoldenLine('1 nypa salt', LineType.ingredient),
    GoldenLine(
      'Vispa ihop ägg och mjölk i en bunke ordentligt.',
      LineType.instruction,
    ),
    GoldenLine(
      'Tillsätt mjöl och salt och blanda till en jämn smet.',
      LineType.instruction,
    ),
    GoldenLine(
      'Stek tunna pannkakor i smör tills gyllenbruna.',
      LineType.instruction,
    ),
  ]),

  // 4. Numbered instruction steps. "1." and "2." should be classified as
  // instruction (step pattern) and not confused with ingredient quantity.
  GoldenRecipe('numbered_steps_kladdkaka', [
    GoldenLine('Kladdkaka', LineType.title),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('150 g smör', LineType.ingredient),
    GoldenLine('3 dl strösocker', LineType.ingredient),
    GoldenLine('2 ägg', LineType.ingredient),
    GoldenLine('1,5 dl vetemjöl', LineType.ingredient),
    GoldenLine('4 msk kakao', LineType.ingredient),
    GoldenLine('1 tsk vaniljsocker', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      '1. Smält smöret i en kastrull och låt svalna något.',
      LineType.instruction,
    ),
    GoldenLine(
      '2. Vispa ihop ägg och socker tills luftigt.',
      LineType.instruction,
    ),
    GoldenLine(
      '3. Blanda i smör, mjöl, kakao och vaniljsocker.',
      LineType.instruction,
    ),
    GoldenLine(
      '4. Grädda i 175 grader i cirka 20 minuter.',
      LineType.instruction,
    ),
  ]),

  // 5. Metadata embedded between title and ingredients. Tests that
  // "30 min" and "4 portioner" survive Viterbi (high enough emission).
  GoldenRecipe('metadata_survival', [
    GoldenLine('Snabb tomatsoppa', LineType.title),
    GoldenLine('4 portioner', LineType.metadata),
    GoldenLine('30 min', LineType.metadata),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('2 burkar krossade tomater', LineType.ingredient),
    GoldenLine('1 lök', LineType.ingredient),
    GoldenLine('2 vitlöksklyftor', LineType.ingredient),
    GoldenLine('1 msk olivolja', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Hacka lök och vitlök fint och fräs i olivoljan.',
      LineType.instruction,
    ),
    GoldenLine(
      'Tillsätt tomater och låt sjuda i 20 minuter.',
      LineType.instruction,
    ),
  ]),

  // 6. Alternative header phrasing: "Du behöver" + "Så gör du".
  GoldenRecipe('alternative_headers_omelett', [
    GoldenLine('Frukostomelett', LineType.title),
    GoldenLine('Du behöver:', LineType.sectionHeader),
    GoldenLine('3 ägg', LineType.ingredient),
    GoldenLine('1 msk grädde', LineType.ingredient),
    GoldenLine('1 nypa salt', LineType.ingredient),
    GoldenLine('1 krm peppar', LineType.ingredient),
    GoldenLine('Så gör du:', LineType.sectionHeader),
    GoldenLine('Vispa ihop ägg och grädde i en skål.', LineType.instruction),
    GoldenLine(
      'Stek i smör på medelvärme tills nästan stelnad.',
      LineType.instruction,
    ),
  ]),

  // 7. Ingredient-only list followed by a one-line instruction. Tests the
  // short-instruction case (length < 50) where Viterbi must still keep it
  // as instruction, not collapse into ingredient.
  GoldenRecipe('short_instruction_drink', [
    GoldenLine('Hallondrink', LineType.title),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('2 dl hallon', LineType.ingredient),
    GoldenLine('3 dl vatten', LineType.ingredient),
    GoldenLine('2 msk honung', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine('Mixa allt och servera kallt.', LineType.instruction),
  ]),

  // 8. Empty lines scattered through the recipe. Tests that empty lines
  // in the middle don't break ingredient context across them.
  GoldenRecipe('empty_lines_scattered', [
    GoldenLine('Pestopasta', LineType.title),
    GoldenLine('', LineType.empty),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('400 g pasta', LineType.ingredient),
    GoldenLine('', LineType.empty),
    GoldenLine('1 dl pesto', LineType.ingredient),
    GoldenLine('50 g parmesan', LineType.ingredient),
    GoldenLine('', LineType.empty),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Koka pastan al dente och spara lite kokvatten.',
      LineType.instruction,
    ),
    GoldenLine('Blanda pastan med pesto och parmesan.', LineType.instruction),
  ]),

  // 9. Long instruction lines (>80 chars) — tests that emission scoring
  // recognizes long sentences as instructions.
  GoldenRecipe('long_instructions_curry', [
    GoldenLine('Kycklingcurry', LineType.title),
    GoldenLine('Ingredienser:', LineType.sectionHeader),
    GoldenLine('500 g kycklingfilé', LineType.ingredient),
    GoldenLine('1 burk kokosmjölk', LineType.ingredient),
    GoldenLine('2 msk röd currypasta', LineType.ingredient),
    GoldenLine('1 lök', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Skär kycklingen i bitar och hacka löken fint i mindre tärningar.',
      LineType.instruction,
    ),
    GoldenLine(
      'Hetta upp olja i en stekpanna och stek lök tills den blir mjuk och glansig.',
      LineType.instruction,
    ),
    GoldenLine(
      'Tillsätt currypasta och rör runt en minut innan kycklingen läggs i pannan.',
      LineType.instruction,
    ),
    GoldenLine(
      'Häll i kokosmjölken och låt allt sjuda i femton minuter under lock.',
      LineType.instruction,
    ),
  ]),

  // 10. Mixed-confidence run: some clear ingredients, some short food-only
  // lines, plus an alternative header. Tests the full "boost + transition"
  // interaction without going through a synthetic harness.
  GoldenRecipe('mixed_confidence_stuvning', [
    GoldenLine('Spenatstuvning', LineType.title),
    GoldenLine('2 portioner', LineType.metadata),
    GoldenLine('Det här behöver du:', LineType.sectionHeader),
    GoldenLine('400 g färsk spenat', LineType.ingredient),
    GoldenLine('2 msk smör', LineType.ingredient),
    GoldenLine('2 msk vetemjöl', LineType.ingredient),
    GoldenLine('3 dl mjölk', LineType.ingredient),
    GoldenLine('salt', LineType.ingredient),
    GoldenLine('peppar', LineType.ingredient),
    GoldenLine('muskot', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine(
      'Skölj spenaten och låt den rinna av ordentligt.',
      LineType.instruction,
    ),
    GoldenLine(
      'Smält smöret i en kastrull och pudra över mjölet.',
      LineType.instruction,
    ),
    GoldenLine(
      'Tillsätt mjölken under vispning och låt koka upp.',
      LineType.instruction,
    ),
    GoldenLine(
      'Vänd ner spenaten och smaka av med salt, peppar och muskot.',
      LineType.instruction,
    ),
  ]),
];
