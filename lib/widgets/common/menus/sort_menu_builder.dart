import 'package:flutter/material.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

/// Helper for building the sort choices used across recipe views.
class SortMenuBuilder {
  /// The choices of a [ButleryMenu] for recipe sorting; the current one
  /// carries the direction arrow.
  static List<ButleryMenuChoice<SortCriteria>> buildChoices({
    required BuildContext context,
    required SortCriteria currentSort,
    required bool sortAscending,
  }) {
    final l10n = context.l10n;
    ButleryMenuChoice<SortCriteria> choice(
      SortCriteria criteria,
      String label,
      IconData icon,
    ) {
      final isSelected = currentSort == criteria;
      return ButleryMenuChoice(
        value: criteria,
        label: label,
        icon: icon,
        selected: isSelected,
        trailingIcon: isSelected
            ? (sortAscending ? ButleryIcons.arrowUp : ButleryIcons.arrowDown)
            : null,
      );
    }

    return [
      choice(SortCriteria.title, l10n.sortTitle, ButleryIcons.type),
      choice(SortCriteria.time, l10n.sortTime, ButleryIcons.clock),
      choice(SortCriteria.rating, l10n.sortRating, ButleryIcons.star),
      choice(SortCriteria.mealType, l10n.sortMealType, ButleryIcons.utensils),
      choice(
        SortCriteria.lastCooked,
        l10n.sortLastCooked,
        ButleryIcons.history,
      ),
      choice(
        SortCriteria.cookCount,
        l10n.sortCookCount,
        ButleryIcons.barChart,
      ),
      choice(SortCriteria.newest, l10n.sortNewest, ButleryIcons.clock),
      choice(SortCriteria.random, l10n.shuffleRecipes, ButleryIcons.shuffle),
    ];
  }
}
