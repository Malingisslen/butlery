import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// What a ready-made wish puts in the prompt field. The fill is only valid
/// while the field still holds exactly [text]; the view enforces that.
@immutable
class MenuWishFill {
  const MenuWishFill({
    required this.text,
    required this.pantryFocus,
    required this.sourceId,
  });

  /// Parser input, so it stays Swedish whatever the UI language.
  final String text;
  final bool pantryFocus;

  /// Which chip made the fill, so that chip can show as selected.
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is MenuWishFill &&
      other.text == text &&
      other.pantryFocus == pantryFocus &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(text, pantryFocus, sourceId);
}

/// Ready-made wishes on an empty week: a tap fills the prompt field and
/// leaves generating to the user, so the wish can be edited first. The rules
/// run over the user's own tagged recipes, with no AI call.
class VeckomenyQuickPicks extends StatelessWidget {
  const VeckomenyQuickPicks({
    super.key,
    required this.onPick,
    this.activeSourceId,
  });

  static const String fastSourceId = 'builtin-fast';
  static const String pantrySourceId = 'builtin-pantry';

  final ValueChanged<MenuWishFill> onPick;

  /// The chip whose fill is still in the field, shown as selected.
  final String? activeSourceId;

  /// One dinner for each day left of the ISO week, today included.
  @visibleForTesting
  static int dinnersLeftThisWeek([DateTime? now]) =>
      DateTime.sunday + 1 - (now ?? clock.now()).weekday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dinners = dinnersLeftThisWeek();
    final prompt = dinners == 1 ? '1 middag' : '$dinners middagar';
    final fills = [
      (
        label: l10n.menuQuickFastTitle,
        fill: MenuWishFill(
          text: '$prompt snabba',
          pantryFocus: false,
          sourceId: fastSourceId,
        ),
      ),
      (
        label: l10n.menuQuickPantryTitle,
        fill: MenuWishFill(
          text: prompt,
          pantryFocus: true,
          sourceId: pantrySourceId,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.menuQuickPicksTitle),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final pick in fills)
              ButleryFilterChip(
                key: ValueKey('wish-chip-${pick.fill.sourceId}'),
                label: pick.label,
                selected: activeSourceId == pick.fill.sourceId,
                onSelected: (_) => onPick(pick.fill),
              ),
          ],
        ),
      ],
    );
  }
}
