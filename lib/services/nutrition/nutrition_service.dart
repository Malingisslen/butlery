import 'package:flutter/services.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/services/permission_service.dart';

/// Nutrition values for a recipe (BUT-643), computed on the device from
/// Livsmedelsverket's bundled table and the household's own food choices.
///
/// Registered in the user scope, so the cached choices belong to one signed-in
/// user and go with the scope on sign-out.
class NutritionService extends BaseService {
  NutritionService({
    required HouseholdRepository householdRepository,
    AssetBundle? bundle,
  }) : _households = householdRepository,
       _bundle = bundle ?? rootBundle;

  static const String foodsAsset = 'assets/data/livsmedel_naring.json';
  static const String matchingAsset = 'assets/data/naring_matchning.json';

  final HouseholdRepository _households;
  final AssetBundle _bundle;

  Future<NutritionTable>? _table;

  // One household read per session; a write updates it in place.
  Map<String, int>? _choices;
  Map<String, NutritionAmountChoice>? _amounts;
  String? _householdId;

  @override
  String get serviceName => 'NutritionService';

  // The auth handle: the household repository refuses any caller that is not
  // the named user.
  String? get _userId =>
      ServiceLocator.tryGet<PermissionService>()?.currentUserId;

  Future<NutritionTable> table() => _table ??= _loadTable();

  Future<NutritionTable> _loadTable() async {
    final results = await Future.wait([
      _bundle.loadString(foodsAsset),
      _bundle.loadString(matchingAsset),
    ]);
    return NutritionTable.fromJsonStrings(
      foodsJson: results[0],
      matchingJson: results[1],
    );
  }

  Future<NutritionSummary> summarize(Recipe recipe) async {
    final loaded = await table();
    final choices = await _householdChoices();
    return NutritionCalculator(
      table: loaded,
      householdChoices: choices,
      amountChoices: _amounts ?? const {},
    ).calculate(
      ingredients: recipe.structuredIngredients,
      portions: recipe.portions,
      recipeId: recipe.id,
    );
  }

  /// Saves (or with null clears) the household's own amount for [key]: an
  /// ingredient key for every recipe, or `NutritionAmountChoice.recipeKey`
  /// for one recipe. Throws when it was not saved, like [setChoice];
  /// [NutritionAmountChoicesFullException] when the household has no room.
  Future<void> setAmount(String key, NutritionAmountChoice? choice) async {
    Object? refused;
    final saved = await executeServiceOperation<bool>(() async {
      final userId = _userId!;
      final householdId =
          _householdId ?? (await _households.ensureForUser(userId)).id;
      try {
        await _households.setNutritionAmountChoice(
          householdId: householdId,
          key: key,
          choice: choice,
        );
      } on NutritionAmountChoicesFullException catch (e) {
        refused = e;
        return false;
      }
      _householdId = householdId;
      // With no successful read yet, the next summarize reads the stored set
      // (this one included) rather than caching it as all of them.
      final cached = _amounts;
      if (cached == null) return true;
      final updated = Map<String, NutritionAmountChoice>.of(cached);
      if (choice == null) {
        updated.remove(key);
      } else {
        updated[key] = choice;
      }
      _amounts = updated;
      return true;
    }, operationName: 'setNutritionAmount');
    if (refused != null) throw refused!;
    if (saved != true) {
      throw StateError('The household amount was not saved');
    }
  }

  /// Saves (or with null clears) the household's food for ingredient [key].
  ///
  /// Throws when the choice was not saved, so the picker can say so;
  /// [executeServiceOperation] reports a failure by returning null.
  Future<void> setChoice(String key, int? foodId) async {
    final saved = await executeServiceOperation<bool>(() async {
      final userId = _userId!;
      final householdId =
          _householdId ?? (await _households.ensureForUser(userId)).id;
      await _households.setNutritionFoodChoice(
        householdId: householdId,
        key: key,
        foodId: foodId,
      );
      _householdId = householdId;
      // With no successful read yet, the next summarize reads the stored set
      // (this pick included) rather than caching this one pick as all of them.
      final cached = _choices;
      if (cached == null) return true;
      final updated = Map<String, int>.of(cached);
      if (foodId == null) {
        updated.remove(key);
      } else {
        updated[key] = foodId;
      }
      _choices = updated;
      return true;
    }, operationName: 'setNutritionChoice');
    if (saved != true) {
      throw StateError('The household food choice was not saved');
    }
  }

  // A failed read leaves recipes computed from the curated table alone and is
  // retried on the next recipe, rather than cached as "no choices".
  Future<Map<String, int>> _householdChoices() async {
    final cached = _choices;
    if (cached != null) return cached;
    try {
      final userId = _userId;
      if (userId == null) return const {};
      final household = await _households.getActiveForUser(userId);
      _householdId = household?.id;
      _amounts = household?.nutritionAmountChoices ?? const {};
      return _choices = household?.nutritionFoodChoices ?? const {};
    } catch (e) {
      AppLogger.warning('Household food choices could not be read: $e');
      return const {};
    }
  }

  @override
  Future<void> onDispose() async {
    _choices = null;
    _amounts = null;
    _householdId = null;
  }
}
