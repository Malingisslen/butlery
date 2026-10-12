/// The sheet behind an Övrigt cell: every dish in the place, and a way to add
/// one. The cell shows the first dish and "+N", so this is where the rest are
/// reached.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

sealed class OvrigtSheetResult {
  const OvrigtSheetResult();
}

/// A dish was chosen.
class OvrigtOpenDish extends OvrigtSheetResult {
  const OvrigtOpenDish(this.recipeId);
  final String recipeId;
}

/// "Lägg till rätt".
class OvrigtAddDish extends OvrigtSheetResult {
  const OvrigtAddDish();
}

Future<OvrigtSheetResult?> showOvrigtSheet(
  BuildContext context, {
  required String dayName,
  required List<WeeklyMenuPlanEntry> entries,
}) {
  return showButlerySheet<OvrigtSheetResult>(
    context: context,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space24,
            0,
            AppDimensions.space24,
            AppDimensions.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.weeklyMenuOvrigtSheetTitle(dayName),
                style: AppTextStyles.headlineSmall.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.space12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (_, i) => Semantics(
                    button: true,
                    label: sheetContext.l10n.a11yMenuPlanRecipeOpen,
                    child: Material(
                      type: MaterialType.transparency,
                      child: PressFill(
                        surface: PressSurface.base,
                        child: InkWell(
                          onTap: () => Navigator.pop(
                            sheetContext,
                            OvrigtOpenDish(entries[i].recipeId),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppDimensions.minTouchTarget,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entries[i].recipeTitle,
                                    style: AppTextStyles.labelLargeBold
                                        .copyWith(
                                          color: cs.onSurface,
                                        ),
                                  ),
                                ),
                                ButleryIcon(
                                  ButleryIcons.chevronRight,
                                  size: AppDimensions.iconSizeM,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              ActionButtons.outlinedButton(
                sheetContext,
                onPressed: () =>
                    Navigator.pop(sheetContext, const OvrigtAddDish()),
                icon: ButleryIcons.plus,
                label: sheetContext.l10n.weeklyMenuOvrigtSheetAdd,
                isExpanded: true,
              ),
            ],
          ),
        ),
      );
    },
  );
}
