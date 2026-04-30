import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

import 'viterbi_context_processor_fixtures.dart';

/// Held-out recipe corpus for `ViterbiContextProcessor` calibration testing.
///
/// These recipes were authored AFTER the original golden set and intentionally
/// chosen to be structurally and lexically distinct from it (different dishes,
/// different header phrasings, different metadata patterns). They are the
/// out-of-sample check: if calibration numbers diverge materially between the
/// golden and held-out sets, the algorithm has overfit the golden set.
///
/// Reuses [GoldenLine] / [GoldenRecipe] from the original fixtures file so
/// the same scoring loop can iterate both corpora.
///
/// **Counts.** 4 recipes, 59 hand-labeled lines (all scorable; no `null`
/// expecteds). Kept smaller than the golden set on purpose — this is a
/// validation lane, not a training set, and held-out corpora that grow as
/// large as the training set lose their value.
const heldOutRecipes = <GoldenRecipe>[
  // H1. Baking with weights and oven instruction. Header phrasing
  // "Det här behövs" — present in the golden set's stuvning recipe but
  // here paired with very different food vocabulary (yeast dough, not
  // creamed spinach). Tests that the classifier+Viterbi generalize
  // beyond the specific food words seen in the golden set.
  GoldenRecipe('held_out_kanelbullar', [
    GoldenLine('Kanelbullar', LineType.title),
    GoldenLine('25 bullar', LineType.metadata),
    GoldenLine('Det här behövs:', LineType.sectionHeader),
    GoldenLine('50 g jäst', LineType.ingredient),
    GoldenLine('5 dl mjölk', LineType.ingredient),
    GoldenLine('150 g smör', LineType.ingredient),
    GoldenLine('1,5 dl strösocker', LineType.ingredient),
    GoldenLine('1 tsk salt', LineType.ingredient),
    GoldenLine('2 tsk kardemumma', LineType.ingredient),
    GoldenLine('cirka 15 dl vetemjöl', LineType.ingredient),
    GoldenLine('Gör så här:', LineType.sectionHeader),
    GoldenLine('Smula jästen i en bunke och rör ut med ljummen mjölk.',
        LineType.instruction),
    GoldenLine('Tillsätt smör, socker, salt, kardemumma och nästan allt mjöl.',
        LineType.instruction),
    GoldenLine(
        'Knåda degen tills den släpper kanterna och låt jäsa i 40 minuter.',
        LineType.instruction),
  ]),

  // H2. Inverted structure — instructions appear before ingredients in the
  // source text (rare but happens in blog posts that lead with the story).
  // The classifier+Viterbi must still identify the runs correctly.
  GoldenRecipe('held_out_potatissallad_inverted', [
    GoldenLine('Krämig potatissallad', LineType.title),
    GoldenLine('6 portioner', LineType.metadata),
    GoldenLine('Så gör du:', LineType.sectionHeader),
    GoldenLine('Koka potatisen mjuk i saltat vatten och låt svalna helt.',
        LineType.instruction),
    GoldenLine('Skär potatisen i tärningar och lägg i en stor skål.',
        LineType.instruction),
    GoldenLine(
        'Blanda majonnäs, gräddfil, senap och pressad citron till en dressing.',
        LineType.instruction),
    GoldenLine('Vänd ner dressingen i potatisen och toppa med hackad gräslök.',
        LineType.instruction),
    GoldenLine('Du behöver:', LineType.sectionHeader),
    GoldenLine('1 kg fast potatis', LineType.ingredient),
    GoldenLine('2 dl majonnäs', LineType.ingredient),
    GoldenLine('1 dl gräddfil', LineType.ingredient),
    GoldenLine('1 msk dijonsenap', LineType.ingredient),
    GoldenLine('1 citron', LineType.ingredient),
    GoldenLine('1 kruka gräslök', LineType.ingredient),
  ]),

  // H3. Fish dish with brining step — long instruction lines, mixed
  // measurement units (g, ml, msk, st). Header phrasing not in the golden
  // set ("Ingredienser" without colon).
  GoldenRecipe('held_out_inkokt_lax', [
    GoldenLine('Inkokt lax', LineType.title),
    GoldenLine('4 portioner', LineType.metadata),
    GoldenLine('Tillagningstid 1 timme', LineType.metadata),
    GoldenLine('Ingredienser', LineType.sectionHeader),
    GoldenLine('800 g laxfilé', LineType.ingredient),
    GoldenLine('1 liter vatten', LineType.ingredient),
    GoldenLine('1 dl ättika 12%', LineType.ingredient),
    GoldenLine('2 msk salt', LineType.ingredient),
    GoldenLine('1 msk socker', LineType.ingredient),
    GoldenLine('10 vitpepparkorn', LineType.ingredient),
    GoldenLine('2 lagerblad', LineType.ingredient),
    GoldenLine('1 gul lök', LineType.ingredient),
    GoldenLine('Tillagning:', LineType.sectionHeader),
    GoldenLine(
        'Koka upp vatten, ättika, salt, socker, peppar och lagerblad i en kastrull.',
        LineType.instruction),
    GoldenLine('Skiva löken tunt och lägg i lagen tillsammans med laxen.',
        LineType.instruction),
    GoldenLine(
        'Sänk värmen till låg och låt sjuda försiktigt under lock i åtta minuter.',
        LineType.instruction),
    GoldenLine(
        'Stäng av plattan och låt fisken dra i lagen tills allt har svalnat.',
        LineType.instruction),
  ]),

  // H4. Vegetarian dish with ingredient sub-grouping by inline labels.
  // No section headers at all — the per-line classifier must carry the
  // structure on its own, with Viterbi only consolidating runs.
  GoldenRecipe('held_out_linsgryta_no_headers', [
    GoldenLine('Indisk linsgryta', LineType.title),
    GoldenLine('2 dl röda linser', LineType.ingredient),
    GoldenLine('1 burk kokosmjölk', LineType.ingredient),
    GoldenLine('1 burk krossade tomater', LineType.ingredient),
    GoldenLine('1 gul lök', LineType.ingredient),
    GoldenLine('2 vitlöksklyftor', LineType.ingredient),
    GoldenLine('1 msk garam masala', LineType.ingredient),
    GoldenLine('1 tsk gurkmeja', LineType.ingredient),
    GoldenLine('1 nypa salt', LineType.ingredient),
    GoldenLine('Skölj linserna noggrant under kallt vatten i en sil.',
        LineType.instruction),
    GoldenLine('Hacka lök och vitlök fint och fräs i olja på medelvärme.',
        LineType.instruction),
    GoldenLine(
        'Tillsätt kryddorna och rör runt en kort stund tills doften känns.',
        LineType.instruction),
    GoldenLine(
        'Häll i tomater, kokosmjölk och linser och låt sjuda tjugo minuter.',
        LineType.instruction),
    GoldenLine('Smaka av med salt och servera med ris eller naanbröd.',
        LineType.instruction),
  ]),
];
