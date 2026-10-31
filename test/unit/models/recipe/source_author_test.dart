import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/realtime/recipe_serialization.dart' as realtime;
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/widgets/recipe/duplicate_merge_sheet.dart';

RecipeCore _core({String? sourceUrl, String? sourceAuthor}) => RecipeCore(
  id: 'r1',
  title: 'Laxpudding',
  description: '',
  ingredients: const ['600 g potatis'],
  instructions: const ['Skiva potatisen.'],
  mealType: 'Middag',
  sourceUrl: sourceUrl,
  sourceAuthor: sourceAuthor,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://matbloggen.se/recept/laxpudding';

  group('RecipeCore.sourceAuthor', () {
    test('is null on recipes saved before the field existed', () {
      final core = RecipeCore.fromJson(
        _core(sourceUrl: url).toJson()..remove('sourceAuthor'),
      );
      expect(core.sourceAuthor, isNull);
    });

    test('copyWith keeps it unless set, and an explicit null clears it', () {
      final core = _core(sourceUrl: url, sourceAuthor: 'Anna Berg');
      expect(core.copyWith(title: 'Ny titel').sourceAuthor, 'Anna Berg');
      expect(core.copyWith(sourceAuthor: null).sourceAuthor, isNull);
    });

    test('survives toJson/fromJson and toFirestore/fromMap', () {
      final core = _core(sourceUrl: url, sourceAuthor: 'Anna Berg');
      expect(RecipeCore.fromJson(core.toJson()).sourceAuthor, 'Anna Berg');
      expect(
        RecipeCore.fromMap('r1', core.toFirestore()).sourceAuthor,
        'Anna Berg',
      );
    });

    test('survives the compressed and the simple export forms', () {
      final recipe = Recipe(
        core: _core(sourceUrl: url, sourceAuthor: 'Anna Berg'),
        type: RecipeType.personal,
      );
      expect(
        RecipeSerialization.fromCompressed(
          RecipeSerialization.toCompressed(recipe),
        ).sourceAuthor,
        'Anna Berg',
      );
      expect(
        RecipeSerialization.fromSimpleImport(
          RecipeSerialization.toSimpleExport(recipe),
        ).sourceAuthor,
        'Anna Berg',
      );
    });

    test(
      'the compressed form stays without the key when there is no author',
      () {
        final recipe = Recipe(
          core: _core(sourceUrl: url),
          type: RecipeType.personal,
        );
        expect(RecipeSerialization.toCompressed(recipe), isNot(contains('sa')));
      },
    );

    test(
      'a changed source drops the old author; an unchanged one keeps it',
      () {
        final recipe = Recipe(
          core: _core(sourceUrl: url, sourceAuthor: 'Anna Berg'),
          type: RecipeType.personal,
        );
        expect(
          RecipeOperations.updateBasicInfo(
            recipe,
            sourceUrl: 'https://annan.se/recept',
          ).sourceAuthor,
          isNull,
        );
        expect(
          RecipeOperations.updateBasicInfo(recipe, sourceUrl: url).sourceAuthor,
          'Anna Berg',
        );
        expect(
          RecipeOperations.updateBasicInfo(recipe, title: 'Ny').sourceAuthor,
          'Anna Berg',
        );
      },
    );
  });

  group('sourceAuthor beyond the core serializers', () {
    Recipe imported({String? author = 'Anna Berg'}) => Recipe(
      core: _core(sourceUrl: url, sourceAuthor: author),
      type: RecipeType.personal,
    );

    test('an edit in the recipe form keeps the author', () {
      final state = RecipeFormState(initialRecipe: imported())
        ..setTitle('Laxpudding med dill');
      addTearDown(state.dispose);

      expect(state.createRecipe().sourceAuthor, 'Anna Berg');
    });

    test('a new source typed in the form drops the author', () {
      final state = RecipeFormState(initialRecipe: imported())
        ..setSourceUrl('https://annan.se/recept');
      addTearDown(state.dispose);

      expect(state.createRecipe().sourceAuthor, isNull);
    });

    test('a new personal recipe made from an import keeps the author', () {
      final draft = Recipe(
        core: _core(
          sourceUrl: url,
          sourceAuthor: 'Anna Berg',
        ).copyWith(createdBy: 'u1'),
        type: RecipeType.personal,
      );
      expect(
        RecipeFactory.newPersonalFrom(draft, ownerId: 'u1').sourceAuthor,
        'Anna Berg',
      );
      // Credit to the page's writer is not owner data: a foreign draft keeps it.
      expect(
        RecipeFactory.newPersonalFrom(
          draft,
          ownerId: 'u2',
          id: 'x',
        ).sourceAuthor,
        'Anna Berg',
      );
    });

    test('a shared recipe snapshot and a shared menu read it back', () {
      final data = imported().core.toJson();
      expect(
        SharedRecipe.fromMap('s1', {
          'recipeSnapshot': data,
        }).recipe?.sourceAuthor,
        'Anna Berg',
      );
      final menu = SharedMenu.fromMap('m1', {
        'menuSnapshot': {
          'Måndag': [data],
        },
      });
      expect(menu.menuSnapshot.values.single.single.sourceAuthor, 'Anna Berg');
    });

    test('the realtime form reads it back', () {
      final data = imported().core.toFirestore();
      expect(
        realtime.RecipeSerialization.deserializeRecipe(data, 'r1').sourceAuthor,
        'Anna Berg',
      );
    });

    test('a duplicate merge keeps the author of the source that won', () {
      final existing = imported(author: 'Gammal Författare');
      final incoming = Recipe(
        core: _core(sourceUrl: 'https://annan.se/recept', sourceAuthor: 'Ny'),
        type: RecipeType.personal,
      );
      final merged = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: incoming,
        similarityScore: 0.9,
      ).buildMergedRecipe();
      expect(merged.sourceUrl, 'https://annan.se/recept');
      expect(merged.sourceAuthor, 'Ny');

      final keptOld = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: Recipe(core: _core(), type: RecipeType.personal),
        similarityScore: 0.9,
      ).buildMergedRecipe();
      expect(keptOld.sourceUrl, url);
      expect(keptOld.sourceAuthor, 'Gammal Författare');
    });

    test('replacing a duplicate takes the new source and its author', () {
      final replaced = DuplicateMergeResult(
        choice: DuplicateMergeChoice.replaceWithNew,
        existingRecipe: imported(author: 'Gammal Författare'),
        newRecipe: Recipe(
          core: _core(sourceUrl: 'https://annan.se/recept', sourceAuthor: 'Ny'),
          type: RecipeType.personal,
        ),
        similarityScore: 0.9,
      ).buildReplacedRecipe();
      expect(replaced.sourceUrl, 'https://annan.se/recept');
      expect(replaced.sourceAuthor, 'Ny');
    });
  });
}
