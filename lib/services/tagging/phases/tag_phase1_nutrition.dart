import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Protein and carb/base tag calculation for Phase 1.
class Phase1NutritionCalculator {
  /// The complete vocabulary of protein tags [calculateProteinTags] can emit —
  /// the single source of truth for the weekly protein-balance system (BUT-1324,
  /// BUT-1458).
  ///
  /// `ProteinCategory` (lib/services/menu/protein_category.dart) maps every one
  /// of these to a balancing category, and its drift-guard test asserts its
  /// coverage against THIS set (not a hand-copied duplicate). So a protein tag
  /// added to the tagger cannot silently escape the balance cap: it must be
  /// listed here, which then fails the guard until `ProteinCategory` maps it
  /// too. The debug `assert` at the end of [calculateProteinTags] enforces the
  /// reverse — the method may never emit a tag missing from this set.
  static const Set<String> proteinTags = {
    // Poultry (generic fallback + species)
    'fågel', 'kyckling', 'anka', 'kalkon',
    // Red meat
    'nötkött', 'fläskkött', 'lamm', 'vilt',
    // Fish (generic + species)
    'fisk', 'lax', 'torsk', 'sill',
    // Shellfish
    'skaldjur', 'räkor',
    // Plant-based (generic fallback + specifics)
    'växtprotein', 'tofu', 'tempeh', 'seitan', 'quorn', 'växtfärs',
    'bönprotein', 'oumph', 'baljväxter',
    // Egg
    'ägg',
  };

  /// Dairy words that mark an ACCOMPANIMENT rather than the protein of the
  /// dish. Matched without requiring a `vegansk` marker: everything in
  /// `protein/plant-based` is plant-based by definition, and the register's own
  /// naming is mostly base-named (kokosyoghurt, sojaqvarg, växtfeta), so
  /// demanding the word `vegansk` would miss that whole family.
  static const _dairyAltWords = {
    'yoghurt',
    'gurt', // sojagurt / havregurt / kokosgurt
    // Yeast SEASONINGS spelled out in full. A bare 'jäst' stem must never be
    // used: it is also the past participle of "jäsa" (to ferment), and
    // fermentation is exactly how the register describes plant proteins —
    // 'jästa sojabönor' and 'tempeh jäst' would be dropped as accompaniments.
    'näringsjäst', 'jästflingor', 'jästextrakt',
    'fraiche', 'fraîche',
    'creme', 'crème',
    'kvarg', 'qvarg',
    'feta', 'mozzarella', 'parmesan',
  };

  /// Matches 'ost' as a whole word or a compound SUFFIX ('vegansk ost',
  /// 'fetaost', 'färskost', 'växtfärskost') but never inside 'rostad' /
  /// 'rostbiff'. Dart's `\b` is ASCII-only and cannot bound å/ä/ö, so the
  /// boundary is spelled out with explicit lookarounds — `(?<!r)` rejects the
  /// 'rost' stem, which would otherwise drop a genuine protein like
  /// "rostade kikärter" or "vegansk rostbiff" out of the fallback.
  static final _ostPattern = RegExp(r'(?<!r)ost(?![a-zåäö])');

  /// Mince variants, bounded at the end for the same reason as [_ostPattern]:
  /// an unbounded contains('växtfärs') also fires on 'växtfärskost' (plant
  /// cream cheese), tagging a tub of spread as a mince-based protein main.
  static final _farsPattern = RegExp(
    r'(?:sojafärs|växtfärs|veggofärs)(?![a-zåäö])',
  );

  /// Cream as a NOUN only. A bare 'grädd' stem also matches 'gräddad'
  /// (griddled / pan-baked), which would drop 'gräddad falafel' out of the
  /// protein balance — the same preparation-adjective trap as 'rostad'.
  static final _graddPattern = RegExp(r'grädd(e|fil)');

  /// True for the plant dairy-alternatives and seasonings the register files
  /// under `protein/plant-based` — they are accompaniments, not the protein of
  /// the dish. Validated against all 61 live rows in that group: exactly the 15
  /// dairy-alts/seasonings are excluded and all 46 genuine proteins survive.
  static bool _isPlantDairyAlternative(String nameLower) {
    if (_dairyAltWords.any(nameLower.contains)) return true;
    if (_graddPattern.hasMatch(nameLower)) return true;
    return _ostPattern.hasMatch(nameLower);
  }

