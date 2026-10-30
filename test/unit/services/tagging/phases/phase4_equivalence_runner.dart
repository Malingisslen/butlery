import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

List<String> runPhase4Case(Map<String, dynamic> input) {
  final ingredients = [
    for (final raw in (input['ingredients'] as List).cast<Map>())
      IngredientData(
        id: raw['name'] as String,
        swedish: raw['name'] as String,
        english: raw['name'] as String,
        group: raw['group'] as String? ?? 'other',
        properties: {...(raw['props'] as List? ?? const []).cast<String>()},
        seasonAvailability: [
          ...(raw['season'] as List? ?? const []).cast<String>(),
        ],
      ),
  ];
  final p1 = Phase1Result(
    tags: {...(input['p1'] as List? ?? const []).cast<String>()},
    allergenStatus: const {},
    dietaryStatus: const {},
    lookup: IngredientLookupResult.fromLists(
      matched: ingredients,
      unmatched: const [],
    ),
  );
  final p2 = Phase2Result(tags: const {}, phase1: p1);
  final p3 = Phase3Result(
    tags: {...(input['p3'] as List? ?? const []).cast<String>()},
    phase1: p1,
    phase2: p2,
  );
  final recipe = RecipeFactory.build(
    title: input['title'] as String,
    timeMinutes: input['time'] as int? ?? 30,
  );
  final phase4 = TagPhase4Mood(seasonThreshold: input['threshold'] as int);
  return phase4.calculate(p1, p2, p3, recipe).tags.toList()..sort();
}
