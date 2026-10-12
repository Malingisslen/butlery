import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_service.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

enum NutritionBasis { perPortion, wholeRecipe }

/// Nutrition values for one recipe on screen: the summary, which basis the
/// table shows, and the household's food choices.
///
/// Values are computed on the device and never logged or sent to analytics.
class NutritionViewModel extends BaseViewModel {
  NutritionViewModel({
    required Recipe recipe,
    required int currentPortions,
    NutritionService? service,
  }) : _recipe = recipe,
       _currentPortions = currentPortions,
       _service = service ?? ServiceLocator.get<NutritionService>();

  final NutritionService _service;

  Recipe _recipe;
  int _currentPortions;
  NutritionSummary? _summary;
  NutritionTable? _table;
  NutritionBasis _basis = NutritionBasis.perPortion;
  String? _saveError;
  bool _isSaving = false;

  Recipe get recipe => _recipe;
  int get currentPortions => _currentPortions;
  NutritionSummary? get summary => _summary;
  NutritionTable? get table => _table;
  bool get isSaving => _isSaving;

  /// Set when the last pick or clear could not be saved; cleared by the next one.
  String? get saveError => _saveError;

  /// A sheet opening starts without the failure of an earlier one.
  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    notifyListeners();
  }

  bool get hasPerPortion => _summary?.perPortion != null;

  /// The basis the table shows; falls back to the whole recipe when the
  /// recipe states no portion count to divide by.
  NutritionBasis get basis =>
      hasPerPortion ? _basis : NutritionBasis.wholeRecipe;

  /// The strip is always per portion when that exists, whatever the sheet shows.
  NutritionBasis get stripBasis =>
      hasPerPortion ? NutritionBasis.perPortion : NutritionBasis.wholeRecipe;

  NutrientValues? get values => _valuesFor(basis);

  NutrientValues? get stripValues => _valuesFor(stripBasis);

  NutrientValues? _valuesFor(NutritionBasis which) {
    final summary = _summary;
    if (summary == null) return null;
    return which == NutritionBasis.perPortion
        ? summary.perPortion
        : summary.forPortions(_currentPortions);
  }

  Future<void> load() async {
    if (isDisposed) return;
    await executeAsyncVoid(
      _compute,
      errorPrefix: AppLocale.current.nutritionLoadFailed,
    );
  }

  Future<void> _compute() async {
    final summary = await _service.summarize(_recipe);
    _table ??= await _service.table();
    if (isDisposed) return;
    _summary = summary;
  }

  void setBasis(NutritionBasis value) {
    if (_basis == value) return;
    _basis = value;
    notifyListeners();
  }

  void updatePortions(int portions) {
    if (portions == _currentPortions) return;
    _currentPortions = portions;
    notifyListeners();
  }

  /// A recipe edited while open needs its nutrition recomputed.
  Future<void> updateRecipe(Recipe recipe) async {
    _recipe = recipe;
    await load();
  }

  /// Saves [foodId] as the household's food for [line]; true when it was saved.
  Future<bool> pickFood(NutritionLine line, int foodId) =>
      _saveChoice(line, foodId);

  /// Removes the household's pick for [line], back to the default match.
  Future<bool> clearFood(NutritionLine line) => _saveChoice(line, null);

  Future<bool> _saveChoice(NutritionLine line, int? foodId) async {
    final key = line.storageKey;
    if (key == null) return false;
    return _save(
      () => _service.setChoice(key, foodId),
      failure: AppLocale.current.nutritionPickerSaveFailed,
    );
  }

  /// Saves [amount] [unit] for [line], as entered for this recipe only, or
  /// for every recipe. The amount is entered for this recipe's portions, and
  /// an every-recipe amount is stored for four, as the curated usual amounts
  /// are.
  Future<bool> saveAmount(
    NutritionLine line,
    double amount,
    String unit, {
    required bool thisRecipeOnly,
  }) {
    final key = _amountKey(line, thisRecipeOnly);
    final portions = _recipe.portions;
    final stored = thisRecipeOnly || portions == null || portions <= 0
        ? amount
        : amount * NutritionCalculator.referencePortions / portions;
    final choice = NutritionAmountChoice(amount: stored, unit: unit);
    if (key == null || !choice.isValid) {
      _saveError = AppLocale.current.nutritionAmountSaveFailed;
      notifyListeners();
      return Future.value(false);
    }
    return _save(
      () => _service.setAmount(key, choice),
      failure: AppLocale.current.nutritionAmountSaveFailed,
    );
  }

  /// Removes the amount [line] is counted from, back to the usual amount or
  /// to missing.
  Future<bool> clearAmount(NutritionLine line) {
    final key = _amountKey(
      line,
      line.amountSource == NutritionAmountSource.thisRecipe,
    );
    if (key == null) return Future.value(false);
    return _save(
      () => _service.setAmount(key, null),
      failure: AppLocale.current.nutritionAmountSaveFailed,
    );
  }

  String? _amountKey(NutritionLine line, bool thisRecipeOnly) {
    final key = line.storageKey;
    if (key == null) return null;
    return thisRecipeOnly
        ? NutritionAmountChoice.recipeKey(_recipe.id, key)
        : key;
  }

  Future<bool> _save(
    Future<void> Function() write, {
    required String failure,
  }) async {
    if (_isSaving || isDisposed) return false;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await write();
      // Recomputed without the loading state so the open sheet keeps its place.
      final summary = await _service.summarize(_recipe);
      if (!isDisposed) _summary = summary;
      return true;
    } on NutritionAmountChoicesFullException {
      _saveError = AppLocale.current.nutritionAmountFull;
      return false;
    } catch (e) {
      AppLogger.warning('Nutrition choice could not be saved: $e');
      _saveError = failure;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
