/// The menu behind a box card in "Skafferiet" (BUT-2486, part 5; approved
/// mockup `but-2486/matlador-kyl-frys.html`, screen 3), in the app's shared
/// list sheet.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

enum MealBoxAction { plan, move, edit, remove }

Future<MealBoxAction?> showMealBoxActionsSheet(
  BuildContext context,
  MealBox box,
) {
  final l10n = context.l10n;
  final toFreezer = box.location == MealBoxLocation.fridge;
  return showButleryListSheet<MealBoxAction>(
    context,
    title: l10n.mealBoxActionsTitle(box.recipeTitle, box.remaining),
    rows: (sheetContext) {
      void choose(MealBoxAction action) =>
          Navigator.of(sheetContext).pop(action);
      return [
        ButleryItemRow(
          key: const ValueKey('meal-box-action-plan'),
          padded: false,
          leadingIcon: ButleryIcons.calendar,
          title: l10n.mealBoxActionPlan,
          subtitle: l10n.mealBoxActionPlanHint,
          showChevron: true,
          onTap: () => choose(MealBoxAction.plan),
        ),
        if (box.remaining >= 1)
          ButleryItemRow(
            key: const ValueKey('meal-box-action-move'),
            padded: false,
            leadingIcon: ButleryIcons.move,
            title: toFreezer
                ? l10n.mealBoxActionMoveToFreezer
                : l10n.mealBoxActionMoveToFridge,
            subtitle: l10n.mealBoxActionMoveHint,
            showChevron: true,
            onTap: () => choose(MealBoxAction.move),
          ),
        ButleryItemRow(
          key: const ValueKey('meal-box-action-edit'),
          padded: false,
          leadingIcon: ButleryIcons.pencil,
          title: l10n.mealBoxActionEdit,
          showChevron: true,
          onTap: () => choose(MealBoxAction.edit),
        ),
        ButleryItemRow(
          key: const ValueKey('meal-box-action-remove'),
          padded: false,
          leadingIcon: ButleryIcons.trash2,
          title: l10n.mealBoxActionRemove,
          danger: true,
          onTap: () => choose(MealBoxAction.remove),
        ),
      ];
    },
  );
}
