// lib/widgets/common/search_filter/filter_models.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
      icon: ButleryIcons.clock,
      value: 30,
    ),
    FilterOption(
      id: 'medium',
      label: '30-60 min',
      icon: ButleryIcons.clock,
      value: 60,
    ),
    FilterOption(
      id: 'long',
      label: '> 60 min',
      icon: ButleryIcons.clock,
      value: 999,
    ),
  ];

  static List<FilterOption> mealTypeFilters(BuildContext context) => [
    FilterOption(
      id: 'breakfast',
      label: context.l10n.filterBreakfast,
      icon: ButleryIcons.utensils,
      value: 'Frukost',
    ),
    FilterOption(
      id: 'lunch',
      label: context.l10n.filterLunch,
      icon: ButleryIcons.utensils,
      value: 'Lunch',
    ),
    FilterOption(
      id: 'dinner',
      label: context.l10n.filterDinner,
      icon: ButleryIcons.utensils,
      value: 'Middag',
    ),
    FilterOption(
      id: 'snack',
      label: context.l10n.filterSnack,
      value: 'Mellanmål',
    ),
    FilterOption(
      id: 'dessert',
      label: context.l10n.filterDessert,
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
      icon: ButleryIcons.circleCheck,
      value: 'gluten',
    ),
    FilterOption(
      id: 'dairy-free',
      label: context.l10n.filterDairyFree,
      icon: ButleryIcons.circleCheck,
      value: 'mjölk',
    ),
    FilterOption(
      id: 'lactose-free',
      label: context.l10n.filterLactoseFree,
      icon: ButleryIcons.circleCheck,
      value: 'laktos',
    ),
    FilterOption(
      id: 'nut-free',
      label: context.l10n.filterNutFree,
      icon: ButleryIcons.circleCheck,
      value: 'nötter',
    ),
    FilterOption(
      id: 'egg-free',
      label: context.l10n.filterEggFree,
      icon: ButleryIcons.circleCheck,
      value: 'ägg',
    ),
    FilterOption(
      id: 'soy-free',
      label: context.l10n.filterSoyFree,
      icon: ButleryIcons.circleCheck,
      value: 'soja',
    ),
  ];

  /// Extended allergen-free filters (shown in "More allergens" section).
  static List<FilterOption> extendedAllergenFreeFilters(BuildContext context) =>
      [
        FilterOption(
          id: 'fish-free',
          label: context.l10n.filterFishFree,
          icon: ButleryIcons.circleCheck,
          value: 'fisk',
        ),
        FilterOption(
          id: 'shellfish-free',
          label: context.l10n.filterShellfishFree,
          icon: ButleryIcons.circleCheck,
          value: 'skaldjur',
        ),
        FilterOption(
          id: 'sesame-free',
          label: context.l10n.filterSesameFree,
          icon: ButleryIcons.circleCheck,
          value: 'sesam',
        ),
        FilterOption(
          id: 'peanut-free',
          label: context.l10n.filterPeanutFree,
          icon: ButleryIcons.circleCheck,
          value: 'jordnötter',
        ),
        FilterOption(
          id: 'tree-nut-free',
          label: context.l10n.filterTreeNutFree,
          icon: ButleryIcons.circleCheck,
          value: 'trädnötter',
        ),
        FilterOption(
          id: 'celery-free',
          label: context.l10n.filterCeleryFree,
          icon: ButleryIcons.circleCheck,
          value: 'selleri',
        ),
        FilterOption(
          id: 'mustard-free',
          label: context.l10n.filterMustardFree,
          icon: ButleryIcons.circleCheck,
          value: 'senap',
        ),
        FilterOption(
          id: 'lupin-free',
          label: context.l10n.filterLupinFree,
          icon: ButleryIcons.circleCheck,
          value: 'lupin',
        ),
        FilterOption(
          id: 'sulfite-free',
          label: context.l10n.filterSulfiteFree,
          icon: ButleryIcons.circleCheck,
          value: 'sulfiter',
        ),
        FilterOption(
          id: 'alcohol-free',
          label: context.l10n.filterAlcoholFree,
          icon: ButleryIcons.circleCheck,
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
      icon: ButleryIcons.leaf,
      value: 'vegetarisk',
    ),
    FilterOption(
      id: 'vegan',
      label: context.l10n.filterVegan,
      icon: ButleryIcons.leaf,
      value: 'vegansk',
    ),
    FilterOption(
      id: 'pescetarian',
      label: context.l10n.filterPescetarian,
      icon: ButleryIcons.utensils,
      value: 'pescetarian',
    ),
    FilterOption(
      id: 'halal',
      label: context.l10n.filterHalal,
      icon: ButleryIcons.utensils,
      value: 'halalanpassad',
    ),
    FilterOption(
      id: 'kid-friendly',
      label: context.l10n.filterKidFriendly,
      value: 'barnvänlig',
    ),
  ];
}
