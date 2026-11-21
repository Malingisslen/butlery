import 'dart:collection';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/models/photo_ai_recipes.dart';
import 'package:butlery/services/import/photo_recipe_merge.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_state_mixin.dart';
import 'package:flutter/foundation.dart';

/// What the photo import does with the recipes an AI reading found: every one
/// goes into the recipe list, so the picker appears as it does when the phone
/// splits a page.
mixin PhotoImportAiRecipesMixin on ImportBaseViewModel, PhotoImportStateMixin {
  // Identity, not equality: a recipe the picker shows is the instance the AI
  // route made, and an index would go stale when the list is rebuilt.
  final Set<Recipe> _aiFound = HashSet<Recipe>.identity();
  int _droppedRecipeCount = 0;

  /// Recipes the AI reading saw on the photo but could not read.
  int get droppedRecipeCount => _droppedRecipeCount;

  /// Whether the AI reading, not the phone, found [recipe] in the list.
  bool isAiFoundRecipe(Recipe recipe) => _aiFound.contains(recipe);

  /// Every recipe in the list came from the AI reading, so the picker can say
  /// the user should check them.
  bool get recipesReadByAi =>
      parsedRecipeList.isNotEmpty && parsedRecipeList.every(_aiFound.contains);

  /// Merged recipes of AI-read [pages] in page order, shown as the result.
  /// One recipe behaves as a single import; more open the picker.
  @protected
  List<Recipe> showAiRecipes(List<PhotoAiRecipes> pages) {
    final recipes = mergePhotoRecipes(
      pages,
      untitled: AppLocale.current.llmUnknownRecipe,
    );
    parsedRecipeList
      ..clear()
      ..addAll(recipes);
    _aiFound
      ..clear()
      ..addAll(recipes);
    _droppedRecipeCount = pages.fold(0, (n, p) => n + p.droppedRecipeCount);
    if (recipes.length == 1) {
      setParsedRecipe(recipes.first);
    } else {
      notifyListeners();
    }
    return recipes;
  }

  /// A recipe list a reading that is not the AI's replaced.
  @protected
  void forgetAiFoundRecipes() {
    _aiFound.clear();
    _droppedRecipeCount = 0;
  }

  /// Recipes the AI saw on some of [pages] but could not read, kept when the
  /// list itself came from the text route, so the user is still told.
  @protected
  void keepDroppedRecipes(Iterable<PhotoAiRecipes> pages) {
    final dropped = pages.fold(0, (n, p) => n + p.droppedRecipeCount);
    if (dropped == 0 || dropped == _droppedRecipeCount) return;
    _droppedRecipeCount = dropped;
    notifyListeners();
  }
}
