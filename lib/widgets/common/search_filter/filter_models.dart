// lib/widgets/common/search_filter/filter_models.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Filter option data model
class FilterOption {
  final String id;
  final String label;
  final IconData? icon;
  final dynamic value;

  const FilterOption({
    required this.id,
    required this.label,
    this.icon,
    this.value,
  });
}

/// Predefined recipe filters
class RecipeFilters {
  // Quick filter chip IDs — used by QuickFilterChips and mina_recept_view
  static const String filterFavorites = 'favorites';
  static const String filterQuick = 'quick';
  static const String filterVegetarian = 'vegetarian';
  static const String filterPantry = 'pantry';
  static const String filterIngredientSearch = 'ingredient-search';

  static const List<FilterOption> timeFilters = [
    FilterOption(
      id: 'quick',
      label: '< 30 min',
      icon: Icons.timer,
      value: 30,
    ),
    FilterOption(
      id: 'medium',
      label: '30-60 min',
      icon: Icons.timer,
      value: 60,
    ),
    FilterOption(
      id: 'long',
      label: '> 60 min',
      icon: Icons.timer,
      value: 999,
    ),
  ];

  static List<FilterOption> mealTypeFilters(BuildContext context) => [
    FilterOption(
      id: 'breakfast',
      label: context.l10n.filterBreakfast,
      icon: Icons.breakfast_dining,
      value: 'Frukost',
    ),
    FilterOption(
      id: 'lunch',
      label: context.l10n.filterLunch,
      icon: Icons.lunch_dining,
      value: 'Lunch',
    ),
    FilterOption(
      id: 'dinner',
      label: context.l10n.filterDinner,
      icon: Icons.dinner_dining,
      value: 'Middag',
    ),
    FilterOption(
      id: 'snack',
      label: context.l10n.filterSnack,
      icon: Icons.cookie,
      value: 'Mellanmål',
    ),
    FilterOption(
      id: 'dessert',
      label: context.l10n.filterDessert,
      icon: Icons.cake,
      value: 'Efterrätt',
    ),
  ];

  static const List<FilterOption> ratingFilters = [
    FilterOption(
      id: 'high_rated',
      label: '4+ ⭐',
      value: 4.0,
    ),
    FilterOption(
      id: 'top_rated',
      label: '5 ⭐',
      value: 5.0,
    ),
  ];

  // Data-only lookups for ViewModel (no BuildContext needed)
  static const _allergenFilterValues = {
    'gluten-free': 'gluten',
    'dairy-free': 'mjölk',
    'lactose-free': 'laktos',
    'nut-free': 'nötter',
    'egg-free': 'ägg',
    'soy-free': 'soja',
    'fish-free': 'fisk',
    'sesame-free': 'sesam',
    'celery-free': 'selleri',
    'mustard-free': 'senap',
    'shellfish-free': 'skaldjur',
    'lupin-free': 'lupin',
    'sulfite-free': 'sulfiter',
    'peanut-free': 'jordnötter',
    'tree-nut-free': 'trädnötter',
    'alcohol-free': 'alkohol',
  };

  static const _dietaryFilterValues = {
    'vegetarian': 'vegetarisk',
    'vegan': 'vegansk',
    'pescetarian': 'pescetarian',
    'halal': 'halalanpassad',
    'kid-friendly': 'barnvänlig',
  };

  /// Look up allergen filter value by ID (no BuildContext needed).
  static String? allergenFilterValue(String filterId) =>
      _allergenFilterValues[filterId];

  /// All allergen filter IDs (e.g. 'gluten-free', 'dairy-free').
  static final Set<String> allergenFilterIds = Set.unmodifiable(
    _allergenFilterValues.keys.toSet(),
  );

  /// Inverse mapping: allergen key → filter ID (e.g. 'gluten' → 'gluten-free').
  static final allergenKeyToFilterId = Map.unmodifiable(
    _allergenFilterValues.map((filterId, key) => MapEntry(key, filterId)),
  );

  /// Look up dietary filter value by ID (no BuildContext needed).
  static String? dietaryFilterValue(String filterId) =>
      _dietaryFilterValues[filterId];

