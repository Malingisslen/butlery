/// The one sheet after "Klart": leftovers as meal boxes and the pantry
/// deduction together (BUT-2486, part 5; approved mockup
/// `but-2486/matlador-kyl-frys.html`, screen 2).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/butlery_segment_switch.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_stepper.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_ui.dart';

/// What the sheet is opened with.
class CookedLeftoversOffer {
  const CookedLeftoversOffer({
    required this.portions,
    required this.eaters,
    required this.defaultCount,
    required this.pantryTakes,
    required this.editPantry,
  });

  final int portions;

  /// The household size: how many ate.
  final int eaters;
  final int defaultCount;

  /// What the pantry plan would take; empty hides the pantry section.
  final List<CookedPantryTake> pantryTakes;

  /// Opens the pantry selection; null leaves the selection as it is.
  final Future<List<CookedPantryTake>?> Function(
    BuildContext context,
    List<CookedPantryTake> takes,
  )
  editPantry;
}

/// What "Spara" answers with.
class CookedLeftoversResult {
  const CookedLeftoversResult({
    required this.boxes,
    required this.location,
    required this.pantryTakes,
  });

  final int boxes;
  final MealBoxLocation location;
  final List<CookedPantryTake> pantryTakes;
}

Future<CookedLeftoversResult?> showCookedLeftoversSheet(
  BuildContext context,
  CookedLeftoversOffer offer,
) {
  return showButlerySheet<CookedLeftoversResult>(
    context: context,
    maxHeightFraction: 0.9,
    builder: (_) => CookedLeftoversSheet(offer: offer),
  );
}

class CookedLeftoversSheet extends StatefulWidget {
  const CookedLeftoversSheet({required this.offer, super.key});

  final CookedLeftoversOffer offer;

  @override
  State<CookedLeftoversSheet> createState() => _CookedLeftoversSheetState();
}

class _CookedLeftoversSheetState extends State<CookedLeftoversSheet> {
  late int _boxes = widget.offer.defaultCount.clamp(0, MealBox.maxCount);
  MealBoxLocation _location = MealBoxLocation.fridge;
  late List<CookedPantryTake> _takes = widget.offer.pantryTakes;

  bool get _canSave => _boxes > 0 || _takes.isNotEmpty;

  Future<void> _editPantry() async {
    final chosen = await widget.offer.editPantry(context, _takes);
    if (chosen == null || !mounted) return;
    setState(() => _takes = chosen);
  }

  void _save() => Navigator.pop(
    context,
    CookedLeftoversResult(
      boxes: _boxes,
      location: _location,
      pantryTakes: _takes,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final offer = widget.offer;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space12,
          AppDimensions.space24,
          AppDimensions.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cookedLeftoversTitle(offer.portions),
              style: AppTextStyles.titleSmall.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppDimensions.space4),
            SectionHeading(
              l10n.cookedLeftoversOverHeading,
              tone: SectionHeadingTone.emphasis,
            ),
            ButleryItemRow(
              padded: false,
              leadingIcon: mealBoxIcon(_location),
              title: l10n.cookedLeftoversBoxes,
              subtitle: l10n.cookedLeftoversEaters(offer.eaters),
              trailing: MealBoxStepper(
                value: _boxes,
                fewerLabel: l10n.a11yCookedLeftoversFewer,
                moreLabel: l10n.a11yCookedLeftoversMore,
                onChanged: (next) => setState(() => _boxes = next),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space8),
              child: ButlerySegmentSwitch<MealBoxLocation>(
                choices: [
                  for (final location in MealBoxLocation.values)
                    (location, mealBoxLocationLabel(l10n, location)),
                ],
                selected: _location,
                onChanged: (location) => setState(() => _location = location),
              ),
            ),
            if (offer.pantryTakes.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space12),
              SectionHeading(
                l10n.cookedLeftoversPantryHeading,
                tone: SectionHeadingTone.emphasis,
              ),
              ButleryItemRow(
                key: const ValueKey('leftovers-pantry'),
                padded: false,
                title: l10n.cookedLeftoversPantrySummary(_takes.length),
                titleMaxLines: 1,
                subtitleWidget: Text(
                  _takes.map((t) => t.item.ingredientName).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionBase.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  l10n.cookedLeftoversChange,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                showChevron: true,
                onTap: _editPantry,
              ),
            ],
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                ButleryTextButton(
                  key: const ValueKey('leftovers-skip'),
                  label: l10n.cookedPantrySkip,
                  tone: ButleryTextButtonTone.muted,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  flex: 3,
                  child: FormButton(
                    key: const ValueKey('leftovers-save'),
                    label: l10n.commonSave,
                    expand: true,
                    onPressed: _canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
