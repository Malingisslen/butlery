// lib/widgets/common/list/section_band.dart
//
// The one heading that opens a group of rows in the shopping lists and the
// pantry: a bar on the
// left, the title in capitals, a count at the right and, when the group
// folds, a chevron. A view names the group and what to count; it never draws
// its own bar, plate or chevron.
library;

import 'package:butlery/widgets/common/press_fill.dart';
import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// What the band says about its group.
enum SectionBandTone {
  /// An ink bar and ink title: a group like any other.
  standard,

  /// A saffron bar and warning-coloured title: the group needs looking at
  /// soon, as the pantry's "Utgår snart".
  warning,
}

class SectionBand extends StatelessWidget {
  static const double _barWidth = 3;

  const SectionBand({
    required this.title,
    this.count,
    this.expanded,
    this.onTap,
    this.tone = SectionBandTone.standard,
    this.plate = true,
    super.key,
  });

  final String title;

  /// Right-hand text.
  final String? count;

  /// Null draws no chevron; true points up (open), false points down
  /// (folded).
  final bool? expanded;

  /// Folds or opens the group. Null makes the band a plain heading.
  final VoidCallback? onTap;

  final SectionBandTone tone;

  /// A tinted plate behind the band: the surface.raised wash, or the warning
  /// tint on a [SectionBandTone.warning] band.
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warning = tone == SectionBandTone.warning;
    final barColor = warning
        ? AppModeColors.actionPrimary(cs.brightness)
        : cs.onSurface;
    final countColor = warning
        ? AppModeColors.textWarning(cs.brightness)
        : cs.onSurfaceVariant;
    final folded = expanded;

    final band = Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.sectionBandHeight,
      ),
      decoration: BoxDecoration(
        color: plate
            ? (warning
                  ? context.modeColors.surfaceTintWarning
                  : cs.surfaceContainerHighest)
            : null,
        border: Border(
          left: BorderSide(color: barColor, width: _barWidth),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.space12,
        end: AppDimensions.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: SectionHeading(
              title,
              tone: warning
                  ? SectionHeadingTone.warning
                  : SectionHeadingTone.strong,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppDimensions.space8),
            Text(
              count!,
              style: AppTextStyles.labelSmall.copyWith(
                color: countColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (folded != null) ...[
            const SizedBox(width: AppDimensions.space4),
            ButleryIcon(
              folded ? ButleryIcons.chevronUp : ButleryIcons.chevronDown,
              color: cs.onSurfaceVariant,
              size: AppDimensions.iconSizeS,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return band;
    return Semantics(
      label: count == null ? title : '$title, $count',
      button: true,
      header: true,
      expanded: folded,
      onTap: onTap,
      excludeSemantics: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Center(child: band),
          ),
        ),
      ),
    );
  }
}