  /// Primary allergen-free filters (always visible).
  static List<FilterOption> allergenFreeFilters(BuildContext context) => [
    FilterOption(
      id: 'gluten-free',
      label: context.l10n.filterGlutenFree,
      icon: Icons.check_circle_outline,
      value: 'gluten',
    ),
    FilterOption(
      id: 'dairy-free',
      label: context.l10n.filterDairyFree,
      icon: Icons.check_circle_outline,
      value: 'mjölk',
    ),
    FilterOption(
      id: 'lactose-free',
      label: context.l10n.filterLactoseFree,
      icon: Icons.check_circle_outline,
      value: 'laktos',
    ),
    FilterOption(
      id: 'nut-free',
      label: context.l10n.filterNutFree,
      icon: Icons.check_circle_outline,
      value: 'nötter',
    ),
    FilterOption(
      id: 'egg-free',
      label: context.l10n.filterEggFree,
      icon: Icons.check_circle_outline,
      value: 'ägg',
    ),
    FilterOption(
      id: 'soy-free',
      label: context.l10n.filterSoyFree,
      icon: Icons.check_circle_outline,
      value: 'soja',
    ),
  ];

  /// Extended allergen-free filters (shown in "More allergens" section).
  static List<FilterOption> extendedAllergenFreeFilters(BuildContext context) =>
      [
        FilterOption(
          id: 'fish-free',
          label: context.l10n.filterFishFree,
          icon: Icons.check_circle_outline,
          value: 'fisk',
        ),
        FilterOption(
          id: 'shellfish-free',
          label: context.l10n.filterShellfishFree,
          icon: Icons.check_circle_outline,
          value: 'skaldjur',
        ),
        FilterOption(
          id: 'sesame-free',
          label: context.l10n.filterSesameFree,
          icon: Icons.check_circle_outline,
          value: 'sesam',
        ),
        FilterOption(
          id: 'peanut-free',
          label: context.l10n.filterPeanutFree,
          icon: Icons.check_circle_outline,
          value: 'jordnötter',
        ),
        FilterOption(
          id: 'tree-nut-free',
          label: context.l10n.filterTreeNutFree,
          icon: Icons.check_circle_outline,
          value: 'trädnötter',
        ),
        FilterOption(
          id: 'celery-free',
          label: context.l10n.filterCeleryFree,
          icon: Icons.check_circle_outline,
          value: 'selleri',
        ),
        FilterOption(
          id: 'mustard-free',
          label: context.l10n.filterMustardFree,
          icon: Icons.check_circle_outline,
          value: 'senap',
        ),
        FilterOption(
          id: 'lupin-free',
          label: context.l10n.filterLupinFree,
          icon: Icons.check_circle_outline,
          value: 'lupin',
        ),
        FilterOption(
          id: 'sulfite-free',
          label: context.l10n.filterSulfiteFree,
          icon: Icons.check_circle_outline,
          value: 'sulfiter',
        ),
        FilterOption(
          id: 'alcohol-free',
          label: context.l10n.filterAlcoholFree,
          icon: Icons.check_circle_outline,
          value: 'alkohol',
        ),
      ];

  /// All allergen-free filters combined (primary + extended).
  static List<FilterOption> allAllergenFreeFilters(BuildContext context) => [
    ...allergenFreeFilters(context),
    ...extendedAllergenFreeFilters(context),
  ];

  /// Dietary restriction filters (recipe must be safe for this diet).
  static List<FilterOption> dietaryFilters(BuildContext context) => [
    FilterOption(
      id: 'vegetarian',
      label: context.l10n.filterVegetarian,
      icon: Icons.eco_outlined,
      value: 'vegetarisk',
    ),
    FilterOption(
      id: 'vegan',
      label: context.l10n.filterVegan,
      icon: Icons.eco_outlined,
      value: 'vegansk',
    ),
    FilterOption(
      id: 'pescetarian',
      label: context.l10n.filterPescetarian,
      icon: Icons.set_meal,
      value: 'pescetarian',
    ),
    FilterOption(
      id: 'halal',
      label: context.l10n.filterHalal,
      icon: Icons.restaurant,
      value: 'halalanpassad',
    ),
    FilterOption(
      id: 'kid-friendly',
      label: context.l10n.filterKidFriendly,
      icon: Icons.child_care,
      value: 'barnvänlig',
    ),
  ];
}