  /// Calculates protein tags from ingredient groups.
  static Set<String> calculateProteinTags(IngredientLookupResult lookup) {
    final tags = <String>{};

    // Poultry: a generic 'fågel' fallback for the whole group (mirrors the
    // generic 'fisk' fallback below) so an unrecognised bird — guinea fowl,
    // quail, or a duck cut whose name doesn't contain the whole word 'anka' —
    // still contributes to the weekly poultry balance cap instead of silently
    // escaping it (BUT-1631). Species specifics are layered on top.
    final poultry = lookup.getIngredientsInGroup('protein/meat/poultry');
    if (poultry.isNotEmpty) {
      tags.add('fågel');
      for (final ingredient in poultry) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('kyckling')) {
          tags.add('kyckling');
        } else if (nameLower.contains('kalkon')) {
          tags.add('kalkon');
        } else if (nameLower.contains('ank')) {
          // 'ank' stem catches ankbröst / ankfilé / anklår / anklever, not just
          // the bare word 'anka'. Checked AFTER the exact species above so a
          // compound that merely contains the stem (a future '...skank' cut)
          // can't out-rank its real species match.
          tags.add('anka');
        }
      }
    }

    if (lookup.hasGroup('protein/meat/beef')) tags.add('nötkött');
    if (lookup.hasGroup('protein/meat/pork')) tags.add('fläskkött');
    if (lookup.hasGroup('protein/meat/lamb')) tags.add('lamm');
    if (lookup.hasGroup('protein/meat/game')) tags.add('vilt');

    // Fish specifics
    final fish = lookup.getIngredientsInGroup('protein/seafood/fish');
    if (fish.isNotEmpty) {
      tags.add('fisk');
      for (final ingredient in fish) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('lax')) {
          tags.add('lax');
        } else if (nameLower.contains('torsk')) {
          tags.add('torsk');
        } else if (nameLower.contains('sill')) {
          tags.add('sill');
        }
      }
    }

    // Shellfish specifics
    final shellfish = lookup.getIngredientsInGroup('protein/seafood/shellfish');
    if (shellfish.isNotEmpty) {
      tags.add('skaldjur');
      for (final ingredient in shellfish) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('räk') && ingredient.hasProperty('crustacean')) {
          tags.add('räkor');
        }
      }
    }

    // L11: Expanded plant-based protein detection. A generic 'växtprotein'
    // fallback covers the whole group (mirrors the generic 'fisk'/'fågel'
    // fallbacks) so an unrecognised plant protein — a novel meat substitute, a
    // pea/lentil isolate, an unbranded product — still counts toward the weekly
    // balance cap; specifics are layered on top (BUT-1631). The generic also
    // subsumes the former "Hälsans kök" branch, which only ever emitted
    // 'växtprotein' anyway.
    // The register files vegan DAIRY-ALTERNATIVES and a seasoning in this same
    // group (yoghurts, näringsjäst, the vegansk ost/grädde/kvarg/parmesan
    // family) — unlike protein/seafood/fish, the group is not homogeneous. Those
    // are never the protein of the dish, so a splash of vegan cream or a
    // sprinkle of nutritional yeast must not tag the recipe 'växtprotein' and
    // enter it into the weekly protein-balance nudge (BUT-1324) as a
    // plant-protein main. Gate the generic fallback on a real center-of-plate
    // member; specifics then only ever consider those.
    final plantProtein = lookup.getIngredientsInGroup('protein/plant-based');
    final centerOfPlate = plantProtein
        .where((i) => !_isPlantDairyAlternative(i.swedish.toLowerCase()))
        .toList();
    if (centerOfPlate.isNotEmpty) {
      tags.add('växtprotein');
      for (final ingredient in centerOfPlate) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('tofu')) {
          tags.add('tofu');
        } else if (nameLower.contains('tempeh')) {
          tags.add('tempeh');
        } else if (nameLower.contains('seitan')) {
          tags.add('seitan');
        } else if (nameLower.contains('quorn')) {
          tags.add('quorn');
        } else if (_farsPattern.hasMatch(nameLower)) {
          tags.add('växtfärs');
        } else if (nameLower.contains('bönbiff') ||
            nameLower.contains('bönburgare')) {
          tags.add('bönprotein');
        } else if (nameLower.contains('oumph')) {
          tags.add('oumph');
        }
      }
    }

    if (lookup.hasGroup('vegetable/legume')) tags.add('baljväxter');
    if (lookup.hasGroup('protein/egg')) tags.add('ägg');

    // The balance system only sees proteins it has a category for, so every tag
    // emitted here must live in the shared [proteinTags] vocabulary (BUT-1458).
    assert(
      tags.every(proteinTags.contains),
      'calculateProteinTags emitted a protein tag missing from '
      'Phase1NutritionCalculator.proteinTags: '
      '${tags.difference(proteinTags)}. Add it to the vocabulary and map it in '
      'ProteinCategory, or the weekly protein-balance cap will not see it.',
    );
    return tags;
  }

  static const _pastaKeywords = [
    'pasta',
    'spagetti',
    'spaghetti',
    'penne',
    'lasagne',
    'tagliatelle',
    'fettuccine',
    'fettucine',
    'ravioli',
    'tortellini',
    'gnocchi',
    'rigatoni',
    'fusilli',
    'farfalle',
    'linguine',
    'orzo',
    'makaroner',
    'cannelloni',
  ];

  /// Calculates carb/base tags.
  static Set<String> calculateCarbTags(
    IngredientLookupResult lookup,
    Recipe recipe,
  ) {
    final tags = <String>{};

    final hasPasta = lookup.matched.any(
      (i) =>
          i.group.contains('pasta-bread') &&
          _pastaKeywords.any((k) => i.swedish.toLowerCase().contains(k)),
    );
    if (hasPasta) tags.add('pastabaserad');

    // Use word boundary to avoid false positives (e.g., "korianderfrisk" → "ris")
    final hasRice = lookup.matched.any(
      (i) =>
          TagPhase1Base.containsSwedishWord(i.swedish.toLowerCase(), 'ris') &&
          i.group.contains('grain'),
    );
    if (hasRice) tags.add('risbaserad');

    final hasPotato = lookup.matched.any(
      (i) =>
          i.swedish.toLowerCase().contains('potatis') &&
          i.group.contains('vegetable/root'),
    );
    if (hasPotato) tags.add('potatisbaserad');

    final hasNoodles = lookup.matched.any((i) {
      final nameLower = i.swedish.toLowerCase();
      return nameLower.contains('nudl') ||
          nameLower.contains('wontonnudl') ||
          nameLower.contains('risnudl') ||
          nameLower.contains('glasnudl');
    });
    if (hasNoodles) tags.add('nudelbaserad');

    final hasBread = lookup.matched.any(
      (i) =>
          i.group.contains('grain/bread') ||
          i.swedish.toLowerCase().contains('bröd'),
    );
    if (hasBread) tags.add('brödbaserad');

    if (lookup.hasGroup('grain/whole')) tags.add('fullkorn');

    return tags;
  }
}
