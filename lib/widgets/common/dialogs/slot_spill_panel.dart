// lib/widgets/common/dialogs/slot_spill_panel.dart
//
// BUT-2153: the slot picker's choice for recipes that do not fit, made
// before anything is written (Skarmar v12 etapp 9 #flermeny). It replaces a
// snackbar button that wrote a whole extra week, which broke produktregler
// § 2.4: the snackbar is the undo channel, never the action channel.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';

class SlotSpillPanel extends StatelessWidget {
  const SlotSpillPanel({
    super.key,
    required this.maxHeight,
    required this.placed,
    required this.titles,
    required this.weekNumber,
    required this.nextWeekNumber,
    required this.onNextWeek,
    required this.onChooseMore,
    required this.onPlaceOnly,
  });

  /// The panel scrolls past this, so a short sheet or large text keeps the
  /// grid above it and every button reachable.
  final double maxHeight;

  /// How many of [titles] fit, in order, from the chosen start.
  final int placed;

  /// The chosen recipes' titles in the order they are placed.
  final List<String> titles;

  final int weekNumber;
  final int nextWeekNumber;
  final VoidCallback onNextWeek;
  final VoidCallback onChooseMore;
  final VoidCallback onPlaceOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final rest = titles.sublist(placed);
    // The ones that do not fit are named: "3 fick inte plats" tells nobody
    // which three.
    final names = PartialOutcome.joinNames(rest, l.partialOutcomeListAnd);
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingMd,
                AppDimensions.spacingLg,
                AppDimensions.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.slotSpillHeading(placed, titles.length),
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    l.slotSpillBody(rest.length, weekNumber, names),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: onNextWeek,
                      child: Text(
                        placed == 0
                            ? l.slotSpillAllNextWeek(nextWeekNumber)
                            : l.slotSpillNextWeek(
                                placed,
                                rest.length,
                                nextWeekNumber,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onChooseMore,
                      child: Text(l.slotSpillChooseMore),
                    ),
                  ),
                  if (placed > 0) ...[
                    const SizedBox(height: AppDimensions.spacingSm),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onPlaceOnly,
                        child: Text(l.slotSpillPlaceOnly(placed)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
