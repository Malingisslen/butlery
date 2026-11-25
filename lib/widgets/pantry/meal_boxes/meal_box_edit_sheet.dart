/// "Ändra antal och datum" for one box (BUT-2486, part 5).
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/meal_boxes_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_stepper.dart';

Future<void> showMealBoxEditSheet(
  BuildContext context,
  MealBox box,
  MealBoxesViewModel viewModel,
) {
  return showButlerySheet<void>(
    context: context,
    builder: (_) => MealBoxEditSheet(box: box, viewModel: viewModel),
  );
}

class MealBoxEditSheet extends StatelessWidget {
  const MealBoxEditSheet({
    required this.box,
    required this.viewModel,
    super.key,
  });

  final MealBox box;
  final MealBoxesViewModel viewModel;

  Future<void> _setRemaining(BuildContext context, MealBox now, int n) async {
    final snackBars = CapturedSnackBars.capture(context);
    final failed = context.l10n.mealBoxChangeFailed;
    if (!await viewModel.setRemaining(now, n)) {
      snackBars.showFailure(what: failed);
    }
  }

  Future<void> _pickDate(BuildContext context, MealBox now) async {
    final snackBars = CapturedSnackBars.capture(context);
    final failed = context.l10n.mealBoxDateFailed;
    final today = clock.now();
    final latest = DateTime(today.year, today.month, today.day);
    final stored = DateTime(
      now.storedOn.year,
      now.storedOn.month,
      now.storedOn.day,
    );
    final initial = stored.isAfter(latest) ? latest : stored;
    final yearAgo = latest.subtract(const Duration(days: 365));
    // A freezer box can be older than a year; the picker refuses an initial
    // date before its first one.
    final earliest = initial.isBefore(yearAgo) ? initial : yearAgo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: latest,
      switchToInputEntryModeIcon: const ButleryIcon(ButleryIcons.pencil),
      switchToCalendarEntryModeIcon: const ButleryIcon(ButleryIcons.calendar),
    );
    if (picked == null) return;
    if (!await viewModel.setStoredOn(now, picked)) {
      snackBars.showFailure(what: failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return SafeArea(
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final now = viewModel.byId(box.id) ?? box;
          final locked = now.takes.isNotEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space16,
                  0,
                  AppDimensions.space16,
                  AppDimensions.space8,
                ),
                child: Text(
                  now.recipeTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              ButleryItemRow(
                title: l10n.mealBoxEditCountLabel,
                trailing: MealBoxStepper(
                  value: now.remaining,
                  max: MealBox.maxCount - now.taken,
                  fewerLabel: l10n.a11yMealBoxFewer(now.recipeTitle),
                  moreLabel: l10n.a11yMealBoxMore(now.recipeTitle),
                  onChanged: (n) => _setRemaining(context, now, n),
                ),
              ),
              Semantics(
                label: l10n.a11yMealBoxEditDate(now.recipeTitle),
                child: ButleryItemRow(
                  key: const ValueKey('meal-box-edit-date'),
                  leadingIcon: ButleryIcons.calendar,
                  title: l10n.mealBoxEditDateLabel,
                  subtitle: DateFormat.yMMMd(locale).format(now.storedOn),
                  enabled: !locked,
                  showChevron: !locked,
                  onTap: locked ? null : () => _pickDate(context, now),
                ),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  child: Text(
                    l10n.mealBoxEditDateLocked,
                    key: const ValueKey('meal-box-edit-date-locked'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space16,
                  AppDimensions.space16,
                  AppDimensions.space16,
                  0,
                ),
                child: ActionButtons.primaryButton(
                  context,
                  key: const ValueKey('meal-box-edit-done'),
                  label: l10n.commonDone,
                  isExpanded: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
