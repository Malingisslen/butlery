/// The day + meal a bulk move goes to (BUT-1043). Lifted out of
/// `calendar_weekly_menu_widget.dart` so the orchestrator stays its size.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// Day + slot target picker for bulk-move. Returns null on dismiss. A lunch
/// that is a lunchbox in [plan] is left out (BUT-2486): a dish moved there
/// would sit unseen under the box.
Future<(DayOfWeek, MealSlot)?> showMoveTargetSheet(
  BuildContext context, {
  WeeklyMenuPlan? plan,
}) async {
  return showButlerySheet<(DayOfWeek, MealSlot)>(
    context: context,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Text(
                sheetContext.l10n.weeklyMenuMoveSheetTitle,
                style: AppTextStyles.titleSmall.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final day in DayOfWeek.values)
                      for (final slot in MealSlot.values)
                        if (!(plan?.hasLunchboxAt(day, slot) ?? false))
                          ButleryItemRow(
                            leading: ButleryIcon(
                              ButleryIcons.utensils,
                              color: cs.secondary,
                            ),
                            title: '${day.displayLabel} · ${slot.displayLabel}',
                            onTap: () =>
                                Navigator.of(sheetContext).pop((day, slot)),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
