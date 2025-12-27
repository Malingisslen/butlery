// lib/widgets/common/search_filter/filter_models.dart

import 'package:flutter/material.dart';

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

  static const List<FilterOption> mealTypeFilters = [
    FilterOption(
      id: 'breakfast',
      label: 'Frukost',
      icon: Icons.breakfast_dining,
      value: 'Frukost',
    ),
    FilterOption(
      id: 'lunch',
      label: 'Lunch',
      icon: Icons.lunch_dining,
      value: 'Lunch',
    ),
    FilterOption(
      id: 'dinner',
      label: 'Middag',
      icon: Icons.dinner_dining,
      value: 'Middag',
    ),
    FilterOption(
      id: 'snack',
      label: 'Mellanmål',
      icon: Icons.cookie,
      value: 'Mellanmål',
    ),
    FilterOption(
      id: 'dessert',
      label: 'Efterrätt',
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

  /// Allergen-free filters (recipe must be proven FREE from these).
  static const List<FilterOption> allergenFreeFilters = [
    FilterOption(
      id: 'gluten-free',
      label: 'Glutenfri',
      icon: Icons.check_circle_outline,
      value: 'gluten',
    ),
    FilterOption(
      id: 'dairy-free',
      label: 'Mjölkfri',
      icon: Icons.check_circle_outline,
      value: 'mjölk',
    ),
    FilterOption(
      id: 'lactose-free',
      label: 'Laktosfri',
      icon: Icons.check_circle_outline,
      value: 'laktos',
    ),
    FilterOption(
      id: 'nut-free',
      label: 'Nötfri',
      icon: Icons.check_circle_outline,
      value: 'nötter',
    ),
    FilterOption(
      id: 'egg-free',
      label: 'Äggfri',
      icon: Icons.check_circle_outline,
      value: 'ägg',
    ),
    FilterOption(
      id: 'soy-free',
      label: 'Sojafri',
      icon: Icons.check_circle_outline,
      value: 'soja',
    ),
  ];

  /// Dietary restriction filters (recipe must be safe for this diet).
  static const List<FilterOption> dietaryFilters = [
    FilterOption(
      id: 'vegetarian',
      label: 'Vegetarisk',
      icon: Icons.eco_outlined,
      value: 'vegetarisk',
    ),
    FilterOption(
      id: 'vegan',
      label: 'Vegansk',
      icon: Icons.eco_outlined,
      value: 'vegansk',
    ),
    FilterOption(
      id: 'pescetarian',
      label: 'Pescetarian',
      icon: Icons.set_meal,
      value: 'pescetarian',
    ),
    FilterOption(
      id: 'halal',
      label: 'Halalanpassad',
      icon: Icons.restaurant,
      value: 'halalanpassad',
    ),
    FilterOption(
      id: 'kid-friendly',
      label: 'Barnvänlig',
      icon: Icons.child_care,
      value: 'barnvänlig',
    ),
  ];
}
