import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
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
    if (key == null || _isSaving || isDisposed) return false;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await _service.setChoice(key, foodId);
      // Recomputed without the loading state so the open sheet keeps its place.
      final summary = await _service.summarize(_recipe);
      if (!isDisposed) _summary = summary;
      return true;
    } catch (e) {
      AppLogger.warning('Nutrition choice could not be saved: $e');
      _saveError = AppLocale.current.nutritionPickerSaveFailed;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
