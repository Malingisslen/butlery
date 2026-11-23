import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// Quick picks on an empty week: one tap fills the prompt and generates,
/// with rules over the user's own tagged recipes and no AI call.
class VeckomenyQuickPicks extends StatelessWidget {
  const VeckomenyQuickPicks({
    super.key,
    required this.onPick,
  });

  /// [prompt] is parser input, so it stays Swedish whatever the UI language.
  final void Function(String prompt, {required bool pantryFocus}) onPick;

  /// One dinner for each day left of the ISO week, today included.
  @visibleForTesting
  static int dinnersLeftThisWeek([DateTime? now]) =>
      DateTime.sunday + 1 - (now ?? clock.now()).weekday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dinners = dinnersLeftThisWeek();
    final prompt = dinners == 1 ? '1 middag' : '$dinners middagar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.menuQuickPicksTitle),
        ButleryItemRow(
          leadingIcon: ButleryIcons.clock,
          title: l10n.menuQuickFastTitle,
          subtitle: l10n.menuQuickFastSubtitle,
          showChevron: true,
          onTap: () => onPick('$prompt snabba', pantryFocus: false),
        ),
        ButleryItemRow(
          leadingIcon: ButleryIcons.refrigerator,
          title: l10n.menuQuickPantryTitle,
          subtitle: l10n.menuQuickPantrySubtitle,
          showChevron: true,
          onTap: () => onPick(prompt, pantryFocus: true),
        ),
      ],
    );
  }
}
