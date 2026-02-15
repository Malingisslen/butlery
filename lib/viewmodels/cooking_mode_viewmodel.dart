// lib/viewmodels/cooking_mode_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';

/// ViewModel for cooking mode — manages portion scaling and ingredient state.
class CookingModeViewModel extends ChangeNotifier {
  final Recipe recipe;

  late int _currentPortions;
  late List<String> _scaledIngredients;

  CookingModeViewModel({required this.recipe}) {
    _currentPortions = recipe.portions ?? 1;
    _scaledIngredients = List.from(recipe.ingredients);
  }

  int get currentPortions => _currentPortions;
  int get originalPortions => recipe.portions ?? 1;
  double get scaleFactor =>
      originalPortions > 0 ? _currentPortions / originalPortions : 1.0;
  List<String> get scaledIngredients => _scaledIngredients;
  List<String> get instructions => recipe.instructions;
  String get title => recipe.title;

  static const int minPortions = 1;
  static const int maxPortions = 50;

  void updatePortions(int newPortions) {
    if (newPortions < minPortions || newPortions > maxPortions) return;
    if (newPortions == _currentPortions) return;

    _currentPortions = newPortions;
    _scaledIngredients = PortionScalerLogic.scaleIngredients(
      recipe.ingredients,
      originalPortions,
      _currentPortions,
      false,
    );
    notifyListeners();
  }
}
