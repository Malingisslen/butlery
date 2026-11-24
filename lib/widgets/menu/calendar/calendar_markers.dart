/// The small marks a calendar cell can carry, and the legend that names them.
///
/// One place for the marks, so the table cell, the legend and the Övrigt sheet
/// draw a mark the same way: a green dot for a dish the last placement added, a
/// triangle for a dish someone at the table cannot eat, a person and a number
/// when only some of the household are home.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';

const double _kDotSize = 8;

/// A dish from the latest generation or placement ("ny").
class CalendarNewDot extends StatelessWidget {
  const CalendarNewDot({super.key});

  static const Key dotKey = ValueKey('calendar-new-dot');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.weeklyMenuNewMark,
      child: ButleryDisc(
        paintOnly: true,
        key: dotKey,
        color: context.modeColors.success,
        child: const SizedBox.square(dimension: _kDotSize),
      ),
    );
  }
}

/// A dish someone eating this meal cannot eat. Icon and words, not colour
/// alone: the tooltip and the screen-reader label say what is wrong and name
/// nobody.
class CalendarAllergenMark extends StatelessWidget {
  const CalendarAllergenMark({super.key});

  static const Key markKey = ValueKey('menu-allergen-warning');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.menuAllergenUnsafeAtMeal;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: ButleryIcon(
          ButleryIcons.triangleAlert,
          key: markKey,
          size: AppDimensions.iconSize14,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

/// A lunch that is a lunchbox (BUT-2486).
class CalendarLunchboxMark extends StatelessWidget {
  const CalendarLunchboxMark({super.key});

  static const Key markKey = ValueKey('calendar-lunchbox-mark');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.lunchboxMark;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: ButleryIcon(
          ButleryIcons.clipboard,
          key: markKey,
          size: AppDimensions.iconSize14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A lunchbox whose dish could not be checked against the allergens of the
/// people taking it (BUT-2486). Says so in words, never passes as safe.
class CalendarUnjudgedMark extends StatelessWidget {
  const CalendarUnjudgedMark({super.key});

  static const Key markKey = ValueKey('calendar-unjudged-mark');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.lunchboxUnjudgedMark;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: ButleryIcon(
          ButleryIcons.circleHelp,
          key: markKey,
          size: AppDimensions.iconSize14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// How many are home, drawn only when it is not everyone.
class CalendarPresenceMark extends StatelessWidget {
  const CalendarPresenceMark({super.key, required this.count});

  final int count;

  static const Key markKey = ValueKey('calendar-presence-mark');

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: context.l10n.menuPresencePortions(count),
      child: ExcludeSemantics(
        child: Row(
          key: markKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              ButleryIcons.user,
              size: AppDimensions.iconSizeXs,
              color: color,
            ),
            const SizedBox(width: AppDimensions.space4 / 2),
            Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The placement order as a number in the cell, in the text accent colour
/// (text.accent.onRaised: #8A5212 light, #DCA968 dark). The number is announced
/// through the cell's semantics value, so it is excluded here.
class PlacementOrderNumber extends StatelessWidget {
  const PlacementOrderNumber({super.key, required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        '$order',
        key: ValueKey('placement-order-$order'),
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// The line under the table that names the marks the week actually shows.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({
    super.key,
    required this.showNew,
    required this.showAllergen,
    required this.showPresence,
    this.showLunchbox = false,
    this.showUnjudged = false,
  });

  final bool showNew;
  final bool showAllergen;
  final bool showPresence;
  final bool showLunchbox;
  final bool showUnjudged;

  static const Key legendKey = ValueKey('calendar-legend');

  @override
  Widget build(BuildContext context) {
    if (!showNew &&
        !showAllergen &&
        !showPresence &&
        !showLunchbox &&
        !showUnjudged) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = AppTextStyles.labelSmallBold.copyWith(color: color);
    Widget entry(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: mark),
        const SizedBox(width: AppDimensions.space4),
        Text(text, style: style),
      ],
    );
    return Padding(
      key: legendKey,
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppDimensions.space16,
        runSpacing: AppDimensions.space4,
        children: [
          if (showNew)
            entry(
              ButleryDisc(
                paintOnly: true,
                color: context.modeColors.success,
                child: const SizedBox.square(dimension: _kDotSize),
              ),
              l10n.weeklyMenuLegendNew,
            ),
          if (showAllergen)
            entry(
              ButleryIcon(
                ButleryIcons.triangleAlert,
                size: AppDimensions.iconSize14,
                color: Theme.of(context).colorScheme.error,
              ),
              l10n.weeklyMenuLegendAllergen,
            ),
          if (showPresence)
            entry(
              ButleryIcon(
                ButleryIcons.user,
                size: AppDimensions.iconSizeXs,
                color: color,
              ),
              l10n.weeklyMenuLegendPresence,
            ),
          if (showLunchbox)
            entry(
              ButleryIcon(
                ButleryIcons.clipboard,
                size: AppDimensions.iconSize14,
                color: color,
              ),
              l10n.lunchboxMark,
            ),
          if (showUnjudged)
            entry(
              ButleryIcon(
                ButleryIcons.circleHelp,
                size: AppDimensions.iconSize14,
                color: color,
              ),
              l10n.lunchboxUnjudgedMark,
            ),
        ],
      ),
    );
  }
}
