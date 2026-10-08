/// BUT-2213: the editor's save carries the revision the opened recipe was
/// read at, so the offline queue compares it against the version the user
/// actually edited, not against whatever the device holds by then.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Recipe opened({int? rev}) {
    final built = RecipeFactory.build(id: 'r1', title: 'Linsgryta');
    return Recipe(core: built.core, type: built.type, rev: rev);
  }

  test('an edited recipe is saved on the revision it was opened at', () {
    final state = RecipeFormState(initialRecipe: opened(rev: 4))
      ..setTitle('Linsgryta med spenat');
    addTearDown(state.dispose);

    final saved = state.createRecipe();

    expect(saved.title, 'Linsgryta med spenat');
    expect(saved.rev, 4);
  });

  test('a recipe opened without a revision is saved without one', () {
    final state = RecipeFormState(initialRecipe: opened());
    addTearDown(state.dispose);

    expect(state.createRecipe().rev, isNull);
  });

  test('a template is a new recipe and carries no revision', () {
    final state = RecipeFormState(
      initialRecipe: opened(rev: 4),
      isTemplate: true,
    );
    addTearDown(state.dispose);

    expect(state.createRecipe().rev, isNull);
  });
}
