import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';
import 'package:butlery/utils/text/import_fractions.dart';

void main() {
  Recipe recipe(List<String> lines, {List<RecipeIngredient>? structured}) =>
      Recipe(
        core: RecipeCore(
          id: 'imported-1',
          title: 'Medelhavsbiffar',
          description: '',
          ingredients: lines,
          structuredIngredients: structured,
          instructions: const ['Blanda.'],
          mealType: 'Middag',
        ),
        type: RecipeType.personal,
      );

  group('the leading amount is written as the recipe page shows it', () {
    for (final (read, shown) in const [
      ('1,5 dl mjölk', '1 ½ dl mjölk'),
      ('0.5 tsk timjan', '½ tsk timjan'),
      ('0,75 dl ströbröd', '¾ dl ströbröd'),
      ('3/4 dl ströbröd', '¾ dl ströbröd'),
      ('1 1/2 msk olja', '1 ½ msk olja'),
      ('2,25 kg potatis', '2 ¼ kg potatis'),
      ('1,5dl grädde', '1 ½ dl grädde'),
      ('0,5', '½'),
    ]) {
      test('"$read" → "$shown"', () {
        expect(ImportFractions.line(read), shown);
      });
    }
  });

  group('everything else stays as read', () {
    for (final line in const [
      '2 dl mjölk',
      '0,94 dl vatten',
      '0,5-1 dl chilisås',
      '0,5 - 1 dl chilisås',
      'ca 1,5 dl mjölk',
      '1 ½ dl mjölk',
      '½ tsk salt',
      'salt och 1,5 tsk peppar',
      '1.500 g mjöl',
      '',
      'Sås:',
    ]) {
      test('"$line"', () {
        expect(ImportFractions.line(line), line);
      });
    }
  });

  test(
    'the structured entries follow their lines, so the save reuses them',
    () {
      final rewritten = ImportFractions.recipe(
        recipe(
          const ['1,5 dl mjölk', '2 ägg'],
          structured: const [
            RecipeIngredient(
              amount: 1.5,
              unit: 'dl',
              name: 'mjölk',
              note: 'rumstempererad',
              raw: '1,5 dl mjölk',
              section: 'Smet',
            ),
            RecipeIngredient(amount: 2, name: 'ägg', raw: '2 ägg'),
          ],
        ),
      );

      expect(rewritten.ingredients, ['1 ½ dl mjölk', '2 ägg']);
      final structured = rewritten.core.structuredIngredients!;
      expect(structured.map((e) => e.raw), rewritten.ingredients);
      expect(structured.first.note, 'rumstempererad');
      expect(structured.first.section, 'Smet');
    },
  );

  test('saving the rewritten lines unedited sends no corrections', () {
    final read = recipe(const [
      '1,5 dl mjölk',
      '0,5 tsk timjan',
      '3/4 dl ströbröd',
      '400 g köttfärs',
    ]);
    final snapshot = ImportCorrectionSnapshot.build(
      read,
      source: ImportSource.photo,
    );

    final correction = RecipeDiffCalculator().calculateDiff(
      original: snapshot,
      corrected: ImportFractions.recipe(read),
      userId: 'u1',
    );

    expect(correction, isNull);
  });
}
