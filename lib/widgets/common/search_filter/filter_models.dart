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
  static final Set<String> allergenFilterIds =
      Set.unmodifiable(_allergenFilterValues.keys.toSet());

  /// Inverse mapping: allergen key → filter ID (e.g. 'gluten' → 'gluten-free').
  static final allergenKeyToFilterId = Map.unmodifiable(
    _allergenFilterValues.map((filterId, key) => MapEntry(key, filterId)),
  );

  /// Look up dietary filter value by ID (no BuildContext needed).
  static String? dietaryFilterValue(String filterId) =>
      _dietaryFilterValues[filterId];

  /// Allergen-free filters (recipe must be proven FREE from these).
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
