/// "UR KYLEN OCH FRYSEN" in the lunchbox sheet (BUT-2486, part 5; approved
/// mockup `but-2486/matlador-kyl-frys.html`, screen 4): the fridge and
/// freezer boxes a lunch can be taken from.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_ui.dart';

/// Starts reading the boxes for the lunch sheet, or returns null with the
/// meal-box flag off, when nothing is read. The future never fails: null
/// inside it means the boxes could not be read, which the sheet shows as a
/// muted row.
Future<List<MealBox>?>? startLunchboxStockLoad({
  bool Function()? enabled,
  MealBoxService Function()? service,
}) {
  if (!(enabled ?? mealBoxesEnabled)()) return null;
  return Future<List<MealBox>?>(
    () => (service ?? ServiceLocator.get<MealBoxService>)().list(),
  ).then<List<MealBox>?>(
    (boxes) => boxes,
    onError: (Object e) {
      AppLogger.warning('Lunch sheet could not read meal boxes: $e');
      return null;
    },
  );
}

/// The box a saved stock lunch takes from, rebuilt from the lunch's own copy
/// of it for when the loaded list lacks the box.
MealBox mealBoxOfLunch(Lunchbox lunch) => MealBox(
  id: lunch.mealBoxId!,
  recipeId: lunch.recipeId,
  recipeTitle: lunch.recipeTitle!,
  location: lunch.mealBoxLocation ?? MealBoxLocation.fridge,
  storedOn: lunch.mealBoxStoredOn!,
);

class LunchboxStockSection extends StatelessWidget {
  const LunchboxStockSection({
    required this.loading,
    required this.failed,
    required this.stock,
    required this.chosen,
    required this.onSelect,
    super.key,
  });

  final bool loading;
  final bool failed;

  final List<MealBox> stock;

  /// The box this lunch takes from, shown even with nothing left (its own
  /// take is what emptied it) and even when [stock] lacks it.
  final MealBox? chosen;
  final ValueChanged<MealBox> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final boxes = [
      for (final box in stock)
        if (box.remaining > 0 || box.id == chosen?.id) box,
      if (chosen != null && !stock.any((b) => b.id == chosen!.id)) chosen!,
    ];
    Widget muted(String text, Key key) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      child: Text(
        text,
        key: key,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space16,
            AppDimensions.space16,
            AppDimensions.space16,
            AppDimensions.space4,
          ),
          child: SectionHeading(
            l10n.lunchboxStockHeading,
            tone: SectionHeadingTone.emphasis,
          ),
        ),
        for (final box in boxes)
          ButleryItemRow(
            key: ValueKey('lunchbox-stock-${box.id}'),
            leadingIcon: mealBoxIcon(box.location),
            title: box.recipeTitle,
            titleMaxLines: 2,
            emphasised: true,
            subtitle: box.location == MealBoxLocation.freezer
                ? l10n.mealBoxLunchSubtitleFreezer(box.remaining)
                : l10n.mealBoxLunchSubtitleFridge(box.remaining),
            selected: box.id == chosen?.id,
            showCheck: true,
            onTap: () => onSelect(box),
          ),
        if (loading && boxes.isEmpty)
          muted(l10n.mealBoxesLoading, const ValueKey('lunchbox-stock-loading'))
        else if (failed && boxes.isEmpty)
          muted(
            l10n.mealBoxesLoadFailed,
            const ValueKey('lunchbox-stock-failed'),
          )
        else if (boxes.isEmpty)
          muted(
            l10n.lunchboxStockEmpty,
            const ValueKey('lunchbox-stock-empty'),
          ),
      ],
    );
  }
}
